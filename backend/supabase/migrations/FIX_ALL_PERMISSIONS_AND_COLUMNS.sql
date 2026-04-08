-- ============================================================
-- FIX: Grant permissions on ALL tables to authenticated role
-- Without these GRANTs, PostgREST blocks access BEFORE RLS is checked.
-- ============================================================

-- Conversations
GRANT SELECT, INSERT, UPDATE ON public.conversations TO authenticated;

-- Messages
GRANT SELECT, INSERT, UPDATE ON public.messages TO authenticated;

-- Waves
GRANT SELECT, INSERT, UPDATE, DELETE ON public.waves TO authenticated;

-- Stories
GRANT SELECT, INSERT, DELETE ON public.stories TO authenticated;

-- Story Views
GRANT SELECT, INSERT ON public.story_views TO authenticated;

-- Groups
GRANT SELECT, INSERT, UPDATE ON public.groups TO authenticated;

-- Group Members
GRANT SELECT, INSERT, DELETE ON public.group_members TO authenticated;

-- Group Messages
GRANT SELECT, INSERT ON public.group_messages TO authenticated;

-- ============================================================
-- FIX: Add missing columns to profiles
-- ============================================================

-- last_seen (used by online status feature)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE;

-- ============================================================
-- FIX: Add missing columns to messages
-- ============================================================

-- delivered_at (delivery receipts)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP WITH TIME ZONE;

-- seen_at (read receipts)
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS seen_at TIMESTAMP WITH TIME ZONE;

-- ============================================================
-- FIX: Ensure Realtime is enabled for key tables
-- (These may already be enabled — errors for "already member" are safe to ignore)
-- ============================================================

-- ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.waves;

-- ============================================================
-- VERIFICATION: Run these queries after migration to confirm:
--
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee = 'authenticated'
-- ORDER BY table_name;
-- ============================================================
