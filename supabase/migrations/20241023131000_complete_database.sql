-- BEGIN TRANSACTION
BEGIN;

-- Drop all existing tables, types, and functions
DO $$
BEGIN
    -- Drop tables if they exist
    DROP TABLE IF EXISTS quiz_attempts CASCADE;
    DROP TABLE IF EXISTS quiz_attempt_purchases CASCADE;
    DROP TABLE IF EXISTS quiz_autosave CASCADE;
    DROP TABLE IF EXISTS payments CASCADE;
    DROP TABLE IF EXISTS user_subscriptions CASCADE;
    DROP TABLE IF EXISTS subscription_plans CASCADE;
    DROP TABLE IF EXISTS user_profiles CASCADE;

    -- Drop types if they exist
    DROP TYPE IF EXISTS subscription_plan CASCADE;
    DROP TYPE IF EXISTS subscription_status CASCADE;
    DROP TYPE IF EXISTS payment_provider CASCADE;
    DROP TYPE IF EXISTS user_role CASCADE;

    -- Drop functions
    DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
    DROP FUNCTION IF EXISTS check_quiz_attempts_limit(UUID) CASCADE;
    DROP FUNCTION IF EXISTS increment_quiz_attempts(UUID) CASCADE;
    DROP FUNCTION IF EXISTS record_quiz_attempt(UUID, JSONB, JSONB) CASCADE;
    DROP FUNCTION IF EXISTS update_timestamp() CASCADE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping objects: %', SQLERRM;
END $$;

-- Create Types
CREATE TYPE subscription_plan AS ENUM ('free', 'standard', 'pro', 'plus');
CREATE TYPE subscription_status AS ENUM ('active', 'inactive', 'canceled', 'expired');
CREATE TYPE payment_provider AS ENUM ('stripe', 'paypal', 'payoneer');
CREATE TYPE user_role AS ENUM ('user', 'admin');

-- Create Tables
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role user_role DEFAULT 'user',
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    plan_type subscription_plan NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quiz_attempts INTEGER NOT NULL,
    description TEXT,
    features JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    status subscription_status DEFAULT 'active',
    current_period_start TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    current_period_end TIMESTAMPTZ,
    quiz_attempts_used INTEGER DEFAULT 0,
    quiz_attempts_limit INTEGER NOT NULL,
    last_attempt_date TIMESTAMPTZ,
    stripe_subscription_id TEXT,
    paypal_subscription_id TEXT,
    payoneer_subscription_id TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES user_subscriptions(id) ON DELETE CASCADE,
    quiz_data JSONB NOT NULL,
    results JSONB,
    attempt_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    has_image_analysis BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE quiz_attempt_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    amount_paid DECIMAL(10,2) NOT NULL,
    purchase_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE quiz_autosave (
    user_id UUID PRIMARY KEY REFERENCES user_profiles(id) ON DELETE CASCADE,
    quiz_data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES user_subscriptions(id) ON DELETE SET NULL,
    provider payment_provider NOT NULL,
    provider_payment_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT DEFAULT 'USD',
    status TEXT NOT NULL,
    payment_data JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Create Indexes
CREATE INDEX idx_user_profiles_email ON user_profiles(email);
CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(status);
CREATE INDEX idx_quiz_attempts_user_id ON quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_attempt_date ON quiz_attempts(attempt_date);
CREATE INDEX idx_quiz_attempts_subscription_id ON quiz_attempts(subscription_id);
CREATE INDEX idx_quiz_attempt_purchases_user_id ON quiz_attempt_purchases(user_id);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_provider_payment_id ON payments(provider_payment_id);

-- Create Functions
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO user_profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'role', 'user')::user_role
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION check_quiz_attempts_limit(user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER AS $$
    SELECT EXISTS (
        SELECT 1 FROM user_subscriptions us
        WHERE us.user_id = user_uuid 
        AND us.status = 'active'
        AND us.quiz_attempts_used < us.quiz_attempts_limit
        AND us.current_period_end > CURRENT_TIMESTAMP
    );
$$;

CREATE OR REPLACE FUNCTION record_quiz_attempt(
    p_user_id UUID,
    p_quiz_data JSONB,
    p_results JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER AS $$
DECLARE
    v_subscription_id UUID;
    v_attempt_id UUID;
BEGIN
    -- Get active subscription
    SELECT id INTO v_subscription_id
    FROM user_subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND current_period_end > CURRENT_TIMESTAMP
    LIMIT 1;

    IF v_subscription_id IS NULL THEN
        RAISE EXCEPTION 'No active subscription found';
    END IF;

    -- Create attempt
    INSERT INTO quiz_attempts (
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

    -- Update subscription
    UPDATE user_subscriptions
    SET quiz_attempts_used = quiz_attempts_used + 1,
        last_attempt_date = CURRENT_TIMESTAMP
    WHERE id = v_subscription_id;

    RETURN v_attempt_id;
END;
$$;

-- Create Triggers
CREATE TRIGGER update_user_profiles_timestamp
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_user_subscriptions_timestamp
    BEFORE UPDATE ON user_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_quiz_attempts_timestamp
    BEFORE UPDATE ON quiz_attempts
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_quiz_attempt_purchases_timestamp
    BEFORE UPDATE ON quiz_attempt_purchases
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_quiz_autosave_timestamp
    BEFORE UPDATE ON quiz_autosave
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Enable Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempt_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_autosave ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Create Policies
CREATE POLICY "users_manage_own_profile"
    ON user_profiles FOR ALL
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

CREATE POLICY "public_read_subscription_plans"
    ON subscription_plans FOR SELECT
    TO public
    USING (is_active = true);

CREATE POLICY "admin_manage_subscription_plans"
    ON subscription_plans FOR ALL
    TO authenticated
    USING (EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.id = auth.uid() AND up.role = 'admin'
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM user_profiles up
        WHERE up.id = auth.uid() AND up.role = 'admin'
    ));

CREATE POLICY "users_manage_own_subscriptions"
    ON user_subscriptions FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_quiz_attempts"
    ON quiz_attempts FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_purchases"
    ON quiz_attempt_purchases FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_autosave"
    ON quiz_autosave FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_payments"
    ON payments FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Insert Default Subscription Plans
INSERT INTO subscription_plans (name, plan_type, price, quiz_attempts, description, features) 
VALUES
    ('Free Plan', 'free', 0.00, 5, 'Basic skin analysis with limited attempts', 
     '["5 quiz attempts per month", "Basic skin analysis", "Email support"]'::jsonb),
    ('Standard Plan', 'standard', 10.00, 25, 'Enhanced skin analysis for regular users', 
     '["25 quiz attempts per month", "Advanced skin analysis", "Priority email support", "Skincare recommendations"]'::jsonb),
    ('Pro Plan', 'pro', 17.00, 50, 'Professional-grade skin analysis', 
     '["50 quiz attempts per month", "Professional skin analysis", "Phone support", "Personalized skincare routine", "Product discounts"]'::jsonb),
    ('Plus Plan', 'plus', 25.00, 80, 'Premium unlimited skin analysis', 
     '["80 quiz attempts per month", "Premium skin analysis", "24/7 support", "Custom skincare routine", "Exclusive product access", "Monthly consultation"]'::jsonb);

COMMIT;