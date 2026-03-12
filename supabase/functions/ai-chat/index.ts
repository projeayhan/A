import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

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

// ========== INTERFACES ==========

interface ScreenContext {
  screen_type: string;
  entity_id?: string;
  entity_name?: string;
  entity_type?: string;
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
      id?: string;
      name: string;
      description: string;
      price: number;
      discounted_price: number | null;
      is_popular: boolean;
      rating: number;
      image_url?: string;
    }>;
    recent_good_reviews: Array<{
      rating: number;
      comment: string;
      customer_name: string;
      created_at: string;
    }>;
  }>;
}

interface StoreSearchResult {
  success: boolean;
  search_query: string;
  result_count: number;
  stores: Array<{
    merchant_id: string;
    business_name: string;
    merchant_type: string;
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
    matching_products: Array<{
      id?: string;
      name: string;
      description: string;
      price: number;
      original_price: number | null;
      is_featured: boolean;
      rating: number;
      image_url?: string;
      brand?: string;
      sold_count?: number;
      stock?: number;
      category?: string;
    }>;
  }>;
}

interface RentalCarSearchResult {
  success: boolean;
  result_count: number;
  cars: Array<{
    car_id: string;
    brand: string;
    model: string;
    year: number;
    category: string;
    transmission: string;
    fuel_type: string;
    seats: number;
    doors: number;
    daily_price: number;
    deposit_amount: number;
    has_ac: boolean;
    has_gps: boolean;
    has_bluetooth: boolean;
    image_url: string;
    company_name: string;
    company_id: string;
    company_city: string;
    company_rating: number;
    mileage_limit: number | null;
    min_driver_age: number;
  }>;
}

interface RentalBookingStatus {
  has_bookings: boolean;
  bookings: Array<{
    booking_id: string;
    booking_number: string;
    status: string;
    car_brand: string;
    car_model: string;
    car_year: number;
    car_category: string;
    company_name: string;
    company_city: string;
    pickup_date: string;
    dropoff_date: string;
    daily_rate: number;
    rental_days: number;
    total_amount: number;
    deposit_amount: number;
    payment_status: string;
    package_name: string | null;
  }>;
}

interface CarListingSearchResult {
  success: boolean; result_count: number;
  cars: Array<{ listing_id: string; title: string; brand_name: string; model_name: string; year: number; mileage: number; body_type: string; fuel_type: string; transmission: string; traction: string; engine_cc: number; horsepower: number; exterior_color: string; condition: string; price: number; currency: string; is_price_negotiable: boolean; is_exchange_accepted: boolean; has_warranty: boolean; city: string; district: string; image_url: string | null; image_count: number; view_count: number; favorite_count: number; is_featured: boolean; is_premium: boolean; created_at: string; }>;
}

