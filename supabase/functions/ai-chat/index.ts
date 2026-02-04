import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface ChatRequest {
  message: string;
  session_id?: string;
  app_source: string;
  user_type?: string;
}

interface OrderStatus {
  has_active_order: boolean;
  message?: string;
  order_id?: string;
  order_number?: string;
  status?: string;
  status_text?: string;
  merchant_name?: string;
  total_amount?: number;
  delivery_address?: string;
  courier_assigned?: boolean;
  courier_name?: string;
  courier_vehicle_type?: string;
  courier_vehicle_plate?: string;
  courier_phone?: string;
  has_location?: boolean;
  distance_km?: number;
  estimated_minutes?: number;
  estimated_arrival_time?: string;
  picked_up_at?: string;
  confirmed_at?: string;
  prepared_at?: string;
  order_created_at?: string;
}

interface MerchantInfo {
  id: string;
  business_name: string;
  type: string;
  commission_rate: number;
  is_active: boolean;
  created_at: string;
}

// Keywords that indicate user is asking about order status
const ORDER_QUERY_KEYWORDS = [
  'sipariş', 'siparişim', 'siparişim nerede', 'nerede kaldı', 'ne zaman gelecek',
  'kurye', 'kuryem', 'teslimat', 'kargo', 'order', 'where is my order',
  'ne kadar sürer', 'geldi mi', 'yolda mı', 'ne zaman', 'tahmini',
  'takip', 'tracking', 'eta', 'varış', 'teslim'
];

// Keywords for order cancellation
const CANCEL_QUERY_KEYWORDS = [
  'iptal', 'iptal et', 'siparişi iptal', 'siparişimi iptal', 'vazgeçtim', 'vazgectim',
  'istemiyorum', 'cancel', 'cancellation', 'iptal edebilir miyim', 'iptal etmek istiyorum'
];

// Keywords for confirming cancellation
const CANCEL_CONFIRM_KEYWORDS = [
  'evet iptal', 'evet, iptal', 'iptal et', 'iptal istiyorum', 'evet', 'onaylıyorum', 'tamam iptal'
];

// Keywords for food recommendations
const FOOD_QUERY_KEYWORDS = [
  'ne yesem', 'ne yiyeyim', 'yemek öner', 'öneri', 'tavsiye', 'acıktım', 'aç', 'canım çekti',
  'bugün ne', 'akşam ne', 'öğle ne', 'kahvaltı', 'yemek istiyorum', 'sipariş ver',
  'güzel bir şey', 'lezzetli', 'farklı bir şey', 'yeni bir şey', 'ne söylesem',
  'food', 'hungry', 'recommendation', 'suggest', 'what should i eat'
];

// Keywords for saving preferences
const PREFERENCE_KEYWORDS = [
  'tercih', 'sevmiyorum', 'seviyorum', 'alerji', 'alerjim', 'yemiyorum', 'vejeteryan',
  'vegan', 'acılı sevmem', 'acısız', 'glutensiz', 'laktozsuz', 'helal', 'budget', 'bütçe'
];

// Keywords for restaurant/food search queries
const RESTAURANT_SEARCH_KEYWORDS = [
  'hangi restoran', 'hangi mekan', 'nerede bulabilirim', 'nerede yenir', 'nerede satılır',
  'en iyi', 'en çok satan', 'en popüler', 'en lezzetli', 'en güzel', 'en ucuz',
  'tavsiye eder misin', 'nereden alsam', 'nereden söylesem', 'neresi iyi',
  'yorumları', 'yorumu', 'puanı', 'değerlendirme', 'rating',
  'kebap', 'pizza', 'burger', 'döner', 'lahmacun', 'pide', 'köfte', 'tavuk', 'balık',
  'çin yemeği', 'japon', 'sushi', 'meksika', 'italyan', 'türk mutfağı',
  'kahvaltı', 'tatlı', 'pasta', 'börek', 'makarna', 'salata', 'çorba',
  'adana', 'urfa', 'iskender', 'tantuni', 'kokoreç', 'dürüm', 'wrap',
  'best', 'popular', 'review', 'where can i find', 'recommend'
];

