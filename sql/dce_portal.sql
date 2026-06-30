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

ALTER TABLE public.dce_documents
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS file_url TEXT,
  ADD COLUMN IF NOT EXISTS file_type TEXT NOT NULL DEFAULT 'image',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS dce_meetings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  title TEXT NOT NULL,
  meeting_date DATE,
  meeting_time TEXT,
  platform TEXT,
  attendees TEXT[],
  notify_numbers TEXT,
  notes TEXT,
  link TEXT,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.dce_meetings
  ADD COLUMN IF NOT EXISTS notify_numbers TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS link TEXT,
  ADD COLUMN IF NOT EXISTS inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE TABLE IF NOT EXISTS dce_notes (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_id TEXT NOT NULL,
  business_name TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  todos JSONB NOT NULL DEFAULT '[]',
  reminder TEXT,
  deadline DATE,
  highlight_color TEXT NOT NULL DEFAULT 'yellow',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.dce_notes
  ADD COLUMN IF NOT EXISTS content TEXT,
  ADD COLUMN IF NOT EXISTS todos JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS reminder TEXT,
  ADD COLUMN IF NOT EXISTS deadline DATE,
  ADD COLUMN IF NOT EXISTS highlight_color TEXT NOT NULL DEFAULT 'yellow',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

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
  note TEXT,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Per-spend note for the simplified mobile Money tab.
ALTER TABLE public.dce_expenditures
  ADD COLUMN IF NOT EXISTS note TEXT;

CREATE TABLE IF NOT EXISTS dce_document_comments (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  document_id BIGINT NOT NULL,
  commenter TEXT,
  comment_text TEXT NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  FOREIGN KEY (document_id) REFERENCES dce_documents(id) ON DELETE CASCADE
);

-- Anonymous meeting scores table
-- Stores meeting feedback with completely anonymous identifiers
-- anonymous_id is a random UUID that doesn't correlate to any user
-- No user identifying information is stored
CREATE TABLE IF NOT EXISTS dce_meeting_scores (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  meeting_id BIGINT NOT NULL,
  anonymous_id TEXT NOT NULL,
  score TEXT NOT NULL,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  FOREIGN KEY (meeting_id) REFERENCES dce_meetings(id) ON DELETE CASCADE
);

ALTER TABLE public.dce_meeting_scores
  ADD COLUMN IF NOT EXISTS anonymous_id TEXT,
  ADD COLUMN IF NOT EXISTS score TEXT,
  ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_dce_documents_business_id ON dce_documents(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_meetings_business_id ON dce_meetings(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_notes_business_id ON dce_notes(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_financial_decisions_business_id ON dce_financial_decisions(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_votes_decision_id ON dce_votes(decision_id);
CREATE INDEX IF NOT EXISTS idx_dce_audit_logs_business_id ON dce_audit_logs(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_expenditures_business_id ON dce_expenditures(business_id);
CREATE INDEX IF NOT EXISTS idx_dce_meeting_scores_meeting_id ON dce_meeting_scores(meeting_id);

-- Enable row-level security and allow the frontend anon role to access DCE portal tables.
-- If you later add authentication, tighten these policies accordingly.
ALTER TABLE public.dce_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_documents_allow_all_anon" ON public.dce_documents;
CREATE POLICY "dce_documents_allow_all_anon" ON public.dce_documents FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_document_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_document_comments_allow_all_anon" ON public.dce_document_comments;
CREATE POLICY "dce_document_comments_allow_all_anon" ON public.dce_document_comments FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_meetings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_meetings_allow_all_anon" ON public.dce_meetings;
CREATE POLICY "dce_meetings_allow_all_anon" ON public.dce_meetings FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_notes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_notes_allow_all_anon" ON public.dce_notes;
CREATE POLICY "dce_notes_allow_all_anon" ON public.dce_notes FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_financial_decisions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_financial_decisions_allow_all_anon" ON public.dce_financial_decisions;
CREATE POLICY "dce_financial_decisions_allow_all_anon" ON public.dce_financial_decisions FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_votes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_votes_allow_all_anon" ON public.dce_votes;
CREATE POLICY "dce_votes_allow_all_anon" ON public.dce_votes FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_audit_logs_allow_all_anon" ON public.dce_audit_logs;
CREATE POLICY "dce_audit_logs_allow_all_anon" ON public.dce_audit_logs FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_expenditures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_expenditures_allow_all_anon" ON public.dce_expenditures;
CREATE POLICY "dce_expenditures_allow_all_anon" ON public.dce_expenditures FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE public.dce_meeting_scores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dce_meeting_scores_allow_all_anon" ON public.dce_meeting_scores;
CREATE POLICY "dce_meeting_scores_allow_all_anon" ON public.dce_meeting_scores FOR ALL USING (true) WITH CHECK (true);

-- Allow public upload, update, delete and read for the DCE media bucket.
-- This is required when the frontend uploads files directly with the anon key.
DROP POLICY IF EXISTS "dce_media_insert" ON storage.objects;
CREATE POLICY "dce_media_insert"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'dce-media');

DROP POLICY IF EXISTS "dce_media_update" ON storage.objects;
CREATE POLICY "dce_media_update"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'dce-media')
WITH CHECK (bucket_id = 'dce-media');

DROP POLICY IF EXISTS "dce_media_delete" ON storage.objects;
CREATE POLICY "dce_media_delete"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'dce-media');

DROP POLICY IF EXISTS "dce_media_select_public" ON storage.objects;
CREATE POLICY "dce_media_select_public"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'dce-media');
