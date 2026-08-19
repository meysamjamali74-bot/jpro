DROP TRIGGER IF EXISTS trg_journal_hard_close_update;

DELIMITER $$
CREATE TRIGGER trg_journal_hard_close_update
BEFORE UPDATE ON journal_entries
FOR EACH ROW
BEGIN
  IF EXISTS(
    SELECT 1 FROM fiscal_periods fp
    WHERE fp.company_id=OLD.company_id AND fp.status='HARD_CLOSED'
      AND COALESCE(OLD.posting_date,OLD.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) OR EXISTS(
    SELECT 1 FROM fiscal_periods fp
    WHERE fp.company_id=NEW.company_id AND fp.status='HARD_CLOSED'
      AND COALESCE(NEW.posting_date,NEW.entry_date) BETWEEN fp.start_date AND fp.end_date
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='ACCOUNTING_PERIOD_HARD_CLOSED';
  END IF;
END$$
DELIMITER ;