interface FoodRecommendation {
  meal_type: string;
  current_hour: number;
  user_preferences: {
    favorite_cuisines: string[];
    dietary_restrictions: string[];
    allergies: string[];
    spice_level: number;
    budget_range: string;
    disliked_ingredients: string[];
  } | null;
  order_history: {
    total_orders: number;
    unique_merchants: number;
    ordered_cuisines: string[];
    avg_order_amount: number;
    most_common_order_hour: number;
    last_order_date: string;
  } | null;
  favorite_restaurants: Array<{
    name: string;
    order_count: number;
    last_order: string;
  }>;
}

interface ProactiveMessage {
  message: string;
  emoji: string;
  message_type: string;
  context: Record<string, unknown>;
}

interface RestaurantSearchResult {
  success: boolean;
  search_query: string;
  result_count: number;
  restaurants: Array<{
    merchant_id: string;
    business_name: string;
    rating: number;
    review_count: number;
    total_orders: number;
    address: string;
    delivery_time: string;
    delivery_fee: number;
    min_order_amount: number;
    is_open: boolean;
    discount_badge: string | null;
    category_tags: string[];
    matching_items: Array<{
      name: string;
      description: string;
      price: number;
      discounted_price: number | null;
      is_popular: boolean;
      rating: number;
    }>;
    recent_good_reviews: Array<{
      rating: number;
      comment: string;
      customer_name: string;
      created_at: string;
    }>;
  }>;
}

interface CancelResult {
  success: boolean;
  can_cancel: boolean;
  reason: string;
  message: string;
  order_number?: string;
  order_id?: string;
  current_status?: string;
}

function isOrderQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  return ORDER_QUERY_KEYWORDS.some(keyword => lowerMessage.includes(keyword));
}

function isCancelQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  return CANCEL_QUERY_KEYWORDS.some(keyword => lowerMessage.includes(keyword));
}

function isCancelConfirmation(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  return CANCEL_CONFIRM_KEYWORDS.some(keyword => lowerMessage.includes(keyword));
}

function isFoodQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  return FOOD_QUERY_KEYWORDS.some(keyword => lowerMessage.includes(keyword));
}

function isPreferenceUpdate(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  return PREFERENCE_KEYWORDS.some(keyword => lowerMessage.includes(keyword));
}

function isRestaurantSearchQuery(message: string): boolean {
  const lowerMessage = message.toLowerCase();
  // Need at least 2 keyword matches or a strong indicator
  const matchCount = RESTAURANT_SEARCH_KEYWORDS.filter(keyword =>
    lowerMessage.includes(keyword)
  ).length;

  // Strong indicators that definitely mean search
  const strongIndicators = [
    'hangi restoran', 'nerede yenir', 'en çok satan', 'en iyi', 'nereden',
    'tavsiye', 'yorumları', 'puanı', 'değerlendirme'
  ];
  const hasStrongIndicator = strongIndicators.some(ind => lowerMessage.includes(ind));

  return hasStrongIndicator || matchCount >= 2;
}

