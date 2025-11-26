-- Create or replace the save_quiz_attempt procedure
CREATE OR REPLACE FUNCTION public.save_quiz_attempt(
    p_user_id UUID,
    p_quiz_data JSONB,
    p_results JSONB,
    p_has_image_analysis BOOLEAN DEFAULT false
)
RETURNS public.quiz_attempts
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_subscription_id UUID;
    v_attempt_record public.quiz_attempts;
BEGIN
    -- Get active subscription ID for the user
    SELECT id INTO v_subscription_id
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND current_period_end > CURRENT_TIMESTAMP
    LIMIT 1;

    -- If no active subscription found, continue without it
    -- Insert the quiz attempt (do not reference 'completed_at' to avoid schema cache mismatch)
    INSERT INTO public.quiz_attempts (
        user_id,
        subscription_id,
        quiz_data,
        results,
        has_image_analysis
    )
    VALUES (
        p_user_id,
        v_subscription_id,
        p_quiz_data,
        p_results,
        p_has_image_analysis
    )
    RETURNING * INTO v_attempt_record;

    -- If we have a subscription, increment the attempts counter
    IF v_subscription_id IS NOT NULL THEN
        PERFORM increment_quiz_attempts(p_user_id);
    END IF;

    RETURN v_attempt_record;
END;
$$;