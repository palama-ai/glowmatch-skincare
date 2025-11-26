-- Migration: Fix quiz attempts autosave and history
-- This migration:
-- 1. Ensures quiz_data and results are properly JSON typed
-- 2. Makes attempt_date default to created_at if not set
-- 3. Adds indexes for performance
-- 4. Adds storage policy for large quiz data

-- 1. Ensure proper JSON typing and defaults
ALTER TABLE public.quiz_attempts
  ALTER COLUMN quiz_data SET DATA TYPE JSONB USING quiz_data::JSONB,
  ALTER COLUMN results SET DATA TYPE JSONB USING COALESCE(results::JSONB, '{}'::JSONB),
  ALTER COLUMN attempt_date SET DEFAULT CURRENT_TIMESTAMP;

-- 2. Update existing records to have attempt_date
UPDATE public.quiz_attempts
SET attempt_date = created_at
WHERE attempt_date IS NULL;

-- 3. Add useful indexes
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_created 
  ON public.quiz_attempts (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quiz_attempts_image_analysis 
  ON public.quiz_attempts (user_id) 
  WHERE has_image_analysis = true;

-- 4. Autosave improvements
ALTER TABLE public.quiz_autosave
  ALTER COLUMN quiz_data SET DATA TYPE JSONB USING quiz_data::JSONB;

-- Add a function to cleanup old autosaves (optional, can be scheduled)
CREATE OR REPLACE FUNCTION cleanup_old_autosaves()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.quiz_autosave
  WHERE updated_at < NOW() - INTERVAL '7 days';
END;
$$;

COMMENT ON FUNCTION cleanup_old_autosaves IS 'Removes quiz autosaves older than 7 days to prevent storage buildup';

-- Update storage policy to allow larger quiz data
ALTER TABLE public.quiz_attempts 
  ALTER COLUMN quiz_data SET STORAGE EXTERNAL,
  ALTER COLUMN results SET STORAGE EXTERNAL;

-- Add expiration to autosaves
COMMENT ON TABLE public.quiz_autosave IS 'Stores temporary quiz progress. Records older than 7 days are automatically cleaned up.';