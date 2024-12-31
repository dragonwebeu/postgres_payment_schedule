This is a proof-of-concept payment schedule creator as a Postgres function.
Each number represents a component, like a lump, penalty, contact fee etc.

```sql
SELECT * FROM create_payment_schedule(CURRENT_DATE, 350, 1000, 20, '{"1":{"amount":609.6,"paid":0},"2":{"amount":390.4,"paid":0},"6":{"amount":20.0,"paid":0}}', true);
```

| payment_date | balance | payment_amount | lump | intress | fines | damage_comp | ps_contract_fee | ps_intrest | ps_penalty | state_fee | representation_fee | procedural_expense |
|--------------|---------|----------------|------|---------|-------|-------------|-----------------|------------|------------|-----------|--------------------|--------------------|
| 2025-01-31   | 650     | 370            | 0    | 0       | 350   | 0           | 20              | NULL       | NULL       | NULL      | NULL               | NULL               |
| 2025-02-28   | 300     | 350            | 309.6| 0       | 40.4  | 0           | 0               | NULL       | NULL       | NULL      | NULL               | NULL               |
| 2025-03-28   | 0       | 300            | 300  | 0       | 0     | 0           | 0               | NULL       | NULL       | NULL      | NULL               | NULL               |
