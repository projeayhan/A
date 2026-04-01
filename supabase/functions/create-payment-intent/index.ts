import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

async function logToDb(level: string, message: string, source: string, errorDetail?: string, metadata?: Record<string, unknown>) {
  try {
    const sb = createClient(supabaseUrl, serviceRoleKey);
    await sb.from('app_logs').insert({
      app_name: 'edge_function_payment',
      level,
      message: message.substring(0, 2000),
      source,
      error_detail: errorDetail?.substring(0, 5000),
      metadata,
    });
  } catch (_) { /* silent */ }
}

/** Önce env var'a bakar, yoksa app_secrets tablosundan okur. */
async function getSecret(envKey: string, dbKey: string): Promise<string> {
  const envVal = Deno.env.get(envKey);
  if (envVal) return envVal;
  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const { data } = await supabase
    .from('app_secrets')
    .select('value')
    .eq('key', dbKey)
    .single();
  return (data?.value as string) ?? '';
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    const body = await req.json();
    const { amount, currency = 'try', description, metadata, mode } = body;

    if (!amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: 'Geçersiz tutar' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const secretKey = await getSecret('STRIPE_SECRET_KEY', 'stripe_secret_key');
    if (!secretKey) {
      return new Response(
        JSON.stringify({ error: 'Ödeme sağlayıcısı yapılandırılmamış' }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const stripe = new Stripe(secretKey, { apiVersion: '2024-06-20' });

    // Amount: Frontend her zaman TRY cinsinden gönderir (1000.0), Stripe kuruş ister (100000)
    const amountInCents = Math.round(amount * 100);

    // ── Checkout Session modu (web için) ──
    if (mode === 'checkout') {
      const successUrl = body.success_url || `${req.headers.get('origin') ?? 'http://localhost'}/food/order-success/{CHECKOUT_SESSION_ID}`;
      const cancelUrl = body.cancel_url || `${req.headers.get('origin') ?? 'http://localhost'}/`;

      const session = await stripe.checkout.sessions.create({
        mode: 'payment',
        payment_method_types: ['card'],
        line_items: [
          {
            price_data: {
              currency: currency.toLowerCase(),
              unit_amount: amountInCents,
              product_data: {
                name: description || 'Sipariş Ödemesi',
              },
            },
            quantity: 1,
          },
        ],
        metadata: metadata ?? {},
        success_url: successUrl,
        cancel_url: cancelUrl,
      });

      return new Response(
        JSON.stringify({
          sessionId: session.id,
          url: session.url,
        }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        },
      );
    }

    // ── PaymentIntent modu (mobil için) ──
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency: currency.toLowerCase(),
      metadata: metadata ?? {},
      ...(description ? { description } : {}),
    });

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        client_secret: paymentIntent.client_secret, // eski uyumluluk
        paymentIntentId: paymentIntent.id,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      },
    );
  } catch (error) {
    console.error('PaymentIntent oluşturma hatası:', error);
    await logToDb('error', 'Payment intent creation failed', 'create-payment-intent:handler', String(error));
    return new Response(
      JSON.stringify({ error: error.message ?? 'Internal server error' }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }
});
