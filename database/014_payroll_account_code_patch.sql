UPDATE accounts SET code='610900'
WHERE code='610100' AND title='هزینه حقوق و دستمزد'
AND NOT EXISTS (SELECT 1 FROM accounts a2 WHERE a2.company_id=accounts.company_id AND a2.code='610900');