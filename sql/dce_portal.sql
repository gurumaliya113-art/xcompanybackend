-- DCE Portal tables for documents, meetings, finance decisions, voting, audit log, and expenditure ledger

-- Replace business_id type with the same type as your existing businesses.id column if it is integer or uuid.

CREATE TABLE IF NOT EXISTS dce_documents (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  title TEXT NOT NULL,
  doc_type TEXT NOT NULL,
  owner TEXT,
  status TEXT NOT NULL,
  confidentiality TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dce_meetings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  title TEXT NOT NULL,
  meeting_date DATE,
  meeting_time TEXT,
  platform TEXT,
  attendees TEXT[],
  notes TEXT,
  link TEXT,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dce_financial_decisions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  title TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  proposer TEXT,
  due_date DATE,
  risk TEXT,
  stage TEXT NOT NULL DEFAULT 'Proposed',
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dce_votes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  decision_id BIGINT NOT NULL,
  voter TEXT,
  vote_option TEXT NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dce_audit_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  event_text TEXT NOT NULL,
  category TEXT,
  actor TEXT,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dce_expenditures (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  vendor TEXT NOT NULL,
  category TEXT,
  amount NUMERIC NOT NULL DEFAULT 0,
  spend_date DATE,
  status TEXT NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dce_documents_business_id ON dce_documents(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_meetings_business_id ON dce_meetings(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_financial_decisions_business_id ON dce_financial_decisions(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_votes_decision_id ON dce_votes(decision_id);
CREATE INDEX IF NOT EXISTS idx_dce_audit_logs_business_id ON dce_audit_logs(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_expenditures_business_id ON dce_expenditures(business_id);
