using System.Data;
using Microsoft.Data.Sqlite;

namespace Bestplus.Data;

public static class Database
{
    public const int SchemaVersion = 3;
    private static readonly object Sync = new();

    public static string ConnectionString => new SqliteConnectionStringBuilder
    {
        DataSource = AppPaths.DbPath,
        Mode = SqliteOpenMode.ReadWriteCreate,
        Cache = SqliteCacheMode.Shared,
        Pooling = true
    }.ToString();

    public static void Initialize()
    {
        AppPaths.Ensure();
        using var cn = Open();
        Execute(cn, null, "PRAGMA journal_mode=WAL;");
        Execute(cn, null, "PRAGMA synchronous=NORMAL;");
        Execute(cn, null, "PRAGMA foreign_keys=ON;");
        Execute(cn, null, "PRAGMA busy_timeout=5000;");

        using var tx = cn.BeginTransaction();
        Execute(cn, tx, SchemaSql);
        Seed(cn, tx);
        tx.Commit();
    }

    public static SqliteConnection Open()
    {
        var cn = new SqliteConnection(ConnectionString);
        cn.Open();
        using var cmd = cn.CreateCommand();
        cmd.CommandText = "PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;";
        cmd.ExecuteNonQuery();
        return cn;
    }

    public static void InTransaction(Action<SqliteConnection, SqliteTransaction> action)
    {
        lock (Sync)
        {
            using var cn = Open();
            using var tx = cn.BeginTransaction();
            try
            {
                action(cn, tx);
                tx.Commit();
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }
    }

    public static int Execute(string sql, params (string Name, object? Value)[] parameters)
    {
        using var cn = Open();
        return Execute(cn, null, sql, parameters);
    }

    public static int Execute(SqliteConnection cn, SqliteTransaction? tx, string sql, params (string Name, object? Value)[] parameters)
    {
        using var cmd = cn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = sql;
        AddParameters(cmd, parameters);
        return cmd.ExecuteNonQuery();
    }

    public static object? Scalar(string sql, params (string Name, object? Value)[] parameters)
    {
        using var cn = Open();
        using var cmd = cn.CreateCommand();
        cmd.CommandText = sql;
        AddParameters(cmd, parameters);
        var v = cmd.ExecuteScalar();
        return v is DBNull ? null : v;
    }

    public static long ScalarLong(string sql, params (string Name, object? Value)[] parameters)
    {
        var v = Scalar(sql, parameters);
        return v == null ? 0L : Convert.ToInt64(v);
    }

    public static double ScalarDouble(string sql, params (string Name, object? Value)[] parameters)
    {
        var v = Scalar(sql, parameters);
        return v == null ? 0d : Convert.ToDouble(v);
    }

    public static string ScalarText(string sql, params (string Name, object? Value)[] parameters)
    {
        var v = Scalar(sql, parameters);
        return v?.ToString() ?? "";
    }

    public static DataTable Query(string sql, params (string Name, object? Value)[] parameters)
    {
        using var cn = Open();
        using var cmd = cn.CreateCommand();
        cmd.CommandText = sql;
        AddParameters(cmd, parameters);
        using var reader = cmd.ExecuteReader();
        var dt = new DataTable();
        dt.Load(reader);
        return dt;
    }

    public static long Insert(SqliteConnection cn, SqliteTransaction tx, string sql, params (string Name, object? Value)[] parameters)
    {
        using var cmd = cn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = sql + "; SELECT last_insert_rowid();";
        AddParameters(cmd, parameters);
        return Convert.ToInt64(cmd.ExecuteScalar());
    }

    private static void AddParameters(SqliteCommand cmd, params (string Name, object? Value)[] parameters)
    {
        foreach (var p in parameters)
            cmd.Parameters.AddWithValue(p.Name, p.Value ?? DBNull.Value);
    }

    public static string GetSetting(string key, string defaultValue = "")
    {
        var v = Scalar("SELECT value FROM settings WHERE key=@k", ("@k", key));
        return v?.ToString() ?? defaultValue;
    }

    public static void SetSetting(string key, string value)
    {
        Execute("INSERT INTO settings(key,value) VALUES(@k,@v) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            ("@k", key), ("@v", value));
    }

    public static string BackupNow()
    {
        AppPaths.Ensure();
        Execute("PRAGMA wal_checkpoint(FULL);");
        var folder = Path.Combine(AppPaths.BackupDir, $"BESTPLUS-{DateTime.Now:yyyyMMdd-HHmmss}");
        Directory.CreateDirectory(folder);
        File.Copy(AppPaths.DbPath, Path.Combine(folder, "bestplus.db"), true);
        var logo = GetSetting("company_logo");
        if (File.Exists(logo)) File.Copy(logo, Path.Combine(folder, Path.GetFileName(logo)), true);
        File.WriteAllText(Path.Combine(folder, "backup-info.txt"),
            $"BESTPLUS Backup\r\nCreated: {DateTime.Now:yyyy-MM-dd HH:mm:ss}\r\nSchema: {SchemaVersion}\r\n", System.Text.Encoding.UTF8);
        return folder;
    }

    public static void Audit(long userId, string action, string entity, string entityId, string detail)
    {
        Execute("INSERT INTO audit_log(user_id,action,entity,entity_id,detail,created_at) VALUES(@u,@a,@e,@i,@d,@c)",
            ("@u", userId), ("@a", action), ("@e", entity), ("@i", entityId), ("@d", detail), ("@c", DateTime.Now.ToString("O")));
    }

    private static void Seed(SqliteConnection cn, SqliteTransaction tx)
    {
        Execute(cn, tx, "INSERT OR IGNORE INTO app_meta(key,value) VALUES('schema_version',@v)", ("@v", SchemaVersion.ToString()));
        var count = Convert.ToInt64(ScalarOn(cn, tx, "SELECT COUNT(*) FROM users") ?? 0L);
        if (count == 0)
        {
            var salt = Security.NewSalt();
            var hash = Security.HashPassword("admin", salt);
            Execute(cn, tx, "INSERT INTO users(username,display_name,password_hash,password_salt,role,is_active,must_change_password,created_at) VALUES('admin','مدیر سیستم',@h,@s,'ADMIN',1,1,@c)",
                ("@h", hash), ("@s", salt), ("@c", DateTime.Now.ToString("O")));
        }

        Execute(cn, tx, "INSERT OR IGNORE INTO warehouses(id,code,name,is_active) VALUES(1,'01','انبار اصلی',1)");
        Execute(cn, tx, "INSERT OR IGNORE INTO cashboxes(id,name,is_active) VALUES(1,'صندوق اصلی',1)");
        Execute(cn, tx, "INSERT OR IGNORE INTO banks(id,name,account_no,card_no,iban,is_active) VALUES(1,'بانک اصلی','','','',1)");

        string[,] accounts =
        {
            {"1101","صندوق","ASSET"}, {"1102","بانک","ASSET"}, {"1103","اسناد دریافتنی","ASSET"},
            {"1201","حساب‌های دریافتنی","ASSET"}, {"1301","موجودی کالا","ASSET"}, {"1401","مالیات ارزش افزوده خرید","ASSET"},
            {"2101","حساب‌های پرداختنی","LIABILITY"}, {"2102","اسناد پرداختنی","LIABILITY"}, {"2201","مالیات ارزش افزوده فروش","LIABILITY"},
            {"3101","سرمایه","EQUITY"}, {"4101","فروش کالا","REVENUE"}, {"4102","برگشت از فروش","REVENUE"},
            {"5101","بهای تمام‌شده کالای فروش‌رفته","EXPENSE"}, {"5102","برگشت از خرید","EXPENSE"}, {"6101","هزینه‌های عمومی و اداری","EXPENSE"}
        };
        for (int i = 0; i < accounts.GetLength(0); i++)
            Execute(cn, tx, "INSERT OR IGNORE INTO accounts(code,name,type,is_active) VALUES(@c,@n,@t,1)",
                ("@c", accounts[i,0]), ("@n", accounts[i,1]), ("@t", accounts[i,2]));

        var defaults = new Dictionary<string,string>
        {
            ["company_name"]="شرکت من", ["company_legal_name"]="", ["company_national_id"]="", ["company_economic_code"]="",
            ["company_reg_no"]="", ["company_phone"]="", ["company_postal_code"]="", ["company_address"]="", ["company_logo"]="",
            ["currency"]="ریال", ["default_tax_percent"]="10", ["allow_negative_stock"]="0", ["invoice_footer"]="با تشکر از حسن انتخاب شما",
            ["locked_until"]=""
        };
        foreach (var kv in defaults)
            Execute(cn, tx, "INSERT OR IGNORE INTO settings(key,value) VALUES(@k,@v)", ("@k",kv.Key),("@v",kv.Value));
    }

    private static object? ScalarOn(SqliteConnection cn, SqliteTransaction tx, string sql, params (string Name, object? Value)[] parameters)
    {
        using var cmd = cn.CreateCommand();
        cmd.Transaction = tx;
        cmd.CommandText = sql;
        AddParameters(cmd, parameters);
        var v = cmd.ExecuteScalar();
        return v is DBNull ? null : v;
    }

    private const string SchemaSql = @"
CREATE TABLE IF NOT EXISTS app_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS users(
 id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL,
 password_hash TEXT NOT NULL, password_salt TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'USER', is_active INTEGER NOT NULL DEFAULT 1,
 must_change_password INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS persons(
 id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, is_customer INTEGER NOT NULL DEFAULT 1,
 is_supplier INTEGER NOT NULL DEFAULT 0, phone TEXT, mobile TEXT, national_id TEXT, economic_code TEXT, address TEXT,
 credit_limit INTEGER NOT NULL DEFAULT 0, opening_balance INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS ix_persons_name ON persons(name);
CREATE TABLE IF NOT EXISTS warehouses(id INTEGER PRIMARY KEY AUTOINCREMENT,code TEXT NOT NULL UNIQUE,name TEXT NOT NULL,is_active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS products(
 id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE, barcode TEXT, name TEXT NOT NULL, category TEXT, brand TEXT,
 base_unit TEXT NOT NULL DEFAULT 'عدد', pack_unit TEXT, pack_factor REAL NOT NULL DEFAULT 1, buy_price INTEGER NOT NULL DEFAULT 0,
 sell_price INTEGER NOT NULL DEFAULT 0, avg_cost REAL NOT NULL DEFAULT 0, min_stock REAL NOT NULL DEFAULT 0,
 tax_percent REAL NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS ix_products_name ON products(name);
CREATE INDEX IF NOT EXISTS ix_products_barcode ON products(barcode);
CREATE TABLE IF NOT EXISTS product_stock(
 product_id INTEGER NOT NULL, warehouse_id INTEGER NOT NULL, qty REAL NOT NULL DEFAULT 0,
 PRIMARY KEY(product_id,warehouse_id), FOREIGN KEY(product_id) REFERENCES products(id), FOREIGN KEY(warehouse_id) REFERENCES warehouses(id));
CREATE TABLE IF NOT EXISTS invoice_series(kind TEXT PRIMARY KEY,prefix TEXT NOT NULL,next_no INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS invoices(
 id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, invoice_no TEXT NOT NULL UNIQUE, date TEXT NOT NULL, due_date TEXT,
 person_id INTEGER NOT NULL, warehouse_id INTEGER NOT NULL, subtotal INTEGER NOT NULL DEFAULT 0, discount INTEGER NOT NULL DEFAULT 0,
 tax INTEGER NOT NULL DEFAULT 0, freight INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL DEFAULT 0, cost_total INTEGER NOT NULL DEFAULT 0,
 status TEXT NOT NULL DEFAULT 'FINAL', notes TEXT, created_by INTEGER NOT NULL, created_at TEXT NOT NULL,
 FOREIGN KEY(person_id) REFERENCES persons(id), FOREIGN KEY(warehouse_id) REFERENCES warehouses(id), FOREIGN KEY(created_by) REFERENCES users(id));
CREATE INDEX IF NOT EXISTS ix_invoices_date ON invoices(date);
CREATE INDEX IF NOT EXISTS ix_invoices_person ON invoices(person_id);
CREATE TABLE IF NOT EXISTS invoice_items(
 id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL, product_id INTEGER NOT NULL, qty REAL NOT NULL,
 unit TEXT NOT NULL, unit_factor REAL NOT NULL DEFAULT 1, unit_price INTEGER NOT NULL, discount INTEGER NOT NULL DEFAULT 0,
 tax INTEGER NOT NULL DEFAULT 0, line_total INTEGER NOT NULL, cost_amount INTEGER NOT NULL DEFAULT 0,
 FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE, FOREIGN KEY(product_id) REFERENCES products(id));
CREATE TABLE IF NOT EXISTS inventory_moves(
 id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL, product_id INTEGER NOT NULL, warehouse_id INTEGER NOT NULL,
 ref_type TEXT NOT NULL, ref_id INTEGER, ref_no TEXT, in_qty REAL NOT NULL DEFAULT 0, out_qty REAL NOT NULL DEFAULT 0,
 unit_cost REAL NOT NULL DEFAULT 0, value INTEGER NOT NULL DEFAULT 0, balance_qty REAL NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
 FOREIGN KEY(product_id) REFERENCES products(id), FOREIGN KEY(warehouse_id) REFERENCES warehouses(id));
CREATE INDEX IF NOT EXISTS ix_inventory_product ON inventory_moves(product_id,warehouse_id,date);
CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY AUTOINCREMENT,code TEXT NOT NULL UNIQUE,name TEXT NOT NULL,type TEXT NOT NULL,is_active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS journal_entries(
 id INTEGER PRIMARY KEY AUTOINCREMENT, journal_no TEXT NOT NULL UNIQUE, date TEXT NOT NULL, description TEXT, ref_type TEXT, ref_id INTEGER,
 ref_no TEXT, is_reversal INTEGER NOT NULL DEFAULT 0, created_by INTEGER NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(created_by) REFERENCES users(id));
CREATE TABLE IF NOT EXISTS journal_lines(
 id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id INTEGER NOT NULL, account_code TEXT NOT NULL, person_id INTEGER,
 debit INTEGER NOT NULL DEFAULT 0, credit INTEGER NOT NULL DEFAULT 0, description TEXT,
 FOREIGN KEY(entry_id) REFERENCES journal_entries(id) ON DELETE CASCADE, FOREIGN KEY(person_id) REFERENCES persons(id));
CREATE INDEX IF NOT EXISTS ix_journal_lines_account ON journal_lines(account_code);
CREATE INDEX IF NOT EXISTS ix_journal_lines_person ON journal_lines(person_id);
CREATE TABLE IF NOT EXISTS cashboxes(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,is_active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS banks(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,account_no TEXT,card_no TEXT,iban TEXT,is_active INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS treasury(
 id INTEGER PRIMARY KEY AUTOINCREMENT, receipt_no TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, date TEXT NOT NULL, person_id INTEGER,
 method TEXT NOT NULL, cashbox_id INTEGER, bank_id INTEGER, amount INTEGER NOT NULL, reference TEXT, notes TEXT,
 created_by INTEGER NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(person_id) REFERENCES persons(id), FOREIGN KEY(created_by) REFERENCES users(id));
CREATE TABLE IF NOT EXISTS checks(
 id INTEGER PRIMARY KEY AUTOINCREMENT, direction TEXT NOT NULL, check_no TEXT NOT NULL, sayad_no TEXT, bank_name TEXT,
 amount INTEGER NOT NULL, issue_date TEXT, due_date TEXT NOT NULL, person_id INTEGER, status TEXT NOT NULL,
 description TEXT, created_by INTEGER NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(person_id) REFERENCES persons(id));
CREATE INDEX IF NOT EXISTS ix_checks_due ON checks(due_date,status);
CREATE TABLE IF NOT EXISTS audit_log(
 id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER,action TEXT NOT NULL,entity TEXT NOT NULL,entity_id TEXT,detail TEXT,created_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS ix_audit_date ON audit_log(created_at);
";
}
