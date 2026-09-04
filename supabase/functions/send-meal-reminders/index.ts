// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendOneSignalPush } from '../_shared/onesignal.ts';
// send-meal-reminders — Task 3. Invoked by pg_cron (06:00/12:00/18:00 UTC =
// 08:00/14:00/20:00 Cairo) via net.http_post with the vault-stored cron
// secret in the x-cron-secret header.
//
// For every user with meal reminders enabled (missing prefs row = enabled,
// per the all-ON default): if nothing was logged in nutrition_logs today
// (Cairo), send one bilingual nudge. Skips quiet hours and users already
// reminded in the same window today.

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const CAIRO_TZ = 'Africa/Cairo';

function cairoNow(): { date: string; time: string; hour: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: CAIRO_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date());
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  const hour = parseInt(get('hour') === '24' ? '0' : get('hour'), 10);
  return { date: `${get('year')}-${get('month')}-${get('day')}`, time: `${get('hour')}:${get('minute')}`, hour };
}

function inQuietHours(now: string, start: string | null, end: string | null): boolean {
  if (!start || !end) return false;
  return start <= end ? now >= start && now < end : now >= start || now < end;
}

Deno.serve(async (req: Request) => {
  try {
    const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
    if (!cronSecret || req.headers.get('x-cron-secret') !== cronSecret) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const { date, time, hour } = cairoNow();
    // Morning (08:00 run) / afternoon (14:00) / evening (20:00) window label
    // — used for the per-window dedupe in notification_log.
    const window = hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';

    // User universe: profiles (service role). Missing prefs row = all-ON.
    const { data: profiles } = await supabase.from('profiles').select('id');
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('user_id, meal_reminders_enabled, quiet_hours_start, quiet_hours_end')
      .eq('meal_reminders_enabled', true);
    const prefMap = new Map((prefs ?? []).map((p) => [p.user_id, p]));

    const cairoDayStartIso = new Date(`${date}T00:00:00+02:00`).toISOString();

    let sent = 0;
    let skippedLogged = 0;
    let skippedQuiet = 0;
    let skippedAlreadyReminded = 0;

    for (const profile of profiles ?? []) {
      const userId = profile.id;
      const pref = prefMap.get(userId);

      // Quiet hours (Cairo wall clock).
      if (inQuietHours(time, pref?.quiet_hours_start ?? null, pref?.quiet_hours_end ?? null)) {
        skippedQuiet++;
        continue;
      }

      // Already logged something today?
      const { data: todaysLogs } = await supabase
        .from('nutrition_logs')
        .select('id')
        .eq('user_id', userId)
        .gte('logged_at', cairoDayStartIso)
        .limit(1);
      if ((todaysLogs ?? []).length > 0) {
        skippedLogged++;
        continue;
      }

      // Already reminded in this window today?
      const { data: prior } = await supabase
        .from('notification_log')
        .select('id')
        .eq('user_id', userId)
        .eq('type', 'meal_reminder')
        .gte('sent_at', cairoDayStartIso)
        .contains('data', { window })
        .limit(1);
      if ((prior ?? []).length > 0) {
        skippedAlreadyReminded++;
        continue;
      }

      const result = await sendOneSignalPush({
        userId,
        title: "Don't forget to log your meals 🍽️",
        body: "You haven't logged anything today — log a meal to stay on track.",
        titleAr: 'متنساش تسجّل وجباتك النهاردة 🍽️',
        bodyAr: 'لسه مسجّلتش أي حاجة النهاردة — سجّل وجبة عشان تفضل على المسار. 📈',
        type: 'meal_reminder',
        data: { window },
      });

      // History for the Task 7 inbox + per-window dedupe.
      await supabase.from('notification_log').insert({
        user_id: userId,
        type: 'meal_reminder',
        title: "Don't forget to log your meals 🍽️",
        body: "You haven't logged anything today — log a meal to stay on track.",
        data: { window },
      });

      if (result.ok) sent++;
    }

    return new Response(
      JSON.stringify({ ok: true, window, sent, skippedLogged, skippedQuiet, skippedAlreadyReminded }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
