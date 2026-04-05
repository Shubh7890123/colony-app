-- Chat list + pending waves: client subscribes via Supabase Realtime.
-- Run once if conversations/messages/waves events are not received.
-- (Skip lines that error with "already member of publication".)

ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.waves;