function extractSearchTerms(message: string): string {
  // Remove common question words and extract the food/restaurant name
  const lowerMessage = message.toLowerCase();

  // Remove question patterns
  const patterns = [
    /hangi restoran(da|dan)?/gi,
    /hangi mekan(da|dan)?/gi,
    /nerede (yenir|bulabilirim|satılır)/gi,
    /en (iyi|çok satan|popüler|lezzetli|güzel|ucuz)/gi,
    /tavsiye eder misin/gi,
    /nereden (alsam|söylesem)/gi,
    /neresi iyi/gi,
    /yorumları (en iyi olan|iyi)/gi,
    /yorumu (nasıl|iyi)/gi,
    /puanı (yüksek|iyi)/gi,
    /\?/g
  ];

  let searchTerm = lowerMessage;
  patterns.forEach(pattern => {
    searchTerm = searchTerm.replace(pattern, ' ');
  });

  // Clean up and return
  searchTerm = searchTerm.replace(/\s+/g, ' ').trim();

  // If we have nothing meaningful, try to extract food names
  const foodPatterns = [
    /(adana\s*kebab?[ıp]?)/i,
    /(urfa\s*kebab?[ıp]?)/i,
    /(iskender)/i,
    /(döner)/i,
    /(lahmacun)/i,
    /(pide)/i,
    /(pizza)/i,
    /(burger)/i,
    /(köfte)/i,
    /(tantuni)/i,
    /(kokoreç)/i,
    /(dürüm)/i,
    /(makarna)/i,
    /(sushi)/i
  ];

  for (const pattern of foodPatterns) {
    const match = message.match(pattern);
    if (match) {
      return match[1];
    }
  }

  return searchTerm || message.substring(0, 50);
}

function formatFoodRecommendationForAI(recommendation: FoodRecommendation): string {
  let info = `\n\n[SİSTEM BİLGİSİ - YEMEK ÖNERİSİ]:
🍽️ ÖĞÜN: ${recommendation.meal_type.toUpperCase()} (Saat: ${recommendation.current_hour}:00)`;

  // Kullanıcı tercihleri
  if (recommendation.user_preferences) {
    const prefs = recommendation.user_preferences;
    info += `\n\n👤 KULLANICI TERCİHLERİ:`;
    if (prefs.favorite_cuisines.length > 0) {
      info += `\n- Favori Mutfaklar: ${prefs.favorite_cuisines.join(', ')}`;
    }
    if (prefs.dietary_restrictions.length > 0) {
      info += `\n- Diyet Kısıtlamaları: ${prefs.dietary_restrictions.join(', ')}`;
    }
    if (prefs.allergies.length > 0) {
      info += `\n- Alerjiler: ${prefs.allergies.join(', ')} ⚠️ DİKKAT!`;
    }
    if (prefs.disliked_ingredients.length > 0) {
      info += `\n- Sevmediği Malzemeler: ${prefs.disliked_ingredients.join(', ')}`;
    }
    info += `\n- Acı Seviyesi: ${prefs.spice_level}/5`;
    info += `\n- Bütçe: ${prefs.budget_range === 'low' ? 'Ekonomik' : prefs.budget_range === 'medium' ? 'Orta' : 'Yüksek'}`;
  } else {
    info += `\n\n👤 KULLANICI TERCİHLERİ: Henüz kaydedilmemiş. Tercihleri sorabilirsin!`;
  }

  // Sipariş geçmişi
  if (recommendation.order_history) {
    const history = recommendation.order_history;
    info += `\n\n📊 SİPARİŞ GEÇMİŞİ:`;
    info += `\n- Toplam Sipariş: ${history.total_orders}`;
    info += `\n- Farklı Restoran: ${history.unique_merchants}`;
    if (history.ordered_cuisines && history.ordered_cuisines.length > 0) {
      info += `\n- Denenen Mutfaklar: ${history.ordered_cuisines.join(', ')}`;
    }
    info += `\n- Ortalama Sipariş: ${history.avg_order_amount} TL`;
    info += `\n- En Sık Sipariş Saati: ${history.most_common_order_hour}:00`;
    if (history.last_order_date) {
      const lastOrderDate = new Date(history.last_order_date);
      const daysSince = Math.floor((Date.now() - lastOrderDate.getTime()) / (1000 * 60 * 60 * 24));
      info += `\n- Son Sipariş: ${daysSince === 0 ? 'Bugün' : daysSince === 1 ? 'Dün' : daysSince + ' gün önce'}`;
    }
  }

  // Favori restoranlar
  if (recommendation.favorite_restaurants && recommendation.favorite_restaurants.length > 0) {
    info += `\n\n⭐ FAVORİ RESTORANLAR:`;
    recommendation.favorite_restaurants.forEach((rest, i) => {
      info += `\n${i + 1}. ${rest.name} (${rest.order_count} sipariş)`;
    });
  }

  // Öneri talimatları
  info += `\n\n📋 ÖNERİ TALİMATLARI:
- Kullanıcının tercihlerine ve geçmişine göre kişiselleştirilmiş öneriler ver
- Alerjileri ve kısıtlamaları KESINLIKLE dikkate al
- Öğün saatine uygun öneriler yap (${recommendation.meal_type})
- Bütçeye uygun seçenekler sun
- Daha önce sipariş verdiği yerlerden veya yeni yerlerden önerebilirsin
- Samimi ve arkadaşça bir dil kullan
- 2-3 somut öneri ver (restoran veya yemek türü)
- "Canın ne çekiyor?" gibi sorularla etkileşimi artır`;

  return info;
}

