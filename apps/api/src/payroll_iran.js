import { pool, withTransaction } from './db.js';
import { requireRole } from './auth.js';

const n = v => Number(v || 0);
const text = v => String(v ?? '').trim();
const fail = (message, status = 400, details = null) => {
  const e = new Error(message);
  e.status = status;
  e.details = details;
  throw e;
};
const wrap = fn => async (req, res) => {
  try { await fn(req, res); }
  catch (e) {
    console.error('payroll error', e);
    res.status(e.status || 400).json({ error: e.message, details: e.details || undefined });
  }
};
const parseJson = v => {
  if (!v) return {};
  if (typeof v === 'object') return v;
  try { return JSON.parse(v); } catch { return {}; }
};

const persianFmt = new Intl.DateTimeFormat('en-US-u-ca-persian', {
  year: 'numeric', month: 'numeric', day: 'numeric', timeZone: 'UTC'
});
function jalaliParts(date) {
  const parts = Object.fromEntries(
    persianFmt.formatToParts(date)
      .filter(x => x.type !== 'literal')
      .map(x => [x.type, Number(x.value)])
  );
  return { year: parts.year, month: parts.month, day: parts.day };
}
function jalaliMonthBounds(year, month) {
  const scanStart = new Date(Date.UTC(year + 621, 1, 1));
  const scanEnd = new Date(Date.UTC(year + 622, 3, 30));
  let start = null;
  let next = null;
  for (let d = new Date(scanStart); d <= scanEnd; d.setUTCDate(d.getUTCDate() + 1)) {
    const x = jalaliParts(d);
    if (x.year === year && x.month === month && x.day === 1) {
      start = new Date(d);
      break;
    }
  }
  if (!start) fail('تبدیل ابتدای ماه شمسی انجام نشد.', 422);
  const nextMonth = month === 12 ? 1 : month + 1;
  const nextYear = month === 12 ? year + 1 : year;
  for (let d = new Date(start); d <= scanEnd; d.setUTCDate(d.getUTCDate() + 1)) {
    const x = jalaliParts(d);
    if (x.year === nextYear && x.month === nextMonth && x.day === 1) {
      next = new Date(d);
      break;
    }
  }
  if (!next) fail('تبدیل پایان ماه شمسی انجام نشد.', 422);
  const end = new Date(next);
  end.setUTCDate(end.getUTCDate() - 1);
  return {
    start: start.toISOString().slice(0, 10),
    end: end.toISOString().slice(0, 10),
    days: Math.round((next - start) / 86400000)
  };
}
function taxByBrackets(amount, params) {
  const base = Math.max(0, n(amount));
  const exemption = n(params.tax_monthly_exemption);
  if (base <= exemption) return 0;
  let tax = 0;
  const brackets = Array.isArray(params.tax_brackets) ? params.tax_brackets : [];
  for (const b of brackets) {
    const from = n(b.from);
    const to = b.to == null ? Infinity : n(b.to);
    if (base <= from) continue;
    const taxable = Math.max(0, Math.min(base, to) - from);
    tax += taxable * n(b.rate) / 100;
  }
  return Math.round(tax);
}
async function audit(req, action, entityType, entityId, payload) {
  try {
    await pool.execute(
      `INSERT INTO audit_logs(company_id,user_id,action,entity_type,entity_id,after_json,ip_address,user_agent)
       VALUES (?,?,?,?,?,?,?,?)`,
      [
        req.user.companyId, Number(req.user.sub), action, entityType, entityId,
        JSON.stringify(payload || {}), req.ip, req.headers['user-agent'] || null
      ]
    );
  } catch (e) {
    console.error('payroll audit failed', e.message);
  }
}
async function nextNo(conn, companyId, type, prefix) {
  const lock = `trz:payroll:${companyId}:${type}`;
  const [[got]] = await conn.query('SELECT GET_LOCK(?,5) got', [lock]);
  if (!got?.got) fail('شماره‌گذاری سند موقتاً درگیر است.', 409);
  try {
    let [rows] = await conn.execute(
      `SELECT id,last_number,prefix,pad_length
       FROM document_sequences
       WHERE company_id=? AND branch_id IS NULL AND fiscal_year_id IS NULL AND document_type=?
       ORDER BY id LIMIT 1 FOR UPDATE`,
      [companyId, type]
    );
    if (!rows.length) {
      await conn.execute(
        `INSERT INTO document_sequences(company_id,document_type,prefix,last_number,pad_length)
         VALUES (?,?,?,0,6)`,
        [companyId, type, prefix]
      );
      [rows] = await conn.execute(
        `SELECT id,last_number,prefix,pad_length
         FROM document_sequences
         WHERE company_id=? AND branch_id IS NULL AND fiscal_year_id IS NULL AND document_type=?
         ORDER BY id LIMIT 1 FOR UPDATE`,
        [companyId, type]
      );
    }
    const row = rows[0];
    const value = n(row.last_number) + 1;
    await conn.execute('UPDATE document_sequences SET last_number=? WHERE id=?', [value, row.id]);
    return `${row.prefix || prefix}-${String(value).padStart(Number(row.pad_length || 6), '0')}`;
  } finally {
    await conn.query('SELECT RELEASE_LOCK(?)', [lock]);
  }
}
async function getLegalParams(conn, companyId, year, start, end) {
  const [rows] = await conn.execute(
    `SELECT *
     FROM payroll_legal_parameters
     WHERE is_active=1
       AND (company_id=? OR company_id IS NULL)
       AND (
         jalali_year=?
         OR (effective_from<=? AND (effective_to IS NULL OR effective_to>=?))
       )
     ORDER BY (company_id IS NOT NULL) DESC, (jalali_year=?) DESC, effective_from DESC, id DESC
     LIMIT 1`,
    [companyId, year, end, start, year]
  );
  if (!rows.length) fail('پارامتر قانونی حقوق و دستمزد برای این دوره تعریف نشده است.', 422);
  return { row: rows[0], params: parseJson(rows[0].parameters_json) };
}
async function postAccountingRules(conn, companyId, batchId, entryDate, amounts, userId) {
  const [existing] = await conn.execute(
    `SELECT id FROM journal_entries
     WHERE company_id=? AND source_type='PAYROLL_BATCH' AND source_id=? AND status<>'VOID'
     LIMIT 1`,
    [companyId, batchId]
  );
  if (existing.length) return { journalEntryId: existing[0].id, duplicatePrevented: true };

  const [rules] = await conn.execute(
    `SELECT * FROM accounting_rule_lines
     WHERE company_id=? AND event_code='PAYROLL_IR' AND is_active=1
     ORDER BY priority,id`,
    [companyId]
  );
  if (!rules.length) fail('قواعد حسابداری حقوق و دستمزد تنظیم نشده است.', 422);

  const entryNo = await nextNo(conn, companyId, 'JOURNAL_IR', 'JE');
  const [je] = await conn.execute(
    `INSERT INTO journal_entries
      (company_id,entry_no,entry_date,posting_date,status,source_type,source_id,description,created_by,posted_at)
     VALUES (?,?,?,?, 'POSTED','PAYROLL_BATCH',?,?,?,NOW())`,
    [companyId, entryNo, entryDate, entryDate, batchId, `ثبت حقوق و دستمزد دوره ${batchId}`, userId]
  );

  let debit = 0;
  let credit = 0;
  for (const rule of rules) {
    const amount = n(amounts[rule.amount_source]);
    if (Math.abs(amount) < 0.01) continue;
    const dr = rule.line_role === 'DEBIT' ? amount : 0;
    const cr = rule.line_role === 'CREDIT' ? amount : 0;
    debit += dr;
    credit += cr;
    await conn.execute(
      `INSERT INTO journal_lines(journal_entry_id,account_id,debit,credit,description)
       VALUES (?,?,?,?,?)`,
      [je.insertId, rule.account_id, dr, cr, `ثبت حقوق و دستمزد دوره ${batchId}`]
    );
  }
  if (Math.abs(debit - credit) > 1) {
    fail('سند حسابداری حقوق و دستمزد تراز نیست.', 422, { debit, credit, amounts });
  }
  return { journalEntryId: je.insertId, entryNo, debit, credit };
}
function componentValue(component, ratio, hourlyBase) {
  switch (component.calculation_type) {
    case 'PERCENT':
      return n(component.amount) || (hourlyBase * n(component.rate) / 100);
    case 'DAILY':
      return n(component.amount) * 30 * ratio;
    case 'HOURLY':
      return n(component.amount);
    default:
      return n(component.amount) * ratio;
  }
}

