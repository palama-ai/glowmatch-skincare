-- حذف كل المشغلات والسياسات المكررة
DO $$
BEGIN
    -- حذف المشغلات
    DROP TRIGGER IF EXISTS update_quiz_attempt_purchases_updated_at ON quiz_attempt_purchases;
    DROP TRIGGER IF EXISTS update_quiz_attempts_updated_at ON quiz_attempts;
    DROP TRIGGER IF EXISTS update_subscription_attempts_on_quiz_attempt ON quiz_attempts;
    DROP TRIGGER IF EXISTS update_quiz_autosave_timestamp ON quiz_autosave;

    -- حذف السياسات
    DROP POLICY IF EXISTS "Users can view their own autosave data" ON quiz_autosave;
    DROP POLICY IF EXISTS "Users can update their own autosave data" ON quiz_autosave;
    DROP POLICY IF EXISTS "Users can insert their own autosave data" ON quiz_autosave;
    DROP POLICY IF EXISTS "Users can delete their own autosave data" ON quiz_autosave;
    DROP POLICY IF EXISTS "Users can read their own quiz attempts" ON quiz_attempts;
    DROP POLICY IF EXISTS "Users can insert their own quiz attempts" ON quiz_attempts;
    DROP POLICY IF EXISTS "Users can view their own quiz attempts" ON quiz_attempts;
    DROP POLICY IF EXISTS "Users can read their own purchases" ON quiz_attempt_purchases;
    DROP POLICY IF EXISTS "Users can insert their own purchases" ON quiz_attempt_purchases;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error dropping existing objects: %', SQLERRM;
END $$;

-- تحديث أو إنشاء الجداول

-- 1. جدول quiz_autosave
CREATE TABLE IF NOT EXISTS quiz_autosave (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    quiz_data jsonb NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. تحديث جدول user_subscriptions
ALTER TABLE user_subscriptions
ADD COLUMN IF NOT EXISTS last_attempt_date timestamptz DEFAULT NULL,
ADD COLUMN IF NOT EXISTS quiz_attempts_used integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS quiz_attempts_limit integer DEFAULT 3;

-- 3. جدول quiz_attempt_purchases
CREATE TABLE IF NOT EXISTS quiz_attempt_purchases (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    quantity integer NOT NULL,
    amount_paid decimal(10,2) NOT NULL,
    purchase_date timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 4. جدول quiz_attempts مع عمود attempt_date
CREATE TABLE IF NOT EXISTS quiz_attempts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id uuid REFERENCES user_subscriptions(id) ON DELETE CASCADE,
    quiz_data jsonb NOT NULL,
    results jsonb,
    attempt_date timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- تمكين RLS على جميع الجداول
ALTER TABLE quiz_autosave ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempt_purchases ENABLE ROW LEVEL SECURITY;

-- إنشاء الوظائف المساعدة

-- 1. وظيفة تحديث التواريخ
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 2. وظيفة تسجيل محاولة الاختبار
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
    -- الحصول على الاشتراك النشط للمستخدم
    SELECT id INTO v_subscription_id
    FROM public.user_subscriptions
    WHERE user_id = p_user_id
    AND status = 'active'
    AND current_period_end > CURRENT_TIMESTAMP
    LIMIT 1;

    IF v_subscription_id IS NULL THEN
        RAISE EXCEPTION 'No active subscription found';
    END IF;

    -- إنشاء محاولة الاختبار
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

    -- تحديث عدد المحاولات في الاشتراك
    UPDATE public.user_subscriptions
    SET quiz_attempts_used = quiz_attempts_used + 1,
        last_attempt_date = CURRENT_TIMESTAMP
    WHERE id = v_subscription_id;

    RETURN v_attempt_id;
END;
$$;

-- إنشاء المشغلات

-- 1. تحديث التواريخ في quiz_autosave
CREATE TRIGGER update_quiz_autosave_timestamp
    BEFORE UPDATE ON quiz_autosave
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- 2. تحديث التواريخ في quiz_attempts
CREATE TRIGGER update_quiz_attempts_timestamp
    BEFORE UPDATE ON quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- 3. تحديث التواريخ في quiz_attempt_purchases
CREATE TRIGGER update_quiz_attempt_purchases_timestamp
    BEFORE UPDATE ON quiz_attempt_purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- إنشاء السياسات

-- 1. سياسات quiz_autosave
CREATE POLICY "Users can manage their own autosave data"
ON quiz_autosave FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 2. سياسات quiz_attempts
CREATE POLICY "Users can manage their own quiz attempts"
ON quiz_attempts FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 3. سياسات quiz_attempt_purchases
CREATE POLICY "Users can manage their own purchases"
ON quiz_attempt_purchases FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- إنشاء الفهارس
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_attempt_date ON quiz_attempts(attempt_date);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_id ON quiz_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempts_subscription_id ON quiz_attempts(subscription_id);
CREATE INDEX IF NOT EXISTS idx_quiz_attempt_purchases_user_id ON quiz_attempt_purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_quiz_autosave_user_id ON quiz_autosave(user_id);

-- تحديث البيانات الموجودة
UPDATE quiz_attempts
SET attempt_date = created_at
WHERE attempt_date IS NULL;

-- تحديث عدد المحاولات المستخدمة في الاشتراكات
WITH attempt_counts AS (
    SELECT subscription_id, COUNT(*) as attempt_count
    FROM quiz_attempts
    GROUP BY subscription_id
)
UPDATE user_subscriptions us
SET quiz_attempts_used = COALESCE(ac.attempt_count, 0)
FROM attempt_counts ac
WHERE us.id = ac.subscription_id;