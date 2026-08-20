DROP TRIGGER IF EXISTS trg_journal_hard_close_insert;
DROP TRIGGER IF EXISTS trg_journal_line_hard_close_insert;

DELIMITER $$
CREATE TRIGGER trg_journal_hard_close_insert
BEFORE INSERT ON journal_entries
FOR EACH ROW
BEGIN
  IF NEW.status IN ('POSTED','LOCKED') AND EXISTS(
    SELECT 1 FROM fiscal_periods fp
    WHERE fp.company_id=NEW.company_id AND fp.status='HARD_CLOSED'
      AND COALESCE(NEW.posting_date,NEW.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) AND NOT (
    NEW.source_type='YEAR_END_CLOSE' AND NEW.source_id IS NOT NULL AND EXISTS(
      SELECT 1 FROM year_end_close_runs y
      WHERE y.id=NEW.source_id AND y.company_id=NEW.company_id AND y.status='APPROVED'
    )
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$

CREATE TRIGGER trg_journal_line_hard_close_insert
BEFORE INSERT ON journal_lines
FOR EACH ROW
BEGIN
  IF EXISTS(
    SELECT 1 FROM journal_entries je
    JOIN fiscal_periods fp ON fp.company_id=je.company_id
    WHERE je.id=NEW.journal_entry_id AND fp.status='HARD_CLOSED'
      AND COALESCE(je.posting_date,je.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) AND NOT EXISTS(
    SELECT 1 FROM journal_entries je
    JOIN year_end_close_runs y ON y.id=je.source_id AND y.company_id=je.company_id
    WHERE je.id=NEW.journal_entry_id AND je.source_type='YEAR_END_CLOSE'
      AND y.status IN ('APPROVED','POSTED')
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$
DELIMITER ;