export function registerPayrollIranRoutes(app) {
  app.get(
    '/api/iran/payroll/legal-parameters',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const [rows] = await pool.execute(
        `SELECT * FROM payroll_legal_parameters
         WHERE company_id=? OR company_id IS NULL
         ORDER BY COALESCE(jalali_year,0) DESC,effective_from DESC,id DESC`,
        [req.user.companyId]
      );
      res.json(rows.map(r => ({ ...r, parameters_json: parseJson(r.parameters_json) })));
    })
  );

  app.get(
    '/api/iran/payroll/batches',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER', 'ACCOUNTANT'),
    wrap(async (req, res) => {
      const [rows] = await pool.execute(
        `SELECT pb.*,u.full_name created_by_name,
          (SELECT COUNT(*) FROM payroll_slips ps WHERE ps.payroll_batch_id=pb.id) employee_count
         FROM payroll_batches pb
         JOIN users u ON u.id=pb.created_by
         WHERE pb.company_id=?
         ORDER BY pb.year_no DESC,pb.month_no DESC,pb.id DESC`,
        [req.user.companyId]
      );
      res.json(rows);
    })
  );

  app.post(
    '/api/iran/payroll/batches',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const year = n(req.body?.yearNo);
      const month = n(req.body?.monthNo);
      if (year < 1300 || month < 1 || month > 12) fail('سال و ماه شمسی نامعتبر است.');
      const bounds = jalaliMonthBounds(year, month);
      const result = await withTransaction(async conn => {
        const legal = await getLegalParams(conn, req.user.companyId, year, bounds.start, bounds.end);
        const [r] = await conn.execute(
          `INSERT INTO payroll_batches(company_id,year_no,month_no,title,status,legal_parameter_id,created_by)
           VALUES (?,?,?,?, 'DRAFT',?,?)`,
          [
            req.user.companyId, year, month,
            req.body?.title || `حقوق ${year}/${String(month).padStart(2, '0')}`,
            legal.row.id, Number(req.user.sub)
          ]
        );
        return { id: r.insertId, periodStart: bounds.start, periodEnd: bounds.end, calendarDays: bounds.days };
      });
      await audit(req, 'CREATE', 'payroll_batch', result.id, result);
      res.status(201).json(result);
    })
  );

  app.get(
    '/api/iran/payroll/batches/:id/slips',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER', 'ACCOUNTANT'),
    wrap(async (req, res) => {
      const [rows] = await pool.execute(
        `SELECT ps.*,p.name employee_name,ep.personnel_no,ec.contract_no
         FROM payroll_slips ps
         JOIN parties p ON p.id=ps.employee_party_id
         JOIN employee_profiles ep ON ep.party_id=p.id
         JOIN employment_contracts ec ON ec.id=ps.employment_contract_id
         JOIN payroll_batches pb ON pb.id=ps.payroll_batch_id
         WHERE ps.payroll_batch_id=? AND pb.company_id=?
         ORDER BY ep.personnel_no`,
        [Number(req.params.id), req.user.companyId]
      );
      res.json(rows);
    })
  );

  app.get(
    '/api/iran/payroll/slips/:id/lines',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER', 'ACCOUNTANT'),
    wrap(async (req, res) => {
      const [rows] = await pool.execute(
        `SELECT psl.*
         FROM payroll_slip_lines psl
         JOIN payroll_slips ps ON ps.id=psl.payroll_slip_id
         JOIN payroll_batches pb ON pb.id=ps.payroll_batch_id
         WHERE psl.payroll_slip_id=? AND pb.company_id=?
         ORDER BY psl.sort_order,psl.id`,
        [Number(req.params.id), req.user.companyId]
      );
      res.json(rows);
    })
  );

  app.post(
    '/api/iran/payroll/batches/:id/calculate',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const batchId = Number(req.params.id);
      const result = await withTransaction(async conn => {
        const [batchRows] = await conn.execute(
          'SELECT * FROM payroll_batches WHERE id=? AND company_id=? FOR UPDATE',
          [batchId, req.user.companyId]
        );
        if (!batchRows.length) fail('دوره حقوق پیدا نشد.', 404);
        const batch = batchRows[0];
        if (!['DRAFT', 'CALCULATED'].includes(batch.status)) {
          fail('دوره در وضعیت قابل محاسبه مجدد نیست.', 422);
        }

        const bounds = jalaliMonthBounds(n(batch.year_no), n(batch.month_no));
        const legal = await getLegalParams(
          conn, req.user.companyId, n(batch.year_no), bounds.start, bounds.end
        );
        const p = legal.params;

        await conn.execute('DELETE FROM payroll_slips WHERE payroll_batch_id=?', [batchId]);

        const [contracts] = await conn.execute(
          `SELECT ec.*,pa.name employee_name,ep.personnel_no,ep.marital_status,
                  ep.children_count,ep.hire_date
           FROM employment_contracts ec
           JOIN parties pa ON pa.id=ec.employee_party_id
           JOIN employee_profiles ep ON ep.party_id=pa.id
           WHERE ec.company_id=?
             AND ec.status='ACTIVE'
             AND ec.start_date<=?
             AND (ec.end_date IS NULL OR ec.end_date>=?)
           ORDER BY ep.personnel_no`,
          [req.user.companyId, bounds.end, bounds.start]
        );

        let totalGross = 0;
        let totalEmployeeInsurance = 0;
        let totalEmployerInsurance = 0;
        let totalTax = 0;
        let totalOtherDeductions = 0;
        let totalLoanDeduction = 0;
        let totalNet = 0;
        const warnings = [];

        for (const contract of contracts) {
          const [attRows] = await conn.execute(
            `SELECT * FROM attendance_monthly_summaries
             WHERE company_id=? AND employee_party_id=? AND year_no=? AND month_no=?`,
            [req.user.companyId, contract.employee_party_id, batch.year_no, batch.month_no]
          );
          const att = attRows[0] || {
            calendar_days: bounds.days, work_days: bounds.days,
            overtime_hours: 0, night_hours: 0, friday_hours: 0,
            mission_days: 0, unpaid_leave_days: 0, absence_days: 0
          };
          const calendarDays = Math.max(1, n(att.calendar_days) || bounds.days);
          const workDays = Math.max(0, Math.min(calendarDays, n(att.work_days)));
          const ratio = workDays / calendarDays;

          const minimumMonthly = n(p.minimum_monthly_wage_30d) * (calendarDays / 30);
          const contractBase = n(contract.base_salary_monthly);
          const fullMonthBase = Math.max(contractBase, minimumMonthly);
          if (contractBase > 0 && contractBase < minimumMonthly) {
            warnings.push(`حقوق پایه ${contract.employee_name} کمتر از حداقل پارامتر قانونی بود.`);
          }

          const hourlyBase = fullMonthBase / Math.max(1, n(p.monthly_hours_divisor) || 220);
          const components = [];
          const add = (code, title, type, amount, insurable = false, taxable = false, sort = 100, sourceType = null, sourceId = null) => {
            amount = Math.round(n(amount));
            if (Math.abs(amount) < 1) return;
            components.push({ code, title, type, amount, insurable, taxable, sort, sourceType, sourceId });
          };

          add('BASE', 'حقوق پایه', 'EARNING', fullMonthBase * ratio, true, true, 10);
          add('HOUSING', 'حق مسکن', 'EARNING', Math.max(n(contract.housing_allowance), n(p.housing_allowance)) * ratio, Boolean(p.housing_insurable), Boolean(p.housing_taxable), 20);
          add('FOOD', 'بن / کمک‌هزینه اقلام مصرفی', 'EARNING', Math.max(n(contract.food_allowance), n(p.food_allowance)) * ratio, Boolean(p.food_insurable), Boolean(p.food_taxable), 30);

          const employedDays = contract.hire_date
            ? Math.floor((new Date(bounds.end) - new Date(contract.hire_date)) / 86400000)
            : 0;
          const seniority = employedDays >= 365
            ? Math.max(n(contract.seniority_allowance), n(p.seniority_monthly)) * ratio
            : n(contract.seniority_allowance) * ratio;
          add('SENIORITY', 'پایه سنوات', 'EARNING', seniority, Boolean(p.seniority_insurable), Boolean(p.seniority_taxable), 40);
          add('FIXED', 'مزایای ثابت قرارداد', 'EARNING', n(contract.fixed_benefits) * ratio, true, true, 50);
          add('MARRIAGE', 'حق تأهل', 'EARNING', contract.marital_status === 'MARRIED' ? n(p.marriage_allowance) * ratio : 0, Boolean(p.marriage_insurable), Boolean(p.marriage_taxable), 60);
          add('CHILD', 'حق اولاد', 'EARNING', n(contract.children_count) * n(p.child_allowance_per_child) * ratio, Boolean(p.child_insurable), Boolean(p.child_taxable), 70);
          add('OVERTIME', 'اضافه‌کاری', 'EARNING', n(att.overtime_hours) * hourlyBase * n(p.overtime_multiplier || 1.4), Boolean(p.overtime_insurable), Boolean(p.overtime_taxable), 80);

          const [customComponents] = await conn.execute(
            `SELECT * FROM contract_wage_components
             WHERE employment_contract_id=? AND is_active=1 ORDER BY id`,
            [contract.id]
          );
          for (const c of customComponents) {
            add(
              `C_${c.component_code}`, c.title, c.component_type,
              componentValue(c, ratio, hourlyBase),
              Boolean(c.is_insurable), Boolean(c.is_taxable), 90
            );
          }

          const gross = components.filter(x => x.type === 'EARNING').reduce((s, x) => s + x.amount, 0);
          const insurableRaw = components.filter(x => x.type === 'EARNING' && x.insurable).reduce((s, x) => s + x.amount, 0);
          const taxableRaw = components.filter(x => x.type === 'EARNING' && x.taxable).reduce((s, x) => s + x.amount, 0);
          const customDeductions = components.filter(x => x.type === 'DEDUCTION').reduce((s, x) => s + x.amount, 0);

          const insuranceDailyCap = n(p.minimum_daily_wage) * n(p.insurance_daily_cap_multiplier || 7);
          const insuranceCap = insuranceDailyCap > 0 ? insuranceDailyCap * workDays : insurableRaw;
          const insurable = Math.min(insurableRaw, insuranceCap || insurableRaw);
          const employeeInsurance = Math.round(insurable * n(p.employee_insurance_rate) / 100);
          const employerBaseInsurance = Math.round(insurable * n(p.employer_insurance_rate) / 100);
          const unemploymentInsurance = Math.round(insurable * n(p.unemployment_insurance_rate) / 100);
          const employerInsurance = employerBaseInsurance + unemploymentInsurance;

          let taxable = taxableRaw;
          if (p.deduct_employee_insurance_before_tax) {
            taxable = Math.max(0, taxable - employeeInsurance);
          }
          const salaryTax = taxByBrackets(taxable, p);

          const [loans] = await conn.execute(
            `SELECT * FROM employee_loans
             WHERE company_id=? AND employee_party_id=? AND status='ACTIVE'
               AND start_date<=? AND (end_date IS NULL OR end_date>=?)
             FOR UPDATE`,
            [req.user.companyId, contract.employee_party_id, bounds.end, bounds.start]
          );
          let loanDeduction = 0;
          for (const loan of loans) {
            const due = Math.min(n(loan.installment_amount), n(loan.remaining_amount));
            if (due > 0) {
              loanDeduction += due;
              add(`LOAN_${loan.id}`, `قسط ${loan.loan_no}`, 'DEDUCTION', due, false, false, 210, 'EMPLOYEE_LOAN', loan.id);
            }
          }

          const deductions = customDeductions + employeeInsurance + salaryTax + loanDeduction;
          const netPay = Math.max(0, gross - deductions);

          const [slipResult] = await conn.execute(
            `INSERT INTO payroll_slips
              (payroll_batch_id,employee_party_id,employment_contract_id,work_days,gross_earnings,
               insurable_amount,taxable_amount,employee_insurance,employer_insurance,
               unemployment_insurance,salary_tax,loan_deduction,other_deductions,net_pay,
               calculation_json,status)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'CALCULATED')`,
            [
              batchId, contract.employee_party_id, contract.id, workDays, gross,
              insurable, taxable, employeeInsurance, employerBaseInsurance,
              unemploymentInsurance, salaryTax, loanDeduction, customDeductions, netPay,
              JSON.stringify({ calendarDays, workDays, ratio, legalParameterId: legal.row.id })
            ]
          );

          add('EMP_INS', 'بیمه سهم کارمند', 'DEDUCTION', employeeInsurance, false, false, 200);
          add('SALARY_TAX', 'مالیات حقوق', 'DEDUCTION', salaryTax, false, false, 220);
          add('EMPLOYER_INS', 'بیمه سهم کارفرما', 'EMPLOYER_COST', employerBaseInsurance, false, false, 300);
          add('UNEMPLOYMENT_INS', 'بیمه بیکاری', 'EMPLOYER_COST', unemploymentInsurance, false, false, 310);

          for (const c of components) {
            await conn.execute(
              `INSERT INTO payroll_slip_lines
                (payroll_slip_id,line_code,title,line_type,amount,is_insurable,is_taxable,source_type,source_id,sort_order)
               VALUES (?,?,?,?,?,?,?,?,?,?)`,
              [
                slipResult.insertId, c.code, c.title, c.type, c.amount,
                c.insurable ? 1 : 0, c.taxable ? 1 : 0, c.sourceType, c.sourceId, c.sort
              ]
            );
          }

          totalGross += gross;
          totalEmployeeInsurance += employeeInsurance;
          totalEmployerInsurance += employerInsurance;
          totalTax += salaryTax;
          totalOtherDeductions += customDeductions;
          totalLoanDeduction += loanDeduction;
          totalNet += netPay;
        }

        await conn.execute(
          `UPDATE payroll_batches
           SET status='CALCULATED',legal_parameter_id=?,total_gross=?,total_employee_insurance=?,
               total_employer_insurance=?,total_tax=?,total_deductions=?,total_net=?
           WHERE id=?`,
          [
            legal.row.id, totalGross, totalEmployeeInsurance, totalEmployerInsurance,
            totalTax, totalOtherDeductions + totalLoanDeduction, totalNet, batchId
          ]
        );

        return {
          id: batchId, employeeCount: contracts.length, totalGross, totalEmployeeInsurance,
          totalEmployerInsurance, totalTax, totalLoanDeduction, totalOtherDeductions,
          totalNet, warnings
        };
      });
      await audit(req, 'CALCULATE', 'payroll_batch', batchId, result);
      res.json(result);
    })
  );

  app.post(
    '/api/iran/payroll/batches/:id/review',
    requireRole('HR_MANAGER', 'FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const id = Number(req.params.id);
      const [r] = await pool.execute(
        `UPDATE payroll_batches SET status='REVIEWED',reviewed_by=?
         WHERE id=? AND company_id=? AND status='CALCULATED'`,
        [Number(req.user.sub), id, req.user.companyId]
      );
      if (!r.affectedRows) fail('دوره باید ابتدا محاسبه شده باشد.', 422);
      await pool.execute(`UPDATE payroll_slips SET status='REVIEWED' WHERE payroll_batch_id=?`, [id]);
      await audit(req, 'REVIEW', 'payroll_batch', id, {});
      res.json({ ok: true, status: 'REVIEWED' });
    })
  );

  app.post(
    '/api/iran/payroll/batches/:id/approve',
    requireRole('FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const id = Number(req.params.id);
      const [r] = await pool.execute(
        `UPDATE payroll_batches SET status='APPROVED',approved_by=?
         WHERE id=? AND company_id=? AND status='REVIEWED'`,
        [Number(req.user.sub), id, req.user.companyId]
      );
      if (!r.affectedRows) fail('دوره باید ابتدا بازبینی شده باشد.', 422);
      await pool.execute(`UPDATE payroll_slips SET status='APPROVED' WHERE payroll_batch_id=?`, [id]);
      await audit(req, 'APPROVE', 'payroll_batch', id, {});
      res.json({ ok: true, status: 'APPROVED' });
    })
  );

  app.post(
    '/api/iran/payroll/batches/:id/post',
    requireRole('FINANCE_MANAGER', 'ACCOUNTANT'),
    wrap(async (req, res) => {
      const id = Number(req.params.id);
      const result = await withTransaction(async conn => {
        const [rows] = await conn.execute(
          `SELECT * FROM payroll_batches WHERE id=? AND company_id=? FOR UPDATE`,
          [id, req.user.companyId]
        );
        if (!rows.length) fail('دوره حقوق پیدا نشد.', 404);
        const batch = rows[0];
        if (batch.status === 'POSTED') {
          const [old] = await conn.execute(
            `SELECT id,entry_no FROM journal_entries
             WHERE company_id=? AND source_type='PAYROLL_BATCH' AND source_id=? AND status<>'VOID' LIMIT 1`,
            [req.user.companyId, id]
          );
          return { ok: true, duplicatePrevented: true, journalEntryId: old[0]?.id || null, entryNo: old[0]?.entry_no || null };
        }
        if (batch.status !== 'APPROVED') fail('دوره حقوق باید قبل از ثبت حسابداری تأیید شود.', 422);

        const bounds = jalaliMonthBounds(n(batch.year_no), n(batch.month_no));
        const [[loanTotals]] = await conn.execute(
          `SELECT COALESCE(SUM(ps.loan_deduction),0) loan_total
           FROM payroll_slips ps WHERE ps.payroll_batch_id=?`,
          [id]
        );
        const amounts = {
          GROSS_PLUS_EMPLOYER_INSURANCE: n(batch.total_gross) + n(batch.total_employer_insurance),
          NET_PAY: n(batch.total_net),
          SALARY_TAX: n(batch.total_tax),
          TOTAL_INSURANCE: n(batch.total_employee_insurance) + n(batch.total_employer_insurance),
          LOAN_DEDUCTION: n(loanTotals.loan_total),
          OTHER_DEDUCTIONS: Math.max(0, n(batch.total_deductions) - n(loanTotals.loan_total))
        };
        const journal = await postAccountingRules(
          conn, req.user.companyId, id, bounds.end, amounts, Number(req.user.sub)
        );

        const [loanLines] = await conn.execute(
          `SELECT psl.source_id loan_id,SUM(psl.amount) amount
           FROM payroll_slip_lines psl
           JOIN payroll_slips ps ON ps.id=psl.payroll_slip_id
           WHERE ps.payroll_batch_id=? AND psl.source_type='EMPLOYEE_LOAN' AND psl.source_id IS NOT NULL
           GROUP BY psl.source_id`,
          [id]
        );
        for (const l of loanLines) {
          await conn.execute(
            `UPDATE employee_loans
             SET remaining_amount=GREATEST(0,remaining_amount-?),
                 status=CASE WHEN GREATEST(0,remaining_amount-?)=0 THEN 'PAID' ELSE status END
             WHERE id=? AND company_id=?`,
            [n(l.amount), n(l.amount), l.loan_id, req.user.companyId]
          );
        }

        await conn.execute(
          `UPDATE payroll_batches SET status='POSTED',posted_at=NOW() WHERE id=?`,
          [id]
        );
        await conn.execute(`UPDATE payroll_slips SET status='POSTED' WHERE payroll_batch_id=?`, [id]);
        return { ok: true, ...journal, amounts };
      });
      await audit(req, 'POST', 'payroll_batch', id, result);
      res.json(result);
    })
  );

  app.post(
    '/api/iran/payroll/batches/:id/pay',
    requireRole('FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const id = Number(req.params.id);
      const [r] = await pool.execute(
        `UPDATE payroll_batches SET status='PAID',paid_at=NOW()
         WHERE id=? AND company_id=? AND status='POSTED'`,
        [id, req.user.companyId]
      );
      if (!r.affectedRows) fail('فقط دوره ثبت‌شده در حسابداری قابل علامت‌گذاری به‌عنوان پرداخت‌شده است.', 422);
      await pool.execute(`UPDATE payroll_slips SET status='PAID' WHERE payroll_batch_id=?`, [id]);
      await audit(req, 'PAY', 'payroll_batch', id, {});
      res.json({ ok: true, status: 'PAID' });
    })
  );

  app.post(
    '/api/iran/payroll/batches/:id/close',
    requireRole('FINANCE_MANAGER'),
    wrap(async (req, res) => {
      const id = Number(req.params.id);
      const [r] = await pool.execute(
        `UPDATE payroll_batches SET status='CLOSED',closed_at=NOW()
         WHERE id=? AND company_id=? AND status='PAID'`,
        [id, req.user.companyId]
      );
      if (!r.affectedRows) fail('فقط دوره پرداخت‌شده قابل بستن است.', 422);
      await audit(req, 'CLOSE', 'payroll_batch', id, {});
      res.json({ ok: true, status: 'CLOSED' });
    })
  );
}