interface JobListingSearchResult {
  success: boolean; result_count: number;
  jobs: Array<{ job_id: string; title: string; description: string; category_id: string; subcategory: string; job_type: string; work_arrangement: string; experience_level: string; education_level: string; salary_min: number; salary_max: number; salary_currency: string; salary_period: string; is_salary_hidden: boolean; city: string; district: string; positions: number; required_skills: string[]; manual_benefits: string[]; is_urgent: boolean; is_featured: boolean; deadline: string; application_count: number; view_count: number; created_at: string; poster_name: string; company_name: string; company_logo: string; company_industry: string; company_verified: boolean; }>;
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

interface ChatMessage {
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string;
  tool_calls?: Array<{ id: string; type: string; function: { name: string; arguments: string } }>;
  tool_call_id?: string;
}

// ========== FORMAT FUNCTIONS ==========

function formatFoodRecommendationForAI(recommendation: FoodRecommendation): string {
  let info = `🍽️ ÖĞÜN: ${recommendation.meal_type.toUpperCase()} (Saat: ${recommendation.current_hour}:00)`;

  if (recommendation.user_preferences) {
    const prefs = recommendation.user_preferences;
    info += `\n\n👤 KULLANICI TERCİHLERİ:`;
    if (prefs.favorite_cuisines.length > 0) info += `\n- Favori Mutfaklar: ${prefs.favorite_cuisines.join(', ')}`;
    if (prefs.dietary_restrictions.length > 0) info += `\n- Diyet Kısıtlamaları: ${prefs.dietary_restrictions.join(', ')}`;
    if (prefs.allergies.length > 0) info += `\n- Alerjiler: ${prefs.allergies.join(', ')} ⚠️ DİKKAT!`;
    if (prefs.disliked_ingredients.length > 0) info += `\n- Sevmediği Malzemeler: ${prefs.disliked_ingredients.join(', ')}`;
    info += `\n- Acı Seviyesi: ${prefs.spice_level}/5`;
    info += `\n- Bütçe: ${prefs.budget_range === 'low' ? 'Ekonomik' : prefs.budget_range === 'medium' ? 'Orta' : 'Yüksek'}`;
  } else {
    info += `\n\n👤 KULLANICI TERCİHLERİ: Henüz kaydedilmemiş.`;
  }

  if (recommendation.order_history) {
    const h = recommendation.order_history;
    info += `\n\n📊 SİPARİŞ GEÇMİŞİ:`;
    info += `\n- Toplam Sipariş: ${h.total_orders} | Farklı Restoran: ${h.unique_merchants}`;
    if (h.ordered_cuisines?.length > 0) info += `\n- Denenen Mutfaklar: ${h.ordered_cuisines.join(', ')}`;
    info += `\n- Ortalama Sipariş: ${h.avg_order_amount} TL`;
    if (h.last_order_date) {
      const daysSince = Math.floor((Date.now() - new Date(h.last_order_date).getTime()) / (1000 * 60 * 60 * 24));
      info += `\n- Son Sipariş: ${daysSince === 0 ? 'Bugün' : daysSince === 1 ? 'Dün' : daysSince + ' gün önce'}`;
    }
  }

  if (recommendation.favorite_restaurants?.length > 0) {
    info += `\n\n⭐ FAVORİ RESTORANLAR:`;
    recommendation.favorite_restaurants.forEach((rest, i) => {
      info += `\n${i + 1}. ${rest.name} (${rest.order_count} sipariş)`;
    });
  }

  return info;
}

function formatRecentOrderItems(data: { recent_orders: Array<{ order_date: string; merchant_name: string; items: Array<{ name: string; quantity: number; price: string }> }>; most_ordered_items: Array<{ name: string; order_count: number }> }): string {
  let info = '';

  if (data.most_ordered_items?.length > 0) {
    info += `\n🔄 EN ÇOK SİPARİŞ EDİLEN ÜRÜNLER:`;
    data.most_ordered_items.slice(0, 5).forEach((item, i) => {
      info += `\n${i + 1}. ${item.name} (${item.order_count} kez)`;
    });
  }

  if (data.recent_orders?.length > 0) {
    info += `\n\n📋 SON SİPARİŞLER:`;
    data.recent_orders.slice(0, 5).forEach((order) => {
      const date = new Date(order.order_date);
      const daysSince = Math.floor((Date.now() - date.getTime()) / (1000 * 60 * 60 * 24));
      const dateStr = daysSince === 0 ? 'Bugün' : daysSince === 1 ? 'Dün' : `${daysSince} gün önce`;
      const itemNames = order.items?.map(i => i.name).join(', ') || '';
      info += `\n- ${dateStr} | ${order.merchant_name}: ${itemNames}`;
    });
  }

  return info;
}

function formatRestaurantSearchForAI(searchResult: RestaurantSearchResult): string {
  if (!searchResult.success || searchResult.result_count === 0) {
    return `"${searchResult.search_query}" araması için sonuç bulunamadı.`;
  }

  let info = `🔍 "${searchResult.search_query}" araması: ${searchResult.result_count} restoran bulundu.\n`;

  searchResult.restaurants.slice(0, 5).forEach((rest, i) => {
    info += `\n${i + 1}. ${rest.business_name}`;
    info += ` | ⭐${rest.rating?.toFixed(1) || 'Yeni'} (${rest.review_count || 0} değerlendirme)`;
    info += ` | 🚚 ${rest.delivery_time || '30-45 dk'} | ${rest.delivery_fee > 0 ? rest.delivery_fee + ' TL' : 'Ücretsiz'}`;
    if (rest.discount_badge) info += ` | 🎉 ${rest.discount_badge}`;
    if (!rest.is_open) info += ` | ⚠️KAPALI`;

    if (rest.matching_items?.length > 0) {
      info += `\n   Ürünler:`;
      rest.matching_items.slice(0, 4).forEach(item => {
        const price = item.discounted_price || item.price;
        info += `\n   - ${item.name}: ${price} TL`;
        if (item.discounted_price) info += ` (eski: ${item.price} TL)`;
        if (item.is_popular) info += ' ⭐';
        if (item.id) info += ` [ID:${item.id}]`;
      });
    }

    if (rest.recent_good_reviews?.length > 0) {
      const review = rest.recent_good_reviews[0];
      const shortComment = review.comment.length > 50 ? review.comment.substring(0, 50) + '...' : review.comment;
      info += `\n   💬 "${shortComment}" - ${review.customer_name} (⭐${review.rating})`;
    }
  });

  return info;
}

function formatStoreSearchForAI(searchResult: StoreSearchResult): string {
  if (!searchResult.success || searchResult.result_count === 0) {
    return `"${searchResult.search_query}" araması için mağaza/market sonucu bulunamadı.`;
  }

  let info = `🏪 "${searchResult.search_query}" araması: ${searchResult.result_count} mağaza/market bulundu.\n`;

  searchResult.stores.slice(0, 5).forEach((store, i) => {
    const typeLabel = store.merchant_type === 'market' ? 'Market' : 'Mağaza';
    info += `\n${i + 1}. ${store.business_name} (${typeLabel})`;
    info += ` | ⭐${store.rating ? Number(store.rating).toFixed(1) : 'Yeni'} (${store.review_count || 0} değerlendirme)`;
    info += ` | 🚚 ${store.delivery_time || '30-45 dk'} | ${store.delivery_fee > 0 ? store.delivery_fee + ' TL' : 'Ücretsiz'}`;
    if (store.discount_badge) info += ` | 🎉 ${store.discount_badge}`;
    if (!store.is_open) info += ` | ⚠️KAPALI`;

    if (store.matching_products?.length > 0) {
      info += `\n   Ürünler:`;
      store.matching_products.slice(0, 4).forEach(product => {
        const price = product.price;
        info += `\n   - ${product.name}: ${price} TL`;
        if (product.original_price && product.original_price > product.price) info += ` (eski: ${product.original_price} TL)`;
        if (product.brand) info += ` [${product.brand}]`;
        if (product.is_featured) info += ' ⭐';
        if (product.id) info += ` [ID:${product.id}]`;
      });
    }
  });

  return info;
}

function formatRentalSearchForAI(result: RentalCarSearchResult): string {
  if (!result.success || result.result_count === 0) {
    return 'Arama kriterlerinize uygun kiralık araç bulunamadı.';
  }
  const catLabels: Record<string, string> = { economy: 'Ekonomi', compact: 'Kompakt', midsize: 'Orta', suv: 'SUV', luxury: 'Lüks', van: 'Van/Minibüs' };
  const transLabels: Record<string, string> = { automatic: 'Otomatik', manual: 'Manuel' };
  const fuelLabels: Record<string, string> = { gasoline: 'Benzin', diesel: 'Dizel', hybrid: 'Hibrit' };

  let info = `🚗 ${result.result_count} kiralık araç bulundu:\n`;
  result.cars.slice(0, 8).forEach((car, i) => {
    info += `\n${i + 1}. ${car.brand} ${car.model} (${car.year}) - ${car.daily_price} TL/gün`;
    info += `\n   ${catLabels[car.category] || car.category} | ${transLabels[car.transmission] || car.transmission} | ${fuelLabels[car.fuel_type] || car.fuel_type}`;
    info += ` | ${car.seats} koltuk`;
    const features: string[] = [];
    if (car.has_ac) features.push('Klima');
    if (car.has_gps) features.push('GPS');
    if (car.has_bluetooth) features.push('Bluetooth');
    if (features.length > 0) info += ` | ${features.join(', ')}`;
    info += `\n   🏢 ${car.company_name} (${car.company_city}) ⭐${car.company_rating}`;
    info += ` | Depozito: ${car.deposit_amount} TL`;
    if (car.min_driver_age > 18) info += ` | Min yaş: ${car.min_driver_age}`;
    info += ` [CID:${car.car_id}] [COMP:${car.company_id}]`;
  });
  return info;
}

function formatRentalBookingForAI(result: RentalBookingStatus): string {
  if (!result.has_bookings || result.bookings.length === 0) {
    return 'Aktif araç kiralama rezervasyonunuz bulunmuyor.';
  }
  const statusLabels: Record<string, string> = { pending: 'Onay Bekliyor', confirmed: 'Onaylandı', active: 'Aktif (Araç Teslim Alındı)', ready: 'Teslime Hazır' };
  let info = `📋 ${result.bookings.length} aktif rezervasyonunuz var:\n`;
  result.bookings.forEach((b, i) => {
    const pickup = new Date(b.pickup_date);
    const dropoff = new Date(b.dropoff_date);
    const pickupStr = `${pickup.getDate()}.${pickup.getMonth() + 1}.${pickup.getFullYear()}`;
    const dropoffStr = `${dropoff.getDate()}.${dropoff.getMonth() + 1}.${dropoff.getFullYear()}`;
    info += `\n${i + 1}. #${b.booking_number} - ${b.car_brand} ${b.car_model} (${b.car_year})`;
    info += `\n   Durum: ${statusLabels[b.status] || b.status}`;
    info += `\n   📅 ${pickupStr} → ${dropoffStr} (${b.rental_days} gün)`;
    info += `\n   💰 ${b.daily_rate} TL/gün = Toplam: ${b.total_amount} TL`;
    info += `\n   🏢 ${b.company_name} (${b.company_city})`;
    if (b.package_name) info += ` | Paket: ${b.package_name}`;
  });
  return info;
}

function formatCancelInfoForAI(cancelResult: CancelResult, wasConfirmed: boolean = false): string {
  if (wasConfirmed && cancelResult.success) {
    return `✅ Sipariş #${cancelResult.order_number} başarıyla iptal edildi.`;
  }
  if (cancelResult.can_cancel) {
    return `Sipariş #${cancelResult.order_number} iptal edilebilir durumda (henüz onaylanmadı). Kullanıcıdan onay iste.`;
  }
  const reasons: Record<string, string> = {
    'already_confirmed': 'İşletme siparişi onayladığı için artık iptal edilemez.',
    'already_cancelled': 'Sipariş zaten iptal edilmiş.',
    'already_delivered': 'Sipariş teslim edilmiş, iptal edilemez.',
    'no_order': 'Aktif sipariş bulunamadı.',
  };
  return `❌ İptal edilemez. Sebep: ${reasons[cancelResult.reason] || cancelResult.message}`;
}

function formatOrderStatusForAI(orderStatus: OrderStatus): string {
  if (!orderStatus.has_active_order) {
    return 'Kullanıcının aktif siparişi bulunmuyor.';
  }

  let info = `Sipariş #${orderStatus.order_number}:`;
  info += `\n- Durum: ${orderStatus.status_text}`;
  info += `\n- Restoran: ${orderStatus.merchant_name || 'Bilinmiyor'}`;
  info += `\n- Tutar: ${orderStatus.total_amount} TL`;
  info += `\n- Adres: ${orderStatus.delivery_address || 'Belirtilmemiş'}`;

  if (orderStatus.courier_assigned) {
    info += `\n- Kurye: ${orderStatus.courier_name}`;
    if (orderStatus.courier_vehicle_type) {
      const v = orderStatus.courier_vehicle_type === 'motorcycle' ? 'Motosiklet' : orderStatus.courier_vehicle_type === 'car' ? 'Araba' : orderStatus.courier_vehicle_type;
      info += ` (${v}${orderStatus.courier_vehicle_plate ? ', ' + orderStatus.courier_vehicle_plate : ''})`;
    }
    if (orderStatus.has_location && orderStatus.distance_km !== null) {
      info += `\n- Mesafe: ${orderStatus.distance_km} km | Tahmini: ~${orderStatus.estimated_minutes} dk (${orderStatus.estimated_arrival_time} civarı)`;
    }
  } else {
    if (orderStatus.status === 'pending') info += `\n- Sipariş onay bekliyor.`;
    else if (orderStatus.status === 'confirmed' || orderStatus.status === 'preparing') info += `\n- Sipariş hazırlanıyor, kurye atanacak.`;
  }

  return info;
}

function formatMerchantInfoForAI(merchant: MerchantInfo): string {
  return `İşletme: ${merchant.business_name} (${merchant.type === 'restaurant' ? 'Restoran' : 'Mağaza'}) | Komisyon: %${merchant.commission_rate} | Durum: ${merchant.is_active ? 'Aktif' : 'Pasif'}`;
}

function formatCarListingSearchForAI(result: CarListingSearchResult): string {
  if (!result.success || result.result_count === 0) return 'Arama kriterlerinize uygun satılık araç bulunamadı.';
  const condLabels: Record<string, string> = { new: 'Sıfır', used: 'İkinci El', certified: 'Sertifikalı' };
  const bodyLabels: Record<string, string> = { sedan: 'Sedan', hatchback: 'Hatchback', suv: 'SUV', crossover: 'Crossover', pickup: 'Pickup', minivan: 'Minivan', wagon: 'Station Wagon', convertible: 'Cabrio', sports: 'Spor', luxury: 'Lüks' };
  const fuelLabels: Record<string, string> = { petrol: 'Benzin', diesel: 'Dizel', lpg: 'LPG', hybrid: 'Hibrit', electric: 'Elektrik', plugin_hybrid: 'Plug-in Hibrit' };
  const transLabels: Record<string, string> = { automatic: 'Otomatik', manual: 'Manuel' };
  let info = `🚗 ${result.result_count} satılık araç bulundu:\n`;
  result.cars.slice(0, 8).forEach((car, i) => {
    info += `\n${i + 1}. ${car.title}`;
    info += `\n   ${car.year} | ${car.mileage?.toLocaleString('tr-TR') || 0} km | ${condLabels[car.condition] || car.condition}`;
    info += ` | ${bodyLabels[car.body_type] || car.body_type} | ${transLabels[car.transmission] || car.transmission} | ${fuelLabels[car.fuel_type] || car.fuel_type}`;
    if (car.horsepower) info += ` | ${car.horsepower} HP`;
    info += `\n   💰 ${Number(car.price).toLocaleString('tr-TR')} ${car.currency || 'TL'}`;
    if (car.is_price_negotiable) info += ' (Pazarlıklı)';
    if (car.is_exchange_accepted) info += ' | Takas Kabul';
    if (car.has_warranty) info += ' | Garantili';
    info += ` | 📍 ${car.city}${car.district ? '/' + car.district : ''}`;
    if (car.image_count > 0) info += ` | 📷 ${car.image_count} foto`;
    info += ` [LID:${car.listing_id}]`;
  });
  return info;
}

function formatJobListingSearchForAI(result: JobListingSearchResult): string {
  if (!result.success || result.result_count === 0) return 'Arama kriterlerinize uygun iş ilanı bulunamadı.';
  const typeLabels: Record<string, string> = { full_time: 'Tam Zamanlı', part_time: 'Yarı Zamanlı', contract: 'Sözleşmeli', freelance: 'Freelance', internship: 'Staj', temporary: 'Geçici' };
  const arrLabels: Record<string, string> = { onsite: 'Ofiste', remote: 'Uzaktan', hybrid: 'Hibrit' };
  const expLabels: Record<string, string> = { entry: 'Giriş Seviye', junior: 'Junior', mid_level: 'Mid-Level', senior: 'Senior', lead: 'Lead', director: 'Direktör', executive: 'Üst Düzey' };
  let info = `💼 ${result.result_count} iş ilanı bulundu:\n`;
  result.jobs.slice(0, 8).forEach((job, i) => {
    info += `\n${i + 1}. ${job.title}`;
    if (job.company_name) info += ` - ${job.company_name}${job.company_verified ? ' ✅' : ''}`;
    info += `\n   ${typeLabels[job.job_type] || job.job_type} | ${arrLabels[job.work_arrangement] || job.work_arrangement}`;
    if (job.experience_level) info += ` | ${expLabels[job.experience_level] || job.experience_level}`;
    info += ` | 📍 ${job.city}${job.district ? '/' + job.district : ''}`;
    if (!job.is_salary_hidden && (job.salary_min || job.salary_max)) {
      const min = job.salary_min ? Number(job.salary_min).toLocaleString('tr-TR') : '';
      const max = job.salary_max ? Number(job.salary_max).toLocaleString('tr-TR') : '';
      info += `\n   💰 ${min}${min && max ? ' - ' : ''}${max} ${job.salary_currency || 'TL'}`;
    }
    if (job.required_skills?.length > 0) info += `\n   🔧 ${job.required_skills.slice(0, 5).join(', ')}`;
    if (job.is_urgent) info += ' 🔴 ACİL';
    if (job.description) info += `\n   ${job.description.substring(0, 100)}...`;
    info += ` [JID:${job.job_id}]`;
  });
  return info;
}

// ========== TAXI FORMAT FUNCTIONS ==========

function formatTaxiFareEstimateForAI(data: { success: boolean; destination?: string; note?: string; vehicle_types: Array<{ name: string; display_name: string; base_fare: number; per_km: number; per_minute: number; minimum_fare: number; capacity: number; icon?: string }> }): string {
  if (!data.success || !data.vehicle_types?.length) return 'Araç tipi bilgisi alınamadı.';
  let info = `🚕 TAKSİ ARAÇ TİPLERİ VE FİYATLAR:\n`;
  if (data.note) info += `ℹ️ ${data.note}\n`;
  data.vehicle_types.forEach((vt, i) => {
    info += `\n${i + 1}. ${vt.display_name} (${vt.name})`;
    info += ` | Açılış: ${vt.base_fare} TL | Km başı: ${vt.per_km} TL | Dk başı: ${vt.per_minute} TL`;
    info += ` | Min: ${vt.minimum_fare} TL | ${vt.capacity} kişilik`;
  });
  return info;
}

function formatTaxiRideStatusForAI(data: { success: boolean; has_active_ride: boolean; message?: string; ride?: { ride_id: string; ride_number: string; status: string; pickup_address: string; dropoff_address: string; fare: number; distance_km: number; duration_minutes: number; driver_name?: string; driver_phone?: string; driver_rating?: number; vehicle_info?: string; vehicle_plate?: string; vehicle_color?: string; created_at: string; accepted_at?: string; arrived_at?: string; picked_up_at?: string } }): string {
  if (!data.has_active_ride) return 'Aktif yolculuğunuz bulunmuyor.';
  const r = data.ride!;
  const statusLabels: Record<string, string> = { pending: 'Sürücü Aranıyor', accepted: 'Sürücü Yolda', arrived: 'Sürücü Kapıda', in_progress: 'Yolculuk Devam Ediyor' };
  let info = `🚕 Yolculuk #${r.ride_number}:`;
  info += `\n- Durum: ${statusLabels[r.status] || r.status}`;
  info += `\n- Güzergah: ${r.pickup_address} → ${r.dropoff_address}`;
  info += `\n- Ücret: ${r.fare} TL | ${r.distance_km} km | ~${r.duration_minutes} dk`;
  if (r.driver_name) {
    info += `\n- Sürücü: ${r.driver_name}`;
    if (r.driver_rating) info += ` (⭐${Number(r.driver_rating).toFixed(1)})`;
    if (r.vehicle_info) info += `\n- Araç: ${r.vehicle_info}`;
    if (r.vehicle_color) info += ` (${r.vehicle_color})`;
    if (r.vehicle_plate) info += ` | Plaka: ${r.vehicle_plate}`;
  }
  return info;
}

function formatTaxiRideHistoryForAI(data: { success: boolean; ride_count: number; rides: Array<{ ride_number: string; status: string; pickup_address: string; dropoff_address: string; fare: number; distance_km: number; duration_minutes: number; rating?: number; driver_name?: string; created_at: string; completed_at?: string; cancelled_at?: string; cancellation_reason?: string }> }): string {
  if (!data.ride_count || data.rides.length === 0) return 'Henüz yolculuk geçmişiniz bulunmuyor.';
  let info = `📋 Son ${data.rides.length} yolculuğunuz:\n`;
  data.rides.forEach((r, i) => {
    const date = new Date(r.completed_at || r.cancelled_at || r.created_at);
    const daysSince = Math.floor((Date.now() - date.getTime()) / (1000 * 60 * 60 * 24));
    const dateStr = daysSince === 0 ? 'Bugün' : daysSince === 1 ? 'Dün' : `${daysSince} gün önce`;
    info += `\n${i + 1}. #${r.ride_number} | ${dateStr}`;
    info += `\n   ${r.pickup_address} → ${r.dropoff_address}`;
    info += ` | ${r.fare} TL | ${r.distance_km} km`;
    if (r.status === 'completed') {
      info += ` | ✅ Tamamlandı`;
      if (r.rating) info += ` | ⭐${r.rating}`;
      if (r.driver_name) info += ` | Sürücü: ${r.driver_name}`;
    } else if (r.status === 'cancelled') {
      info += ` | ❌ İptal`;
      if (r.cancellation_reason) info += ` (${r.cancellation_reason})`;
    }
  });
  return info;
}

function formatTaxiCancelForAI(data: { success: boolean; can_cancel?: boolean; reason?: string; ride_number?: string; pickup_address?: string; dropoff_address?: string; cancelled?: boolean; message?: string }, wasConfirmed: boolean = false): string {
  if (wasConfirmed && data.cancelled) {
    return `✅ Yolculuk #${data.ride_number} başarıyla iptal edildi.`;
  }
  if (data.can_cancel) {
    return `Yolculuk #${data.ride_number} (${data.pickup_address} → ${data.dropoff_address}) iptal edilebilir. Kullanıcıdan onay iste.`;
  }
  return `❌ ${data.reason || data.message || 'Yolculuk iptal edilemez.'}`;
}

// ========== OPENAI TOOL DEFINITIONS (customer_app) ==========

const CUSTOMER_TOOLS = [
  {
    type: "function" as const,
    function: {
      name: "search_food",
      description: "Yemek, ürün, restoran, mağaza veya market ara. Kullanıcı herhangi bir şey istediğinde bu aracı kullan: yiyecek/içecek, elektronik, giyim, ev eşyası, market ürünleri vb. Hem restoranlarda hem mağaza/marketlerde arama yapar. ⚠️ Anahtar kelimeleri KISA ve YALITILMIŞ tut (Türkçe ek EKLEME, çekim yalın halde): 'cep telefonu arıyorum' → ['telefon'], 'bilgisayar bakıyorum' → ['bilgisayar'], 'etli birşeyler' → ['kebap','köfte'], 'tişört istiyorum' → ['tişört'], 'marketten su' → ['su']. Marka belirtilmişse ekle: 'samsung telefon' → ['telefon','samsung']",
      parameters: {
        type: "object",
        properties: {
          keywords: {
            type: "array",
            items: { type: "string" },
            description: "Aranacak ürün anahtar kelimeleri. Yemek, elektronik, giyim, market ürünü vb. her türlü ürün olabilir."
          }
        },
        required: ["keywords"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "get_recommendations",
      description: "Kullanıcının sipariş geçmişine ve tercihlerine göre kişiselleştirilmiş yemek önerileri al. 'ne yesem', 'öner bana', 'geçen sefer ne yediysem onu', 'her zamankinden' gibi ifadelerde veya genel öneri istendiğinde kullan.",
      parameters: {
        type: "object",
        properties: {},
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "get_order_status",
      description: "Kullanıcının aktif siparişinin durumunu kontrol et. 'siparişim nerede', 'ne zaman gelecek', 'kuryem nerede', 'yolda mı' gibi sorularda kullan.",
      parameters: {
        type: "object",
        properties: {},
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "cancel_order",
      description: "Kullanıcının siparişini iptal et. İlk seferde confirmed=false ile kontrol yap, kullanıcı onaylarsa confirmed=true ile iptal et.",
      parameters: {
        type: "object",
        properties: {
          confirmed: {
            type: "boolean",
            description: "true: siparişi gerçekten iptal et, false: sadece iptal edilebilir mi kontrol et"
          }
        },
        required: ["confirmed"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "save_preference",
      description: "Kullanıcının yemek tercihini kaydet. 'acılı sevmem', 'fıstık alerjim var', 'vejetaryenim' gibi ifadelerde kullan.",
      parameters: {
        type: "object",
        properties: {
          preference_type: {
            type: "string",
            enum: ["allergy", "dislike", "like", "dietary_restriction"],
            description: "allergy: alerji, dislike: sevmediği, like: sevdiği, dietary_restriction: diyet kısıtlaması"
          },
          value: {
            type: "string",
            description: "Tercih değeri (ör: 'fıstık', 'acılı', 'vejeteryan')"
          }
        },
        required: ["preference_type", "value"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "search_rental_cars",
      description: "Kiralık araç ara. Kullanıcı araç kiralamak istediğinde, araç aradığında veya kiralama fiyatlarını sorduğunda bu aracı kullan. Kategori, vites, yakıt tipi, fiyat, marka, şehir ve tarih aralığına göre filtre yapabilir. Örnekler: 'ekonomi sınıfı araç', 'otomatik SUV', 'Girne araç kiralama', '8-15 Şubat arası araç'",
      parameters: {
        type: "object",
        properties: {
          category: {
            type: "string",
            enum: ["economy", "compact", "midsize", "suv", "luxury", "van"],
            description: "Araç kategorisi: economy=Ekonomi, compact=Kompakt, midsize=Orta sınıf, suv=SUV/Jeep, luxury=Lüks, van=Van/Minibüs"
          },
          transmission: {
            type: "string",
            enum: ["automatic", "manual"],
            description: "Vites tipi: automatic=Otomatik, manual=Manuel"
          },
          fuel_type: {
            type: "string",
            enum: ["gasoline", "diesel", "hybrid"],
            description: "Yakıt tipi: gasoline=Benzin, diesel=Dizel, hybrid=Hibrit"
          },
          max_daily_price: {
            type: "number",
            description: "Maksimum günlük fiyat (TL). Kullanıcı 'uygun fiyatlı', 'ucuz' derse düşük fiyat sınırı belirle."
          },
          brand: {
            type: "string",
            description: "Araç markası (ör: Toyota, Hyundai, Volkswagen)"
          },
          city: {
            type: "string",
            description: "Şehir (ör: Lefkoşa, Girne, Mağusa)"
          },
          pickup_date: {
            type: "string",
            description: "Teslim alma tarihi (ISO format, ör: 2026-02-08T10:00:00Z)"
          },
          dropoff_date: {
            type: "string",
            description: "Teslim etme tarihi (ISO format, ör: 2026-02-15T10:00:00Z)"
          }
        },
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "get_rental_booking_status",
      description: "Kullanıcının aktif araç kiralama rezervasyonlarını getir. 'Rezervasyonum var mı', 'araç kiralama durumum', 'kiralama reservasyonum' gibi sorularda kullan.",
      parameters: {
        type: "object",
        properties: {},
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "add_to_cart",
      description: "Kullanıcının sepetine ürün ekle. Kullanıcı bir ürünü beğenip 'ekle', 'sepete at', 'onu istiyorum', 'tamam onu alayım' gibi onay verdiğinde bu aracı kullan. Ürün bilgilerini search_food sonuçlarından al. Kullanıcı onay vermeden ASLA çağırma.",
      parameters: {
        type: "object",
        properties: {
          product_id: {
            type: "string",
            description: "Ürün ID'si (search_food sonucundaki [ID:xxx] değeri)"
          },
          name: {
            type: "string",
            description: "Ürün adı"
          },
          price: {
            type: "number",
            description: "Ürün fiyatı (TL)"
          },
          image_url: {
            type: "string",
            description: "Ürün resim URL'si (varsa)"
          },
          merchant_id: {
            type: "string",
            description: "İşletme ID'si"
          },
          merchant_name: {
            type: "string",
            description: "İşletme adı"
          },
          merchant_type: {
            type: "string",
            enum: ["restaurant", "store", "market"],
            description: "İşletme türü: restaurant (restoran), store (mağaza), market"
          },
          quantity: {
            type: "number",
            description: "Adet (varsayılan 1)"
          }
        },
        required: ["product_id", "name", "price", "merchant_id", "merchant_name", "merchant_type"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "search_car_listings",
      description: "Satılık araç ilanı ara. Kullanıcı araba almak, satılık araç bakmak istediğinde bu aracı kullan. Marka, model, fiyat aralığı, yıl, km, yakıt tipi, vites, kasa tipi, şehir ve durum filtresi yapılabilir. Örnekler: 'ikinci el BMW', '500bin altı araç', 'otomatik SUV', 'İstanbul araç ilanları', 'sıfır Tesla'",
      parameters: {
        type: "object",
        properties: {
          keywords: { type: "string", description: "Aranacak anahtar kelimeler (virgülle ayrılmış). Marka, model, özellik vb. Ör: 'BMW,X5' veya 'elektrikli araç'" },
          brand: { type: "string", description: "Araç markası (ör: Toyota, BMW, Mercedes, Fiat)" },
          min_price: { type: "number", description: "Minimum fiyat (TL)" },
          max_price: { type: "number", description: "Maksimum fiyat (TL)" },
          min_year: { type: "integer", description: "Minimum model yılı (ör: 2020)" },
          max_year: { type: "integer", description: "Maksimum model yılı" },
          max_mileage: { type: "integer", description: "Maksimum kilometre" },
          body_type: { type: "string", enum: ["sedan", "hatchback", "suv", "crossover", "pickup", "minivan", "wagon", "convertible", "sports", "luxury"], description: "Kasa tipi" },
          fuel_type: { type: "string", enum: ["petrol", "diesel", "lpg", "hybrid", "electric", "plugin_hybrid"], description: "Yakıt tipi" },
          transmission: { type: "string", enum: ["automatic", "manual"], description: "Vites tipi" },
          city: { type: "string", description: "Şehir (ör: İstanbul, Ankara)" },
          condition: { type: "string", enum: ["new", "used", "certified"], description: "Araç durumu: new=Sıfır, used=İkinci el, certified=Sertifikalı" }
        },
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "search_jobs",
      description: "İş ilanı ara. Kullanıcı iş arıyorsa, kariyer fırsatları soruyorsa veya belirli bir pozisyon arıyorsa bu aracı kullan. Anahtar kelime, kategori, iş tipi, çalışma şekli, deneyim seviyesi, şehir ve maaş aralığına göre filtre yapılabilir. Örnekler: 'yazılım geliştirici', 'uzaktan çalışma', 'staj', 'İstanbul garson', 'part-time iş'",
      parameters: {
        type: "object",
        properties: {
          keywords: { type: "string", description: "Aranacak anahtar kelimeler (virgülle ayrılmış). Pozisyon, beceri, sektör vb. Ör: 'flutter,developer' veya 'muhasebeci'" },
          job_type: { type: "string", enum: ["full_time", "part_time", "contract", "freelance", "internship", "temporary"], description: "İş tipi: full_time=Tam zamanlı, part_time=Yarı zamanlı, contract=Sözleşmeli, freelance=Freelance, internship=Staj, temporary=Geçici" },
          work_arrangement: { type: "string", enum: ["onsite", "remote", "hybrid"], description: "Çalışma şekli: onsite=Ofiste, remote=Uzaktan, hybrid=Hibrit" },
          experience_level: { type: "string", enum: ["entry", "junior", "mid_level", "senior", "lead", "director", "executive"], description: "Deneyim seviyesi" },
          city: { type: "string", description: "Şehir (ör: İstanbul, Ankara, Lefkoşa)" },
          min_salary: { type: "number", description: "Minimum maaş (TL)" },
          max_salary: { type: "number", description: "Maksimum maaş (TL)" }
        },
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "get_taxi_fare_estimate",
      description: "Taksi araç tiplerini ve tahmini fiyatları göster. 'taksi ne kadar', 'taksi ücreti', 'araç tipleri', 'taksi fiyatları' gibi sorularda kullan.",
      parameters: {
        type: "object",
        properties: {
          vehicle_type: { type: "string", description: "Belirli bir araç tipi (economy, standard, comfort, xl, VIP, KULİS). Boş bırakılırsa tümünü gösterir." }
        },
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "get_taxi_ride_status",
      description: "Kullanıcının aktif taksi yolculuğunun durumunu kontrol et. 'taksim nerede', 'sürücü nerede', 'yolculuğum ne durumda', 'şoför geldi mi' gibi sorularda kullan.",
      parameters: { type: "object", properties: {} }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "cancel_taxi_ride",
      description: "Kullanıcının aktif taksi yolculuğunu iptal et. İlk seferde confirmed=false ile kontrol yap, kullanıcı onaylarsa confirmed=true ile iptal et.",
      parameters: {
        type: "object",
        properties: {
          confirmed: { type: "boolean", description: "true: yolculuğu iptal et, false: iptal edilebilir mi kontrol et" }
        },
        required: ["confirmed"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "request_taxi",
      description: "Kullanıcı için taksi çağır. 'taksi çağır', 'eve taksi', 'taksi istiyorum', 'işe git', 'taksi lazım' gibi isteklerde kullan. Hedef adres kayıtlı adreslerden (ev, iş) çözülür.",
      parameters: {
        type: "object",
        properties: {
          destination: { type: "string", description: "Hedef: kayıtlı adres adı (ev, iş, ofis) veya adres metni" },
          vehicle_type: { type: "string", enum: ["economy", "standard", "comfort", "xl", "VIP", "KULİS"], description: "Araç tipi. Varsayılan: economy. Eşleştirmeler: ucuz/ekonomi→economy, standart→standard, konfor→comfort, büyük→xl, lüks→VIP" }
        },
        required: ["destination"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "get_taxi_ride_history",
      description: "Kullanıcının geçmiş taksi yolculuklarını getir. 'önceki yolculuklarım', 'taksi geçmişim', 'geçen seferki taksi', 'son yolculuğum' gibi sorularda kullan.",
      parameters: { type: "object", properties: {} }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "search_store_products",
      description: "Mağaza ürünlerini ara. Kullanıcı alışveriş yapmak, ürün aramak, fiyat sorgulamak istediğinde bu aracı kullan. Elektronik, giyim, kozmetik, ev eşyası, spor, gıda vb. kategorilerde arama yapabilir. Örnekler: 'iPhone fiyatı', 'erkek gömlek', 'parfüm', 'bulaşık makinesi', 'ucuz kulaklık'",
      parameters: {
        type: "object",
        properties: {
          query: { type: "string", description: "Aranacak ürün adı veya anahtar kelime (ör: iPhone, gömlek, parfüm)" },
          category: { type: "string", description: "Kategori filtresi (ör: Elektronik, Giyim, Kozmetik, Ev & Yaşam, Spor & Outdoor, Telefon & Aksesuar)" },
          min_price: { type: "number", description: "Minimum fiyat (TL)" },
          max_price: { type: "number", description: "Maksimum fiyat (TL). 'Ucuz' derse düşük sınır koy." },
          store_name: { type: "string", description: "Mağaza adı filtresi" }
        }
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "compare_market_prices",
      description: "Market/mağaza fiyat karşılaştırması yap. Kullanıcı birden fazla ürün söyleyip en ucuz marketi bulmak istediğinde bu aracı kullan. 'En ucuz neresi', 'fiyat karşılaştır', 'hangi market daha ucuz', 'alışveriş listesi' gibi ifadelerde kullan. Ürün isimlerini KISA ve YALIN tut.",
      parameters: {
        type: "object",
        properties: {
          products: {
            type: "array",
            items: { type: "string" },
            description: "Karşılaştırılacak ürün isimleri listesi. Kısa ve yalın: ['süt', 'ekmek', 'peynir']"
          }
        },
        required: ["products"]
      }
    }
  },
  {
    type: "function" as const,
    function: {
      name: "connect_live_support",
      description: "Kullanıcıyı canlı destek temsilcisine bağla. ÖNEMLİ: Bu aracı hemen çağırma! Önce kullanıcının sorununu öğren, en az 1 soru sor. Konuyu anladıktan sonra çağır. Tetiklenme: canlı destek, gerçek kişi, müşteri hizmetleri, temsilci, insan ile görüşmek, yardım hattı, şikayet, destek talebi.",
      parameters: {
        type: "object",
        properties: {
          reason: { type: "string", description: "Kullanıcının canlı destek isteme sebebinin DETAYLI özeti. Sohbette öğrenilen tüm bilgileri yaz: sorun ne, hangi hizmetle ilgili, ne denendi." }
        },
        required: ["reason"]
      }
    }
  }
];

// ========== TOOL EXECUTION ==========

interface ToolExecContext {
  supabase: ReturnType<typeof createClient>;
  userId: string;
  addressData: { latitude: number; longitude: number } | null;
  appSource: string;
  sessionId: string;
}

interface SearchResultProduct {
  id: string;
  name: string;
  price: number;
  original_price?: number | null;
  image_url: string;
  merchant_id: string;
  merchant_name: string;
  merchant_type: 'restaurant' | 'store' | 'market';
  description?: string;
  brand?: string;
}

interface RentalResultCar {
  car_id: string;
  brand: string;
  model: string;
  year: number;
  category: string;
  transmission: string;
  fuel_type: string;
  daily_price: number;
  deposit_amount: number;
  image_url: string;
  company_name: string;
  company_id: string;
  company_city: string;
  company_rating: number;
  seats: number;
  has_ac: boolean;
  has_gps: boolean;
  has_bluetooth: boolean;
}

async function executeToolCall(
  toolName: string,
  args: Record<string, unknown>,
  ctx: ToolExecContext,
  actions?: Array<{ type: string; payload: Record<string, unknown> }>,
  searchResultsCollector?: SearchResultProduct[],
  rentalResultsCollector?: RentalResultCar[]
): Promise<string> {
  const { supabase, userId, addressData } = ctx;

  switch (toolName) {
    case 'search_food': {
      const rawKeywords = (args.keywords as string[]) || [];
      if (rawKeywords.length === 0) return 'Arama yapılacak anahtar kelime belirtilmedi.';

      // Expand keywords with Turkish/English aliases for better matching
      const keywordAliases: Record<string, string[]> = {
        'tişört': ['tişört', 't-shirt', 'tshirt'],
        't-shirt': ['t-shirt', 'tişört'],
        'tshirt': ['tshirt', 'tişört', 't-shirt'],
        'şort': ['şort', 'short'],
        'kazak': ['kazak', 'sweater', 'sweatshirt'],
        'ceket': ['ceket', 'jacket', 'mont'],
        'mont': ['mont', 'coat', 'ceket'],
        'ayakkabı': ['ayakkabı', 'sneaker', 'shoe'],
        'çanta': ['çanta', 'bag'],
        'parfüm': ['parfüm', 'perfume', 'edt', 'edp'],
        'telefon': ['telefon', 'phone', 'iphone', 'samsung', 'xiaomi'],
        'cep telefonu': ['telefon', 'phone', 'iphone', 'samsung', 'xiaomi'],
        'akıllı telefon': ['telefon', 'phone', 'iphone', 'samsung', 'xiaomi'],
        'bilgisayar': ['bilgisayar', 'laptop', 'notebook', 'tablet'],
        'dizüstü': ['laptop', 'notebook', 'bilgisayar'],
        'kulaklık': ['kulaklık', 'earphone', 'headphone', 'airpods'],
        'televizyon': ['televizyon', 'tv', 'smart tv'],
        'beyaz eşya': ['beyaz eşya', 'buzdolabı', 'çamaşır makinesi', 'bulaşık makinesi'],
        'buzdolabı': ['buzdolabı', 'beyaz eşya'],
        'çamaşır makinesi': ['çamaşır makinesi', 'beyaz eşya'],
        'temizlik': ['temizlik', 'deterjan', 'çamaşır suyu'],
        'saat': ['saat', 'akıllı saat', 'watch'],
      };

      const keywords = new Set<string>();
      for (const kw of rawKeywords) {
        keywords.add(kw);
        const lower = kw.toLowerCase();
        // Check exact alias match
        if (keywordAliases[lower]) {
          for (const alias of keywordAliases[lower]) keywords.add(alias);
        }
        // Strip common Turkish suffixes to find base form aliases
        // e.g., 'telefonu' → 'telefon', 'bilgisayarı' → 'bilgisayar'
        const turkishSuffixes = ['ları', 'leri', 'lar', 'ler', 'dan', 'den', 'tan', 'ten', 'da', 'de', 'ta', 'te', 'yu', 'yü', 'yı', 'yi', 'u', 'ü', 'ı', 'i'];
        for (const suffix of turkishSuffixes) {
          if (lower.endsWith(suffix) && lower.length > suffix.length + 3) {
            const stem = lower.slice(0, -suffix.length);
            keywords.add(stem);
            if (keywordAliases[stem]) {
              for (const alias of keywordAliases[stem]) keywords.add(alias);
            }
            break; // Only strip one suffix
          }
        }
      }
      const expandedKeywords = [...keywords];

      // Search restaurants AND stores/markets in parallel for each keyword
      const restaurantPromises = expandedKeywords.map(keyword => {
        const rpcParams: Record<string, unknown> = { p_search_query: keyword };
        if (addressData?.latitude && addressData?.longitude) {
          rpcParams.p_customer_lat = addressData.latitude;
          rpcParams.p_customer_lon = addressData.longitude;
        }
        return supabase.rpc('ai_search_restaurants', rpcParams);
      });

      const storePromises = expandedKeywords.map(keyword => {
        const rpcParams: Record<string, unknown> = { p_search_query: keyword, p_merchant_type: 'market' };
        if (addressData?.latitude && addressData?.longitude) {
          rpcParams.p_customer_lat = addressData.latitude;
          rpcParams.p_customer_lon = addressData.longitude;
        }
        return supabase.rpc('ai_search_stores', rpcParams);
      });

      const [restaurantResults, storeResults] = await Promise.all([
        Promise.allSettled(restaurantPromises),
        Promise.allSettled(storePromises),
      ]);

      // Merge restaurant results
      const seenMerchants = new Set<string>();
      const allRestaurants: RestaurantSearchResult['restaurants'] = [];
      for (const result of restaurantResults) {
        if (result.status === 'fulfilled' && !result.value.error && result.value.data) {
          const data = result.value.data as RestaurantSearchResult;
          for (const rest of (data.restaurants || [])) {
            if (!seenMerchants.has(rest.merchant_id)) {
              seenMerchants.add(rest.merchant_id);
              allRestaurants.push(rest);
            }
          }
        }
      }
      allRestaurants.sort((a, b) => (b.rating || 0) - (a.rating || 0));

      // Merge store/market results
      const allStores: StoreSearchResult['stores'] = [];
      for (const result of storeResults) {
        if (result.status === 'fulfilled' && !result.value.error && result.value.data) {
          const data = result.value.data as StoreSearchResult;
          for (const store of (data.stores || [])) {
            if (!seenMerchants.has(store.merchant_id)) {
              seenMerchants.add(store.merchant_id);
              allStores.push(store);
            }
          }
        }
      }

      // Collect structured product data for visual cards
      if (searchResultsCollector) {
        for (const rest of allRestaurants.slice(0, 5)) {
          for (const item of (rest.matching_items || []).slice(0, 4)) {
            searchResultsCollector.push({
              id: item.id || '',
              name: item.name,
              price: item.discounted_price || item.price,
              original_price: item.discounted_price ? item.price : null,
              image_url: item.image_url || '',
              merchant_id: rest.merchant_id,
              merchant_name: rest.business_name,
              merchant_type: 'restaurant',
              description: item.description,
            });
          }
        }
        for (const store of allStores.slice(0, 5)) {
          for (const product of (store.matching_products || []).slice(0, 4)) {
            searchResultsCollector.push({
              id: product.id || '',
              name: product.name,
              price: product.price,
              original_price: product.original_price,
              image_url: product.image_url || '',
              merchant_id: store.merchant_id,
              merchant_name: store.business_name,
              merchant_type: store.merchant_type === 'market' ? 'market' : 'store',
              description: product.description,
              brand: product.brand,
            });
          }
        }
      }

      if (allRestaurants.length === 0 && allStores.length === 0) {
        return `"${expandedKeywords.join(', ')}" araması için sonuç bulunamadı.`;
      }

      // Return minimal summary - visual cards already show full details to user
      const productLines: string[] = [];
      for (const rest of allRestaurants.slice(0, 5)) {
        for (const item of (rest.matching_items || []).slice(0, 4)) {
          productLines.push(`- ${item.name} ${item.discounted_price || item.price} TL | ${rest.business_name} [ID:${item.id}] [MID:${rest.merchant_id}] [restaurant]`);
        }
      }
      for (const store of allStores.slice(0, 5)) {
        for (const product of (store.matching_products || []).slice(0, 4)) {
          productLines.push(`- ${product.name} ${product.price} TL | ${store.business_name} [ID:${product.id}] [MID:${store.merchant_id}] [${store.merchant_type || 'store'}]`);
        }
      }
      return `${productLines.length} ürün bulundu ve kullanıcıya GÖRSEL KART olarak gösterildi.\nÜrün listesi (sepete eklemek için referans):\n${productLines.join('\n')}\n\n⚠️ Bu ürünler zaten görsel kartlarla gösteriliyor. Sen SADECE kısa bir giriş yaz (ör: "İşte bulduklarım:"). Ürünleri tek tek listeleme, fiyat yazma, detay verme.`;
    }

    case 'get_recommendations': {
      // Fetch recommendations + recent order items in parallel
      const [recResult, recentResult, promoResult] = await Promise.allSettled([
        supabase.rpc('ai_get_food_recommendations', { p_user_id: userId }),
        supabase.rpc('ai_get_recent_order_items', { p_user_id: userId }),
        supabase.rpc('ai_get_user_promotions', { p_user_id: userId }),
      ]);

      let info = '';

      if (recResult.status === 'fulfilled' && !recResult.value.error && recResult.value.data) {
        info += formatFoodRecommendationForAI(recResult.value.data as FoodRecommendation);
      }

      if (recentResult.status === 'fulfilled' && !recentResult.value.error && recentResult.value.data) {
        info += formatRecentOrderItems(recentResult.value.data as { recent_orders: Array<{ order_date: string; merchant_name: string; items: Array<{ name: string; quantity: number; price: string }> }>; most_ordered_items: Array<{ name: string; order_count: number }> });
      }

      if (promoResult.status === 'fulfilled' && !promoResult.value.error) {
        const promoData = promoResult.value.data as { has_promotions: boolean; active_promotions: Array<{ business_name: string; discount_badge: string }> };
        if (promoData?.has_promotions) {
          info += `\n\n🎉 AKTİF KAMPANYALAR:`;
          promoData.active_promotions.forEach(p => {
            info += `\n- ${p.business_name}: ${p.discount_badge}`;
          });
        }
      }

      return info || 'Kullanıcının henüz sipariş geçmişi bulunmuyor.';
    }

    case 'get_order_status': {
      const { data, error } = await supabase.rpc('ai_get_order_status', { p_user_id: userId });
      if (error) return 'Sipariş durumu kontrol edilemedi.';
      return formatOrderStatusForAI(data as OrderStatus);
    }

    case 'cancel_order': {
      const confirmed = args.confirmed as boolean;
      if (confirmed) {
        const { data, error } = await supabase.rpc('ai_cancel_order', { p_user_id: userId, p_order_id: null });
        if (error) return 'İptal işlemi başarısız oldu.';
        return formatCancelInfoForAI(data as CancelResult, true);
      } else {
        const { data, error } = await supabase.rpc('ai_check_cancel_eligibility', { p_user_id: userId });
        if (error) return 'İptal durumu kontrol edilemedi.';
        return formatCancelInfoForAI(data as CancelResult, false);
      }
    }

    case 'save_preference': {
      const prefType = args.preference_type as string;
      const value = args.value as string;

      // Get existing preferences
      const { data: existing } = await supabase
        .from('user_food_preferences')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();

      const updates: Record<string, unknown> = { user_id: userId, updated_at: new Date().toISOString() };

      if (prefType === 'allergy') {
        const current = existing?.allergies || [];
        if (!current.includes(value)) current.push(value);
        updates.allergies = current;
      } else if (prefType === 'dislike') {
        const current = existing?.disliked_ingredients || [];
        if (!current.includes(value)) current.push(value);
        updates.disliked_ingredients = current;
      } else if (prefType === 'like') {
        const current = existing?.favorite_cuisines || [];
        if (!current.includes(value)) current.push(value);
        updates.favorite_cuisines = current;
      } else if (prefType === 'dietary_restriction') {
        const current = existing?.dietary_restrictions || [];
        if (!current.includes(value)) current.push(value);
        updates.dietary_restrictions = current;
      }

      if (existing) {
        await supabase.from('user_food_preferences').update(updates).eq('user_id', userId);
      } else {
        updates.created_at = new Date().toISOString();
        await supabase.from('user_food_preferences').insert(updates);
      }

      return `✅ "${value}" tercihi (${prefType}) kaydedildi.`;
    }

    case 'search_rental_cars': {
      const rpcParams: Record<string, unknown> = {};
      if (args.category) rpcParams.p_category = args.category;
      if (args.transmission) rpcParams.p_transmission = args.transmission;
      if (args.fuel_type) rpcParams.p_fuel_type = args.fuel_type;
      if (args.max_daily_price) rpcParams.p_max_daily_price = args.max_daily_price;
      if (args.brand) rpcParams.p_brand = args.brand;
      if (args.city) rpcParams.p_city = args.city;
      if (args.pickup_date) rpcParams.p_pickup_date = args.pickup_date;
      if (args.dropoff_date) rpcParams.p_dropoff_date = args.dropoff_date;

      const { data, error } = await supabase.rpc('ai_search_rental_cars', rpcParams);
      if (error) return 'Araç arama başarısız oldu: ' + error.message;
      const result = data as RentalCarSearchResult;

      // Collect for visual cards
      if (rentalResultsCollector && result.cars) {
        for (const car of result.cars.slice(0, 8)) {
          rentalResultsCollector.push({
            car_id: car.car_id,
            brand: car.brand,
            model: car.model,
            year: car.year,
            category: car.category,
            transmission: car.transmission,
            fuel_type: car.fuel_type,
            daily_price: car.daily_price,
            deposit_amount: car.deposit_amount,
            image_url: car.image_url,
            company_name: car.company_name,
            company_id: car.company_id,
            company_city: car.company_city,
            company_rating: car.company_rating,
            seats: car.seats,
            has_ac: car.has_ac,
            has_gps: car.has_gps,
            has_bluetooth: car.has_bluetooth,
            ...(args.pickup_date && { pickup_date: args.pickup_date }),
            ...(args.dropoff_date && { dropoff_date: args.dropoff_date }),
          });
        }
      }

      if (!result.cars || result.cars.length === 0) {
        return 'Belirtilen kriterlere uygun kiralık araç bulunamadı.';
      }
      // Return minimal summary - visual cards already show full details
      const carLines = result.cars.slice(0, 8).map((c: { brand: string; model: string; year: number; daily_price: number; company_name: string; car_id: string }) =>
        `- ${c.brand} ${c.model} (${c.year}) ${c.daily_price} TL/gün | ${c.company_name} [ID:${c.car_id}]`
      );
      return `${carLines.length} araç bulundu ve kullanıcıya GÖRSEL KART olarak gösterildi.\nAraç listesi:\n${carLines.join('\n')}\n\n⚠️ Bu araçlar zaten görsel kartlarla gösteriliyor. Sen SADECE kısa bir giriş yaz. Araçları tek tek listeleme.`;
    }

    case 'get_rental_booking_status': {
      const { data, error } = await supabase.rpc('ai_get_rental_booking_status', { p_user_id: userId });
      if (error) return 'Rezervasyon durumu kontrol edilemedi.';
      return formatRentalBookingForAI(data as RentalBookingStatus);
    }

    case 'search_car_listings': {
      const rpcParams: Record<string, unknown> = {};
      if (args.keywords) rpcParams.p_keywords = args.keywords;
      if (args.brand) rpcParams.p_brand = args.brand;
      if (args.min_price) rpcParams.p_min_price = args.min_price;
      if (args.max_price) rpcParams.p_max_price = args.max_price;
      if (args.min_year) rpcParams.p_min_year = args.min_year;
      if (args.max_year) rpcParams.p_max_year = args.max_year;
      if (args.max_mileage) rpcParams.p_max_mileage = args.max_mileage;
      if (args.body_type) rpcParams.p_body_type = args.body_type;
      if (args.fuel_type) rpcParams.p_fuel_type = args.fuel_type;
      if (args.transmission) rpcParams.p_transmission = args.transmission;
      if (args.city) rpcParams.p_city = args.city;
      if (args.condition) rpcParams.p_condition = args.condition;

      const { data, error } = await supabase.rpc('ai_search_car_listings', rpcParams);
      if (error) return 'Araç ilanı arama başarısız oldu: ' + error.message;
      return formatCarListingSearchForAI(data as CarListingSearchResult);
    }

    case 'search_jobs': {
      const rpcParams: Record<string, unknown> = {};
      if (args.keywords) rpcParams.p_keywords = args.keywords;
      if (args.job_type) rpcParams.p_job_type = args.job_type;
      if (args.work_arrangement) rpcParams.p_work_arrangement = args.work_arrangement;
      if (args.experience_level) rpcParams.p_experience_level = args.experience_level;
      if (args.city) rpcParams.p_city = args.city;
      if (args.min_salary) rpcParams.p_min_salary = args.min_salary;
      if (args.max_salary) rpcParams.p_max_salary = args.max_salary;

      const { data, error } = await supabase.rpc('ai_search_job_listings', rpcParams);
      if (error) return 'İş ilanı arama başarısız oldu: ' + error.message;
      return formatJobListingSearchForAI(data as JobListingSearchResult);
    }

    case 'add_to_cart': {
      const productId = args.product_id as string;
      const name = args.name as string;
      const price = args.price as number;
      const imageUrl = (args.image_url as string) || '';
      const merchantId = args.merchant_id as string;
      const merchantName = args.merchant_name as string;
      const merchantType = (args.merchant_type as string) || 'restaurant';
      const quantity = (args.quantity as number) || 1;

      if (!productId || !name || !price || !merchantId) {
        return 'Ürün bilgileri eksik, sepete eklenemedi.';
      }

      if (actions) {
        actions.push({
          type: 'add_to_cart',
          payload: {
            product_id: productId,
            name,
            price,
            image_url: imageUrl,
            merchant_id: merchantId,
            merchant_name: merchantName,
            merchant_type: merchantType,
            quantity,
          }
        });
      }

      return `✅ ${name} (${quantity} adet, ${price} TL) sepete eklendi.`;
    }

    case 'get_taxi_fare_estimate': {
      const vType = (args.vehicle_type as string) || null;
      const { data, error } = await supabase.rpc('ai_get_taxi_fare_estimate', { p_user_id: userId, p_vehicle_type: vType });
      if (error) return 'Taksi fiyat bilgisi alınamadı.';
      return formatTaxiFareEstimateForAI(data as any);
    }

    case 'get_taxi_ride_status': {
      const { data, error } = await supabase.rpc('ai_get_taxi_ride_status', { p_user_id: userId });
      if (error) return 'Yolculuk durumu kontrol edilemedi.';
      return formatTaxiRideStatusForAI(data as any);
    }

    case 'cancel_taxi_ride': {
      const confirmed = args.confirmed as boolean;
      if (confirmed) {
        const { data, error } = await supabase.rpc('ai_cancel_taxi_ride', { p_user_id: userId });
        if (error) return 'Yolculuk iptal edilemedi.';
        return formatTaxiCancelForAI(data as any, true);
      } else {
        const { data, error } = await supabase.rpc('ai_check_taxi_cancel_eligibility', { p_user_id: userId });
        if (error) return 'İptal durumu kontrol edilemedi.';
        return formatTaxiCancelForAI(data as any, false);
      }
    }

    case 'request_taxi': {
      const destination = args.destination as string;
      const vehicleType = (args.vehicle_type as string) || 'economy';
      if (!destination) return 'Nereye gitmek istediğinizi belirtmelisiniz.';

      const { data, error } = await supabase.rpc('ai_request_taxi_ride', {
        p_user_id: userId,
        p_destination_text: destination,
        p_vehicle_type: vehicleType,
      });
      if (error) return 'Taksi çağırma başarısız oldu: ' + error.message;

      const result = data as { success: boolean; needs_manual?: boolean; message: string; ride_id?: string; ride_number?: string; pickup_address?: string; dropoff_address?: string; fare?: number; distance_km?: number; vehicle_type?: string };

      if (result.success && result.ride_id && actions) {
        actions.push({
          type: 'taxi_ride_created',
          payload: { ride_id: result.ride_id, ride_number: result.ride_number }
        });
      } else if (result.needs_manual && actions) {
        actions.push({ type: 'navigate', payload: { route: '/taxi' } });
      }

      return result.message;
    }

    case 'get_taxi_ride_history': {
      const { data, error } = await supabase.rpc('ai_get_taxi_ride_history', { p_user_id: userId });
      if (error) return 'Yolculuk geçmişi alınamadı.';
      return formatTaxiRideHistoryForAI(data as any);
    }

    case 'search_store_products': {
      const rpcParams: Record<string, unknown> = {};
      if (args.query) rpcParams.p_query = args.query;
      if (args.category) rpcParams.p_category = args.category;
      if (args.min_price) rpcParams.p_min_price = args.min_price;
      if (args.max_price) rpcParams.p_max_price = args.max_price;
      if (args.store_name) rpcParams.p_store_name = args.store_name;
      rpcParams.p_limit = 8;

      const { data, error } = await supabase.rpc('ai_search_store_products', rpcParams);
      if (error) return 'Ürün arama başarısız: ' + error.message;
      const result = data as { total: number; products: Array<{ product_id: string; name: string; price: number; original_price?: number; image_url: string; category: string; store_id: string; store_name: string; store_logo: string; description: string; rating: number; review_count: number; free_shipping: boolean; fast_delivery: boolean; promotion_label?: string }> };

      // Collect for visual cards (reuse searchResultsCollector)
      if (searchResultsCollector && result.products) {
        for (const p of result.products.slice(0, 8)) {
          searchResultsCollector.push({
            id: p.product_id,
            name: p.name,
            price: p.price,
            original_price: p.original_price,
            image_url: p.image_url || '',
            merchant_id: p.store_id,
            merchant_name: p.store_name,
            merchant_type: 'store',
            description: p.description,
          });
        }
      }

      if (!result.products || result.products.length === 0) return 'Aradığınız kriterlere uygun ürün bulunamadı.';
      const lines = result.products.map((p, i) => {
        let line = `${i + 1}. ${p.name} - ${p.price} TL`;
        if (p.original_price && p.original_price > p.price) line += ` (eski: ${p.original_price} TL)`;
        line += ` | ${p.store_name} | ${p.category}`;
        if (p.free_shipping) line += ' | Ücretsiz kargo';
        if (p.promotion_label) line += ` | ${p.promotion_label}`;
        return line;
      });
      return `${result.total} ürün bulundu:\n${lines.join('\n')}`;
    }

    case 'compare_market_prices': {
      const products = (args.products as string[]) || [];
      if (products.length === 0) return 'Karşılaştırılacak ürün belirtilmedi.';
      if (products.length > 10) return 'En fazla 10 ürün karşılaştırılabilir. Lütfen listeyi kısaltın.';

      const { data: cmpData, error: cmpError } = await supabase.rpc('ai_compare_market_prices', {
        p_product_names: products
      });

      if (cmpError) return 'Fiyat karşılaştırması yapılamadı: ' + cmpError.message;

      const cmpResult = cmpData as {
        success: boolean;
        requested_products: string[];
        total_products_requested: number;
        store_count: number;
        stores: Array<{
          merchant_id: string; business_name: string; merchant_type: string;
          is_open: boolean; rating: number; delivery_fee: number; delivery_time: string;
          min_order_amount: number; discount_badge: string | null;
          matched_count: number; total_requested: number; has_all_products: boolean;
          total_price: number; total_with_delivery: number;
          matched_products: Array<{ search_term: string; product_id: string; product_name: string; price: number; original_price: number | null; image_url: string; brand: string; stock: number }>;
          missing_products: string[];
        }>;
      };

      if (!cmpResult.stores || cmpResult.stores.length === 0) {
        return `Aranan ürünler (${products.join(', ')}) hiçbir markette bulunamadı.`;
      }

      // Collect visual cards
      if (searchResultsCollector) {
        for (const store of cmpResult.stores.slice(0, 5)) {
          for (const product of store.matched_products) {
            searchResultsCollector.push({
              id: product.product_id,
              name: product.product_name,
              price: product.price,
              original_price: product.original_price,
              image_url: product.image_url || '',
              merchant_id: store.merchant_id,
              merchant_name: store.business_name,
              merchant_type: store.merchant_type === 'market' ? 'market' : 'store',
              brand: product.brand,
            });
          }
        }
      }

      // Push comparison action for Flutter UI
      if (actions) {
        actions.push({
          type: 'price_comparison',
          payload: {
            requested_products: cmpResult.requested_products,
            stores: cmpResult.stores.slice(0, 5).map(store => ({
              merchant_id: store.merchant_id,
              business_name: store.business_name,
              merchant_type: store.merchant_type,
              is_open: store.is_open,
              rating: store.rating,
              delivery_fee: store.delivery_fee,
              delivery_time: store.delivery_time,
              has_all_products: store.has_all_products,
              matched_count: store.matched_count,
              total_requested: store.total_requested,
              total_price: store.total_price,
              total_with_delivery: store.total_with_delivery,
              discount_badge: store.discount_badge,
              matched_products: store.matched_products,
              missing_products: store.missing_products,
            })),
          }
        });
      }

      // Format text summary for AI
      let summary = `FİYAT KARŞILAŞTIRMASI: ${products.join(', ')}\n`;
      summary += `${cmpResult.store_count} market/mağazada arandı.\n\n`;

      for (const store of cmpResult.stores.slice(0, 5)) {
        const statusIcon = store.is_open ? 'AÇIK' : 'KAPALI';
        const allFlag = store.has_all_products ? 'Tüm ürünler var' : `${store.matched_count}/${store.total_requested} ürün`;
        summary += `${store.business_name} (${statusIcon}) | ${allFlag}\n`;
        for (const p of store.matched_products) {
          summary += `  - ${p.product_name}: ${p.price} TL [ID:${p.product_id}]\n`;
        }
        if (store.missing_products.length > 0) {
          summary += `  Eksik: ${store.missing_products.join(', ')}\n`;
        }
        summary += `  Toplam: ${store.total_price} TL`;
        if (store.delivery_fee > 0) summary += ` + ${store.delivery_fee} TL teslimat = ${store.total_with_delivery} TL`;
        summary += `\n  [MID:${store.merchant_id}] [${store.merchant_type}]\n\n`;
      }

      summary += `Karşılaştırma sonuçları kullanıcıya GÖRSEL olarak gösterildi. Kısa özet yaz ve en ucuz marketi öner. Kullanıcı onaylarsa seçilen marketin TÜM ürünlerini sepete ekle (her biri için ayrı add_to_cart çağır).`;

      return summary;
    }

    case 'connect_live_support': {
      const reason = (args.reason as string) || 'Canlı destek talebi';
      const { supabase: sb, userId: uid, appSource: src, sessionId: sid } = ctx;

      // Get ONLY recent conversation (last 3 minutes) for context - ignore old sessions
      let conversationContext = reason;
      try {
        const threeMinAgo = new Date(Date.now() - 3 * 60 * 1000).toISOString();
        const { data: recentMsgs } = await sb
          .from('support_chat_messages')
          .select('role, content')
          .eq('session_id', sid)
          .gte('created_at', threeMinAgo)
          .order('created_at', { ascending: false })
          .limit(5);
        if (recentMsgs && recentMsgs.length > 0) {
          conversationContext = recentMsgs
            .reverse()
            .filter((m: { content?: string }) => !m.content?.startsWith('[') && !m.content?.includes('Destek talebi #'))
            .map((m: { role: string; content?: string }) => `${m.role === 'user' ? 'Müşteri' : 'AI'}: ${(m.content || '').substring(0, 200)}`)
            .join('\n');
          if (!conversationContext.trim()) conversationContext = reason;
        }
      } catch (_) { /* ignore */ }

      const serviceTypeMap: Record<string, string> = {
        'super_app': 'general', 'customer_app': 'general',
        'merchant_panel': 'food', 'rent_a_car_panel': 'rental',
        'courier_app': 'food', 'emlakci_panel': 'emlak',
        'arac_satis_panel': 'car_sales',
      };

      const { data: ticketResult, error: ticketError } = await sb.rpc('create_live_support_ticket', {
        p_user_id: uid,
        p_app_source: src,
        p_subject: `Canlı Destek: ${reason.substring(0, 100)}`,
        p_description: conversationContext,
        p_service_type: serviceTypeMap[src] || 'general',
        p_metadata: { ai_session_id: sid },
      });

      if (ticketError || !ticketResult?.success) {
        return 'Canlı destek bağlantısı kurulamadı. Lütfen tekrar deneyin.';
      }

      if (actions) {
        actions.push({
          type: 'connect_live_support',
          payload: {
            ticket_id: ticketResult.ticket_id,
            ticket_number: ticketResult.ticket_number,
            is_existing: ticketResult.is_existing || false,
          }
        });
      }

      return ticketResult.is_existing
        ? `Mevcut destek talebiniz (#${ticketResult.ticket_number}) bulundu. Temsilciye bağlanıyorsunuz...`
        : `Destek talebi #${ticketResult.ticket_number} oluşturuldu. Bir temsilci en kısa sürede size dönecek.`;
    }

    default:
      return 'Bilinmeyen araç.';
  }
}

// ========== MAIN HANDLER ==========

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
    if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY is not configured');

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // ===== AUTH =====
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ success: false, error: 'Oturum bulunamadı. Lütfen tekrar giriş yapın.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 });
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
    if (authError || !user) {
      return new Response(JSON.stringify({ success: false, error: 'Oturum süresi dolmuş. Lütfen tekrar giriş yapın.' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 });
    }

    const body: ChatRequest = await req.json();
    const { message, session_id, app_source, user_type = 'customer', screen_context, generate_audio = false, stream = false } = body;

    if (!message || !app_source) throw new Error('Message and app_source are required');

    // ===== SESSION =====
    let currentSessionId = session_id;
    if (!currentSessionId) {
      const { data: newSession, error: sessionError } = await supabase
        .from('support_chat_sessions')
        .insert({ user_id: user.id, app_source, user_type, status: 'active' })
        .select('id').single();
      if (sessionError) throw sessionError;
      currentSessionId = newSession.id;
    }

    // Save user message (fire and forget)
    supabase.from('support_chat_messages').insert({
      session_id: currentSessionId, role: 'user', content: message
    }).then(() => {});

    const isCustomerApp = app_source === 'super_app' || app_source === 'customer_app';
    const isMerchant = app_source === 'merchant_panel';

    // ===== PARALLEL DATA FETCH (always needed) =====
    const parallelQueries: Record<string, Promise<unknown>> = {
      systemPrompt: supabase.from('ai_system_prompts')
        .select('system_prompt, restrictions')
        .eq('app_source', app_source).eq('is_active', true).single(),

      knowledgeBase: supabase.from('ai_knowledge_base')
        .select('question, answer, category')
        .or(`app_source.eq.${app_source},app_source.eq.all`)
        .eq('is_active', true).order('priority', { ascending: false }).limit(15),

      history: supabase.from('support_chat_messages')
        .select('role, content')
        .eq('session_id', currentSessionId)
        .order('created_at', { ascending: false }).limit(30),
    };

    // Customer: always fetch user address & preferences
    if (isCustomerApp) {
      parallelQueries.userAddress = supabase.from('user_addresses')
        .select('latitude, longitude')
        .eq('user_id', user.id).eq('is_default', true).limit(1).maybeSingle();

      parallelQueries.userPrefs = supabase.from('user_food_preferences')
        .select('*').eq('user_id', user.id).limit(1).maybeSingle();
    }

    // Screen context: merchant products when on detail page
    if (screen_context && app_source === 'super_app' && screen_context.entity_id && screen_context.screen_type?.endsWith('_detail')) {
      parallelQueries.merchantProducts = supabase.rpc('ai_search_merchant_products', {
        p_merchant_id: screen_context.entity_id,
        p_search_query: message.length > 2 ? message : null,
        p_merchant_type: screen_context.entity_type || 'restaurant',
      });
    }

    // Merchant panel: fetch merchant data
    if (isMerchant) {
      parallelQueries.merchantData = supabase.from('merchants')
        .select('id, business_name, type, is_active, created_at')
        .eq('user_id', user.id).single();
    }

    // Execute all
    const keys = Object.keys(parallelQueries);
    const results = await Promise.allSettled(Object.values(parallelQueries));
    const qr: Record<string, { data?: unknown; error?: unknown }> = {};
    keys.forEach((key, i) => {
      const r = results[i];
      qr[key] = r.status === 'fulfilled' ? r.value as { data?: unknown; error?: unknown } : { data: null, error: r.reason };
    });

    // ===== PROCESS BASE DATA =====
    const promptData = qr.systemPrompt?.data as { system_prompt: string; restrictions: string } | null;
    const allKnowledge = (qr.knowledgeBase?.data || []) as Array<{ question: string; answer: string; category: string }>;
    // History comes descending (newest first), reverse to ascending order
    const rawHistory = ((qr.history?.data || []) as Array<{ role: string; content: string }>).reverse();
    // Separate internal context from conversation messages
    // Truncate history after last live support ticket creation to start fresh
    let lastSearchContext = '';
    let lastCartContext = '';
    const allConversation: Array<{ role: string; content: string }> = [];
    for (const msg of rawHistory) {
      if (msg.role !== 'user' && msg.role !== 'assistant') continue;
      if (msg.content?.startsWith('[ARAMA_SONUÇLARI]') || msg.content?.startsWith('[ARAMA_SONUCLARI]')) {
        lastSearchContext = msg.content;
        continue;
      }
      if (msg.content?.startsWith('[SEPETE_EKLENDİ]') || msg.content?.startsWith('[SEPETE_EKLENDI]')) {
        lastCartContext = msg.content;
        continue;
      }
      allConversation.push(msg);
    }
    // Find last "ticket created" message and only keep messages after it
    let lastTicketIdx = -1;
    for (let i = allConversation.length - 1; i >= 0; i--) {
      const c = allConversation[i].content || '';
      if (c.includes('Destek talebi #') || c.includes('Mevcut destek talebiniz')) {
        lastTicketIdx = i;
        break;
      }
    }
    const conversationHistory = lastTicketIdx >= 0
      ? allConversation.slice(lastTicketIdx + 1)
      : allConversation;
    const addressData = (qr.userAddress?.data || null) as { latitude: number; longitude: number } | null;
    const userPrefs = qr.userPrefs?.data as Record<string, unknown> | null;

    // Filter knowledge base
    const lowerMessage = message.toLowerCase();
    const messageWords = lowerMessage.split(/\s+/).filter(w => w.length > 2);
    const relevantKnowledge = allKnowledge.filter(kb => {
      const kbText = `${kb.question} ${kb.category}`.toLowerCase();
      return messageWords.some(word => kbText.includes(word));
    }).slice(0, 3);

    // ===== BUILD SYSTEM PROMPT =====
    const systemPrompt = promptData?.system_prompt || 'Sen SuperCyp AI asistanısın.';
    const restrictions = promptData?.restrictions || '';

    let systemContent = `${systemPrompt}\n\nKISITLAMALAR:\n${restrictions}`;

    systemContent += `\n\nKRİTİK KURALLAR:
1. ⛔ ASLA veritabanında olmayan ürün UYDURMAYACAKSIN. SADECE search_food sonuçlarındaki ürünleri listele. Sonuçlarda olmayan bir ürünü ASLA ekleme, tahmin etme veya hayal etme.
2. Yemek/ürün/mağaza bilgisi vermeden ÖNCE mutlaka search_food aracını çağır.
3. Araç sonuçlarında dönen ürünleri birebir kullan. Ürün adı, fiyat, mağaza adı, ürün ID - hepsi sonuçlardan gelsin.
4. Arama sonucu boşsa veya istenen ürün yoksa dürüstçe söyle. "Malesef tişört bulunamadı" de, uydurmak yerine.
5. Kullanıcı kavramsal konuşabilir ("etli birşeyler", "tişört bakıyorum"). search_food aracına ilgili ürün türlerini anahtar kelime olarak ver.
6. Türkçe ve samimi konuş, kısa ve öz yanıtlar ver.
7. ⛔ SEPETE EKLEME KURALI: Kullanıcı "sepete at", "onu ekle", "istiyorum" dediğinde add_to_cart çağır. ANCAK: product_id, merchant_id, fiyat gibi bilgileri MUTLAKA önceki search_food sonuçlarından veya [ARAMA_SONUÇLARI] context'inden al. Bu bilgiler yoksa kullanıcıya "Hangi ürünü sepete ekleyeyim?" diye sor, ASLA bilgileri uydurup ekleme.
8. ⛔ YANITLARDA ASLA ham ID, UUID, [ARAMA_SONUÇLARI], [SEPETE_EKLENDİ], [ID:...], [MID:...] gibi teknik etiketler veya veritabanı ID'leri GÖSTERME. Bunlar sadece dahili araç kullanımı içindir. Kullanıcıya sadece ürün adı, fiyat ve mağaza adı göster.
9. Birden fazla ürün istenirse her biri için ayrı add_to_cart çağrısı yap.
10. merchant_type'ı doğru belirle: restoran ürünü ise "restaurant", mağaza ürünü ise "store", market ürünü ise "market".
11. ⚡ ARAMA SONUÇLARI GÖSTERME: Arama sonuçları kullanıcıya GÖRSEL KART olarak otomatik gösterilecek. Sen sadece KISA bir giriş yaz (ör: "3 tişört buldum:", "İşte pizza seçenekleri:"). Ürünleri tek tek listeleme, fiyat yazma, detay verme. Kartlar zaten resim, isim, fiyat ve sepete ekle butonu ile gösteriliyor. Sadece kısa giriş + varsa genel öneri yaz.
12. ⛔ ONAY KONTEKST KURALI: Kullanıcı "Onaylıyorum", "Evet", "Tamam", "Ekle", "Olsun" gibi bir ONAY verdiğinde, MUTLAKA sohbetteki EN SON önerdiğin/bahsettiğin ürünü sepete ekle. Onaydan hemen önce hangi ürünü teklif ettin ise (isim, fiyat, ID) O ürünü add_to_cart'a gönder. ASLA başka bir ürünü gönderme. Emin değilsen kullanıcıya "Hangi ürünü ekleyeyim?" diye sor. ÖNEMLİ: Onay geldiğinde tekrar search_food ÇAĞIRMA - [ÖNCEKİ ARAMA SONUÇLARI]'ndaki ürün bilgilerini kullanarak doğrudan add_to_cart çağır.
13. ⛔ ÜRÜN EŞLEŞME KURALI: add_to_cart çağırırken product_id, name, price, merchant_id bilgilerinin TUTARLI olduğundan emin ol. Ayran için onay verdiyse ayranın ID'sini gönder, Somon Izgara'nın değil. Sohbet geçmişindeki son assistant mesajında hangi ürünü önerdiysen SADECE onu ekle.
14. ⛔ ASLA kullanıcı yerine seçim YAPMA. "Ben X'i seçiyorum", "X'i ekliyorum" gibi kendi kararını verme. Seçenekleri sun ve kullanıcının seçmesini bekle. Sadece kullanıcı açıkça bir ürün adı söylediğinde veya onay verdiğinde add_to_cart çağır.
15. ⛔ BİLGİ TEKRARLAMA: Daha önce söylediğin bilgileri (sepete eklenen ürünler, fiyatlar) tekrar etme. Kısa ve yeni bilgi odaklı yanıtlar ver.
16. 🚗 ARAÇ KİRALAMA: Kullanıcı araç kiralamak istediğinde search_rental_cars aracını kullan. Kategori eşleştirmeleri: ekonomi/ucuz→economy, kompakt→compact, orta/sedan→midsize, jeep/arazi→suv, lüks/premium→luxury, minibüs→van. ⚠️ ZORUNLU: Kullanıcı tarih belirtmişse pickup_date ve dropoff_date parametrelerini KESİNLİKLE ISO formatında gönder (ör: "5-15 şubat"→pickup_date:"2026-02-05T10:00:00Z",dropoff_date:"2026-02-15T10:00:00Z"). Tarih göndermezsen rezervasyon ekranında yanlış toplam fiyat gösterilir! "Uygun fiyatlı" derse max_daily_price=900 gibi makul bir sınır koy.
17. ⚡ ARAÇ KİRALAMA SONUÇLARI GÖSTERME: Araç kiralama sonuçları kullanıcıya GÖRSEL KART olarak otomatik gösterilecek. Sen sadece KISA bir giriş yaz (ör: "3 araç buldum:", "İşte uygun araçlar:"). Araçları tek tek listeleme, fiyat yazma, detay verme. Kartlar zaten marka, model, fiyat ve kirala butonu ile gösteriliyor. Sadece kısa giriş + varsa genel öneri yaz.
18. 📋 KİRALAMA REZERVASYONU: Kullanıcı "rezervasyonum var mı", "kiralama durumum" derse get_rental_booking_status aracını kullan.
19. 🚘 SATILIK ARAÇ: Kullanıcı araba almak, satılık araç aramak veya araç ilanlarına bakmak istediğinde search_car_listings aracını kullan. Marka eşleştirmeleri: "beemer/bimer"→BMW, "mersedes"→Mercedes. Kasa tipi eşleştirmeleri: jeep/arazi→suv, station→wagon, cabrio→convertible. "Uygun fiyatlı" derse max_price=500000, "ucuz araba" derse max_price=300000 gibi makul sınırlar koy. Sonuçları kısa özetle sun.
20. 💼 İŞ İLANLARI: Kullanıcı iş arıyorsa, kariyer fırsatları soruyorsa veya belirli bir pozisyon arıyorsa search_jobs aracını kullan. İş tipi eşleştirmeleri: "tam zamanlı/full-time"→full_time, "yarı zamanlı/part-time"→part_time, "staj/intern"→internship, "freelance/serbest"→freelance. Çalışma şekli: "uzaktan/remote"→remote, "ofiste"→onsite, "hibrit/karma"→hybrid. Sonuçları kısa özetle sun, detaylı bilgi için kullanıcıyı yönlendir.
21. 🚕 TAKSİ ÇAĞIRMA: Kullanıcı taksi çağırmak istediğinde request_taxi aracını kullan. Nereye gideceğini sor. Kayıtlı adresler (ev, iş) varsa doğrudan kullanılır. Araç tipi eşleştirmeleri: ucuz/ekonomi→economy, standart/normal→standard, konfor/rahat→comfort, büyük/geniş→xl, lüks/premium→VIP. Belirtilmezse economy kullan.
22. 🚕 TAKSİ FİYAT: "Taksi ne kadar", "ücret tahmini" sorularında get_taxi_fare_estimate ile araç tiplerini ve fiyatları göster.
23. 🚕 TAKSİ DURUM: "Taksim nerede", "sürücü nerede", "yolculuğum" sorularında get_taxi_ride_status kullan.
24. 🚕 TAKSİ İPTAL: İptal isteğinde cancel_taxi_ride(confirmed=false) ile kontrol, kullanıcı onaylarsa confirmed=true ile iptal et. (Sipariş iptali ile aynı 2 adımlı pattern)
25. 🚕 TAKSİ GEÇMİŞ: "Önceki yolculuklarım", "taksi geçmişim" sorularında get_taxi_ride_history kullan.
26. 🛍️ MAĞAZA ÜRÜN ARAMA: Kullanıcı alışveriş yapmak, ürün aramak veya fiyat sorgulamak istediğinde search_store_products aracını kullan. Kategoriler: Elektronik, Giyim, Kozmetik, Ev & Yaşam, Spor & Outdoor, Telefon & Aksesuar, Ayakkabı & Çanta, vb. "Ucuz" derse max_price ile düşük sınır koy. Sonuçlar kullanıcıya GÖRSEL KART olarak otomatik gösterilecek. Sen sadece kısa giriş yaz, ürünleri tek tek listeleme.
28. 🛒 FİYAT KARŞILAŞTIRMASI: Kullanıcı birden fazla ürün söyleyip "en ucuz market", "karşılaştır", "nerede ucuz", "alışveriş listesi", "hangi market", "toplam fiyat" gibi ifadeler kullandığında compare_market_prices aracını çağır. Ürün isimlerini kısa ve yalın diziye dönüştür (ör: "süt ekmek yumurta peynir al" → ["süt","ekmek","yumurta","peynir"]). Sonuçları kısa özetle: en ucuz marketi belirt, toplam fiyatı söyle. Kullanıcı onaylarsa ("tamam oradan al", "ekle hepsini", "o marketten istiyorum") seçilen marketin TÜM ürünleri için ayrı ayrı add_to_cart çağır. ⚠️ Kullanıcı onay vermeden HİÇBİR ürünü sepete ekleme.
27. 🛑 CANLI DESTEK KURALI: Kullanıcı canlı destek/temsilci istediğinde connect_live_support aracını HEMEN ÇAĞIRMA! Önce: a) Sorunun ne olduğunu sor b) Hangi hizmetle ilgili olduğunu anla c) Kısaca yardımcı olmayı dene d) Çözemiyorsan veya kullanıcı ısrar ediyorsa ANCAK O ZAMAN connect_live_support çağır, reason parametresine tüm öğrendiğin bilgileri detaylı yaz.`;

    // User preferences & allergies
    if (userPrefs) {
      const allergies = (userPrefs.allergies as string[] || []).filter(a => a?.trim());
      const dislikes = (userPrefs.disliked_ingredients as string[] || []).filter(a => a?.trim());
      const diets = (userPrefs.dietary_restrictions as string[] || []).filter(a => a?.trim());

      if (allergies.length > 0) {
        systemContent += `\n\n⚠️ KULLANICI ALERJİLERİ: ${allergies.join(', ')}
- Yemek önerirken bu alerjenlere DİKKAT ET
- İçerik bilgisi olmayan ürünlerde "içerebilir" şeklinde uyar`;
      }
      if (dislikes.length > 0) systemContent += `\n❌ SEVMEDİĞİ: ${dislikes.join(', ')}`;
      if (diets.length > 0) systemContent += `\n🥗 DİYET: ${diets.join(', ')}`;
    }

    // Knowledge base
    if (relevantKnowledge.length > 0) {
      systemContent += '\n\nİLGİLİ BİLGİLER:\n';
      relevantKnowledge.forEach((kb, i) => {
        systemContent += `${i + 1}. S: ${kb.question}\n   C: ${kb.answer}\n`;
      });
    }

    // Screen context
    if (screen_context && app_source === 'super_app') {
      const { screen_type, entity_id, entity_name, entity_type } = screen_context;
      const screenNames: Record<string, string> = {
        'home': 'Ana Sayfa', 'food_home': 'Yemek Siparişi', 'restaurant_detail': `${entity_name || 'Restoran'} Detay`,
        'store_detail': `${entity_name || 'Mağaza'} Detay`, 'market_detail': `${entity_name || 'Market'} Detay`,
        'store_cart': 'Mağaza Sepeti', 'food_cart': 'Yemek Sepeti', 'grocery_home': 'Market',
        'store_home': 'Mağaza', 'rental_home': 'Araç Kiralama', 'car_detail': 'Araç Detay',
        'my_bookings': 'Rezervasyonlarım', 'booking_detail': 'Rezervasyon Detay',
        'car_sales_home': 'Araç Satış', 'car_listing_detail': 'Araç İlanı Detay',
        'jobs_home': 'İş İlanları', 'job_detail': 'İş İlanı Detay',
        'favorites': 'Favoriler', 'orders': 'Siparişlerim', 'profile': 'Profil',
      };
      systemContent += `\n\n[EKRAN]: Kullanıcı "${screenNames[screen_type] || screen_type}" sayfasında.`;

      // Merchant products on detail page
      const productResult = qr.merchantProducts?.data as { products?: Array<Record<string, unknown>>; total_count?: number } | null;
      if (entity_id && screen_type?.endsWith('_detail') && productResult?.products?.length) {
        const products = productResult.products;
        systemContent += `\n\n[${entity_name?.toUpperCase() || 'MAĞAZA'} ÜRÜNLERİ] (${productResult.total_count} ürün):`;
        products.slice(0, 10).forEach((p, i) => {
          systemContent += `\n${i + 1}. ${p.name} - ${p.discounted_price || p.price} TL`;
          if (p.discounted_price && p.discounted_price !== p.price) systemContent += ` (eski: ${p.price} TL)`;
          if (p.is_popular) systemContent += ' ⭐';
          systemContent += ` | ID: ${p.id}`;
        });
        systemContent += `\nKullanıcı "sepete ekle" derse ürün bilgilerini action olarak döndür.`;
      }
    }

    // Merchant panel context
    let merchantContext = '';
    if (isMerchant && qr.merchantData?.data) {
      const md = qr.merchantData.data as { id: string; business_name: string; type: string; is_active: boolean; created_at: string };
      const serviceType = md.type === 'restaurant' ? 'restaurant' : 'store';
      const { data: cd } = await supabase.from('platform_commissions')
        .select('platform_commission_rate').eq('service_type', serviceType).eq('is_active', true).maybeSingle();
      const rate = cd?.platform_commission_rate ? parseFloat(cd.platform_commission_rate) : 15.0;
      merchantContext = formatMerchantInfoForAI({ ...md, commission_rate: rate });
      systemContent += `\n\n[İŞLETME]: ${merchantContext}`;
    }

    // Include previous search results context so AI can use product IDs for add_to_cart
    if (lastSearchContext) {
      systemContent += `\n\n[ÖNCEKİ ARAMA SONUÇLARI - Kullanıcı "evet/tamam/ekle/onaylıyorum" gibi ONAY verirse bu bilgilerden add_to_cart çağır. ANCAK kullanıcı farklı/yeni bir ürün istiyorsa veya önceki sonuçlarda olmayan bir ürün soruyorsa YENİDEN search_food çağır]:\n${lastSearchContext.substring(0, 2000)}`;
    }
    if (lastCartContext) {
      systemContent += `\n\n[SEPET DURUMU]:\n${lastCartContext}`;
    }

    // ===== BUILD MESSAGES =====
    const messages: ChatMessage[] = [{ role: 'system', content: systemContent }];

    // Include conversation history (internal context already separated above)
    for (const msg of conversationHistory) {
      messages.push({ role: msg.role as 'user' | 'assistant', content: msg.content });
    }

    if (conversationHistory.length === 0 || conversationHistory[conversationHistory.length - 1].content !== message) {
      messages.push({ role: 'user', content: message });
    }

    // ===== FIRST OPENAI CALL: TOOL DECISION =====
    const useTools = isCustomerApp; // Only customer app uses tool calling
    const actions: Array<{ type: string; payload: Record<string, unknown> }> = [];
    let searchResultProducts: SearchResultProduct[] = [];
    let rentalResultProducts: RentalResultCar[] = [];

    let finalMessages = messages;

    if (useTools) {
      const toolCtx: ToolExecContext = { supabase, userId: user.id, addressData, appSource: app_source, sessionId: currentSessionId || '' };
      searchResultProducts = [];
      rentalResultProducts = [];
      const allToolContextParts: string[] = [];

      // Multi-round tool calling loop (max 3 rounds to prevent infinite loops)
      for (let round = 0; round < 3; round++) {
        const currentMessages = round === 0 ? messages : finalMessages;
        const toolResponse = await fetch('https://api.openai.com/v1/chat/completions', {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'gpt-4o-mini',
            messages: currentMessages,
            tools: CUSTOMER_TOOLS,
            tool_choice: 'auto',
            max_tokens: 300,
            temperature: 0.3,
          }),
        });

        if (!toolResponse.ok) {
          const errText = await toolResponse.text();
          console.error(`OpenAI Tool Error (round ${round}):`, toolResponse.status, errText);
          throw new Error(`OpenAI tool error (${toolResponse.status}): ${errText.substring(0, 200)}`);
        }

        const toolData = await toolResponse.json();
        const assistantMsg = toolData.choices[0]?.message;

        if (!assistantMsg?.tool_calls || assistantMsg.tool_calls.length === 0) {
          // No tool calls - AI wants to respond directly
          if (round === 0 && assistantMsg?.content) {
            // First round, no tools needed - return early
            const aiMessage = assistantMsg.content;
            const tokensUsed = toolData.usage?.total_tokens || 0;

            if (screen_context && app_source === 'super_app') {
              detectNavigationAction(message, screen_context, qr.merchantProducts?.data, actions);
            }

            if (stream && !generate_audio) {
              const encoder = new TextEncoder();
              const sseStream = new ReadableStream({
                async start(controller) {
                  controller.enqueue(encoder.encode(`event: session\ndata: ${JSON.stringify({ session_id: currentSessionId })}\n\n`));
                  controller.enqueue(encoder.encode(`event: chunk\ndata: ${JSON.stringify({ text: aiMessage })}\n\n`));
                  if (actions.length > 0) {
                    controller.enqueue(encoder.encode(`event: actions\ndata: ${JSON.stringify({ actions })}\n\n`));
                  }
                  controller.enqueue(encoder.encode(`event: done\ndata: ${JSON.stringify({ message: aiMessage, tokens_used: tokensUsed })}\n\n`));
                  Promise.all([
                    supabase.from('support_chat_messages').insert({ session_id: currentSessionId, role: 'assistant', content: aiMessage, tokens_used: tokensUsed }),
                    supabase.from('support_chat_sessions').update({ updated_at: new Date().toISOString() }).eq('id', currentSessionId),
                  ]).catch(err => console.error('DB save error:', err));
                  controller.close();
                }
              });
              return new Response(sseStream, {
                headers: { ...corsHeaders, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive' },
              });
            }

            let audioBase64: string | null = null;
            if (generate_audio) audioBase64 = await generateTTSAudio(aiMessage, OPENAI_API_KEY);

            await Promise.all([
              supabase.from('support_chat_messages').insert({ session_id: currentSessionId, role: 'assistant', content: aiMessage, tokens_used: tokensUsed }),
              supabase.from('support_chat_sessions').update({ updated_at: new Date().toISOString() }).eq('id', currentSessionId),
            ]);

            return new Response(JSON.stringify({
              success: true, session_id: currentSessionId, message: aiMessage, tokens_used: tokensUsed,
              ...(actions.length > 0 && { actions }),
              ...(audioBase64 && { audio: audioBase64, audio_format: 'mp3' }),
            }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 });
          }
          break; // Later rounds: no more tool calls, proceed to final response
        }

        // AI wants to call tools - build finalMessages
        if (round === 0) {
          finalMessages = [...messages];
        }
        finalMessages.push({ role: 'assistant' as const, content: assistantMsg.content || '', tool_calls: assistantMsg.tool_calls });

        // Execute all tool calls in parallel
        const toolResults = await Promise.allSettled(
          assistantMsg.tool_calls.map(async (tc: { id: string; function: { name: string; arguments: string } }) => {
            const args = JSON.parse(tc.function.arguments);
            const result = await executeToolCall(tc.function.name, args, toolCtx, actions, searchResultProducts, rentalResultProducts);
            return { id: tc.id, name: tc.function.name, args: tc.function.arguments, result };
          })
        );

        // Build context for history saving
        for (const tc of assistantMsg.tool_calls) {
          const toolName = tc.function.name;
          if (toolName === 'add_to_cart') {
            try {
              const cartArgs = JSON.parse(tc.function.arguments);
              allToolContextParts.push(`[SEPETE_EKLENDİ] ${cartArgs.name} (${cartArgs.price} TL) - ${cartArgs.merchant_name} [ID:${cartArgs.product_id}]`);
            } catch { /* skip */ }
          } else if (toolName === 'search_food') {
            try {
              const searchArgs = JSON.parse(tc.function.arguments);
              allToolContextParts.push(`[ARAMA: ${(searchArgs.keywords || []).join(', ')}]`);
            } catch { /* skip */ }
          }
        }

        // Add tool results to messages (must include ALL tool calls or OpenAI returns 400)
        for (let ti = 0; ti < toolResults.length; ti++) {
          const tr = toolResults[ti];
          const tcId = assistantMsg.tool_calls[ti].id;
          if (tr.status === 'fulfilled') {
            finalMessages.push({
              role: 'tool' as const,
              content: tr.value.result,
              tool_call_id: tr.value.id,
            });
          } else {
            finalMessages.push({
              role: 'tool' as const,
              content: 'Araç çalıştırılamadı, lütfen tekrar deneyin.',
              tool_call_id: tcId,
            });
          }
        }
      } // end tool round loop

      // Save tool results context for future turns
      try {
        if (searchResultProducts.length > 0) {
          searchResultProducts.slice(0, 8).forEach((p, i) => {
            allToolContextParts.push(`${i + 1}. ${p.name} - ${p.price} TL | ${p.merchant_name} [ID:${p.id}] [MID:${p.merchant_id}] [${p.merchant_type}]`);
          });
        }
        if (allToolContextParts.length > 0) {
          supabase.from('support_chat_messages').insert({
            session_id: currentSessionId, role: 'assistant',
            content: `[ARAMA_SONUÇLARI]\n${allToolContextParts.join('\n').substring(0, 2000)}`
          }).then(() => {});
        }
      } catch (ctxErr) {
        console.error('Tool context save error:', ctxErr);
      }

      // Handle add-to-cart from detail page context
      if (screen_context?.entity_id && screen_context.screen_type?.endsWith('_detail')) {
        const productResult = qr.merchantProducts?.data as { products?: Array<Record<string, unknown>> } | null;
        if (productResult?.products) {
          const lowerMsg = message.toLowerCase();
          const addKeywords = ['sepete ekle', 'sepetime ekle', 'ekle', 'almak istiyorum', 'istiyorum', 'sipariş ver', 'tane', 'adet'];
          if (addKeywords.some(kw => lowerMsg.includes(kw))) {
            const matched = productResult.products.find((p) => {
              const pName = (p.name as string).toLowerCase();
              return lowerMsg.includes(pName) || pName.includes(lowerMsg.replace(/sepete ekle|ekle|istiyorum|almak|sipariş|ver|et|tane|adet|\d+/gi, '').trim());
            });
            if (matched) {
              const qMatch = lowerMsg.match(/(\d+)\s*(tane|adet)/);
              actions.push({
                type: 'add_to_cart',
                payload: {
                  product_id: matched.id, name: matched.name,
                  price: matched.discounted_price || matched.price,
                  image_url: matched.image_url || '',
                  merchant_id: screen_context.entity_id,
                  merchant_name: screen_context.entity_name || '',
                  merchant_type: screen_context.entity_type || 'restaurant',
                  quantity: qMatch ? parseInt(qMatch[1]) : 1,
                }
              });
            }
          }
        }
      }
    }

    // Handle navigation for super_app
    if (screen_context && app_source === 'super_app') {
      detectNavigationAction(message, screen_context, qr.merchantProducts?.data, actions);
    }

    // ===== LIVE SUPPORT KEYWORD DETECTION (non-tool-calling apps) =====
    if (!useTools) {
      const liveKw = ['canlı destek', 'canli destek', 'gerçek kişi', 'gercek kisi', 'temsilci', 'müşteri hizmetleri', 'musteri hizmetleri', 'insan ile', 'yardım hattı', 'şikayet'];
      const lowerMsg = message.toLowerCase();
      if (liveKw.some(kw => lowerMsg.includes(kw))) {
        const serviceTypeMap: Record<string, string> = {
          'merchant_panel': 'food', 'rent_a_car_panel': 'rental',
          'courier_app': 'food', 'emlakci_panel': 'emlak',
          'arac_satis_panel': 'car_sales', 'admin_panel': 'general',
        };
        const { data: ticketResult } = await supabase.rpc('create_live_support_ticket', {
          p_user_id: user.id,
          p_app_source: app_source,
          p_subject: `Canlı Destek: ${message.substring(0, 100)}`,
          p_description: message,
          p_service_type: serviceTypeMap[app_source] || 'general',
          p_metadata: { ai_session_id: currentSessionId },
        });
        if (ticketResult?.success) {
          actions.push({
            type: 'connect_live_support',
            payload: {
              ticket_id: ticketResult.ticket_id,
              ticket_number: ticketResult.ticket_number,
              is_existing: ticketResult.is_existing || false,
            }
          });
          // Return early with live support response
          const liveMsg = ticketResult.is_existing
            ? `Mevcut destek talebiniz (#${ticketResult.ticket_number}) bulundu. Temsilciye bağlanıyorsunuz...`
            : `Destek talebi #${ticketResult.ticket_number} oluşturuldu. Bir temsilci en kısa sürede size dönecek.`;

          await supabase.from('support_chat_messages').insert({
            session_id: currentSessionId, role: 'assistant', content: liveMsg
          });

          if (stream && !generate_audio) {
            const enc = new TextEncoder();
            const liveStream = new ReadableStream({
              start(ctrl) {
                ctrl.enqueue(enc.encode(`event: session\ndata: ${JSON.stringify({ session_id: currentSessionId })}\n\n`));
                ctrl.enqueue(enc.encode(`event: chunk\ndata: ${JSON.stringify({ text: liveMsg })}\n\n`));
                ctrl.enqueue(enc.encode(`event: actions\ndata: ${JSON.stringify({ actions })}\n\n`));
                ctrl.enqueue(enc.encode(`event: done\ndata: ${JSON.stringify({ message: liveMsg, tokens_used: 0 })}\n\n`));
                ctrl.close();
              }
            });
            return new Response(liveStream, { headers: { ...corsHeaders, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' } });
          }
          return new Response(JSON.stringify({
            success: true, session_id: currentSessionId, message: liveMsg,
            actions, tokens_used: 0,
          }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 });
        }
      }
    }

    // ===== FINAL OPENAI CALL (streaming or non-streaming) =====
    if (stream && !generate_audio) {
      // STREAMING
      const encoder = new TextEncoder();
      const sseStream = new ReadableStream({
        async start(controller) {
          try {
            controller.enqueue(encoder.encode(`event: session\ndata: ${JSON.stringify({ session_id: currentSessionId })}\n\n`));

            // Emit search results as visual cards before AI text starts
            if (searchResultProducts && searchResultProducts.length > 0) {
              controller.enqueue(encoder.encode(`event: search_results\ndata: ${JSON.stringify({ products: searchResultProducts })}\n\n`));
            }
            if (rentalResultProducts && rentalResultProducts.length > 0) {
              controller.enqueue(encoder.encode(`event: rental_results\ndata: ${JSON.stringify({ cars: rentalResultProducts })}\n\n`));
            }

            // Emit price comparison data
            const priceCompAction = actions.find(a => a.type === 'price_comparison');
            if (priceCompAction) {
              controller.enqueue(encoder.encode(`event: price_comparison\ndata: ${JSON.stringify(priceCompAction.payload)}\n\n`));
            }

            const streamResponse = await fetch('https://api.openai.com/v1/chat/completions', {
              method: 'POST',
              headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({
                model: 'gpt-4o-mini', messages: finalMessages, max_tokens: 500, temperature: 0.3,
                stream: true, stream_options: { include_usage: true },
              }),
            });

            if (!streamResponse.ok) {
              console.error('OpenAI Stream Error:', await streamResponse.text());
              controller.enqueue(encoder.encode(`event: error\ndata: ${JSON.stringify({ error: 'AI servisi hatası' })}\n\n`));
              controller.close();
              return;
            }

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
                    controller.enqueue(encoder.encode(`event: chunk\ndata: ${JSON.stringify({ text: delta })}\n\n`));
                  }
                  if (parsed.usage) totalTokens = parsed.usage.total_tokens || 0;
                } catch { /* skip */ }
              }
            }

            // Process remaining buffer
            if (sseBuffer.trim()?.startsWith('data: ')) {
              const data = sseBuffer.trim().slice(6);
              if (data !== '[DONE]') {
                try {
                  const parsed = JSON.parse(data);
                  const delta = parsed.choices?.[0]?.delta?.content;
                  if (delta) {
                    fullMessage += delta;
                    controller.enqueue(encoder.encode(`event: chunk\ndata: ${JSON.stringify({ text: delta })}\n\n`));
                  }
                } catch { /* skip */ }
              }
            }

            if (!fullMessage) fullMessage = 'Üzgünüm, yanıt oluşturulamadı.';

            if (actions.length > 0) {
              controller.enqueue(encoder.encode(`event: actions\ndata: ${JSON.stringify({ actions })}\n\n`));
            }

            controller.enqueue(encoder.encode(`event: done\ndata: ${JSON.stringify({ message: fullMessage, tokens_used: totalTokens })}\n\n`));

            // Save to DB (fire and forget) - include search/rental results in metadata
            const msgMetadata: Record<string, unknown> = {};
            if (searchResultProducts.length > 0) msgMetadata.search_results = searchResultProducts.slice(0, 8);
            if (rentalResultProducts.length > 0) msgMetadata.rental_results = rentalResultProducts.slice(0, 8);
            Promise.all([
              supabase.from('support_chat_messages').insert({ session_id: currentSessionId, role: 'assistant', content: fullMessage, tokens_used: totalTokens, ...(Object.keys(msgMetadata).length > 0 && { metadata: msgMetadata }) }),
              supabase.from('support_chat_sessions').update({ updated_at: new Date().toISOString() }).eq('id', currentSessionId),
            ]).catch(err => console.error('DB save error:', err));

            controller.close();
          } catch (error) {
            console.error('Streaming error:', error);
            controller.enqueue(encoder.encode(`event: error\ndata: ${JSON.stringify({ error: error instanceof Error ? error.message : 'Streaming hatası' })}\n\n`));
            controller.close();
          }
        }
      });

      return new Response(sseStream, {
        headers: { ...corsHeaders, 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', 'Connection': 'keep-alive' },
      });
    }

    // NON-STREAMING
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'gpt-4o-mini', messages: finalMessages, max_tokens: 500, temperature: 0.3 }),
    });

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      console.error('OpenAI Error:', openaiResponse.status, errText);
      throw new Error(`OpenAI error (${openaiResponse.status}): ${errText.substring(0, 200)}`);
    }

    const aiData = await openaiResponse.json();
    const aiMessage = aiData.choices[0]?.message?.content || 'Üzgünüm, yanıt oluşturulamadı.';
    const tokensUsed = aiData.usage?.total_tokens || 0;

    // TTS
    let audioBase64: string | null = null;
    if (generate_audio) {
      audioBase64 = await generateTTSAudio(aiMessage, OPENAI_API_KEY);
    }

    // Save - include search/rental results in metadata
    const nsMeta: Record<string, unknown> = {};
    if (searchResultProducts.length > 0) nsMeta.search_results = searchResultProducts.slice(0, 8);
    if (rentalResultProducts.length > 0) nsMeta.rental_results = rentalResultProducts.slice(0, 8);
    await Promise.all([
      supabase.from('support_chat_messages').insert({ session_id: currentSessionId, role: 'assistant', content: aiMessage, tokens_used: tokensUsed, ...(Object.keys(nsMeta).length > 0 && { metadata: nsMeta }) }),
      supabase.from('support_chat_sessions').update({ updated_at: new Date().toISOString() }).eq('id', currentSessionId),
    ]);

    const nsPriceComp = actions.find(a => a.type === 'price_comparison');
    return new Response(JSON.stringify({
      success: true, session_id: currentSessionId, message: aiMessage, tokens_used: tokensUsed,
      ...(actions.length > 0 && { actions }),
      ...(searchResultProducts.length > 0 && { search_results: searchResultProducts }),
      ...(rentalResultProducts.length > 0 && { rental_results: rentalResultProducts }),
      ...(nsPriceComp && { price_comparison: nsPriceComp.payload }),
      ...(audioBase64 && { audio: audioBase64, audio_format: 'mp3' }),
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 });

  } catch (error) {
    const errMsg = error instanceof Error ? error.message : String(error);
    const errStack = error instanceof Error ? error.stack : '';
    console.error('Error:', errMsg);
    console.error('Stack:', errStack);
    return new Response(JSON.stringify({
      success: false, error: errMsg || 'Bilinmeyen bir hata oluştu'
    }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 });
  }
});

// ========== HELPER FUNCTIONS ==========

function detectNavigationAction(
  message: string,
  _screenContext: ScreenContext,
  merchantProductsData: unknown,
  actions: Array<{ type: string; payload: Record<string, unknown> }>
) {
  const lower = message.toLowerCase();
  const navKeywords: Record<string, string> = {
    'yemek sipariş': '/food', 'restoran': '/food', 'market': '/grocery', 'mağaza': '/market',
    'araç kiralama': '/rental', 'araba kiralama': '/rental', 'rent a car': '/rental', 'kiralama': '/rental',
    'sepet': merchantProductsData ? '/store/cart' : '/food/cart',
    'siparişlerim': '/orders-main', 'favoriler': '/favorites', 'profil': '/profile',
    'araç satış': '/car-sales', 'araba al': '/car-sales', 'satılık araç': '/car-sales', 'araç ilanı': '/car-sales',
    'iş ilan': '/jobs', 'iş ara': '/jobs', 'kariyer': '/jobs', 'iş bul': '/jobs',
    'taksi': '/taxi', 'taxi': '/taxi',
    'ayarlar': '/settings', 'ana sayfa': '/',
  };

  for (const [keyword, route] of Object.entries(navKeywords)) {
    if (lower.includes(keyword) && (lower.includes('git') || lower.includes('aç') || lower.includes('göster') || lower.includes('gitmek'))) {
      actions.push({ type: 'navigate', payload: { route } });
      break;
    }
  }
}

async function generateTTSAudio(text: string, apiKey: string): Promise<string | null> {
  try {
    const cleanText = cleanTextForTTS(text);
    if (cleanText.length === 0) return null;

    const ttsResponse = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'tts-1', voice: 'nova', input: cleanText.substring(0, 500), response_format: 'mp3', speed: 1.1 }),
    });

    if (ttsResponse.ok) {
      const buf = await ttsResponse.arrayBuffer();
      return uint8ArrayToBase64(new Uint8Array(buf));
    }
  } catch (e) {
    console.error('TTS error:', e);
  }
  return null;
}