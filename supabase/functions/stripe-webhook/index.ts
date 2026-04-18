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
      headers: { 'Access-Control-Allow-Origin': '*' },
    });
  }

  try {
    // Verify Stripe webhook signature
    const signature = req.headers.get('stripe-signature');
    if (!signature) return new Response('Missing signature', { status: 400 });

    const body = await req.text();
    const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

    let event: Stripe.Event;
    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
    } catch (err) {
      console.error('Webhook signature verification failed:', err);
      return new Response('Invalid signature', { status: 400 });
    }

    // ── Handle events ────────────────────────────────────────────────────────

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      const { client_id, coach_id, tier } = session.metadata ?? {};

      if (client_id && coach_id) {
        // Cancel any existing active subscription for this client
        await supabase
          .from('subscriptions')
          .update({ status: 'cancelled', updated_at: new Date().toISOString() })
          .eq('client_id', client_id)
          .eq('status', 'active');

        // Insert new active subscription
        await supabase.from('subscriptions').insert({
          client_id,
          coach_id,
          tier: tier ?? 'standard',
          status: 'active',
          stripe_sub_id: session.subscription as string,
          start_date: new Date().toISOString(),
        });

        // Record payment intent
        if (session.payment_intent) {
          await supabase.from('payment_intents').insert({
            client_id,
            coach_id,
            stripe_payment_id: session.payment_intent as string,
            amount: (session.amount_total ?? 0) / 100,
            status: 'succeeded',
          });
        }
      }
    }

    else if (event.type === 'invoice.payment_succeeded') {
      const invoice = event.data.object as Stripe.Invoice;
      const subscriptionId = typeof invoice.subscription === 'string'
        ? invoice.subscription
        : invoice.subscription?.id;

      if (subscriptionId) {
        const endDate = new Date(
          ((invoice as unknown as { period_end: number }).period_end) * 1000,
        ).toISOString();

        await supabase
          .from('subscriptions')
          .update({ status: 'active', end_date: endDate, updated_at: new Date().toISOString() })
          .eq('stripe_sub_id', subscriptionId);

        // Record renewal payment
        const clientSub = await supabase
          .from('subscriptions')
          .select('client_id, coach_id')
          .eq('stripe_sub_id', subscriptionId)
          .maybeSingle();

        if (clientSub.data && invoice.payment_intent) {
          await supabase.from('payment_intents').insert({
            client_id: clientSub.data.client_id,
            coach_id: clientSub.data.coach_id,
            stripe_payment_id: typeof invoice.payment_intent === 'string'
              ? invoice.payment_intent
              : invoice.payment_intent?.id,
            amount: (invoice.amount_paid ?? 0) / 100,
            status: 'succeeded',
          });
        }
      }
    }

    else if (event.type === 'invoice.payment_failed') {
      const invoice = event.data.object as Stripe.Invoice;
      const subscriptionId = typeof invoice.subscription === 'string'
        ? invoice.subscription
        : invoice.subscription?.id;

      if (subscriptionId) {
        await supabase
          .from('subscriptions')
          .update({ status: 'expired', updated_at: new Date().toISOString() })
          .eq('stripe_sub_id', subscriptionId);
      }
    }

    else if (event.type === 'customer.subscription.deleted') {
      const subscription = event.data.object as Stripe.Subscription;
      await supabase
        .from('subscriptions')
        .update({ status: 'cancelled', updated_at: new Date().toISOString() })
        .eq('stripe_sub_id', subscription.id);
    }

    return Response.json({ received: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('Webhook error:', message);
    return new Response(message, { status: 500 });
  }
});
