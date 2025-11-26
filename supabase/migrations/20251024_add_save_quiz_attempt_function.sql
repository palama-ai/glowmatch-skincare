-- Create the save_quiz_attempt function
CREATE OR REPLACE FUNCTION public.save_quiz_attempt(
    p_user_id uuid,
    p_quiz_data jsonb,
    p_results jsonb DEFAULT '{}'::jsonb,
    p_has_image_analysis boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_attempt_id uuid;
BEGIN
    -- Insert the quiz attempt
    INSERT INTO public.quiz_attempts (
        user_id,
        quiz_data,
        results,
        has_image_analysis,
        attempt_date
    )
    VALUES (
        p_user_id,
        p_quiz_data,
        p_results,
        p_has_image_analysis,
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_attempt_id;

    -- Clean up any autosave data
    DELETE FROM public.quiz_autosave
    WHERE user_id = p_user_id;

    -- Return the created attempt
    RETURN jsonb_build_object(
        'id', v_attempt_id,
        'status', 'success'
    );
END;
$$;