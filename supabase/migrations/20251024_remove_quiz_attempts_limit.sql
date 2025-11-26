-- Migration: Remove quiz attempts limit system-wide
-- This migration removes the quiz attempts limiting feature by:
-- 1. Setting all plans to unlimited attempts
-- 2. Updating existing subscriptions to unlimited
-- 3. Modifying functions to skip attempt counting

-- 1. Update all subscription plans to have unlimited attempts
UPDATE public.subscription_plans
SET quiz_attempts = 999999999,
    features = (
      SELECT jsonb_agg(
        CASE 
          WHEN value::text LIKE '%attempts%' THEN 'Unlimited quiz attempts'::text
          ELSE value::text
        END
      )
      FROM jsonb_array_elements(features)
    );

-- 2. Update all existing subscriptions to unlimited attempts
UPDATE public.user_subscriptions
SET quiz_attempts_limit = 999999999,
    quiz_attempts_used = 0;

-- 3. Modify the check_quiz_attempts_limit function to always return true
CREATE OR REPLACE FUNCTION public.check_quiz_attempts_limit(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  -- Always return true since we no longer limit attempts
  SELECT true;
$$;

-- 4. Modify the increment_quiz_attempts function to be a no-op
CREATE OR REPLACE FUNCTION public.increment_quiz_attempts(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Always return true and don't increment counter since we no longer track attempts
  RETURN true;
END;
$$;

-- 5. Add a comment to the schema to document this change
COMMENT ON FUNCTION public.check_quiz_attempts_limit IS 'This function now always returns true as quiz attempts are unlimited.';
COMMENT ON FUNCTION public.increment_quiz_attempts IS 'This function is now a no-op as quiz attempts are unlimited.';