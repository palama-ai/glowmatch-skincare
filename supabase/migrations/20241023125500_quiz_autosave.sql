-- Create quiz autosave table
CREATE TABLE IF NOT EXISTS quiz_autosave (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    quiz_data jsonb NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add RLS policies
ALTER TABLE quiz_autosave ENABLE ROW LEVEL SECURITY;

-- Allow users to view their own autosave data
CREATE POLICY "Users can view their own autosave data"
ON quiz_autosave FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Allow users to update their own autosave data
CREATE POLICY "Users can update their own autosave data"
ON quiz_autosave FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- Allow users to insert their own autosave data
CREATE POLICY "Users can insert their own autosave data"
ON quiz_autosave FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Allow users to delete their own autosave data
CREATE POLICY "Users can delete their own autosave data"
ON quiz_autosave FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION update_quiz_autosave_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for updating timestamps
CREATE TRIGGER update_quiz_autosave_timestamp
    BEFORE UPDATE ON quiz_autosave
    FOR EACH ROW
    EXECUTE FUNCTION update_quiz_autosave_timestamp();