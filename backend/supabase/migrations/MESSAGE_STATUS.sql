-- ============================================================
-- INCREMENTAL MIGRATION: MESSAGE DELIVERY STATUS
-- Run this to add delivery status fields to messages table
-- ============================================================

-- Add delivery status columns to messages table
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS seen_at TIMESTAMP WITH TIME ZONE;

-- Add last_seen column to profiles for online status
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE;

-- Create index for faster online status queries
CREATE INDEX IF NOT EXISTS profiles_last_seen_idx ON public.profiles(last_seen);

-- Function to update last_seen when user is active
CREATE OR REPLACE FUNCTION public.update_last_seen()
RETURNS void AS $$
BEGIN
  UPDATE public.profiles 
  SET last_seen = TIMEZONE('utc', NOW())
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- DONE! Run this in Supabase SQL Editor
-- ============================================================