function formatRestaurantSearchForAI(searchResult: RestaurantSearchResult): string {
  if (!searchResult.success || searchResult.result_count === 0) {
    return `\n\n[SİSTEM BİLGİSİ - RESTORAN ARAMA]:
🔍 Arama: "${searchResult.search_query}"
❌ Sonuç bulunamadı.

📋 TALİMAT: Kullanıcıya aradığı ürünü sunan restoran bulunamadığını belirt. Benzer ürünler veya farklı anahtar kelimelerle arama yapmasını öner.`;
  }

  let info = `\n\n[SİSTEM BİLGİSİ - RESTORAN ARAMA SONUÇLARI]:
🔍 Arama: "${searchResult.search_query}"
📊 Bulunan: ${searchResult.result_count} restoran

🏆 EN İYİ SONUÇLAR:`;

  searchResult.restaurants.slice(0, 5).forEach((rest, i) => {
    info += `\n\n${i + 1}. ${rest.business_name}`;
    info += `\n   ⭐ Puan: ${rest.rating?.toFixed(1) || 'Yeni'} (${rest.review_count || 0} değerlendirme)`;
    info += `\n   📦 Toplam Sipariş: ${rest.total_orders || 0}`;
    info += `\n   🚚 Teslimat: ${rest.delivery_time || '30-45 dk'} | ${rest.delivery_fee > 0 ? rest.delivery_fee + ' TL' : 'Ücretsiz'}`;
    info += `\n   📍 ${rest.address || 'Adres bilgisi yok'}`;

    if (rest.discount_badge) {
      info += `\n   🎉 Kampanya: ${rest.discount_badge}`;
    }

    if (!rest.is_open) {
      info += `\n   ⚠️ ŞU AN KAPALI`;
    }

    // Matching items
    if (rest.matching_items && rest.matching_items.length > 0) {
      info += `\n   🍽️ Eşleşen Ürünler:`;
      rest.matching_items.slice(0, 3).forEach(item => {
        const price = item.discounted_price || item.price;
        const originalPrice = item.discounted_price ? ` (~~${item.price}~~)` : '';
        info += `\n      - ${item.name}: ${price} TL${originalPrice}`;
        if (item.is_popular) info += ' ⭐Popüler';
      });
    }

    // Recent reviews
    if (rest.recent_good_reviews && rest.recent_good_reviews.length > 0) {
      info += `\n   💬 Son İyi Yorumlar:`;
      rest.recent_good_reviews.slice(0, 2).forEach(review => {
        const shortComment = review.comment.length > 60
          ? review.comment.substring(0, 60) + '...'
          : review.comment;
        info += `\n      "${shortComment}" - ${review.customer_name} (⭐${review.rating})`;
      });
    }
  });

  info += `\n\n📋 TALİMAT:
- Bu arama sonuçlarını kullanarak kullanıcıya yardımcı ol
- En yüksek puanlı ve en çok sipariş alan restoranları öner
- Kullanıcının sorduğu ürünü sunan restoranları vurgula
- Yorumlardan öne çıkan bilgileri paylaş
- Açık/kapalı durumunu mutlaka belirt
- Fiyat ve kampanya bilgilerini ver
- Samimi ve yardımcı bir dil kullan`;

  return info;
}

