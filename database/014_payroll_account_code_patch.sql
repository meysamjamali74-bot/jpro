UPDATE accounts a
LEFT JOIN accounts existing
  ON existing.company_id=a.company_id AND existing.code='610900'
SET a.code='610900'
WHERE a.code='610100'
  AND a.title='هزینه حقوق و دستمزد'
  AND existing.id IS NULL;