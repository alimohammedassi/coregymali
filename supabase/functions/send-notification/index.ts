// @ts-nocheck
// send-notification — test/admin callable for OneSignal pushes.
//
// POST /functions/v1/send-notification
// Auth: Bearer <user JWT> (required). Users may only send a test push to
// THEMSELVES — server flows (cron/chat triggers) call the shared helper
// directly with the service role instead.
//
// Body: { "user_id": "<uuid>", "title": "...", "body": "...", "type": "test" }
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendOneSignalPush } from '../_shared/onesignal.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing authorization header');

    const token = authHeader.replace('Bearer ', '');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    // Server callers (cron, triggers, CI) pass the shared secret in a
    // separate header so the platform's JWT check still sees a valid JWT in
    // Authorization.
    const adminHeader = req.headers.get('x-admin-key') ?? '';
    const adminKey = Deno.env.get('ADMIN_API_KEY') ?? '';

    // Two accepted callers:
    //  - server-side (service role bearer or x-admin-key secret): may push
    //    to any user_id — keys never leave the server
    //  - a signed-in user JWT: may only push to themselves
    const isAdmin =
        (serviceKey.length > 0 && token === serviceKey) ||
        (adminKey.length > 0 && adminHeader === adminKey);

    if (!isAdmin) {
      const { data: userData, error: authError } = await supabase.auth.getUser(token);
      if (authError || !userData?.user) throw new Error('Invalid token');
      const { user_id } = await req.json();
      if (user_id !== userData.user.id) {
        throw new Error('user_id must match the authenticated user');
      }
    }

    const { user_id, title, body, type } = await req.json();

    const result = await sendOneSignalPush({
      userId: user_id,
      title: title ?? 'CoreGym test',
      body: body ?? 'Push notifications are working 💪',
      type: type ?? 'test',
    });

    return new Response(JSON.stringify(result), {
      status: result.ok ? 200 : 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    });
  }
});
