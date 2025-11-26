-- Migration: allow recording quiz attempts even when user has no active subscription
-- Replaces record_quiz_attempt to not require an active subscription. If a subscription
-- exists it will be linked and updated; otherwise subscription_id will be NULL and no
-- attempt counters will be updated.

CREATE OR REPLACE FUNCTION public.record_quiz_attempt(
    p_user_id UUID,
    p_quiz_data JSONB,
    p_results JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_subscription_id UUID;
    v_attempt_id UUID;
BEGIN
    -- Try to get active subscription; if none found, proceed with NULL
    SELECT id INTO v_subscription_id
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND (current_period_end IS NULL OR current_period_end > CURRENT_TIMESTAMP)
    LIMIT 1;

    -- Create attempt (subscription_id may be null)
    INSERT INTO public.quiz_attempts (
        id,
        user_id,
        subscription_id,
        quiz_data,
        results,
        attempt_date
    )
    VALUES (
        gen_random_uuid(),
        p_user_id,
        v_subscription_id,
        p_quiz_data,
        p_results,
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_attempt_id;

    -- If we have a subscription, update usage counters
    IF v_subscription_id IS NOT NULL THEN
      UPDATE public.user_subscriptions
      SET quiz_attempts_used = COALESCE(quiz_attempts_used, 0) + 1,
          last_attempt_date = CURRENT_TIMESTAMP
      WHERE id = v_subscription_id;
    END IF;

    RETURN v_attempt_id;
END;
$$;

COMMENT ON FUNCTION public.record_quiz_attempt IS 'Record a quiz attempt; links to active subscription if present, otherwise stores attempt with NULL subscription_id.';
