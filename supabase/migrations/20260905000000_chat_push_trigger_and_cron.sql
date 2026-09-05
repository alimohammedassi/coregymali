-- Task 3 — meal reminder cron + Task 6 — chat push trigger.
-- NOTE: applied live via the Management API on 2026-09-05; kept here for
-- reproducibility. The cron secret lives in Vault (generated at apply time,
-- never in the repo) and is mirrored into the CRON_SECRET edge-function
-- secret so the functions can verify the calls.

-- ── Task 3: meal reminder schedule (08:00 / 14:00 / 20:00 Cairo = UTC+2) ──
-- select vault.create_secret(encode(gen_random_bytes(32), 'hex'), 'coregym_cron_secret');
-- (already created — re-running would duplicate; the schedule below reads it)

-- select cron.schedule(
--   'coregym-meal-reminders',
--   '0 6,12,18 * * *',
--   $$ select net.http_post(
--        url := 'https://mkrjvrnysuvtokqkyoll.supabase.co/functions/v1/send-meal-reminders',
--        headers := jsonb_build_object(
--          'Content-Type', 'application/json',
--          'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'coregym_cron_secret')
--        ),
--        body := '{}'::jsonb
--      ) $$
-- );

-- ── Task 6: chat push fired from the notify_new_message trigger ────────────
CREATE OR REPLACE FUNCTION public.notify_new_message()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  r uuid;
  sender_name text;
  preview text;
  content text;
BEGIN
  SELECT CASE WHEN NEW.sender_id = c.client_id THEN c.coach_id ELSE c.client_id END INTO r
  FROM conversations c WHERE c.id = NEW.conversation_id;
  IF r IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT coalesce(full_name, name, 'CoreGym') INTO sender_name
  FROM profiles WHERE id = NEW.sender_id;

  content := coalesce(NEW.content, '');
  IF NEW.type = 'voice' THEN
    preview := '🎤 Voice message (' || content || 's)';
  ELSIF NEW.type = 'image' THEN
    preview := '📷 Photo';
  ELSIF NEW.type = 'file' THEN
    preview := '📎 ' || coalesce(CASE WHEN content LIKE '{%' THEN (content::jsonb->>'name') END, 'File');
  ELSE
    preview := substr(content, 1, 60);
  END IF;

  INSERT INTO notifications (user_id, type, title, body, conversation_id)
  VALUES (r, 'message', sender_name, preview, NEW.conversation_id);

  -- OneSignal push for the receiving participant (async via pg_net).
  PERFORM net.http_post(
    url := 'https://mkrjvrnysuvtokqkyoll.supabase.co/functions/v1/send-chat-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'coregym_cron_secret')
    ),
    body := jsonb_build_object(
      'recipient_id', r,
      'sender_name', sender_name,
      'preview', preview,
      'conversation_id', NEW.conversation_id
    )
  );

  RETURN NEW;
END;
$function$;
