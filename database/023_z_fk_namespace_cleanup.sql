-- MySQL requires foreign-key constraint names to be unique within a schema.
-- Legacy commission_rule_assignments used the generic fk_ca_company name,
-- which collides with crm_activities in migration 024.

ALTER TABLE commission_rule_assignments
  DROP FOREIGN KEY fk_ca_company,
  ADD CONSTRAINT fk_comm_assignment_company
    FOREIGN KEY(company_id) REFERENCES companies(id);
