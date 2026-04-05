-- Migration: FCM Tokens for Push Notifications
-- Created: 2024-01-XX

-- Create user_fcm_tokens table
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_id TEXT,
    device_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);

-- Enable RLS
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own FCM token"
    ON user_fcm_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own FCM token"
    ON user_fcm_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM token"
    ON user_fcm_tokens FOR UPDATE
    USING (auth.uid() = user_id);

-- Function to send push notification (callable from Edge Function)
CREATE OR REPLACE FUNCTION get_user_fcm_token(target_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    token TEXT;
BEGIN
    SELECT fcm_token INTO token
    FROM user_fcm_tokens
    WHERE user_id = target_user_id;
    
    RETURN token;
END;
$$;

-- Function to delete old/invalid tokens
CREATE OR REPLACE FUNCTION cleanup_invalid_tokens()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM user_fcm_tokens
    WHERE updated_at < NOW() - INTERVAL '30 days';
END;
$$;
