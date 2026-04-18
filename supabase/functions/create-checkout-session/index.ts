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
    // 1. Verify JWT → get client_id
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error('Missing authorization header');

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) throw new Error('Invalid token');

    const client_id = user.id;

    // 2. Parse request body
    const { coach_id, tier = 'standard' } = await req.json();
    if (!coach_id) throw new Error('coach_id is required');

    // 3. Fetch coach + profile (name and price)
    const { data: coach, error: coachErr } = await supabase
      .from('coaches')
      .select('id, price_monthly, profiles(name)')
      .eq('id', coach_id)
      .single();
    if (coachErr || !coach) throw new Error('Coach not found');

    const price_monthly = coach.price_monthly as number;
    const coach_name = (coach.profiles as { name: string } | null)?.name ?? 'Coach';

    // 4. Get or create Stripe customer
    let stripe_customer_id: string;
    const { data: existing } = await supabase
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', client_id)
      .maybeSingle();

    if (existing?.stripe_customer_id) {
      stripe_customer_id = existing.stripe_customer_id;
    } else {
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: { supabase_uid: client_id },
      });
      stripe_customer_id = customer.id;
      await supabase.from('stripe_customers').insert({
        user_id: client_id,
        stripe_customer_id,
      });
    }

    // 5. Create Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      customer: stripe_customer_id,
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'usd',
            unit_amount: Math.round(price_monthly * 100),
            recurring: { interval: 'month' },
            product_data: { name: `CoreGym Coach: ${coach_name}` },
          },
          quantity: 1,
        },
      ],
      metadata: { client_id, coach_id, tier },
      success_url: 'coregym://payment/success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: 'coregym://payment/cancel',
    });

    return Response.json(
      { checkout_url: session.url, session_id: session.id },
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
