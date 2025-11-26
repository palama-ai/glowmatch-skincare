-- Drop any existing triggers that we need to recreate
DROP TRIGGER IF EXISTS update_quiz_attempt_purchases_updated_at ON quiz_attempt_purchases;

-- Drop any existing policies that we need to recreate
DROP POLICY IF EXISTS "Users can view their own autosave data" ON quiz_autosave;

-- Add attempt_date to quiz_attempts if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'quiz_attempts'
        AND column_name = 'attempt_date'
    ) THEN
        ALTER TABLE public.quiz_attempts
        ADD COLUMN attempt_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
    END IF;
END $$;

-- Create or replace functions for quiz attempt management
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
    -- Get active subscription for the user
    SELECT id INTO v_subscription_id
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND current_period_end > CURRENT_TIMESTAMP
    LIMIT 1;

    IF v_subscription_id IS NULL THEN
        RAISE EXCEPTION 'No active subscription found';
    END IF;

    -- Create the quiz attempt
    INSERT INTO public.quiz_attempts (
        id,
        user_id,
        subscription_id,
        quiz_data,
        results,
        attempt_date,
        created_at
    )
    VALUES (
        gen_random_uuid(),
        p_user_id,
        v_subscription_id,
        p_quiz_data,
        p_results,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_attempt_id;

    -- Update subscription attempts count
    UPDATE public.user_subscriptions
    SET quiz_attempts_used = quiz_attempts_used + 1,
        last_attempt_date = CURRENT_TIMESTAMP
    WHERE id = v_subscription_id;

    RETURN v_attempt_id;
END;
$$;

-- Update RLS policies for quiz_attempts
DROP POLICY IF EXISTS "Users can view their own quiz attempts" ON quiz_attempts;
CREATE POLICY "Users can view their own quiz attempts"
ON public.quiz_attempts
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_attempt_date ON public.quiz_attempts(attempt_date);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_subscription_id ON public.quiz_attempts(subscription_id);

-- Update or create the trigger for updating timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_quiz_attempts_updated_at ON quiz_attempts;
CREATE TRIGGER update_quiz_attempts_updated_at
    BEFORE UPDATE ON quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();