function formatCancelInfoForAI(cancelResult: CancelResult, wasConfirmed: boolean = false): string {
  if (wasConfirmed && cancelResult.success) {
    return `\n\n[SİSTEM BİLGİSİ - SİPARİŞ İPTALİ]:
✅ İPTAL BAŞARILI
- Sipariş No: #${cancelResult.order_number}
- Durum: Sipariş başarıyla iptal edildi.

📋 TALİMAT: Müşteriye siparişinin iptal edildiğini samimi bir şekilde bildir. Tekrar sipariş vermek isterse yardımcı olabileceğini söyle.`;
  }

  if (cancelResult.can_cancel) {
    return `\n\n[SİSTEM BİLGİSİ - SİPARİŞ İPTAL KONTROLİ]:
✅ İPTAL EDİLEBİLİR
- Sipariş No: #${cancelResult.order_number}
- Durum: Sipariş henüz işletme tarafından onaylanmadı, iptal edilebilir.

📋 TALİMAT: Müşteriye siparişinin iptal edilebileceğini söyle. İptal etmek istediğinden emin olup olmadığını sor. "Evet, iptal et" derse işlemi gerçekleştir.`;
  }

  // Cannot cancel
  let reason = '';
  switch (cancelResult.reason) {
    case 'already_confirmed':
      reason = 'İşletme siparişi onayladığı için artık uygulama üzerinden iptal edilemez.';
      break;
    case 'already_cancelled':
      reason = 'Sipariş zaten iptal edilmiş durumda.';
      break;
    case 'already_delivered':
      reason = 'Sipariş teslim edilmiş, iptal edilemez.';
      break;
    case 'no_order':
      reason = 'Aktif sipariş bulunamadı.';
      break;
    default:
      reason = cancelResult.message;
  }

  return `\n\n[SİSTEM BİLGİSİ - SİPARİŞ İPTAL KONTROLİ]:
❌ İPTAL EDİLEMEZ
- Sipariş No: #${cancelResult.order_number || 'Yok'}
- Mevcut Durum: ${cancelResult.current_status || 'Bilinmiyor'}
- Sebep: ${reason}

📋 KURAL: Siparişler sadece "beklemede" (pending) durumundayken, yani işletme onaylamadan önce iptal edilebilir. İşletme onayladıktan sonra sipariş hazırlanmaya başladığı için uygulama üzerinden iptal yapılamaz.

📋 TALİMAT: Müşteriye kibarca siparişinin neden iptal edilemeyeceğini açıkla. İptal için işletmeyi aramasını veya müşteri hizmetleri ile iletişime geçmesini öner.`;
}

