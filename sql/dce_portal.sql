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
  description TEXT,
  file_url TEXT,
  file_type TEXT NOT NULL DEFAULT 'image',
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

CREATE TABLE IF NOT EXISTS dce_document_comments (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  document_id BIGINT NOT NULL,
  commenter TEXT,
  comment_text TEXT NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  FOREIGN KEY (document_id) REFERENCES dce_documents(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dce_documents_business_id ON dce_documents(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_meetings_business_id ON dce_meetings(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_financial_decisions_business_id ON dce_financial_decisions(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_votes_decision_id ON dce_votes(decision_id);
CREATE INDEX IF NOT EXISTS idx_dce_audit_logs_business_id ON dce_audit_logs(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_expenditures_business_id ON dce_expenditures(business_id);

-- Enable row-level security and allow the frontend anon role to access DCE portal tables.
-- If you later add authentication, tighten these policies accordingly.
ALTER TABLE public.dce_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_documents_allow_all_anon" ON public.dce_documents FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_document_comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_document_comments_allow_all_anon" ON public.dce_document_comments FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_meetings ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_meetings_allow_all_anon" ON public.dce_meetings FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_financial_decisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_financial_decisions_allow_all_anon" ON public.dce_financial_decisions FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_votes_allow_all_anon" ON public.dce_votes FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_audit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_audit_logs_allow_all_anon" ON public.dce_audit_logs FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_expenditures ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS "dce_expenditures_allow_all_anon" ON public.dce_expenditures FOR ALL USING (true) WITH CHECK (true);
