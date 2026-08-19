DELIMITER $$

CREATE TRIGGER trg_journal_hard_close_delete
BEFORE DELETE ON journal_entries
FOR EACH ROW
BEGIN
  IF EXISTS(
    SELECT 1 FROM fiscal_periods fp
    WHERE fp.company_id=OLD.company_id AND fp.status='HARD_CLOSED'
      AND COALESCE(OLD.posting_date,OLD.entry_date) BETWEEN fp.start_date AND fp.end_date
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
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$

CREATE TRIGGER trg_journal_line_hard_close_update
BEFORE UPDATE ON journal_lines
FOR EACH ROW
BEGIN
  IF EXISTS(
    SELECT 1 FROM journal_entries je
    JOIN fiscal_periods fp ON fp.company_id=je.company_id
    WHERE je.id=OLD.journal_entry_id AND fp.status='HARD_CLOSED'
      AND COALESCE(je.posting_date,je.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) OR EXISTS(
    SELECT 1 FROM journal_entries je
    JOIN fiscal_periods fp ON fp.company_id=je.company_id
    WHERE je.id=NEW.journal_entry_id AND fp.status='HARD_CLOSED'
      AND COALESCE(je.posting_date,je.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$

CREATE TRIGGER trg_journal_line_hard_close_delete
BEFORE DELETE ON journal_lines
FOR EACH ROW
BEGIN
  IF EXISTS(
    SELECT 1 FROM journal_entries je
    JOIN fiscal_periods fp ON fp.company_id=je.company_id
    WHERE je.id=OLD.journal_entry_id AND fp.status='HARD_CLOSED'
      AND COALESCE(je.posting_date,je.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$

DELIMITER ;