function formatOrderStatusForAI(orderStatus: OrderStatus): string {
  if (!orderStatus.has_active_order) {
    return '\n\n[SİSTEM BİLGİSİ - SİPARİŞ DURUMU]: Kullanıcının aktif siparişi bulunmuyor. Geçmiş siparişleri kontrol etmek istiyorsa "Siparişlerim" bölümüne yönlendir.';
  }

  let info = `\n\n[SİSTEM BİLGİSİ - SİPARİŞ DURUMU]:
- Sipariş No: #${orderStatus.order_number}
- Durum: ${orderStatus.status_text}
- Restoran/Mağaza: ${orderStatus.merchant_name || 'Bilinmiyor'}
- Toplam Tutar: ${orderStatus.total_amount} TL
- Teslimat Adresi: ${orderStatus.delivery_address || 'Belirtilmemiş'}`;

  if (orderStatus.courier_assigned) {
    info += `\n\n📍 KURYE BİLGİLERİ:`;
    info += `\n- Kurye Adı: ${orderStatus.courier_name}`;

    if (orderStatus.courier_vehicle_type) {
      const vehicleText = orderStatus.courier_vehicle_type === 'motorcycle' ? 'Motosiklet' :
                         orderStatus.courier_vehicle_type === 'car' ? 'Araba' :
                         orderStatus.courier_vehicle_type === 'bicycle' ? 'Bisiklet' : orderStatus.courier_vehicle_type;
      info += `\n- Araç: ${vehicleText}`;
    }

    if (orderStatus.courier_vehicle_plate) {
      info += `\n- Plaka: ${orderStatus.courier_vehicle_plate}`;
    }

    if (orderStatus.has_location && orderStatus.distance_km !== null) {
      info += `\n\n⏱️ TAHMİNİ TESLİMAT:`;
      info += `\n- Kuryenin Mesafesi: ${orderStatus.distance_km} km`;
      info += `\n- Tahmini Varış: Yaklaşık ${orderStatus.estimated_minutes} dakika`;
      info += `\n- Tahmini Saat: ${orderStatus.estimated_arrival_time} civarı`;
    } else if (orderStatus.status === 'picked_up' || orderStatus.status === 'on_the_way') {
      info += `\n- Kurye yolda, konum bilgisi güncelleniyor...`;
    } else if (orderStatus.status === 'preparing' || orderStatus.status === 'ready') {
      info += `\n- Sipariş henüz kuryeye teslim edilmedi`;
    }
  } else {
    if (orderStatus.status === 'pending') {
      info += `\n\n⏳ Sipariş onay bekliyor. Restoran onayladıktan sonra kurye atanacak.`;
    } else if (orderStatus.status === 'confirmed' || orderStatus.status === 'preparing') {
      info += `\n\n👨‍🍳 Sipariş hazırlanıyor. Hazır olunca kurye atanacak.`;
    } else {
      info += `\n\n🔍 Kurye henüz atanmadı, en kısa sürede atanacak.`;
    }
  }

  info += `\n\n📋 TALİMAT: Bu bilgileri kullanarak müşteriye samimi ve yardımcı bir şekilde cevap ver. Kurye bilgileri varsa mutlaka paylaş. Tahmini süreyi belirt.`;

  return info;
}

function formatMerchantInfoForAI(merchant: MerchantInfo): string {
  const typeText = merchant.type === 'restaurant' ? 'Restoran' : 'Mağaza';

  return `\n\n[SİSTEM BİLGİSİ - İŞLETME BİLGİLERİ]:
- İşletme Adı: ${merchant.business_name}
- İşletme Türü: ${typeText}
- Komisyon Oranı: %${merchant.commission_rate}
- Hesap Durumu: ${merchant.is_active ? 'Aktif' : 'Pasif'}
- Kayıt Tarihi: ${new Date(merchant.created_at).toLocaleDateString('tr-TR')}

Bu işletme bilgilerini kullanarak sorulara yanıt ver. Komisyon oranı sorulduğunda kesin olarak %${merchant.commission_rate} olduğunu söyle.`;
}

interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
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

    // Get user from JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Oturum bulunamadı. Lütfen tekrar giriş yapın.'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        }
      );
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.'
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        }
      );
    }

    const body: ChatRequest = await req.json();
    const { message, session_id, app_source, user_type = 'customer' } = body;

    if (!message || !app_source) {
      throw new Error('Message and app_source are required');
    }

    // Get or create session
    let currentSessionId = session_id;
    if (!currentSessionId) {
      const { data: newSession, error: sessionError } = await supabase
        .from('support_chat_sessions')
        .insert({
          user_id: user.id,
          app_source,
          user_type,
          status: 'active'
        })
        .select('id')
        .single();

      if (sessionError) throw sessionError;
      currentSessionId = newSession.id;
    }

    // Save user message
    await supabase.from('support_chat_messages').insert({
      session_id: currentSessionId,
      role: 'user',
      content: message
    });

    // Get system prompt for this app
    const { data: promptData } = await supabase
      .from('ai_system_prompts')
      .select('system_prompt, restrictions')
      .eq('app_source', app_source)
      .eq('is_active', true)
      .single();

    // Get relevant knowledge base entries
    const keywords = message.toLowerCase().split(' ').filter(w => w.length > 2);
    const { data: knowledgeBase } = await supabase
      .from('ai_knowledge_base')
      .select('question, answer, category')
      .or(`app_source.eq.${app_source},app_source.eq.all`)
      .eq('is_active', true)
      .order('priority', { ascending: false })
      .limit(5);

    // Build context from knowledge base
    let contextInfo = '';
    if (knowledgeBase && knowledgeBase.length > 0) {
      contextInfo = '\n\nİLGİLİ BİLGİLER (bu bilgileri kullan):\n';
      knowledgeBase.forEach((kb, i) => {
        contextInfo += `${i + 1}. Soru: ${kb.question}\n   Cevap: ${kb.answer}\n\n`;
      });
    }

    // Check if user is asking about order status (for super_app/customer_app)
    let orderContext = '';
    if (isOrderQuery(message) && (app_source === 'super_app' || app_source === 'customer_app')) {
      const { data: orderStatus, error: orderError } = await supabase.rpc('ai_get_order_status', {
        p_user_id: user.id
      });

      if (!orderError && orderStatus) {
        orderContext = formatOrderStatusForAI(orderStatus as OrderStatus);
      }
    }

    // Check for order cancellation requests (for super_app/customer_app)
    let cancelContext = '';
    if (isCancelQuery(message) && (app_source === 'super_app' || app_source === 'customer_app')) {
      // Check previous messages to see if this is a confirmation
      const { data: recentMessages } = await supabase
        .from('support_chat_messages')
        .select('role, content')
        .eq('session_id', currentSessionId)
        .order('created_at', { ascending: false })
        .limit(4);

      // Check if AI previously asked for confirmation and user is confirming
      const aiAskedForConfirmation = recentMessages?.some(msg =>
        msg.role === 'assistant' &&
        (msg.content.includes('iptal etmek istediğinizden') ||
         msg.content.includes('emin misiniz') ||
         msg.content.includes('İptal etmek istiyor musunuz'))
      );

      if (aiAskedForConfirmation && isCancelConfirmation(message)) {
        // User confirmed cancellation - execute it
        const { data: cancelResult, error: cancelError } = await supabase.rpc('ai_cancel_order', {
          p_user_id: user.id,
          p_order_id: null
        });

        if (!cancelError && cancelResult) {
          cancelContext = formatCancelInfoForAI(cancelResult as CancelResult, true);
        }
      } else {
        // First time asking about cancellation - check eligibility
        const { data: eligibility, error: eligError } = await supabase.rpc('ai_check_cancel_eligibility', {
          p_user_id: user.id
        });

        if (!eligError && eligibility) {
          cancelContext = formatCancelInfoForAI(eligibility as CancelResult, false);
        }
      }
    }

    // Get food recommendations for super_app
    let foodContext = '';
    if ((isFoodQuery(message) || isPreferenceUpdate(message)) && (app_source === 'super_app' || app_source === 'customer_app')) {
      const { data: foodRecommendation, error: foodError } = await supabase.rpc('ai_get_food_recommendations', {
        p_user_id: user.id
      });

      if (!foodError && foodRecommendation) {
        foodContext = formatFoodRecommendationForAI(foodRecommendation as FoodRecommendation);
      }

      // Check for promotions too
      const { data: promotions } = await supabase.rpc('ai_get_user_promotions', {
        p_user_id: user.id
      });

      if (promotions && promotions.has_promotions) {
        foodContext += `\n\n🎉 AKTİF KAMPANYALAR:`;
        promotions.active_promotions.forEach((promo: { business_name: string; discount_badge: string; category_tags: string[] }) => {
          foodContext += `\n- ${promo.business_name}: ${promo.discount_badge}`;
        });
        foodContext += `\n\n💡 İPUCU: Kampanyalı restoranları önerebilirsin!`;
      }
    }

    // Check for restaurant/food search queries (for super_app/customer_app)
    let restaurantSearchContext = '';
    if (isRestaurantSearchQuery(message) && (app_source === 'super_app' || app_source === 'customer_app')) {
      const searchTerms = extractSearchTerms(message);
      console.log('Restaurant search query detected, terms:', searchTerms);

      const { data: searchResult, error: searchError } = await supabase.rpc('ai_search_restaurants', {
        p_search_query: searchTerms
      });

      if (!searchError && searchResult) {
        restaurantSearchContext = formatRestaurantSearchForAI(searchResult as RestaurantSearchResult);
      } else {
        console.error('Restaurant search error:', searchError);
      }
    }

    // Get merchant info for merchant_panel
    let merchantContext = '';
    if (app_source === 'merchant_panel') {
      // Get merchant data for this user
      const { data: merchantData } = await supabase
        .from('merchants')
        .select('id, business_name, type, is_active, created_at')
        .eq('owner_id', user.id)
        .single();

      if (merchantData) {
        // Get commission rate for this merchant type
        const serviceType = merchantData.type === 'restaurant' ? 'restaurant' : 'store';
        const { data: commissionData } = await supabase
          .from('platform_commissions')
          .select('platform_commission_rate')
          .eq('service_type', serviceType)
          .eq('is_active', true)
          .maybeSingle();

        const commissionRate = commissionData?.platform_commission_rate
          ? parseFloat(commissionData.platform_commission_rate)
          : 15.0;

        const merchantInfo: MerchantInfo = {
          id: merchantData.id,
          business_name: merchantData.business_name,
          type: merchantData.type,
          commission_rate: commissionRate,
          is_active: merchantData.is_active,
          created_at: merchantData.created_at
        };

        merchantContext = formatMerchantInfoForAI(merchantInfo);
      }
    }

    // Get conversation history (last 10 messages)
    const { data: history } = await supabase
      .from('support_chat_messages')
      .select('role, content')
      .eq('session_id', currentSessionId)
      .order('created_at', { ascending: true })
      .limit(10);

    // Build messages array for ChatGPT
    const systemPrompt = promptData?.system_prompt || 'Sen yardımcı bir asistansın.';
    const restrictions = promptData?.restrictions || '';

    const messages: ChatMessage[] = [
      {
        role: 'system',
        content: `${systemPrompt}\n\nKISITLAMALAR:\n${restrictions}${contextInfo}${orderContext}${cancelContext}${foodContext}${restaurantSearchContext}${merchantContext}`
      }
    ];

    // Add history
    if (history) {
      history.forEach(msg => {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role, content: msg.content });
        }
      });
    }

    // Add current message if not already in history
    if (!history || history.length === 0 || history[history.length - 1].content !== message) {
      messages.push({ role: 'user', content: message });
    }

    // Call ChatGPT API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages,
        max_tokens: 1000,
        temperature: 0.7,
      }),
    });

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.text();
      console.error('OpenAI Error:', errorData);
      throw new Error('AI service error');
    }

    const aiData = await openaiResponse.json();
    const aiMessage = aiData.choices[0]?.message?.content || 'Üzgünüm, yanıt oluşturulamadı.';
    const tokensUsed = aiData.usage?.total_tokens || 0;

    // Save AI response
    await supabase.from('support_chat_messages').insert({
      session_id: currentSessionId,
      role: 'assistant',
      content: aiMessage,
      tokens_used: tokensUsed
    });

    // Update session
    await supabase
      .from('support_chat_sessions')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', currentSessionId);

    return new Response(
      JSON.stringify({
        success: true,
        session_id: currentSessionId,
        message: aiMessage,
        tokens_used: tokensUsed
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
        error: error instanceof Error ? error.message : 'Bilinmeyen bir hata oluştu'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
