-- ============================================================
-- COMPLETE COLONY APP DATABASE MIGRATION
-- Run this entire script in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- STEP 1: PROFILES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    username TEXT UNIQUE,
    full_name TEXT,
    display_name TEXT,
    avatar_url TEXT,
    device_id TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_text TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Drop existing policies first (in case of re-run)
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by authenticated users" ON public.profiles;

-- IMPORTANT: PostgREST/SQL privileges are checked before RLS policies.
-- Without explicit GRANTs, users can still get "permission denied for table profiles".
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

-- Authenticated users can view all profiles
CREATE POLICY "Profiles are viewable by authenticated users" ON public.profiles
    FOR SELECT TO authenticated USING (true);

-- Users can update their own profile
CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Create indexes
CREATE INDEX IF NOT EXISTS profiles_username_idx ON public.profiles(username);
CREATE INDEX IF NOT EXISTS profiles_device_id_idx ON public.profiles(device_id);
CREATE INDEX IF NOT EXISTS profiles_location_idx ON public.profiles(latitude, longitude);

-- Create function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, username, full_name, display_name, device_id)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'display_name',
        NEW.raw_user_meta_data->>'device_id'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update profile when user metadata changes
CREATE OR REPLACE FUNCTION public.handle_user_update()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.profiles
    SET
        username = COALESCE(NEW.raw_user_meta_data->>'username', username),
        full_name = COALESCE(NEW.raw_user_meta_data->>'full_name', full_name),
        display_name = COALESCE(NEW.raw_user_meta_data->>'display_name', display_name),
        updated_at = TIMEZONE('utc', NOW())
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for user updates
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
    AFTER UPDATE ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();


-- ============================================================
-- STEP 2: STORIES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.stories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    media_url TEXT NOT NULL,
    media_type TEXT DEFAULT 'image' CHECK (media_type IN ('image', 'video')),
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (TIMEZONE('utc', NOW()) + INTERVAL '24 hours')
);

-- Enable RLS
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Stories are viewable by authenticated users" ON public.stories
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can insert their own stories" ON public.stories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own stories" ON public.stories
    FOR DELETE USING (auth.uid() = user_id);

-- Index for fetching active stories
CREATE INDEX IF NOT EXISTS stories_active_idx ON public.stories(created_at DESC);


-- ============================================================
-- STEP 3: STORY VIEWS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.story_views (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    story_id UUID REFERENCES public.stories(id) ON DELETE CASCADE NOT NULL,
    viewer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(story_id, viewer_id)
);

ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Story views are viewable by story owner" ON public.story_views
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.stories WHERE stories.id = story_views.story_id AND stories.user_id = auth.uid())
    );

CREATE POLICY "Users can insert their own views" ON public.story_views
    FOR INSERT WITH CHECK (auth.uid() = viewer_id);


-- ============================================================
-- STEP 4: GROUPS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT DEFAULT 'general',
    cover_image_url TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    location_text TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    is_private BOOLEAN DEFAULT false
);

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Groups are viewable by authenticated users" ON public.groups
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create groups" ON public.groups
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Group creators can update their groups" ON public.groups
    FOR UPDATE USING (created_by = auth.uid());

-- Index for location-based queries
CREATE INDEX IF NOT EXISTS groups_location_idx ON public.groups(latitude, longitude);


-- ============================================================
-- STEP 5: GROUP MEMBERS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(group_id, user_id)
);

ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members are viewable by authenticated users" ON public.group_members
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can join groups" ON public.group_members
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can leave groups" ON public.group_members
    FOR DELETE USING (auth.uid() = user_id);


-- ============================================================
-- STEP 6: WAVES TABLE (mutual wave enables chat)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.waves (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    receiver_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    responded_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(sender_id, receiver_id)
);

ALTER TABLE public.waves ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own waves" ON public.waves
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send waves" ON public.waves
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update waves they received" ON public.waves
    FOR UPDATE USING (auth.uid() = receiver_id);


-- ============================================================
-- STEP 7: CHAT CONVERSATIONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user1_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    user2_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    last_message_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user1_id, user2_id)
);

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own conversations" ON public.conversations
    FOR SELECT USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "Users can create conversations" ON public.conversations
    FOR INSERT WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);


-- ============================================================
-- STEP 8: MESSAGES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    media_url TEXT,
    media_type TEXT CHECK (media_type IN ('image', 'video', 'audio')),
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view messages in their conversations" ON public.messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.conversations
            WHERE conversations.id = messages.conversation_id
            AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
        )
    );

CREATE POLICY "Users can insert messages in their conversations" ON public.messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.conversations
            WHERE conversations.id = messages.conversation_id
            AND (conversations.user1_id = auth.uid() OR conversations.user2_id = auth.uid())
        )
    );

-- Index for fetching messages
CREATE INDEX IF NOT EXISTS messages_conversation_idx ON public.messages(conversation_id, created_at DESC);


