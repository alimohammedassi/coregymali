// @ts-nocheck
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

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
    // Verify JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) throw new Error('Invalid token');

    const { session_id } = await req.json();
    if (!session_id) throw new Error('session_id is required');

    // Retrieve session from Stripe
    const session = await stripe.checkout.sessions.retrieve(session_id);

    return Response.json(
      {
        status: session.payment_status,          // 'paid' | 'unpaid' | 'no_payment_required'
        subscription_id: session.subscription,
        coach_id: session.metadata?.coach_id ?? null,
      },
      { headers: { 'Access-Control-Allow-Origin': '*' } },
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return Response.json(
      { error: message },
      { status: 400, headers: { 'Access-Control-Allow-Origin': '*' } },
    );
  }
});
