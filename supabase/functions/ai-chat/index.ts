import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function uint8ArrayToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunkSize = 8192;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const end = Math.min(i + chunkSize, bytes.length);
    for (let j = i; j < end; j++) {
      binary += String.fromCharCode(bytes[j]);
    }
  }
  return btoa(binary);
}

function cleanTextForTTS(text: string): string {
  return text
    .replace(/[\u{1F600}-\u{1F6FF}]/gu, '')
    .replace(/[\u{2600}-\u{27BF}]/gu, '')
    .replace(/[\u{1F300}-\u{1F5FF}]/gu, '')
    .replace(/[\u{1F900}-\u{1F9FF}]/gu, '')
    .replace(/[\u{1FA00}-\u{1FA6F}]/gu, '')
    .replace(/[\u{1FA70}-\u{1FAFF}]/gu, '')
    .replace(/\[.*?\]/g, '')
    .replace(/[*_~`#]+/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

interface ScreenContext {
  screen_type: string;
  entity_id?: string;
  entity_name?: string;
  entity_type?: string; // restaurant, store, market
  extra?: Record<string, unknown>;
}

interface ChatRequest {
  message: string;
  session_id?: string;
  app_source: string;
  user_type?: string;
  screen_context?: ScreenContext;
  generate_audio?: boolean;
  stream?: boolean;
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

// All known food names for extraction
const FOOD_NAMES = [
  'adana kebap', 'adana kebabı', 'urfa kebap', 'urfa kebabı', 'iskender', 'döner', 'dürüm',
  'lahmacun', 'pide', 'pizza', 'burger', 'hamburger', 'köfte', 'tantuni', 'kokoreç',
  'makarna', 'sushi', 'kebap', 'kebab', 'tavuk', 'balık', 'çorba', 'salata', 'börek',
  'tatlı', 'pasta', 'wrap', 'tost', 'sandviç', 'kahvaltı', 'waffle', 'krep', 'çiğ köfte',
  'mantı', 'gözleme', 'kumpir', 'midye', 'kanat', 'ciğer', 'kuzu', 'biftek', 'steak',
  'noodle', 'ramen', 'falafel', 'humus', 'karnıyarık', 'imam bayıldı', 'mercimek',
  'pilav', 'sarma', 'dolma', 'künefe', 'baklava', 'profiterol', 'sufle', 'tiramisu',
  'acılı', 'peynirli', 'etli', 'tavuklu', 'karışık', 'vejeteryan', 'vegan',
];

function extractFoodKeywords(message: string): string | null {
  const lowerMessage = message.toLowerCase();
  const found: string[] = [];

  // Check multi-word food names first (longer matches take priority)
  const sortedFoods = [...FOOD_NAMES].sort((a, b) => b.length - a.length);
  for (const food of sortedFoods) {
    if (lowerMessage.includes(food)) {
      found.push(food);
      if (found.length >= 3) break; // Max 3 keywords
    }
  }

  return found.length > 0 ? found.join(' ') : null;
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
  const foodKeywords = extractFoodKeywords(message);
  if (foodKeywords) return foodKeywords;

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
- SADECE aşağıda [RESTORAN ARAMA SONUÇLARI] bölümünde verilen restoran ve ürün isimlerini kullan
- Eğer restoran arama sonuçları boşsa veya yoksa, genel yemek türü öner (ör: "kebap", "pizza") ama ASLA belirli restoran veya menü adı uydurmayın
- Samimi ve arkadaşça bir dil kullan`;

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
    const { message, session_id, app_source, user_type = 'customer', screen_context, generate_audio = false, stream = false } = body;

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

    // Save user message (don't await - fire and forget)
    const saveUserMsg = supabase.from('support_chat_messages').insert({
      session_id: currentSessionId,
      role: 'user',
      content: message
    });

    // ========== PARALLEL DATA FETCHING ==========
    // All these queries are independent - run them simultaneously
    const isCustomerApp = app_source === 'super_app' || app_source === 'customer_app';
    const isMerchant = app_source === 'merchant_panel';
    const needsOrderCheck = isCustomerApp && isOrderQuery(message);
    const needsCancelCheck = isCustomerApp && isCancelQuery(message);
    const needsFoodRec = isCustomerApp && (isFoodQuery(message) || isPreferenceUpdate(message));
    const needsExplicitRestSearch = isCustomerApp && isRestaurantSearchQuery(message);
    // When user asks about food (e.g. "karnım acıktı kebap"), also search restaurants
    // so we can provide REAL data instead of hallucinating
    const foodKeywordsForSearch = isCustomerApp && needsFoodRec ? extractFoodKeywords(message) : null;
    // Also search when user mentions a food name directly (e.g. "kebap", "pizza")
    const directFoodNameSearch = isCustomerApp && !needsFoodRec && !needsExplicitRestSearch ? extractFoodKeywords(message) : null;
    const needsRestSearch = needsExplicitRestSearch || (foodKeywordsForSearch !== null) || (directFoodNameSearch !== null);

    // Build parallel promises
    const parallelQueries: Record<string, Promise<unknown>> = {
      // Always needed
      systemPrompt: supabase
        .from('ai_system_prompts')
        .select('system_prompt, restrictions')
        .eq('app_source', app_source)
        .eq('is_active', true)
        .single(),

      // Knowledge base - filter by message keywords for relevance
      knowledgeBase: supabase
        .from('ai_knowledge_base')
        .select('question, answer, category')
        .or(`app_source.eq.${app_source},app_source.eq.all`)
        .eq('is_active', true)
        .order('priority', { ascending: false })
        .limit(15),

      // Conversation history
      history: supabase
        .from('support_chat_messages')
        .select('role, content')
        .eq('session_id', currentSessionId)
        .order('created_at', { ascending: true })
        .limit(8),

      // User message save
      saveMsg: saveUserMsg,
    };

    // Conditional queries - only add what's needed
    if (needsOrderCheck) {
      parallelQueries.orderStatus = supabase.rpc('ai_get_order_status', { p_user_id: user.id });
    }

    if (needsCancelCheck) {
      parallelQueries.cancelMessages = supabase
        .from('support_chat_messages')
        .select('role, content')
        .eq('session_id', currentSessionId)
        .order('created_at', { ascending: false })
        .limit(4);
    }

    if (needsFoodRec) {
      parallelQueries.foodRec = supabase.rpc('ai_get_food_recommendations', { p_user_id: user.id });
      parallelQueries.promotions = supabase.rpc('ai_get_user_promotions', { p_user_id: user.id });
    }

    // NOTE: restSearch is deferred until after parallel batch to use userAddress lat/lon

    if (screen_context && app_source === 'super_app' && screen_context.entity_id && screen_context.screen_type?.endsWith('_detail')) {
      parallelQueries.merchantProducts = supabase.rpc('ai_search_merchant_products', {
        p_merchant_id: screen_context.entity_id,
        p_search_query: message.length > 2 ? message : null,
        p_merchant_type: screen_context.entity_type || 'restaurant',
      });
    }

    if (isMerchant) {
      parallelQueries.merchantData = supabase
        .from('merchants')
        .select('id, business_name, type, is_active, created_at')
        .eq('user_id', user.id)
        .single();
    }

    // Fetch user's default address for delivery zone filtering (customer only)
    if (isCustomerApp && needsRestSearch) {
      parallelQueries.userAddress = supabase
        .from('user_addresses')
        .select('latitude, longitude')
        .eq('user_id', user.id)
        .eq('is_default', true)
        .limit(1)
        .maybeSingle();
    }

    // Fetch user allergies for food safety awareness (customer only)
    if (isCustomerApp && (needsRestSearch || needsFoodRec)) {
      parallelQueries.userAllergies = supabase
        .from('user_food_preferences')
        .select('allergies')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    }

    // Execute ALL queries in parallel
    const keys = Object.keys(parallelQueries);
    const results = await Promise.allSettled(Object.values(parallelQueries));

    // Map results back to named keys
    const queryResults: Record<string, { data?: unknown; error?: unknown }> = {};
    keys.forEach((key, i) => {
      const result = results[i];
      if (result.status === 'fulfilled') {
        queryResults[key] = result.value as { data?: unknown; error?: unknown };
      } else {
        queryResults[key] = { data: null, error: result.reason };
        console.error(`Query ${key} failed:`, result.reason);
      }
    });

    // ========== PROCESS RESULTS ==========
    const promptData = queryResults.systemPrompt?.data as { system_prompt: string; restrictions: string } | null;
    const allKnowledge = (queryResults.knowledgeBase?.data || []) as Array<{ question: string; answer: string; category: string }>;
    const history = (queryResults.history?.data || []) as Array<{ role: string; content: string }>;

    // Filter knowledge base by relevance to user message
    const lowerMessage = message.toLowerCase();
    const messageWords = lowerMessage.split(/\s+/).filter(w => w.length > 2);
    const relevantKnowledge = allKnowledge.filter(kb => {
      const kbText = `${kb.question} ${kb.category}`.toLowerCase();
      return messageWords.some(word => kbText.includes(word));
    }).slice(0, 3);

    let contextInfo = '';
    if (relevantKnowledge.length > 0) {
      contextInfo = '\n\nİLGİLİ BİLGİLER:\n';
      relevantKnowledge.forEach((kb, i) => {
        contextInfo += `${i + 1}. S: ${kb.question}\n   C: ${kb.answer}\n\n`;
      });
    }

    // Process order status
    let orderContext = '';
    if (needsOrderCheck && queryResults.orderStatus?.data) {
      orderContext = formatOrderStatusForAI(queryResults.orderStatus.data as OrderStatus);
    }

    // Process cancellation - may need a sequential follow-up
    let cancelContext = '';
    if (needsCancelCheck) {
      const recentMessages = (queryResults.cancelMessages?.data || []) as Array<{ role: string; content: string }>;
      const aiAskedForConfirmation = recentMessages.some(msg =>
        msg.role === 'assistant' &&
        (msg.content.includes('iptal etmek istediğinizden') ||
         msg.content.includes('emin misiniz') ||
         msg.content.includes('İptal etmek istiyor musunuz'))
      );

      if (aiAskedForConfirmation && isCancelConfirmation(message)) {
        const { data: cancelResult, error: cancelError } = await supabase.rpc('ai_cancel_order', {
          p_user_id: user.id,
          p_order_id: null
        });
        if (!cancelError && cancelResult) {
          cancelContext = formatCancelInfoForAI(cancelResult as CancelResult, true);
        }
      } else {
        const { data: eligibility, error: eligError } = await supabase.rpc('ai_check_cancel_eligibility', {
          p_user_id: user.id
        });
        if (!eligError && eligibility) {
          cancelContext = formatCancelInfoForAI(eligibility as CancelResult, false);
        }
      }
    }

    // Process food recommendations
    let foodContext = '';
    if (needsFoodRec) {
      const foodRec = queryResults.foodRec;
      if (foodRec && !foodRec.error && foodRec.data) {
        foodContext = formatFoodRecommendationForAI(foodRec.data as FoodRecommendation);
      }
      const promoResult = queryResults.promotions as { data?: { has_promotions: boolean; active_promotions: Array<{ business_name: string; discount_badge: string; category_tags: string[] }> } };
      if (promoResult?.data?.has_promotions) {
        foodContext += `\n\n🎉 AKTİF KAMPANYALAR:`;
        promoResult.data.active_promotions.forEach(promo => {
          foodContext += `\n- ${promo.business_name}: ${promo.discount_badge}`;
        });
      }
    }

    // Process restaurant search (deferred - needs userAddress from parallel batch)
    let restaurantSearchContext = '';
    if (needsRestSearch) {
      const searchTerms = foodKeywordsForSearch || directFoodNameSearch || extractSearchTerms(message);
      const addressData = queryResults.userAddress?.data as { latitude: number; longitude: number } | null;
      const rpcParams: Record<string, unknown> = { p_search_query: searchTerms };
      if (addressData?.latitude && addressData?.longitude) {
        rpcParams.p_customer_lat = addressData.latitude;
        rpcParams.p_customer_lon = addressData.longitude;
      }
      const { data: restSearchData, error: restSearchError } = await supabase.rpc('ai_search_restaurants', rpcParams);
      if (!restSearchError && restSearchData) {
        restaurantSearchContext = formatRestaurantSearchForAI(restSearchData as RestaurantSearchResult);
      }
    }

    // Process screen context & merchant products
    let screenContextInfo = '';
    let merchantProductsContext = '';
    const actions: Array<{type: string; payload: Record<string, unknown>}> = [];

    if (screen_context && app_source === 'super_app') {
      const { screen_type, entity_id, entity_name, entity_type } = screen_context;

      const screenNames: Record<string, string> = {
        'home': 'Ana Sayfa',
        'food_home': 'Yemek Siparişi Ana Sayfa',
        'restaurant_detail': `${entity_name || 'Restoran'} Detay Sayfası`,
        'store_detail': `${entity_name || 'Mağaza'} Detay Sayfası`,
        'market_detail': `${entity_name || 'Market'} Detay Sayfası`,
        'store_cart': 'Mağaza Sepeti',
        'food_cart': 'Yemek Sepeti',
        'grocery_home': 'Market Ana Sayfa',
        'store_home': 'Mağaza Ana Sayfa',
        'favorites': 'Favoriler',
        'orders': 'Siparişlerim',
        'profile': 'Profil',
      };
      const screenLabel = screenNames[screen_type] || screen_type;
      screenContextInfo = `\n\n[EKRAN BAĞLAMI]: Kullanıcı şu anda "${screenLabel}" sayfasında.`;

      // Process product results if available
      const productResult = queryResults.merchantProducts?.data as { products?: Array<Record<string, unknown>>; total_count?: number } | null;
      if (entity_id && screen_type?.endsWith('_detail') && productResult) {
        const products = productResult.products || [];
        const totalCount = productResult.total_count || 0;

        if (products.length > 0) {
          const merchantType = entity_type || 'restaurant';
          merchantProductsContext = `\n\n[SİSTEM BİLGİSİ - ${entity_name?.toUpperCase() || 'MAĞAZA'} ÜRÜNLERİ]:`;
          merchantProductsContext += `\n📦 Toplam ${totalCount} ürün bulundu.`;
          merchantProductsContext += `\n\n🛍️ ÜRÜNLER:`;

          products.slice(0, 10).forEach((p: Record<string, unknown>, i: number) => {
            const price = p.discounted_price || p.original_price ? p.price : p.price;
            const originalPrice = (p.discounted_price && p.discounted_price !== p.price)
              ? ` (İndirimli! Eski: ${p.price} TL)`
              : (p.original_price && p.original_price !== p.price)
                ? ` (İndirimli! Eski: ${p.original_price} TL)`
                : '';
            merchantProductsContext += `\n${i + 1}. ${p.name} - ${price} TL${originalPrice}`;
            if (p.description) merchantProductsContext += `\n   ${(p.description as string).substring(0, 80)}`;
            if (p.is_popular || p.is_featured) merchantProductsContext += ` ⭐Popüler`;
            if (p.stock !== undefined && (p.stock as number) <= 5 && (p.stock as number) > 0) merchantProductsContext += ` ⚠️Son ${p.stock} adet`;
            if (p.brand) merchantProductsContext += ` | Marka: ${p.brand}`;
            merchantProductsContext += ` | ID: ${p.id}`;
          });

          merchantProductsContext += `\n\n📋 TALİMAT:
- Kullanıcı ürün sorarsa bu listeden bilgi ver
- "Sepete ekle" denirse ürün bilgilerini action olarak döndür
- Fiyatları ve indirimleri belirt
- Stok durumunu paylaş`;

          // Detect add-to-cart intent
          const addToCartKeywords = [
            'sepete ekle', 'sepetime ekle', 'ekle', 'almak istiyorum', 'al', 'istiyorum',
            'sipariş ver', 'sipariş et', 'cart', 'add to cart', 'buy', 'tane', 'adet'
          ];
          const lowerMsg = message.toLowerCase();
          const wantsToAdd = addToCartKeywords.some(kw => lowerMsg.includes(kw));

          if (wantsToAdd) {
            const matchedProduct = products.find((p: Record<string, unknown>) => {
              const productName = (p.name as string).toLowerCase();
              return lowerMsg.includes(productName) || productName.includes(lowerMsg.replace(/sepete ekle|ekle|istiyorum|almak|sipariş|ver|et|tane|adet|\d+/gi, '').trim());
            });

            if (matchedProduct) {
              const quantityMatch = lowerMsg.match(/(\d+)\s*(tane|adet)/);
              const quantity = quantityMatch ? parseInt(quantityMatch[1]) : 1;

              actions.push({
                type: 'add_to_cart',
                payload: {
                  product_id: matchedProduct.id,
                  name: matchedProduct.name,
                  price: matchedProduct.discounted_price || matchedProduct.price,
                  image_url: matchedProduct.image_url || '',
                  merchant_id: entity_id,
                  merchant_name: entity_name || '',
                  merchant_type: merchantType,
                  quantity,
                }
              });
            }
          }
        }
      }

      // Detect navigation intent
      const lowerMsgNav = message.toLowerCase();
      const navKeywords: Record<string, string> = {
        'yemek sipariş': '/food',
        'restoran': '/food',
        'market': '/grocery',
        'mağaza': '/market',
        'sepet': merchantProductsContext ? '/store/cart' : '/food/cart',
        'siparişlerim': '/orders-main',
        'favoriler': '/favorites',
        'profil': '/profile',
        'ayarlar': '/settings',
        'ana sayfa': '/',
      };

      for (const [keyword, route] of Object.entries(navKeywords)) {
        if (lowerMsgNav.includes(keyword) && (lowerMsgNav.includes('git') || lowerMsgNav.includes('aç') || lowerMsgNav.includes('göster') || lowerMsgNav.includes('gitmek'))) {
          actions.push({
            type: 'navigate',
            payload: { route }
          });
          break;
        }
      }
    }

    // Process merchant info
    let merchantContext = '';
    if (isMerchant && queryResults.merchantData?.data) {
      const merchantData = queryResults.merchantData.data as { id: string; business_name: string; type: string; is_active: boolean; created_at: string };
      // Commission rate needs sequential query (depends on merchant type)
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

      merchantContext = formatMerchantInfoForAI({
        id: merchantData.id,
        business_name: merchantData.business_name,
        type: merchantData.type,
        commission_rate: commissionRate,
        is_active: merchantData.is_active,
        created_at: merchantData.created_at
      });
    }

    // ========== BUILD AI REQUEST ==========
    const systemPrompt = promptData?.system_prompt || 'Sen yardımcı bir asistansın.';
    const restrictions = promptData?.restrictions || '';

    // Build system message with ONLY relevant context
    let systemContent = `${systemPrompt}\n\nKISITLAMALAR:\n${restrictions}`;
    systemContent += `\n\nKRİTİK KURALLAR:
1. ASLA veritabanında olmayan restoran adı, menü adı veya ürün ismi UYDURMAYACAKSIN. Bu en önemli kural.
2. Restoran veya yemek önerisi yaparken SADECE [RESTORAN ARAMA SONUÇLARI] bölümünde sana verilen gerçek verileri kullan.
3. Eğer arama sonuçları yoksa veya boşsa, "Maalesef şu an bu ürünü sunan aktif bir restoran bulamadım" de. Uydurma isim verme.
4. Bilmediğin veya sana verilmeyen konularda bilgi uydurma. Emin olmadığın bilgileri kesin ifadelerle paylaşma.
5. SADECE sana verilen sistem bilgileri doğrultusunda cevap ver.`;

    // Allergy awareness block
    const userAllergiesData = queryResults.userAllergies?.data as { allergies: string[] } | null;
    const userAllergies = userAllergiesData?.allergies?.filter(a => a && a.trim()) || [];
    if (userAllergies.length > 0) {
      systemContent += `\n\n⚠️ KULLANICI ALERJİLERİ: ${userAllergies.join(', ')}
ALERJI KURALLARI:
- Yemek önerirken bu alerjenlere DİKKAT ET
- Restoran ürün içeriği/malzeme bilgisi eklememişse, o yemeğin genel tarifinde bu alerjen varsa UYAR
- Uyarı formatı: "Bu restoran içerik bilgisi eklememiş ama [yemek] genellikle [alerjen] içerebilir, dikkatli olmanızı öneririm"
- KESİN ifade KULLANMA. "İçerebilir", "ihtimali var", "dikkatli olun" gibi ihtimal belirten ifadeler kullan
- İçerik bilgisi olmayan ürünlerde HER ZAMAN uyar
- Bilinen güvenli ürünleri (ör: fıstık alerjisi olan birine sade pilav) güvenle önerebilirsin`;
    }

    // Only append non-empty contexts
    if (contextInfo) systemContent += contextInfo;
    if (screenContextInfo) systemContent += screenContextInfo;
    if (merchantProductsContext) systemContent += merchantProductsContext;
    if (orderContext) systemContent += orderContext;
    if (cancelContext) systemContent += cancelContext;
    if (foodContext) systemContent += foodContext;
    if (restaurantSearchContext) systemContent += restaurantSearchContext;
    if (merchantContext) systemContent += merchantContext;

    const messages: ChatMessage[] = [
      { role: 'system', content: systemContent }
    ];

    // Add history (skip duplicates)
    if (history) {
      history.forEach(msg => {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role as 'user' | 'assistant', content: msg.content });
        }
      });
    }

    // Add current message if not already in history
    if (!history || history.length === 0 || history[history.length - 1].content !== message) {
      messages.push({ role: 'user', content: message });
    }

    // ========== STREAMING vs NON-STREAMING BRANCH ==========
    if (stream && !generate_audio) {
      // STREAMING PATH: SSE response with word-by-word delivery
      const encoder = new TextEncoder();

      const sseStream = new ReadableStream({
        async start(controller) {
          try {
            // 1. Send session event immediately
            controller.enqueue(encoder.encode(
              `event: session\ndata: ${JSON.stringify({ session_id: currentSessionId })}\n\n`
            ));

            // 2. Call OpenAI with stream: true
            const streamResponse = await fetch('https://api.openai.com/v1/chat/completions', {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                model: 'gpt-4o-mini',
                messages,
                max_tokens: 500,
                temperature: 0.3,
                stream: true,
                stream_options: { include_usage: true },
              }),
            });

            if (!streamResponse.ok) {
              const errorText = await streamResponse.text();
              console.error('OpenAI Stream Error:', errorText);
              controller.enqueue(encoder.encode(
                `event: error\ndata: ${JSON.stringify({ error: 'AI servisi hatası' })}\n\n`
              ));
              controller.close();
              return;
            }

            // 3. Read OpenAI SSE stream and forward chunks to client
            const reader = streamResponse.body!.getReader();
            const decoder = new TextDecoder();
            let fullMessage = '';
            let totalTokens = 0;
            let sseBuffer = '';

            while (true) {
              const { done, value } = await reader.read();
              if (done) break;

              sseBuffer += decoder.decode(value, { stream: true });
              const lines = sseBuffer.split('\n');
              sseBuffer = lines.pop() || '';

              for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed || !trimmed.startsWith('data: ')) continue;

                const data = trimmed.slice(6);
                if (data === '[DONE]') continue;

                try {
                  const parsed = JSON.parse(data);
                  const delta = parsed.choices?.[0]?.delta?.content;
                  if (delta) {
                    fullMessage += delta;
                    controller.enqueue(encoder.encode(
                      `event: chunk\ndata: ${JSON.stringify({ text: delta })}\n\n`
                    ));
                  }
                  if (parsed.usage) {
                    totalTokens = parsed.usage.total_tokens || 0;
                  }
                } catch {
                  // Skip malformed JSON
                }
              }
            }

            // Process remaining buffer
            if (sseBuffer.trim()) {
              const trimmed = sseBuffer.trim();
              if (trimmed.startsWith('data: ') && trimmed.slice(6) !== '[DONE]') {
                try {
                  const parsed = JSON.parse(trimmed.slice(6));
                  const delta = parsed.choices?.[0]?.delta?.content;
                  if (delta) {
                    fullMessage += delta;
                    controller.enqueue(encoder.encode(
                      `event: chunk\ndata: ${JSON.stringify({ text: delta })}\n\n`
                    ));
                  }
                } catch { /* skip */ }
              }
            }

            if (!fullMessage) {
              fullMessage = 'Üzgünüm, yanıt oluşturulamadı.';
            }

            // 4. Send actions if any
            if (actions.length > 0) {
              controller.enqueue(encoder.encode(
                `event: actions\ndata: ${JSON.stringify({ actions })}\n\n`
              ));
            }

            // 5. Send done event
            controller.enqueue(encoder.encode(
              `event: done\ndata: ${JSON.stringify({ message: fullMessage, tokens_used: totalTokens })}\n\n`
            ));

            // 6. Save to DB after stream completes (fire and forget)
            Promise.all([
              supabase.from('support_chat_messages').insert({
                session_id: currentSessionId,
                role: 'assistant',
                content: fullMessage,
                tokens_used: totalTokens,
              }),
              supabase
                .from('support_chat_sessions')
                .update({ updated_at: new Date().toISOString() })
                .eq('id', currentSessionId),
            ]).catch(err => console.error('DB save error:', err));

            controller.close();
          } catch (error) {
            console.error('Streaming error:', error);
            controller.enqueue(encoder.encode(
              `event: error\ndata: ${JSON.stringify({ error: error instanceof Error ? error.message : 'Streaming hatası' })}\n\n`
            ));
            controller.close();
          }
        }
      });

      return new Response(sseStream, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      });
    }

    // ========== NON-STREAMING PATH (existing) ==========
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
        max_tokens: 500,
        temperature: 0.3,
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

    // Generate TTS audio inline if requested (voice mode)
    let audioBase64: string | null = null;
    if (generate_audio && aiMessage) {
      try {
        const cleanText = cleanTextForTTS(aiMessage);
        if (cleanText.length > 0) {
          // Truncate to 500 chars for faster TTS
          const ttsInput = cleanText.substring(0, 500);
          const ttsResponse = await fetch('https://api.openai.com/v1/audio/speech', {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${OPENAI_API_KEY}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              model: 'tts-1',
              voice: 'nova',
              input: ttsInput,
              response_format: 'mp3',
              speed: 1.1,
            }),
          });

          if (ttsResponse.ok) {
            const audioBuffer = await ttsResponse.arrayBuffer();
            audioBase64 = uint8ArrayToBase64(new Uint8Array(audioBuffer));
          }
        }
      } catch (ttsError) {
        console.error('Inline TTS error:', ttsError);
        // Continue without audio - text response still works
      }
    }

    // Save AI response & update session IN PARALLEL
    await Promise.all([
      supabase.from('support_chat_messages').insert({
        session_id: currentSessionId,
        role: 'assistant',
        content: aiMessage,
        tokens_used: tokensUsed
      }),
      supabase
        .from('support_chat_sessions')
        .update({ updated_at: new Date().toISOString() })
        .eq('id', currentSessionId)
    ]);

    return new Response(
      JSON.stringify({
        success: true,
        session_id: currentSessionId,
        message: aiMessage,
        tokens_used: tokensUsed,
        ...(actions.length > 0 && { actions }),
        ...(audioBase64 && { audio: audioBase64, audio_format: 'mp3' }),
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
