// delete-account — permanently deletes the calling user's account and every
// row tied to it (profile, goals, workout history, subscriptions, coach
// content when the caller is a coach). Google Play User Data policy requires
// this to be doable from inside the app with no support intervention.
//
// Elevated credentials never reach the client: the service-role key lives
// only in this function's environment. The caller's JWT is verified and must
// identify the user being deleted — an admin token cannot wipe other users.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) throw new Error('Invalid token');
    const uid = user.id;

    // Storage: the user's avatar objects (best-effort — a storage hiccup
    // must not leave the account undeletable).
    try {
      const { data: files } = await supabase.storage.from('coach-media').list(uid);
      if (files && files.length) {
        await supabase.storage
          .from('coach-media')
          .remove(files.map((f) => `${uid}/${f.name}`));
      }
    } catch (_) { /* non-fatal */ }

    // Data deletion. Every step is idempotent (deleting 0 rows succeeds), so
    // a failed run can simply be retried. Steps run in FK-safe order:
    //  1. children under NO ACTION constraints + tables with no FK at all
    //     (they would otherwise orphan or block later deletes),
    //  2. coach-owned content — programs BEFORE templates, because
    //     coach_program_days.template_id is NO ACTION,
    //  3. the rest of the user-scoped rows (many also cascade from profiles),
    //  4. the profile row, then the auth user itself.
    const failed: string[] = [];

    const delEq = (table: string, column: string) =>
      supabase.from(table).delete().eq(column, uid);
    const delOr = (table: string, a: string, b: string) =>
      supabase.from(table).delete().or(`${a}.eq.${uid},${b}.eq.${uid}`);

    // Guard against a partially-failed critical delete aborting silently:
    // only data tables are soft-fail; the profile and auth user must succeed.
    const softFail = async (label: string, p: PromiseLike<{ error: unknown }>) => {
      const { error } = await p;
      if (error) failed.push(label);
    };

    // 1 — enrollment/assignment chains and no-FK tables
    await softFail('nutrition_change_log', delOr('nutrition_change_log', 'client_id', 'coach_id'));
    await softFail('workout_sessions', delEq('workout_sessions', 'user_id'));
    await softFail('workout_assignments', delOr('workout_assignments', 'client_id', 'coach_id'));
    await softFail('nutrition_assignments', delOr('nutrition_assignments', 'client_id', 'coach_id'));
    await softFail('client_nutrition_enrollments', delOr('client_nutrition_enrollments', 'client_id', 'coach_id'));
    await softFail('client_program_enrollments', delOr('client_program_enrollments', 'client_id', 'coach_id'));
    await softFail('client_assignments', delEq('client_assignments', 'client_id'));

    // 2 — coach-owned content (programs before templates)
    await softFail('coach_programs', delEq('coach_programs', 'coach_id'));
    await softFail('nutrition_programs', delEq('nutrition_programs', 'coach_id'));
    await softFail('workout_templates', delEq('workout_templates', 'coach_id'));
    await softFail('coach_content', delEq('coach_content', 'coach_id'));
    await softFail('subscription_plans', delEq('subscription_plans', 'coach_id'));
    await softFail('coach_onboarding', delEq('coach_onboarding', 'user_id'));

    // 3 — user-scoped rows (client and, where applicable, coach side)
    await softFail('messages', delEq('messages', 'sender_id'));
    await softFail('conversations', delOr('conversations', 'client_id', 'coach_id'));
    await softFail('notifications', delEq('notifications', 'user_id'));
    await softFail('reviews', delOr('reviews', 'client_id', 'coach_id'));
    await softFail('coach_reviews', delOr('coach_reviews', 'client_id', 'coach_id'));
    await softFail('subscriptions', delOr('subscriptions', 'client_id', 'coach_id'));
    await softFail('payment_intents', delOr('payment_intents', 'client_id', 'coach_id'));
    await softFail('stripe_customers', delEq('stripe_customers', 'user_id'));
    await softFail('coaches', delEq('coaches', 'user_id'));
    await softFail('coach_profiles', delEq('coach_profiles', 'id'));

    const userTables = [
      'barcode_scan_history',
      'body_measurements',
      'daily_activity',
      'daily_summary',
      'exercise_progress',
      'food_scans',
      'notification_log',
      'notification_preferences',
      'nutrition_logs',
      'onboarding',
      'streak_activity_log',
      'user_active_program',
      'user_goals',
      'user_programs',
      'user_streaks',
      'voice_food_logs',
      'weekly_activity',
      'workout_sets',
    ];
    for (const t of userTables) {
      await softFail(t, delEq(t, 'user_id'));
    }

    // 4 — profile, then the auth user. If the profile delete fails, stop
    // before deleting the auth user so state stays inspectable.
    { const { error } = await delEq('profiles', 'id');
      if (error) {
        return Response.json(
          { error: `Profile delete failed: ${error.message}`, partial: failed },
          { status: 500, headers: CORS },
        );
      }
    }

    const { error: delError } = await supabase.auth.admin.deleteUser(uid);
    if (delError) {
      return Response.json(
        { error: `Auth user delete failed: ${delError.message}`, partial: failed },
        { status: 500, headers: CORS },
      );
    }

    return Response.json(
      { deleted: true, partial: failed },
      { headers: CORS },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return Response.json({ error: message }, { status: 400, headers: CORS });
  }
});
