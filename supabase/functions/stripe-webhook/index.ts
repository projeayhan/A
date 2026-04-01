import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

async function logToDb(level: string, message: string, source: string, errorDetail?: string, metadata?: Record<string, unknown>) {
  try {
    const sb = createClient(supabaseUrl, serviceRoleKey);
    await sb.from('app_logs').insert({
      app_name: 'edge_function_stripe_webhook',
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
  try {
    const signature = req.headers.get('stripe-signature');
    if (!signature) {
      return new Response(JSON.stringify({ error: 'Missing stripe-signature header' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Raw body okunmalı — imza doğrulaması için zorunlu
    const body = await req.text();

    const [secretKey, webhookSecret] = await Promise.all([
      getSecret('STRIPE_SECRET_KEY', 'stripe_secret_key'),
      getSecret('STRIPE_WEBHOOK_SECRET', 'stripe_webhook_secret'),
    ]);

    if (!webhookSecret) {
      console.error('stripe_webhook_secret yapılandırılmamış');
      return new Response(JSON.stringify({ error: 'Webhook secret not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const stripe = new Stripe(secretKey, { apiVersion: '2024-06-20' });

    let event: Stripe.Event;
    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
    } catch (err) {
      console.error('Stripe imza doğrulama hatası:', err);
      await logToDb('error', 'Stripe signature verification failed', 'stripe-webhook:constructEvent', String(err));
      return new Response(JSON.stringify({ error: 'Invalid signature' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Hem payment_intent.succeeded hem checkout.session.completed destekle
    let meta: Record<string, string> = {};
    let paymentRef = '';

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      meta = (session.metadata ?? {}) as Record<string, string>;
      paymentRef = session.payment_intent as string ?? session.id;
    } else if (event.type === 'payment_intent.succeeded') {
      const pi = event.data.object as Stripe.PaymentIntent;
      meta = (pi.metadata ?? {}) as Record<string, string>;
      paymentRef = pi.id;
    }

    if (event.type === 'payment_intent.succeeded' || event.type === 'checkout.session.completed') {
      const supabase = createClient(supabaseUrl, serviceRoleKey);

      if (meta.type === 'car_promotion' && meta.promotion_id) {
        // Araç promosyonunu aktifleştir (idempotent)
        await supabase
          .from('car_listing_promotions')
          .update({ status: 'active', payment_status: 'completed' })
          .eq('id', meta.promotion_id)
          .neq('status', 'active');

        await supabase
          .from('car_listings')
          .update({
            is_featured: true,
            ...(meta.promotion_type === 'premium' ? { is_premium: true } : {}),
            updated_at: new Date().toISOString(),
          })
          .eq('id', meta.listing_id);

        console.log(`Araç promosyonu aktifleştirildi: ${meta.promotion_id} (${paymentRef})`);
        await logToDb('info', 'Car promotion activated', 'stripe-webhook:car_promotion', undefined, { promotion_id: meta.promotion_id, payment_ref: paymentRef });

      } else if (meta.type === 'property_promotion' && meta.promotion_id) {
        // Emlak promosyonunu aktifleştir (idempotent)
        await supabase
          .from('property_promotions')
          .update({ status: 'active', payment_status: 'completed' })
          .eq('id', meta.promotion_id)
          .neq('status', 'active');

        await supabase
          .from('properties')
          .update({
            is_featured: true,
            ...(meta.promotion_type === 'premium' ? { is_premium: true } : {}),
            updated_at: new Date().toISOString(),
          })
          .eq('id', meta.listing_id);

        console.log(`Emlak promosyonu aktifleştirildi: ${meta.promotion_id} (${paymentRef})`);
        await logToDb('info', 'Property promotion activated', 'stripe-webhook:property_promotion', undefined, { promotion_id: meta.promotion_id, payment_ref: paymentRef });

      } else if (meta.type === 'food_order' && meta.order_id) {
        // Yemek siparişi: ödeme durumu + ödeme yöntemi + referans kaydı
        await supabase
          .from('orders')
          .update({
            payment_status: 'paid',
            payment_method: 'online',
            payment_reference: paymentRef,
          })
          .eq('id', meta.order_id)
          .neq('payment_status', 'paid');

        console.log(`Yemek siparişi ödeme onaylandı: ${meta.order_id} (${paymentRef})`);
        await logToDb('info', 'Food order payment confirmed', 'stripe-webhook:food_order', undefined, { order_id: meta.order_id, payment_ref: paymentRef });

      } else if (meta.type === 'store_order' && meta.order_ids) {
        // Mağaza siparişleri: ödeme durumu + ödeme yöntemi + referans kaydı
        const orderIds = (meta.order_ids as string).split(',').map((s) => s.trim()).filter(Boolean);
        for (const orderId of orderIds) {
          await supabase
            .from('orders')
            .update({
              payment_status: 'paid',
              payment_method: 'online',
              payment_reference: paymentRef,
            })
            .eq('id', orderId)
            .neq('payment_status', 'paid');
        }
        console.log(`Mağaza siparişleri ödeme onaylandı: ${meta.order_ids} (${paymentRef})`);
        await logToDb('info', 'Store orders payment confirmed', 'stripe-webhook:store_order', undefined, { order_ids: meta.order_ids, payment_ref: paymentRef });

      } else if (meta.type === 'banner' && meta.banner_id) {
        // Banner ödeme tamamlandı → admin onayına taşı
        await supabase
          .from('banners')
          .update({
            payment_status: 'completed',
            status: 'pending_approval',
            amount_paid: Number(meta.amount ?? 0),
          })
          .eq('id', meta.banner_id)
          .neq('payment_status', 'completed');

        console.log(`Banner ödeme tamamlandı, admin onayına alındı: ${meta.banner_id} (${paymentRef})`);
        await logToDb('info', 'Banner payment completed', 'stripe-webhook:banner', undefined, { banner_id: meta.banner_id, payment_ref: paymentRef });

      } else if (meta.type === 'invoice' && meta.invoice_id) {
        // Fatura ödeme onayı (safety net — app crash durumu için)
        const { error: rpcError } = await supabase.rpc('mark_invoice_paid', {
          p_invoice_id: meta.invoice_id,
          p_payment_method: 'card',
          p_payment_note: 'Stripe webhook ile onaylandı',
          p_payment_reference: paymentRef,
        });

        if (rpcError) {
          // Fallback: service_role ile direkt update
          await supabase
            .from('invoices')
            .update({
              payment_status: 'paid',
              paid_at: new Date().toISOString(),
              payment_method: 'card',
              payment_note: 'Stripe webhook fallback',
              payment_reference: paymentRef,
            })
            .eq('id', meta.invoice_id)
            .neq('payment_status', 'paid');
        }

        console.log(`Fatura ödeme onaylandı: ${meta.invoice_id} (${paymentRef})`);
        await logToDb('info', 'Invoice payment confirmed via webhook', 'stripe-webhook:invoice', undefined, {
          invoice_id: meta.invoice_id,
          invoice_number: meta.invoice_number ?? '',
          payment_ref: paymentRef,
          used_fallback: !!rpcError,
        });
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Webhook hatası:', error);
    await logToDb('error', 'Webhook processing failed', 'stripe-webhook:handler', String(error));
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
