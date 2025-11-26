-- First, clean up any existing policies to start fresh
DROP POLICY IF EXISTS "users_manage_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_insert_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_read_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "users_insert_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_profile_creation" ON public.user_profiles;

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS public.save_quiz_with_profile;
DROP FUNCTION IF EXISTS public.ensure_user_profile;

-- Create a clean, simple function to handle quiz saving
CREATE OR REPLACE FUNCTION public.save_quiz_attempt(
    quiz_data jsonb,
    quiz_results jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_id uuid;
    attempt_id uuid;
BEGIN
    -- Get current user ID
    user_id := auth.uid();
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Create profile if it doesn't exist
    INSERT INTO public.user_profiles (id, email, full_name)
    SELECT 
        auth.uid(),
        COALESCE(au.email, 'user-' || auth.uid()),
        COALESCE(au.raw_user_meta_data->>'full_name', split_part(COALESCE(au.email, 'user'), '@', 1))
    FROM auth.users au
    WHERE au.id = auth.uid()
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
GRANT EXECUTE ON FUNCTION public.save_quiz_attempt TO authenticated;

-- Ensure has_image_analysis column exists
ALTER TABLE public.quiz_attempts 
ADD COLUMN IF NOT EXISTS has_image_analysis BOOLEAN DEFAULT false;

-- Create simple, clear policies for user profiles
CREATE POLICY "allow_users_to_manage_own_profile"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Create simple, clear policies for quiz attempts
CREATE POLICY "allow_users_to_manage_own_attempts"
ON public.quiz_attempts
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_id ON public.user_profiles(id);