-- ============================================================
-- INCREMENTAL MIGRATION: USER_KEYS TABLE FOR E2E ENCRYPTION
-- Run this ONLY if you already have the database set up
-- This adds the user_keys table for storing public keys
-- ============================================================

-- Create user_keys table for E2E encryption
CREATE TABLE IF NOT EXISTS public.user_keys (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    key_version INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Enable Row Level Security
ALTER TABLE public.user_keys ENABLE ROW LEVEL SECURITY;

-- Policies for user_keys
DROP POLICY IF EXISTS "Users can view their own keys" ON public.user_keys;
DROP POLICY IF EXISTS "Users can view public keys for encryption" ON public.user_keys;
DROP POLICY IF EXISTS "Users can insert their own keys" ON public.user_keys;
DROP POLICY IF EXISTS "Users can update their own keys" ON public.user_keys;

-- Users can view their own keys
CREATE POLICY "Users can view their own keys" ON public.user_keys
    FOR SELECT USING (auth.uid() = user_id);

-- Users can view other users' public keys (needed for E2E encryption)
CREATE POLICY "Users can view public keys for encryption" ON public.user_keys
    FOR SELECT TO authenticated USING (true);

-- Users can insert their own keys
CREATE POLICY "Users can insert their own keys" ON public.user_keys
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own keys
CREATE POLICY "Users can update their own keys" ON public.user_keys
    FOR UPDATE USING (auth.uid() = user_id);

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_keys TO authenticated;

-- Create index for quick lookup
CREATE INDEX IF NOT EXISTS user_keys_user_id_idx ON public.user_keys(user_id);

-- ============================================================
-- DONE! Run this in Supabase SQL Editor to add E2E encryption support
-- ============================================================
