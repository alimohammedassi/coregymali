// Shared OneSignal push helper — used by every notification flow
// (welcome, meal/water reminders, calorie alerts, chat messages).
//
// Required Supabase secrets (Project Settings → Edge Functions → Secrets):
//   ONESIGNAL_APP_ID         — the CoreGym app id from the OneSignal dashboard
//   ONESIGNAL_REST_API_KEY   — the REST API key (server-side only, NEVER in Flutter)
//
// Users are targeted by OneSignal's external_id alias, which the Flutter app
// sets to our Supabase auth user_id via OneSignal.login() on sign-in.

export interface PushPayload {
  /** Our Supabase auth user id — used as the OneSignal external_id alias. */
  userId: string;
  title: string;
  body: string;
  /** Optional Arabic variants — OneSignal picks per device language. */
  titleAr?: string;
  bodyAr?: string;
  /** welcome | meal_reminder | water_reminder | calorie_alert | chat */
  type: string;
  /** Extra data for deep-linking (e.g. { conversationId }). */
  data?: Record<string, unknown>;
}

export interface PushResult {
  ok: boolean;
  /** OneSignal notification id on success, error message on failure. */
  id?: string;
  error?: string;
}

export async function sendOneSignalPush(payload: PushPayload): Promise<PushResult> {
  const appId = Deno.env.get('ONESIGNAL_APP_ID');
  const apiKey = Deno.env.get('ONESIGNAL_REST_API_KEY');
  if (!appId || !apiKey) {
    return { ok: false, error: 'OneSignal secrets not configured' };
  }

  try {
    const res = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${apiKey}`,
      },
      body: JSON.stringify({
        app_id: appId,
        target_channel: 'push',
        // external_id alias == Supabase auth user id (set by OneSignal.login)
        include_aliases: { external_id: [payload.userId] },
        headings: { en: payload.title, ...(payload.titleAr ? { ar: payload.titleAr } : {}) },
        contents: { en: payload.body, ...(payload.bodyAr ? { ar: payload.bodyAr } : {}) },
        data: { type: payload.type, ...(payload.data ?? {}) },
      }),
    });

    const json = await res.json();
    if (!res.ok || json.errors) {
      return {
        ok: false,
        error: json.errors
          ? JSON.stringify(json.errors)
          : `HTTP ${res.status}`,
      };
    }
    return { ok: true, id: json.id };
  } catch (e) {
    return { ok: false, error: String(e) };
  }
}
