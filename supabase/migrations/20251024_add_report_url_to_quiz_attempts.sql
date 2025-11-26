-- Add report_url and report_storage_path to quiz_attempts
ALTER TABLE public.quiz_attempts
  ADD COLUMN IF NOT EXISTS report_url text,
  ADD COLUMN IF NOT EXISTS report_storage_path text;

COMMENT ON COLUMN public.quiz_attempts.report_url IS 'Public URL to the generated PDF report for this attempt';
COMMENT ON COLUMN public.quiz_attempts.report_storage_path IS 'Storage path inside Supabase storage bucket for the report file';
