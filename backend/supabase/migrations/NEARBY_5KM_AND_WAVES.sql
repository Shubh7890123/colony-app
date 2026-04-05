-- Enforce max 5 km for discovery (client cannot widen radius).
-- Waves: only allowed when both users have coordinates and are within 5 km
-- (accepted chats stay available via conversations; this policy is INSERT only).

CREATE OR REPLACE FUNCTION public.get_nearby_users(
  user_lat double precision,
  user_lon double precision,
  radius_km double precision DEFAULT 5.0
)
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
DECLARE
  cap_km double precision;
BEGIN
  cap_km := LEAST(COALESCE(radius_km, 5.0), 5.0);

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
    public.calculate_distance(user_lat, user_lon, p.latitude, p.longitude) AS distance
  FROM public.profiles p
  WHERE p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND public.calculate_distance(user_lat, user_lon, p.latitude, p.longitude) <= cap_km
    AND p.id != auth.uid()
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_nearby_groups(
  user_lat double precision,
  user_lon double precision,
  radius_km double precision DEFAULT 5.0
)
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
DECLARE
  cap_km double precision;
BEGIN
  cap_km := LEAST(COALESCE(radius_km, 5.0), 5.0);

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
    (SELECT COUNT(*)::bigint FROM public.group_members gm WHERE gm.group_id = g.id) AS member_count,
    public.calculate_distance(user_lat, user_lon, g.latitude, g.longitude) AS distance
  FROM public.groups g
  WHERE g.latitude IS NOT NULL
    AND g.longitude IS NOT NULL
    AND public.calculate_distance(user_lat, user_lon, g.latitude, g.longitude) <= cap_km
    AND g.is_private = false
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Distance check for new waves (both profiles must have lat/lon).
CREATE OR REPLACE FUNCTION public.are_profiles_within_km(
  profile_a uuid,
  profile_b uuid,
  max_km double precision DEFAULT 5.0
)
RETURNS boolean AS $$
DECLARE
  a_lat double precision;
  a_lon double precision;
  b_lat double precision;
  b_lon double precision;
  cap double precision;
BEGIN
  cap := LEAST(GREATEST(COALESCE(max_km, 5.0), 0.0), 5.0);

  SELECT p.latitude, p.longitude INTO a_lat, a_lon
  FROM public.profiles p WHERE p.id = profile_a;

  SELECT p.latitude, p.longitude INTO b_lat, b_lon
  FROM public.profiles p WHERE p.id = profile_b;

  IF a_lat IS NULL OR a_lon IS NULL OR b_lat IS NULL OR b_lon IS NULL THEN
    RETURN false;
  END IF;

  RETURN public.calculate_distance(a_lat, a_lon, b_lat, b_lon) <= cap;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

DROP POLICY IF EXISTS "Users can send waves" ON public.waves;

CREATE POLICY "Users can send waves" ON public.waves
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND public.are_profiles_within_km(sender_id, receiver_id, 5.0)
  );
