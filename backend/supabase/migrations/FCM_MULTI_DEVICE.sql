-- Migration: support multiple devices per user for push notifications

-- Remove strict one-token-per-user constraint
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'user_fcm_tokens_user_id_key'
  ) THEN
    ALTER TABLE user_fcm_tokens DROP CONSTRAINT user_fcm_tokens_user_id_key;
  END IF;
END $$;

-- Ensure device_id exists
ALTER TABLE user_fcm_tokens
  ADD COLUMN IF NOT EXISTS device_id TEXT;

-- Backfill existing rows
UPDATE user_fcm_tokens
SET device_id = COALESCE(device_id, 'legacy-' || SUBSTRING(fcm_token FROM 1 FOR 24))
WHERE device_id IS NULL;

-- device_id should be present for conflict target
ALTER TABLE user_fcm_tokens
  ALTER COLUMN device_id SET NOT NULL;

-- Avoid duplicate token rows
CREATE UNIQUE INDEX IF NOT EXISTS user_fcm_tokens_fcm_token_uq
  ON user_fcm_tokens (fcm_token);

-- One row per user-device pair
CREATE UNIQUE INDEX IF NOT EXISTS user_fcm_tokens_user_device_uq
  ON user_fcm_tokens (user_id, device_id);
