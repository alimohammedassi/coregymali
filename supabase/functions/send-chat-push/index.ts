// @ts-nocheck
// send-chat-push — Task 6. Invoked by the notify_new_message() DB trigger
// (via pg_net) whenever a chat message is inserted. Pushes to the receiving
// participant with the sender name + a type-aware preview, and deep-link
// data so tapping the notification opens that conversation.
//
// Auth: x-cron-secret header must match the CRON_SECRET function secret
// (same vault-generated value the trigger reads) — deployed with
// --no-verify-jwt since the secret header is the auth.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendOneSignalPush } from '../_shared/onesignal.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req: Request) => {
  try {
    const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
    if (!cronSecret || req.headers.get('x-cron-secret') !== cronSecret) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const { recipient_id, sender_name, preview, conversation_id } = await req.json();
    if (!recipient_id || !conversation_id) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing fields' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // chat_notifications_enabled (missing prefs row = enabled).
    const { data: pref } = await supabase
      .from('notification_preferences')
      .select('chat_notifications_enabled')
      .eq('user_id', recipient_id)
      .maybeSingle();
    if (pref && pref.chat_notifications_enabled === false) {
      return new Response(JSON.stringify({ ok: true, skipped: 'disabled' }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const name = sender_name ?? 'New message';
    const result = await sendOneSignalPush({
      userId: recipient_id,
      title: name,
      body: preview ?? 'New message',
      titleAr: name,
      bodyAr: preview ?? 'رسالة جديدة',
      type: 'chat',
      data: { conversation_id },
    });

    // In-app history (Task 7 inbox) + tap deep-link.
    try {
      await supabase.from('notification_log').insert({
        user_id: recipient_id,
        type: 'chat',
        title: name,
        body: preview ?? 'New message',
        data: { conversation_id },
      });
    } catch (logError) {
      console.error('notification_log insert failed:', logError);
    }

    return new Response(JSON.stringify(result), {
      status: result.ok ? 200 : 500,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
