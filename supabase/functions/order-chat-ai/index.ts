import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface ChatRequest {
  order_id: string;
  message: string;
}

// Haversine formula - iki koordinat arası mesafe (km)
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Dünya yarıçapı (km)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Mesafeye göre tahmini varış süresi (dakika)
function estimateArrivalTime(distanceKm: number, avgSpeedKmh: number = 25): number {
  return Math.ceil((distanceKm / avgSpeedKmh) * 60);
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
    if (!OPENAI_API_KEY) {
      throw new Error('OPENAI_API_KEY is not configured');
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Authenticate user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      throw new Error('Invalid token');
    }

    const body: ChatRequest = await req.json();
    const { order_id, message } = body;

    if (!order_id || !message) {
      throw new Error('order_id and message are required');
    }

    // Get order details
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('id, user_id, merchant_id, courier_id, status, order_number, delivery_latitude, delivery_longitude, delivery_address')
      .eq('id', order_id)
      .eq('user_id', user.id)
      .single();

    if (orderError || !order) {
      throw new Error('Order not found or unauthorized');
    }

    // Get merchant info
    const { data: merchant } = await supabase
      .from('merchants')
      .select('id, business_name')
      .eq('id', order.merchant_id)
      .single();

    // Get courier info if assigned (including current location)
    let courier: { id: string; full_name: string; current_latitude: number | null; current_longitude: number | null } | null = null;
    let distanceKm: number | null = null;
    let estimatedMinutes: number | null = null;

    if (order.courier_id) {
      const { data: courierData } = await supabase
        .from('couriers')
        .select('id, full_name, current_latitude, current_longitude')
        .eq('id', order.courier_id)
        .single();
      courier = courierData;

      // Calculate distance if we have both courier and delivery locations
      if (courier?.current_latitude && courier?.current_longitude &&
          order.delivery_latitude && order.delivery_longitude) {
        distanceKm = calculateDistance(
          Number(courier.current_latitude),
          Number(courier.current_longitude),
          Number(order.delivery_latitude),
          Number(order.delivery_longitude)
        );
        estimatedMinutes = estimateArrivalTime(distanceKm);
      }
    }

    // Save customer's message first
    const { data: customerMsg } = await supabase.from('order_messages').insert({
      order_id,
      merchant_id: order.merchant_id,
      sender_type: 'customer',
      sender_id: user.id,
      sender_name: 'Müşteri',
      message,
      is_ai_response: false
    }).select().single();

    // Get recent chat history
    const { data: chatHistory } = await supabase
      .from('order_messages')
      .select('sender_type, message, is_ai_response')
      .eq('order_id', order_id)
      .order('created_at', { ascending: true })
      .limit(10);

    // Get status text in Turkish
    const statusTexts: Record<string, string> = {
      'pending': 'Onay Bekliyor',
      'confirmed': 'Onaylandı',
      'preparing': 'Hazırlanıyor',
      'ready': 'Hazır - Kurye Bekleniyor',
      'picked_up': 'Kurye Teslim Aldı',
      'on_the_way': 'Yolda',
      'delivering': 'Teslim Ediliyor',
      'delivered': 'Teslim Edildi',
      'cancelled': 'İptal Edildi'
    };

    const statusText = statusTexts[order.status] || order.status;

    // Build courier info string
    let courierInfo = 'Henüz atanmadı';
    if (courier) {
      courierInfo = courier.full_name;
      if (distanceKm !== null && estimatedMinutes !== null) {
        courierInfo += ` (${distanceKm.toFixed(1)} km uzaklıkta, tahmini ${estimatedMinutes} dakika)`;
      } else if (courier.current_latitude && courier.current_longitude) {
        courierInfo += ' (mesafe hesaplanamadı - teslimat konumu eksik)';
      }
    }

    // Build AI prompt with real-time courier data
    const systemPrompt = `Sen bir restoran asistanısın ve restoran adına müşteri sorularını yanıtlıyorsun.
ÖNEMLİ: Mesajın başına herhangi bir etiket (AI, asistan vs.) EKLEME. Direkt cevabı yaz.

Restoran: ${merchant?.business_name || 'Restoran'}
Sipariş No: ${order.order_number || '-'}
Durum: ${statusText}
Kurye: ${courierInfo}
${distanceKm !== null ? `Kurye Mesafesi: ${distanceKm.toFixed(1)} km` : ''}
${estimatedMinutes !== null ? `Tahmini Varış: ${estimatedMinutes} dakika` : ''}

Kurallar:
1. Kısa ve net yanıt ver (1-3 cümle)
2. Sipariş durumuna göre bilgi ver
3. Eğer kurye atandıysa ve mesafe bilgisi varsa, gerçek mesafe ve tahmini süreyi kullan
4. Samimi ama profesyonel ol
5. Bilmediğin konularda "Restoranımız size kısa sürede dönüş yapacaktır" de
6. Türkçe yanıt ver`;

    const messages: any[] = [
      { role: 'system', content: systemPrompt }
    ];

    // Add chat history
    if (chatHistory) {
      chatHistory.forEach(msg => {
        const role = msg.sender_type === 'customer' ? 'user' : 'assistant';
        messages.push({ role, content: msg.message });
      });
    }

    // Call OpenAI
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages,
        max_tokens: 300,
        temperature: 0.7,
      }),
    });

    let aiResponse = null;
    let aiMessageRecord = null;

    if (openaiResponse.ok) {
      const aiData = await openaiResponse.json();
      aiResponse = aiData.choices[0]?.message?.content;

      if (aiResponse) {
        // Save AI response - marked clearly as AI
        const { data: aiMsg } = await supabase.from('order_messages').insert({
          order_id,
          merchant_id: order.merchant_id,
          sender_type: 'merchant',
          sender_id: null,
          sender_name: `🤖 ${merchant?.business_name || 'Restoran'} (AI Asistan)`,
          message: aiResponse,
          is_ai_response: true,
          ai_confidence: 0.85
        }).select().single();

        aiMessageRecord = aiMsg;
      }
    }

    // Get all messages for response
    const { data: allMessages } = await supabase
      .from('order_messages')
      .select('*')
      .eq('order_id', order_id)
      .order('created_at', { ascending: true });

    return new Response(
      JSON.stringify({
        success: true,
        customer_message: customerMsg,
        ai_response: aiMessageRecord,
        ai_responded: !!aiResponse,
        messages: allMessages
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
