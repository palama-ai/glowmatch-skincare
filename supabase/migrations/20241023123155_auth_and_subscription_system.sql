-- Location: supabase/migrations/20241023123155_auth_and_subscription_system.sql
-- Schema Analysis: No existing schema found - creating from scratch
-- Integration Type: Complete authentication and subscription system
-- Dependencies: None - creating new schema

-- 1. Types and Enums
CREATE TYPE public.subscription_plan AS ENUM ('free', 'standard', 'pro', 'plus');
CREATE TYPE public.subscription_status AS ENUM ('active', 'inactive', 'canceled', 'expired');
CREATE TYPE public.payment_provider AS ENUM ('stripe', 'paypal', 'payoneer');
CREATE TYPE public.user_role AS ENUM ('user', 'admin');

-- 2. Core Tables
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role public.user_role DEFAULT 'user'::public.user_role,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    plan_type public.subscription_plan NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quiz_attempts INTEGER NOT NULL,
    description TEXT,
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    status public.subscription_status DEFAULT 'active'::public.subscription_status,
    current_period_start TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    current_period_end TIMESTAMPTZ,
    quiz_attempts_used INTEGER DEFAULT 0,
    quiz_attempts_limit INTEGER NOT NULL,
    stripe_subscription_id TEXT,
    paypal_subscription_id TEXT,
    payoneer_subscription_id TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    quiz_data JSONB NOT NULL,
    completed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    results JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.user_subscriptions(id) ON DELETE SET NULL,
    provider public.payment_provider NOT NULL,
    provider_payment_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    status TEXT NOT NULL,
    payment_data JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. Essential Indexes
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_user_subscriptions_user_id ON public.user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON public.user_subscriptions(status);
CREATE INDEX idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_completed_at ON public.quiz_attempts(completed_at);
CREATE INDEX idx_payments_user_id ON public.payments(user_id);
CREATE INDEX idx_payments_provider_payment_id ON public.payments(provider_payment_id);

-- 4. Functions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')::public.user_role
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_quiz_attempts_limit(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.user_subscriptions us
    WHERE us.user_id = user_uuid 
    AND us.status = 'active'
    AND us.quiz_attempts_used < us.quiz_attempts_limit
    AND us.current_period_end > CURRENT_TIMESTAMP
)
$$;

CREATE OR REPLACE FUNCTION public.increment_quiz_attempts(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    subscription_record RECORD;
BEGIN
    SELECT us.id, us.quiz_attempts_used, us.quiz_attempts_limit 
    INTO subscription_record
    FROM public.user_subscriptions us
    WHERE us.user_id = user_uuid 
    AND us.status = 'active'
    AND us.current_period_end > CURRENT_TIMESTAMP
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    IF subscription_record.quiz_attempts_used >= subscription_record.quiz_attempts_limit THEN
        RETURN FALSE;
    END IF;

    UPDATE public.user_subscriptions 
    SET quiz_attempts_used = quiz_attempts_used + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = subscription_record.id;

    RETURN TRUE;
END;
$$;

-- 5. Triggers
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. RLS Setup
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Pattern 1: Core user table - Simple access only
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Pattern 4: Public read for subscription plans
CREATE POLICY "public_can_read_subscription_plans"
ON public.subscription_plans
FOR SELECT
TO public
USING (is_active = true);

CREATE POLICY "admin_manage_subscription_plans"
ON public.subscription_plans
FOR ALL
TO authenticated
USING (EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'
))
WITH CHECK (EXISTS (
    SELECT 1 FROM public.user_profiles up
    WHERE up.id = auth.uid() AND up.role = 'admin'
));

-- Pattern 2: Simple user ownership
CREATE POLICY "users_manage_own_subscriptions"
ON public.user_subscriptions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_quiz_attempts"
ON public.quiz_attempts
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_payments"
ON public.payments
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 7. Default subscription plans data
DO $$
DECLARE
    free_plan_id UUID := gen_random_uuid();
    standard_plan_id UUID := gen_random_uuid();
    pro_plan_id UUID := gen_random_uuid();
    plus_plan_id UUID := gen_random_uuid();
BEGIN
    INSERT INTO public.subscription_plans (id, name, plan_type, price, quiz_attempts, description, features) VALUES
        (free_plan_id, 'Free Plan', 'free'::public.subscription_plan, 0.00, 5, 'Basic skin analysis with limited attempts', 
         '["5 quiz attempts per month", "Basic skin analysis", "Email support"]'::jsonb),
        (standard_plan_id, 'Standard Plan', 'standard'::public.subscription_plan, 10.00, 25, 'Enhanced skin analysis for regular users', 
         '["25 quiz attempts per month", "Advanced skin analysis", "Priority email support", "Skincare recommendations"]'::jsonb),
        (pro_plan_id, 'Pro Plan', 'pro'::public.subscription_plan, 17.00, 50, 'Professional-grade skin analysis', 
         '["50 quiz attempts per month", "Professional skin analysis", "Phone support", "Personalized skincare routine", "Product discounts"]'::jsonb),
        (plus_plan_id, 'Plus Plan', 'plus'::public.subscription_plan, 25.00, 80, 'Premium unlimited skin analysis', 
         '["80 quiz attempts per month", "Premium skin analysis", "24/7 support", "Custom skincare routine", "Exclusive product access", "Monthly consultation"]'::jsonb);
END $$;

-- 8. Mock users for testing
DO $$
DECLARE
    admin_uuid UUID := gen_random_uuid();
    user_uuid UUID := gen_random_uuid();
    free_plan_id UUID;
    standard_plan_id UUID;
BEGIN
    -- Get plan IDs
    SELECT id INTO free_plan_id FROM public.subscription_plans WHERE plan_type = 'free' LIMIT 1;
    SELECT id INTO standard_plan_id FROM public.subscription_plans WHERE plan_type = 'standard' LIMIT 1;

    -- Create auth users with required fields
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (admin_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@glowmatch.com', crypt('admin123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "GlowMatch Admin", "role": "admin"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (user_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'user@glowmatch.com', crypt('user123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Test User", "role": "user"}'::jsonb, '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Create default subscriptions for test users
    INSERT INTO public.user_subscriptions (user_id, plan_id, quiz_attempts_limit, current_period_end) VALUES
        (admin_uuid, standard_plan_id, 25, CURRENT_TIMESTAMP + INTERVAL '30 days'),
        (user_uuid, free_plan_id, 5, CURRENT_TIMESTAMP + INTERVAL '30 days');

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;