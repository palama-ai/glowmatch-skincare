-- Migration: create admin and dev accounts with unlimited quiz attempts
-- Run this in your Supabase project's SQL editor. It inserts two new auth.users rows,
-- creates corresponding user_profiles, and gives them user_subscriptions with a very large limit.
-- Passwords are hashed using crypt(); the plaintext passwords are provided to you separately.

DO $$
DECLARE
  admin_uuid UUID := gen_random_uuid();
  dev_uuid   UUID := gen_random_uuid();
  free_plan_id UUID;
BEGIN
  -- Attempt to find any plan to reference (fallback: NULL)
  SELECT id INTO free_plan_id FROM public.subscription_plans LIMIT 1;

  -- Insert admin user into auth.users
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
    is_sso_user, is_anonymous
  ) VALUES (
    admin_uuid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin2@glowmatch.com',
    crypt('Adm1n!Glow2025#', gen_salt('bf', 10)),
    now(),
    now(),
    now(),
    jsonb_build_object('full_name', 'GlowMatch Admin 2', 'role', 'admin'),
    jsonb_build_object('provider', 'email', 'providers', array['email']::text[]),
    false,
    false
  );

  -- Insert dev user into auth.users
  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
    is_sso_user, is_anonymous
  ) VALUES (
    dev_uuid,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'dev@glowmatch.com',
    crypt('Dev!Glow2025#', gen_salt('bf', 10)),
    now(),
    now(),
    now(),
    jsonb_build_object('full_name', 'GlowMatch Dev', 'role', 'admin'),
    jsonb_build_object('provider', 'email', 'providers', array['email']::text[]),
    false,
    false
  );

  -- Create matching profiles in public.user_profiles
  INSERT INTO public.user_profiles (id, email, full_name, role, created_at, updated_at)
  VALUES
    (admin_uuid, 'admin2@glowmatch.com', 'GlowMatch Admin 2', 'admin', now(), now()),
    (dev_uuid, 'dev@glowmatch.com', 'GlowMatch Dev', 'admin', now(), now())
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        role = EXCLUDED.role,
        updated_at = now();

  -- Give them "unlimited" quiz attempts by setting a very large limit and long expiry
  INSERT INTO public.user_subscriptions (user_id, plan_id, status, current_period_start, current_period_end, quiz_attempts_used, quiz_attempts_limit, created_at, updated_at)
  VALUES
    (admin_uuid, free_plan_id, 'active', now(), now() + INTERVAL '100 years', 0, 999999999, now(), now()),
    (dev_uuid, free_plan_id, 'active', now(), now() + INTERVAL '100 years', 0, 999999999, now(), now())
  ON CONFLICT (user_id) DO UPDATE
    SET plan_id = EXCLUDED.plan_id,
        status = EXCLUDED.status,
        current_period_start = EXCLUDED.current_period_start,
        current_period_end = EXCLUDED.current_period_end,
        quiz_attempts_limit = EXCLUDED.quiz_attempts_limit,
        updated_at = now();

EXCEPTION
  WHEN unique_violation THEN
    RAISE NOTICE 'One of the users already exists - operation skipped for existing records.';
  WHEN OTHERS THEN
    RAISE NOTICE 'Unexpected error during admin/dev creation: %', SQLERRM;
END $$;
