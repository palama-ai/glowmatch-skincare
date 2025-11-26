-- Function to ensure user profile exists and save quiz attempt
CREATE OR REPLACE FUNCTION public.save_quiz_with_profile(
    quiz_data jsonb,
    quiz_results jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_id uuid;
    user_email text;
    user_fullname text;
    attempt_id uuid;
BEGIN
    -- Get current user ID
    user_id := auth.uid();
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user details from auth.users
    SELECT email, COALESCE(raw_user_meta_data->>'full_name', split_part(email, '@', 1))
    INTO user_email, user_fullname
    FROM auth.users
    WHERE id = user_id;

    -- Create profile if it doesn't exist
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (user_id, user_email, user_fullname)
    ON CONFLICT (id) DO NOTHING;

    -- Create quiz attempt
    INSERT INTO public.quiz_attempts (
        user_id,
        quiz_data,
        results,
        has_image_analysis
    ) VALUES (
        user_id,
        quiz_data,
        COALESCE(quiz_results, '{}'::jsonb),
        false
    )
    RETURNING id INTO attempt_id;

    RETURN attempt_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.save_quiz_with_profile TO authenticated;

-- Add has_image_analysis column and update the quiz_attempts table
ALTER TABLE public.quiz_attempts 
ADD COLUMN IF NOT EXISTS has_image_analysis BOOLEAN DEFAULT false;

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "users_manage_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;

-- Create more permissive policies for profiles and quiz attempts
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Create insert policy for profiles
CREATE POLICY "allow_profile_creation"
ON public.user_profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- Create policies for quiz attempts
CREATE POLICY "users_insert_own_quiz_attempts"
ON public.quiz_attempts
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_read_own_quiz_attempts"
ON public.quiz_attempts
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Create a table for quiz autosave
CREATE TABLE IF NOT EXISTS public.quiz_autosave (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    quiz_data JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Enable RLS on quiz_autosave
ALTER TABLE public.quiz_autosave ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for quiz_autosave
CREATE POLICY "users_manage_own_quiz_autosave"
ON public.quiz_autosave
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());