-- Add new columns to user_subscriptions table
ALTER TABLE user_subscriptions
ADD COLUMN IF NOT EXISTS last_attempt_date timestamptz DEFAULT NULL,
ADD COLUMN IF NOT EXISTS quiz_attempts_used integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS quiz_attempts_limit integer DEFAULT 3;

-- Create quiz attempt purchases table
CREATE TABLE IF NOT EXISTS quiz_attempt_purchases (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    quantity integer NOT NULL,
    amount_paid decimal(10,2) NOT NULL,
    purchase_date timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updating timestamps
CREATE TRIGGER update_quiz_attempt_purchases_updated_at
    BEFORE UPDATE ON quiz_attempt_purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_timestamp();

-- Create quiz attempts table
CREATE TABLE IF NOT EXISTS quiz_attempts (
    id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id uuid REFERENCES user_subscriptions(id) ON DELETE CASCADE,
    quiz_data jsonb NOT NULL,
    results jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create trigger for updating timestamps
CREATE TRIGGER update_quiz_attempts_updated_at
    BEFORE UPDATE ON quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_timestamp();

-- Create function to update subscription attempts count
CREATE OR REPLACE FUNCTION update_subscription_attempts()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the quiz_attempts_used and last_attempt_date in user_subscriptions
    UPDATE user_subscriptions
    SET 
        quiz_attempts_used = quiz_attempts_used + 1,
        last_attempt_date = now()
    WHERE id = NEW.subscription_id;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to update subscription attempts when quiz attempt is created
CREATE TRIGGER update_subscription_attempts_on_quiz_attempt
    AFTER INSERT ON quiz_attempts
    FOR EACH ROW
    EXECUTE FUNCTION update_subscription_attempts();

-- Create policy to allow authenticated users to read their own attempts
CREATE POLICY "Users can read their own quiz attempts"
ON quiz_attempts FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Create policy to allow authenticated users to insert their own attempts
CREATE POLICY "Users can insert their own quiz attempts"
ON quiz_attempts FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Create policy to allow authenticated users to read their own purchases
CREATE POLICY "Users can read their own purchases"
ON quiz_attempt_purchases FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Create policy to allow authenticated users to insert their own purchases
CREATE POLICY "Users can insert their own purchases"
ON quiz_attempt_purchases FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Enable RLS on new tables
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempt_purchases ENABLE ROW LEVEL SECURITY;