-- ============================================================
-- STEP 9: USER KEYS TABLE (for E2E encryption)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.user_keys (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    key_version INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE public.user_keys ENABLE ROW LEVEL SECURITY;

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
GRANT SELECT, INSERT, UPDATE ON public.user_keys TO authenticated;

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS user_keys_user_id_idx ON public.user_keys(user_id);


-- ============================================================
-- STEP 10: GROUP CHAT MESSAGES TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.group_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    media_url TEXT,
    media_type TEXT CHECK (media_type IN ('image', 'video', 'audio')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Group members can view messages" ON public.group_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.group_members
            WHERE group_members.group_id = group_messages.group_id
            AND group_members.user_id = auth.uid()
        )
    );

CREATE POLICY "Group members can send messages" ON public.group_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.group_members
            WHERE group_members.group_id = group_messages.group_id
            AND group_members.user_id = auth.uid()
        )
    );


-- ============================================================
-- STEP 11: FUNCTIONS FOR LOCATION-BASED QUERIES
-- ============================================================

-- Function to calculate distance between two points (in km) using Haversine formula
CREATE OR REPLACE FUNCTION calculate_distance(lat1 double precision, lon1 double precision, lat2 double precision, lon2 double precision)
RETURNS double precision AS $$
BEGIN
    RETURN (
        6371 * acos(
            cos(radians(lat1)) * cos(radians(lat2)) * cos(radians(lon2) - radians(lon1)) +
            sin(radians(lat1)) * sin(radians(lat2))
        )
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get nearby users within radius
CREATE OR REPLACE FUNCTION get_nearby_users(user_lat double precision, user_lon double precision, radius_km double precision DEFAULT 5.0)
RETURNS TABLE (
    id uuid,
    email text,
    username text,
    full_name text,
    display_name text,
    avatar_url text,
    bio text,
    location_text text,
    distance double precision
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.email,
        p.username,
        p.full_name,
        p.display_name,
        p.avatar_url,
        p.bio,
        p.location_text,
        calculate_distance(user_lat, user_lon, p.latitude, p.longitude) as distance
    FROM public.profiles p
    WHERE p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND calculate_distance(user_lat, user_lon, p.latitude, p.longitude) <= radius_km
    AND p.id != auth.uid()
    ORDER BY distance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Allow authenticated role to execute location RPCs
GRANT EXECUTE ON FUNCTION public.get_nearby_users(double precision, double precision, double precision)
  TO authenticated;

-- Function to get nearby groups within radius
CREATE OR REPLACE FUNCTION get_nearby_groups(user_lat double precision, user_lon double precision, radius_km double precision DEFAULT 5.0)
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    category text,
    cover_image_url text,
    location_text text,
    latitude double precision,
    longitude double precision,
    is_private boolean,
    member_count bigint,
    distance double precision
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        g.id,
        g.name,
        g.description,
        g.category,
        g.cover_image_url,
        g.location_text,
        g.latitude,
        g.longitude,
        g.is_private,
        (SELECT COUNT(*) FROM public.group_members WHERE group_members.group_id = g.id) as member_count,
        calculate_distance(user_lat, user_lon, g.latitude, g.longitude) as distance
    FROM public.groups g
    WHERE g.latitude IS NOT NULL
    AND g.longitude IS NOT NULL
    AND calculate_distance(user_lat, user_lon, g.latitude, g.longitude) <= radius_km
    AND g.is_private = false
    ORDER BY distance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Allow authenticated role to execute location RPCs
GRANT EXECUTE ON FUNCTION public.get_nearby_groups(double precision, double precision, double precision)
  TO authenticated;


-- ============================================================
-- STEP 12: FUNCTION TO CHECK IF CHAT IS ENABLED
-- ============================================================

CREATE OR REPLACE FUNCTION can_chat_with(target_user_id uuid)
RETURNS boolean AS $$
DECLARE
    wave_exists integer;
BEGIN
    SELECT COUNT(*) INTO wave_exists
    FROM public.waves w
    WHERE ((w.sender_id = auth.uid() AND w.receiver_id = target_user_id)
        OR (w.sender_id = target_user_id AND w.receiver_id = auth.uid()))
    AND w.status = 'accepted';

    RETURN wave_exists > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.can_chat_with(uuid) TO authenticated;


-- ============================================================
-- STEP 13: TRIGGER TO UPDATE LAST_MESSAGE_AT
-- ============================================================

CREATE OR REPLACE FUNCTION update_conversation_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.conversations
    SET last_message_at = TIMEZONE('utc', NOW())
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_message_inserted ON public.messages;
CREATE TRIGGER on_message_inserted
    AFTER INSERT ON public.messages
    FOR EACH ROW EXECUTE FUNCTION update_conversation_timestamp();


-- ============================================================
-- MIGRATION COMPLETE!
-- ============================================================
-- After running this script, your Supabase database will have:
-- 1. profiles - User profiles with location support
-- 2. stories - User stories (24hr expiry)
-- 3. story_views - Track who viewed stories
-- 4. groups - User-created groups
-- 5. group_members - Group membership
-- 6. waves - Mutual wave system for chat enable
-- 7. conversations - Chat conversations
-- 8. messages - Chat messages
-- 9. user_keys - Public keys for E2E encryption
-- 10. group_messages - Group chat messages
-- 11. Functions for location-based queries
-- 12. Function to check if chat is enabled
-- 13. Trigger to update conversation timestamp
-- ============================================================
