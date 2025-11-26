-- Drop and recreate the handle_new_user trigger function with better error handling
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_profiles (
    id,
    email,
    full_name,
    role
  ) VALUES (
    NEW.id,
    COALESCE(NEW.email, 'no-email-' || NEW.id::text),
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      split_part(COALESCE(NEW.email, 'anonymous'), '@', 1)
    ),
    COALESCE(
      (NEW.raw_user_meta_data->>'role')::public.user_role,
      'user'::public.user_role
    )
  )
  ON CONFLICT (id) DO UPDATE
  SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    updated_at = CURRENT_TIMESTAMP;

  RETURN NEW;
END;
$$;

-- Drop and recreate the trigger to ensure it's properly associated
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Create a function to safely ensure a user profile exists
CREATE OR REPLACE FUNCTION public.ensure_user_profile(
  user_uuid UUID,
  user_email TEXT DEFAULT NULL,
  user_full_name TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  profile_id UUID;
BEGIN
  -- First try to find existing profile
  SELECT id INTO profile_id
  FROM public.user_profiles
  WHERE id = user_uuid;

  -- If no profile exists, create one
  IF profile_id IS NULL THEN
    INSERT INTO public.user_profiles (
      id,
      email,
      full_name,
      role
    ) VALUES (
      user_uuid,
      COALESCE(user_email, 'no-email-' || user_uuid::text),
      COALESCE(user_full_name, 'User ' || substr(user_uuid::text, 1, 8)),
      'user'::public.user_role
    )
    RETURNING id INTO profile_id;
  END IF;

  RETURN profile_id;
END;
$$;

-- Grant execute permission on the function to authenticated users
GRANT EXECUTE ON FUNCTION public.ensure_user_profile TO authenticated;

-- Create a secure wrapper function for the application to use
CREATE OR REPLACE FUNCTION public.create_quiz_attempt(
  quiz_data jsonb,
  results jsonb DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_uuid UUID;
  profile_id UUID;
  attempt_id UUID;
BEGIN
  -- Get current user's ID
  user_uuid := auth.uid();
  
  IF user_uuid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Ensure user has a profile
  profile_id := public.ensure_user_profile(user_uuid);
  
  -- Create the quiz attempt
  INSERT INTO public.quiz_attempts (
    user_id,
    quiz_data,
    results,
    has_image_analysis
  ) VALUES (
    profile_id,
    quiz_data,
    COALESCE(results, '{}'::jsonb),
    false
  )
  RETURNING id INTO attempt_id;

  RETURN attempt_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_quiz_attempt TO authenticated;