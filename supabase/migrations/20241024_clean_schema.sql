-- Clean up all existing objects
DROP FUNCTION IF EXISTS public.save_quiz_attempt CASCADE;
DROP FUNCTION IF EXISTS public.ensure_user_profile CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user CASCADE;
DROP FUNCTION IF EXISTS public.check_quiz_attempts_limit CASCADE;
DROP FUNCTION IF EXISTS public.increment_quiz_attempts CASCADE;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DROP POLICY IF EXISTS "users_manage_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_insert_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_read_own_quiz_attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "users_manage_own_user_profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "users_insert_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_profile_creation" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_users_to_manage_own_profile" ON public.user_profiles;
DROP POLICY IF EXISTS "allow_users_to_manage_own_attempts" ON public.quiz_attempts;

-- Create clean schema
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    quiz_data JSONB NOT NULL,
    results JSONB,
    has_image_analysis BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create efficient indexes
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_user_profiles_id ON public.user_profiles(id);

-- Create the user profile handler
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Create the secure quiz saving function
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

    -- Ensure profile exists
    INSERT INTO public.user_profiles (id, email, full_name)
    SELECT 
        auth.uid(),
        COALESCE(au.email, 'user-' || auth.uid()),
        COALESCE(au.raw_user_meta_data->>'full_name', split_part(COALESCE(au.email, 'user'), '@', 1))
    FROM auth.users au
    WHERE au.id = auth.uid()
    ON CONFLICT (id) DO NOTHING;

    -- Save quiz attempt
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

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION public.save_quiz_attempt TO authenticated;

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;

-- Create simple RLS policies
CREATE POLICY "allow_users_to_manage_own_profile"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY "allow_users_to_manage_own_attempts"
ON public.quiz_attempts
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());