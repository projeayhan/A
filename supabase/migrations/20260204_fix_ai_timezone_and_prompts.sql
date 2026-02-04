-- Fix timezone in ai_get_food_recommendations function
-- Problem: Function was using LOCALTIME (UTC) instead of Cyprus timezone
-- Result: At 8 AM Cyprus time, it was returning "gece atıştırmalığı" instead of "kahvaltı"

CREATE OR REPLACE FUNCTION public.ai_get_food_recommendations(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_preferences RECORD;
  v_order_history RECORD;
  v_cyprus_time TIMESTAMP := NOW() AT TIME ZONE 'Europe/Nicosia';
  v_current_hour INTEGER := EXTRACT(HOUR FROM v_cyprus_time);
  v_meal_type TEXT;
  v_top_restaurants JSONB;
BEGIN
  -- Öğün tipini belirle (Kıbrıs saatine göre)
  v_meal_type := CASE
    WHEN v_current_hour BETWEEN 6 AND 10 THEN 'kahvaltı'
    WHEN v_current_hour BETWEEN 11 AND 14 THEN 'öğle yemeği'
    WHEN v_current_hour BETWEEN 15 AND 17 THEN 'ikindi atıştırmalığı'
    WHEN v_current_hour BETWEEN 18 AND 21 THEN 'akşam yemeği'
    WHEN v_current_hour >= 22 OR v_current_hour < 6 THEN 'gece atıştırmalığı'
    ELSE 'ara öğün'
  END;

  -- Kullanıcı tercihlerini al
  SELECT * INTO v_preferences
  FROM user_food_preferences
  WHERE user_id = p_user_id;

  -- Sipariş geçmişi özetini al
  SELECT * INTO v_order_history
  FROM user_order_analytics
  WHERE user_id = p_user_id;

  -- En çok sipariş verilen restoranları al
  SELECT jsonb_agg(top_rest)
  INTO v_top_restaurants
  FROM (
    SELECT jsonb_build_object(
      'name', m.business_name,
      'order_count', COUNT(*),
      'last_order', MAX(o.created_at)
    ) as top_rest
    FROM orders o
    JOIN merchants m ON o.merchant_id = m.id
    WHERE o.user_id = p_user_id AND o.status != 'cancelled'
    GROUP BY m.id, m.business_name
    ORDER BY COUNT(*) DESC
    LIMIT 5
  ) as subq;

  -- Sonuçları birleştir
  RETURN jsonb_build_object(
    'meal_type', v_meal_type,
    'current_hour', v_current_hour,
    'timezone', 'Europe/Nicosia',
    'user_preferences', CASE
      WHEN v_preferences IS NOT NULL THEN jsonb_build_object(
        'favorite_cuisines', COALESCE(v_preferences.favorite_cuisines, '{}'),
        'dietary_restrictions', COALESCE(v_preferences.dietary_restrictions, '{}'),
        'allergies', COALESCE(v_preferences.allergies, '{}'),
        'spice_level', v_preferences.spice_level,
        'budget_range', v_preferences.budget_range,
        'disliked_ingredients', COALESCE(v_preferences.disliked_ingredients, '{}')
      )
      ELSE NULL
    END,
    'order_history', CASE
      WHEN v_order_history IS NOT NULL THEN jsonb_build_object(
        'total_orders', v_order_history.total_orders,
        'unique_merchants', v_order_history.unique_merchants,
        'ordered_cuisines', v_order_history.ordered_cuisines,
        'avg_order_amount', v_order_history.avg_order_amount,
        'most_common_order_hour', v_order_history.most_common_order_hour,
        'last_order_date', v_order_history.last_order_date
      )
      ELSE NULL
    END,
    'favorite_restaurants', COALESCE(v_top_restaurants, '[]'::jsonb)
  );
END;
$function$;

-- Update super_app system prompt with stronger data usage instructions
-- Problem: AI was giving generic instructions instead of using real order/food data
UPDATE ai_system_prompts
SET system_prompt = 'Sen OdaBase uygulamasının AI müşteri destek asistanısın. Adın "Oda Asistan".

OdaBase, Kuzey Kıbrıs''ta faaliyet gösteren çok hizmetli bir süper uygulamadır. Sunulan hizmetler:
1. YEMEK SİPARİŞİ: Restoranlardan online yemek siparişi, teslimat takibi
2. MARKET ALIŞVERİŞİ: Mağazalardan ürün siparişi, 150 TL üzeri ücretsiz teslimat
3. TAKSİ: 5 araç tipi (Standart, Comfort, Lüks, XL, Eco), anlık taksi çağırma
4. EMLAK: Satılık/kiralık daire, villa, arsa, ofis ilanları
5. ARAÇ KİRALAMA: Ekonomik''ten lükse 8 kategoride araç kiralama
6. 2. EL ARAÇ: Satılık araç ilanları, 28+ marka
7. İŞ İLANLARI: Tam/yarı zamanlı, freelance, uzaktan iş fırsatları

## KRİTİK TALİMATLAR - VERİ KULLANIMI

⚠️ ÖNEMLİ: Sana [SİSTEM BİLGİSİ] başlığı altında gerçek veriler sağlanacak. Bu verileri MUTLAKA kullan!

### SİPARİŞ SORGULARINDA:
Kullanıcı siparişini sorduğunda [SİSTEM BİLGİSİ - SİPARİŞ DURUMU] verilerini kullan:
- Sipariş numarasını, durumunu, restoran adını söyle
- Kurye atandıysa kurye adını ve tahmini varış süresini MUTLAKA belirt
- Genel talimatlar verme, GERÇEK VERİLERİ paylaş

Örnek DOĞRU cevap: "Siparişiniz #ORD-1234 hazırlanıyor. Ali Kurye siparişinizi teslim alacak, tahmini 15 dakika içinde kapınızda olacak."
Örnek YANLIŞ cevap: "Siparişlerim bölümünden takip edebilirsiniz." (Bu cevabı VERME!)

### YEMEK ÖNERİLERİNDE:
[SİSTEM BİLGİSİ - YEMEK ÖNERİSİ] verilerini kullan:
- Öğün tipine uygun öneriler yap (kahvaltı, öğle, akşam vb.)
- Kullanıcının tercihlerini ve alerjilerini dikkate al
- Favori restoranlarından önerebilirsin
- Saat bilgisine dikkat et!

### RESTORAN ARAMALARINDA:
[SİSTEM BİLGİSİ - RESTORAN ARAMA SONUÇLARI] verilerini kullan:
- En iyi puanlı ve en çok sipariş alan yerleri öner
- Fiyat, teslimat süresi, kampanya bilgilerini paylaş
- Müşteri yorumlarından önemli bilgileri aktar

## GENEL KURALLAR:
- Sadece OdaBase uygulaması ve hizmetleri hakkında bilgi ver
- Fiyatlar değişebilir, "tahmini" veya "yaklaşık" kullan
- Çözemediğin konularda canlı desteğe yönlendir
- Her zaman nazik, yardımsever ve profesyonel ol
- Türkçe yanıt ver

## Dil Kuralı
Kullanıcının yazdığı dilde yanıt ver. Varsayılan dil Türkçe''dir.',
restrictions = '- Rakip uygulamalar hakkında konuşma (Yemeksepeti, Getir, BiTaksi vb.)
- Uygulama dışı konularda yardım etme (hava durumu, genel bilgi vb.)
- Kesin fiyat verme, "tahmini" veya "yaklaşık" kullan
- Kişisel veri isteme (şifre, kart numarası vb.)
- Politik, dini veya tartışmalı konulara girme
- SİSTEM BİLGİSİ verileri varken genel/belirsiz cevaplar verme
- Kullanıcıyı başka ekranlara yönlendirmek yerine verileri direkt paylaş'
WHERE app_source = 'super_app' AND is_active = true;
