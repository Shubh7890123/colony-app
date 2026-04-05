-- Optional: live updates in group chat (Flutter Realtime).
-- Skip if already in publication.

ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;
