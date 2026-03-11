-- Employee Ledger: AR (employee owes company) and AP (company owes employee)
CREATE TABLE IF NOT EXISTS employee_ledger (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('AR', 'AP')),
  description TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE employee_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for anon" ON employee_ledger FOR ALL USING (true) WITH CHECK (true);
