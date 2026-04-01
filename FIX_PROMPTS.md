# SuperCyp — Doğrulanmış Sorunlar İçin Düzeltme Prompt'ları

Her biri ayrı bir sohbette çalıştırılacak. Sırayla yap — her fix bağımsız.

---

## FIX 1 — taxi_rides RLS: Müşteri verisi tüm kullanıcılara açık

**Sorun (DB'den doğrulandı):**
`taxi_rides` tablosundaki "Drivers can view assigned rides" policy'si şu şekilde:
```sql
qual = (driver_id IN (SELECT id FROM taxi_drivers WHERE user_id = auth.uid()))
       OR (status = 'pending')
```
`status = 'pending'` koşulu nedeniyle kimliği doğrulanmış HER kullanıcı tüm bekleyen yolculukları ve içindeki `pickup_address`, `dropoff_address`, `customer_name`, `customer_phone`, `pickup_lat`, `pickup_lng`, `dropoff_lat`, `dropoff_lng` alanlarını görebiliyor.

**Görevin:**
`c:\A\supabase\migrations\` klasörüne yeni bir migration dosyası oluştur.

Mevcut policy'yi kaldır ve yerine iki ayrı policy koy:
1. Sürücüler yalnızca kendi sürüşlerini (driver_id eşleşen) görebilsin
2. Onaylı (`status = 'approved'`) sürücüler bekleyen sürüşleri görebilsin — ama sadece `id`, `status`, `pickup_lat`, `pickup_lng`, `vehicle_type`, `fare`, `distance_km` kolonlarını görmesi yeterli. Tam izolasyon için column-level security veya ayrı bir view kullanılabilir.

Migration dosyasını şu isimle oluştur: `20260316_fix_taxi_rides_rls.sql`

İçerik:
```sql
-- Mevcut geniş policy'yi kaldır
DROP POLICY IF EXISTS "Drivers can view assigned rides" ON taxi_rides;

-- Policy 1: Sürücü kendi atanmış sürüşlerini görür
CREATE POLICY "Drivers can view own rides"
ON taxi_rides FOR SELECT
USING (
  driver_id IN (
    SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
  )
);

-- Policy 2: Onaylı sürücüler pending sürüşleri görebilir (kabul için)
-- Sadece onaylı (status='approved') sürücüler pending ride görebilir
CREATE POLICY "Approved drivers can view pending rides"
ON taxi_rides FOR SELECT
USING (
  status = 'pending'
  AND EXISTS (
    SELECT 1 FROM taxi_drivers
    WHERE user_id = auth.uid()
      AND status = 'approved'
  )
);
```

Bu migration dosyasını oluşturduktan sonra Supabase MCP tool ile `apply_migration` uygula.

Ardından `c:\A\super_app\lib\core\services\taxi_service.dart` dosyasındaki `subscribeToNewRideRequests` fonksiyonunu bul (satır ~1001) ve şu kontrolü ekle: callback içinde zaten `status == 'pending'` kontrolü var, bu yeterli. RLS tarafı düzeltildi.

---

## FIX 2 — users tablosu: Admin ban için UPDATE policy eksik

**Sorun (DB'den doğrulandı):**
`users` tablosunda sadece şu policy'ler var:
- INSERT: kendi profili
- SELECT: kendi profili / support agent tümünü görebilir
- UPDATE: yalnızca `auth.uid() = id` (kullanıcı kendini)

Admin'in `is_banned = true` yapabilmesi için RLS düzeyinde policy yok. Admin panel muhtemelen service_role key ile bunu bypass ediyor ama bu riskli.

**Görevin:**
`c:\A\supabase\migrations\` klasörüne yeni migration dosyası oluştur: `20260316_fix_users_admin_policy.sql`

```sql
-- Admin kullanıcıları users tablosunu güncelleyebilsin (ban, unban, profil düzenleme)
CREATE POLICY "Admins can update all users"
ON users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admin_users WHERE user_id = auth.uid()
  )
);

-- Admin kullanıcıları tüm user kayıtlarını görebilsin
CREATE POLICY "Admins can read all users"
ON users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admin_users WHERE user_id = auth.uid()
  )
);
```

Ardından `c:\A\super_app\lib\core\providers\auth_provider.dart` dosyasını oku.
`_checkBanned` fonksiyonu sadece login ve startup'ta çağrılıyor. Buna ek olarak `_authSubscription` içinde (auth state değişimlerini dinleyen yer) her token refresh'te de `_checkBanned` çağrısını ekle, böylece ban daha hızlı yansır.

Migration dosyasını oluşturduktan sonra Supabase MCP ile `apply_migration` uygula.

---

## FIX 3 — updateDriverOnlineStatus: Başka sürücüyü offline yapabilme açığı

**Sorun (kod analizinden doğrulandı):**
`c:\A\super_app\lib\core\services\taxi_service.dart` dosyasındaki `updateDriverOnlineStatus` fonksiyonu (satır ~775) sadece `.eq('id', driverId)` filtresiyle güncelleme yapıyor. `user_id` kontrolü yok — herhangi bir kullanıcı herhangi bir sürücünün ID'sini biliyorsa onu offline yapabilir.

**Görevin:**
`c:\A\super_app\lib\core\services\taxi_service.dart` dosyasını oku, `updateDriverOnlineStatus` fonksiyonunu bul.

Mevcut:
```dart
.eq('id', driverId)
```

Şu şekilde değiştir:
```dart
.eq('id', driverId)
.eq('user_id', SupabaseService.currentUser!.id)
```

Aynı dosyada `updateDriverLocation` fonksiyonunu da kontrol et — orada `user_id` filtresi var mı? Yoksa aynı düzeltmeyi orada da yap.

Değişiklikleri yaptıktan sonra dosyayı kaydet. Test için: fonksiyonun imzasını değiştirmeden sadece where koşuluna ekleme yapman yeterli.

---

## FIX 4 — subscribeToNewRideRequests: Realtime filtre eksikliği

**Sorun (DB ve kod'dan doğrulandı):**
`c:\A\super_app\lib\core\services\taxi_service.dart` satır ~1001'deki `subscribeToNewRideRequests` fonksiyonu `taxi_rides` tablosunun tüm INSERT olaylarını `filter` olmadan dinliyor. RLS düzeltmesiyle (FIX 1) veri artık korumalı olacak ama gereksiz network trafiği hala mevcut.

**Görevin:**
`c:\A\super_app\lib\core\services\taxi_service.dart` dosyasını oku, `subscribeToNewRideRequests` fonksiyonunu bul.

Fonksiyona `vehicle_type` parametresi ekle (opsiyonel, null ise tümünü dinle):

```dart
static RealtimeChannel subscribeToNewRideRequests(
  void Function(Map<String, dynamic>) onNewRide, {
  String? vehicleType,
}) {
  return _client
      .channel('new_rides_${vehicleType ?? 'all'}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'taxi_rides',
        filter: vehicleType != null
            ? PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'vehicle_type',
                value: vehicleType,
              )
            : null,
        callback: (payload) {
          if (payload.newRecord['status'] == 'pending') {
            onNewRide(payload.newRecord);
          }
        },
      )
      .subscribe();
}
```

Ardından bu fonksiyonun çağrıldığı yeri bul (muhtemelen bir provider veya home screen) ve sürücünün `vehicle_types` alanından ilk tipi `vehicleType` olarak geç.

---

## FIX 5 — Admin ban → Aktif oturumları hemen sonlandır

**Sorun (DB ve kod'dan doğrulandı):**
`is_banned = true` yapıldığında kullanıcının mevcut JWT token'ı 1 saat daha geçerli kalıyor. `_checkBanned` sadece login ve startup'ta çağrılıyor.

**Görevin:**
`c:\A\admin_panel\lib\features\sanctions\services\sanction_service.dart` dosyasını oku, `banUser` veya kullanıcı yasaklama fonksiyonunu bul.

Yasaklama işleminin ardından şu Supabase Admin Auth çağrısını ekle (service_role key gerekiyor):

```dart
// Kullanıcının tüm aktif oturumlarını sonlandır
await SupabaseService.adminClient.auth.admin.signOut(userId);
```

`adminClient`'ın `SUPABASE_SERVICE_ROLE_KEY` ile initialize edilmiş ayrı bir Supabase istemcisi olduğundan emin ol. `c:\A\admin_panel\lib\core\config\app_config.dart` dosyasında `supabaseServiceRoleKey` getter var — bunu kullanabilirsin.

Eğer `adminClient` henüz yoksa `c:\A\admin_panel\lib\core\services\supabase_service.dart` dosyasına ekle:

```dart
static SupabaseClient get adminClient => SupabaseClient(
  AppConfig.supabaseUrl,
  AppConfig.supabaseServiceRoleKey,
);
```

**DİKKAT:** Service role key'i sadece güvenli sunucu ortamında (admin panel backend veya edge function) kullanılmalı. Doğrudan Flutter web uygulamasında service role key kullanmak güvenli değildir — bunun yerine bir Supabase Edge Function aracılığıyla yapılması önerilir. Bu durumu kullanıcıya belirt ve Edge Function yaklaşımını da göster.

**Sorun (kod analizinden doğrulandı):**
`invoice_service.dart` fatura üretiyor ama hiçbir `invoices` tablosu yok. Her PDF tıklamada yeni numara üretiliyor, geçmiş faturalar kaydedilmiyor. Fatura numarası `millisecondsSinceEpoch.substring(7)` ile üretiliyor — aynı saniyede çakışabilir, GİB standardına göre sıralı olması zorunlu.

**Görevin:**
`c:\A\supabase\migrations\` klasörüne `20260316_create_invoices_table.sql` dosyası oluştur:

```sql
-- Sıralı fatura numarası için sequence
CREATE SEQUENCE IF NOT EXISTS invoice_seq START 1;

-- Şirket/platform ayarları tablosu (hardcoded bilgileri buraya taşı)
CREATE TABLE IF NOT EXISTS company_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  address TEXT NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(100),
  tax_office VARCHAR(100) NOT NULL,
  tax_number VARCHAR(20) NOT NULL,
  website VARCHAR(100),
  invoice_prefix VARCHAR(10) DEFAULT 'ODB',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- İlk kayıt (gerçek şirket bilgileriyle güncelle)
INSERT INTO company_settings (name, address, phone, email, tax_office, tax_number, website, invoice_prefix)
VALUES (
  'SuperCyp Teknoloji A.Ş.',
  'Levent Mah. Büyükdere Cad. No:123, 34394 Şişli/İstanbul',
  '+90 212 555 00 00',
  'fatura@supercyp.com',
  'Beşiktaş Vergi Dairesi',
  'GERÇEK_VERGİ_NUMARASI_GİR', -- Bunu gerçek vergi numarasıyla doldur
  'www.supercyp.com',
  'ODB'
) ON CONFLICT DO NOTHING;

-- Ana faturalar tablosu
CREATE TABLE IF NOT EXISTS invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Numara (sıralı, kesintisiz, GİB uyumlu)
  invoice_number VARCHAR(30) UNIQUE NOT NULL
    DEFAULT (
      'ODB' ||
      TO_CHAR(NOW(), 'YYYY') ||
      TO_CHAR(NOW(), 'MM') ||
      '-' ||
      LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0')
    ),

  -- Tür ve kaynak
  invoice_type VARCHAR(20) NOT NULL DEFAULT 'sale',
    -- 'sale' | 'refund' | 'proforma'
  source_type VARCHAR(20) NOT NULL,
    -- 'taxi' | 'food' | 'store' | 'rental' | 'car_sales' | 'manual'
  source_id UUID,          -- İlgili sipariş/ödeme UUID'si
  parent_invoice_id UUID REFERENCES invoices(id),  -- İade faturalarında orijinal fatura

  -- Satıcı bilgileri (o anki snapshot — sonra company_settings değişse bile doğru kalır)
  seller_name VARCHAR(200) NOT NULL,
  seller_tax_number VARCHAR(20) NOT NULL,
  seller_tax_office VARCHAR(100),
  seller_address TEXT,

  -- Alıcı bilgileri
  buyer_name VARCHAR(200),
  buyer_tax_number VARCHAR(20),  -- TC kimlik veya vergi numarası
  buyer_address TEXT,
  buyer_email VARCHAR(100),

  -- Tutar (DECIMAL — float değil!)
  subtotal DECIMAL(15,2) NOT NULL,
  kdv_rate DECIMAL(5,2) NOT NULL,
  kdv_amount DECIMAL(15,2) NOT NULL,
  total DECIMAL(15,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'TRY',

  -- Durum
  status VARCHAR(20) NOT NULL DEFAULT 'issued',
    -- 'issued' | 'sent' | 'cancelled'
  cancelled_at TIMESTAMPTZ,
  cancel_reason TEXT,
  sent_at TIMESTAMPTZ,

  -- GİB e-Fatura (ileride entegre edilecek)
  gib_uuid VARCHAR(50),
  gib_status VARCHAR(20),        -- 'pending' | 'accepted' | 'rejected'
  gib_submitted_at TIMESTAMPTZ,

  -- PDF Supabase Storage linki
  pdf_url TEXT,

  -- Audit
  created_by UUID,  -- Admin veya sistem (NULL = otomatik)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performans index'leri
CREATE INDEX idx_invoices_source ON invoices(source_type, source_id);
CREATE INDEX idx_invoices_buyer_email ON invoices(buyer_email);
CREATE INDEX idx_invoices_created_at ON invoices(created_at DESC);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_number ON invoices(invoice_number);

-- Fatura kalemleri (çok satırlı fatura desteği)
CREATE TABLE IF NOT EXISTS invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(15,2) NOT NULL,
  kdv_rate DECIMAL(5,2) NOT NULL DEFAULT 20.00,
  total DECIMAL(15,2) NOT NULL,
  sort_order INTEGER DEFAULT 0
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);

-- RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;

-- Sadece adminler görebilir/yazabilir
CREATE POLICY "Admins can manage invoices" ON invoices
  FOR ALL USING (
    EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can manage invoice items" ON invoice_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
  );

-- Kullanıcılar kendi faturalarını görebilir (buyer_email eşleşmesi)
CREATE POLICY "Users can view own invoices" ON invoices
  FOR SELECT USING (
    buyer_email = (SELECT email FROM users WHERE id = auth.uid())
  );
```

Migration dosyasını oluşturduktan sonra Supabase MCP `apply_migration` ile uygula.

---

## FIX 7 — invoice_service.dart: Hardcoded şirket bilgilerini veritabanından çek

**Sorun (kod analizinden doğrulandı):**
`c:\A\admin_panel\lib\core\services\invoice_service.dart` dosyasında satır 17-25 arası şirket bilgileri ve vergi numarası hardcoded. Vergi numarası `1234567890` (test verisi). Bu faturalar yasal fatura sayılmaz.

**Görevin:**
`c:\A\admin_panel\lib\core\services\invoice_service.dart` dosyasını oku.

Şu değişiklikleri yap:

1. `companyInfo` sabit map'ini kaldır.
2. Yerine `getCompanyInfo()` adlı async static metod ekle:

```dart
static Map<String, String>? _cachedCompanyInfo;

static Future<Map<String, String>> getCompanyInfo() async {
  if (_cachedCompanyInfo != null) return _cachedCompanyInfo!;
  final supabase = SupabaseService.client;
  final row = await supabase
      .from('company_settings')
      .select()
      .limit(1)
      .single();
  _cachedCompanyInfo = {
    'name': row['name'] as String,
    'address': row['address'] as String,
    'phone': row['phone'] as String? ?? '',
    'email': row['email'] as String? ?? '',
    'taxOffice': row['tax_office'] as String,
    'taxNumber': row['tax_number'] as String,
    'website': row['website'] as String? ?? '',
    'invoicePrefix': row['invoice_prefix'] as String? ?? 'ODB',
  };
  return _cachedCompanyInfo!;
}

static void clearCompanyInfoCache() => _cachedCompanyInfo = null;
```

3. `generateInvoiceNumber()` metodunu şöyle güncelle — artık sequence'ten gelsin:

```dart
// Fatura numarasını DB sequence'ten üret (çakışma olmaz)
static Future<String> generateInvoiceNumberFromDB() async {
  final supabase = SupabaseService.client;
  final result = await supabase.rpc('get_next_invoice_number');
  return result as String;
}
```

Bunun için migration'a şu fonksiyonu da ekle (FIX 6 migration'ına ekleyebilirsin):

```sql
CREATE OR REPLACE FUNCTION get_next_invoice_number()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prefix TEXT;
  v_seq BIGINT;
BEGIN
  SELECT invoice_prefix INTO v_prefix FROM company_settings LIMIT 1;
  v_seq := NEXTVAL('invoice_seq');
  RETURN v_prefix || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(v_seq::TEXT, 6, '0');
END;
$$;
```

4. `generateInvoicePdf()` ve `generateFoodOrderInvoicePdf()` metodlarını `async` yap, başına `final company = await getCompanyInfo();` ekle ve `companyInfo[...]` referanslarını `company[...]` ile değiştir.

`c:\A\admin_panel\lib\core\services\supabase_service.dart` dosyasında `client` getter'inin public olduğundan emin ol.

---

## FIX 8 — Fatura DB'ye kaydet ve PDF'i Storage'a yükle

**Sorun (kod analizinden doğrulandı):**
`c:\A\admin_panel\lib\features\invoices\screens\invoices_screen.dart` dosyasında PDF oluşturuluyor ama `invoices` tablosuna hiç kaydedilmiyor. Her tıklamada yeni numara üretilip geçici PDF veriliyor.

**Görevin:**
`c:\A\admin_panel\lib\core\services\invoice_service.dart` dosyasını oku.

`saveInvoice()` adlı yeni bir static metod ekle. Bu metod:
1. `get_next_invoice_number` RPC ile numara alır
2. PDF byte'larını Supabase Storage `invoices` bucket'ına yükler
3. `invoices` tablosuna kaydeder
4. Kaydedilen satırı döndürür

```dart
static Future<Map<String, dynamic>> saveInvoice({
  required String sourceType,       // 'taxi' | 'food' | 'store' | 'rental'
  required String sourceId,
  required String buyerName,
  String? buyerEmail,
  String? buyerTaxNumber,
  String? buyerAddress,
  required double subtotal,
  required double kdvRate,
  required double kdvAmount,
  required double total,
  required List<Map<String, dynamic>> items,  // [{description, quantity, unit_price, total}]
  String invoiceType = 'sale',
  String? parentInvoiceId,          // İade faturası için orijinal fatura ID
}) async {
  final supabase = SupabaseService.client;
  final company = await getCompanyInfo();
  final invoiceNumber = await generateInvoiceNumberFromDB();

  // 1. Önce DB'ye kaydet (PDF olmadan)
  final invoice = await supabase.from('invoices').insert({
    'invoice_number': invoiceNumber,
    'invoice_type': invoiceType,
    'source_type': sourceType,
    'source_id': sourceId,
    'parent_invoice_id': parentInvoiceId,
    'seller_name': company['name'],
    'seller_tax_number': company['taxNumber'],
    'seller_tax_office': company['taxOffice'],
    'seller_address': company['address'],
    'buyer_name': buyerName,
    'buyer_email': buyerEmail,
    'buyer_tax_number': buyerTaxNumber,
    'buyer_address': buyerAddress,
    'subtotal': subtotal,
    'kdv_rate': kdvRate,
    'kdv_amount': kdvAmount,
    'total': total,
    'currency': 'TRY',
    'status': 'issued',
  }).select().single();

  // 2. Kalemleri ekle
  if (items.isNotEmpty) {
    await supabase.from('invoice_items').insert(
      items.asMap().entries.map((e) => {
        'invoice_id': invoice['id'],
        'description': e.value['description'],
        'quantity': e.value['quantity'] ?? 1,
        'unit_price': e.value['unit_price'],
        'kdv_rate': kdvRate,
        'total': e.value['total'],
        'sort_order': e.key,
      }).toList(),
    );
  }

  // 3. PDF oluştur
  final pdfBytes = await generateInvoicePdfFromRecord(invoice, items);

  // 4. Storage'a yükle
  final fileName = 'invoices/${invoice['id']}.pdf';
  await supabase.storage.from('invoices').uploadBinary(
    fileName,
    pdfBytes,
    fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
  );
  final pdfUrl = supabase.storage.from('invoices').getPublicUrl(fileName);

  // 5. pdf_url güncelle
  await supabase.from('invoices')
      .update({'pdf_url': pdfUrl})
      .eq('id', invoice['id']);

  return {...invoice, 'pdf_url': pdfUrl};
}
```

Supabase dashboard'da `invoices` adlı Storage bucket'ını oluştur (public değil, authenticated erişim). Bunun için Supabase MCP ile şu SQL'i çalıştır:

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('invoices', 'invoices', false)
ON CONFLICT DO NOTHING;

CREATE POLICY "Admins can manage invoice files"
ON storage.objects FOR ALL
USING (
  bucket_id = 'invoices' AND
  EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid())
);
```

---

## FIX 9 — Sipariş tamamlandığında otomatik fatura oluştur

**Sorun (kod analizinden doğrulandı):**
Fatura kesilmesi tamamen manueldir — admin `invoices_screen.dart`'ta PDF butonuna basmak zorunda. Sipariş tamamlandığında fatura **otomatik** oluşturulmalıdır.

**Görevin:**
`c:\A\supabase\migrations\` klasörüne `20260316_auto_invoice_triggers.sql` dosyası oluştur:

```sql
-- Taksi ödemesi tamamlandığında fatura oluştur
CREATE OR REPLACE FUNCTION create_taxi_invoice()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_invoice_number TEXT;
  v_company RECORD;
  v_user RECORD;
  v_ride RECORD;
  v_subtotal DECIMAL(15,2);
  v_kdv_rate DECIMAL(5,2) := 20.00;
  v_kdv_amount DECIMAL(15,2);
BEGIN
  -- Sadece 'completed' statüsüne geçişte tetikle
  IF NEW.status != 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;

  -- Zaten fatura kesilmişse tekrar kesme
  IF EXISTS (
    SELECT 1 FROM invoices
    WHERE source_type = 'taxi' AND source_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_company FROM company_settings LIMIT 1;
  SELECT full_name, email INTO v_user FROM users WHERE id = NEW.passenger_id;

  v_subtotal := ROUND(NEW.amount / 1.20, 2);
  v_kdv_amount := NEW.amount - v_subtotal;
  v_invoice_number := v_company.invoice_prefix ||
                      TO_CHAR(NOW(), 'YYYYMM') || '-' ||
                      LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

  INSERT INTO invoices (
    invoice_number, invoice_type, source_type, source_id,
    seller_name, seller_tax_number, seller_tax_office, seller_address,
    buyer_name, buyer_email,
    subtotal, kdv_rate, kdv_amount, total, currency, status
  ) VALUES (
    v_invoice_number, 'sale', 'taxi', NEW.id,
    v_company.name, v_company.tax_number, v_company.tax_office, v_company.address,
    COALESCE(v_user.full_name, 'Müşteri'), v_user.email,
    v_subtotal, v_kdv_rate, v_kdv_amount, NEW.amount, 'TRY', 'issued'
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_taxi_invoice
  AFTER UPDATE OF status ON taxi_rides
  FOR EACH ROW EXECUTE FUNCTION create_taxi_invoice();

-- Yemek siparişi tamamlandığında fatura oluştur
CREATE OR REPLACE FUNCTION create_food_invoice()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_invoice_number TEXT;
  v_company RECORD;
  v_user RECORD;
  v_merchant RECORD;
  v_subtotal DECIMAL(15,2);
  v_kdv_rate DECIMAL(5,2) := 10.00;
  v_kdv_amount DECIMAL(15,2);
BEGIN
  IF NEW.status != 'delivered' OR OLD.status = 'delivered' THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM invoices
    WHERE source_type = 'food' AND source_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_company FROM company_settings LIMIT 1;
  SELECT full_name, email INTO v_user FROM users WHERE id = NEW.user_id;
  SELECT name INTO v_merchant FROM merchants WHERE id = NEW.merchant_id;

  v_subtotal := ROUND(NEW.total_amount / 1.10, 2);
  v_kdv_amount := NEW.total_amount - v_subtotal;
  v_invoice_number := v_company.invoice_prefix ||
                      TO_CHAR(NOW(), 'YYYYMM') || '-' ||
                      LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

  INSERT INTO invoices (
    invoice_number, invoice_type, source_type, source_id,
    seller_name, seller_tax_number, seller_tax_office, seller_address,
    buyer_name, buyer_email,
    subtotal, kdv_rate, kdv_amount, total, currency, status
  ) VALUES (
    v_invoice_number, 'sale', 'food', NEW.id,
    COALESCE(v_merchant.name, v_company.name),
    v_company.tax_number, v_company.tax_office, v_company.address,
    COALESCE(v_user.full_name, 'Müşteri'), v_user.email,
    v_subtotal, v_kdv_rate, v_kdv_amount, NEW.total_amount, 'TRY', 'issued'
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_food_invoice
  AFTER UPDATE OF status ON orders
  FOR EACH ROW EXECUTE FUNCTION create_food_invoice();
```

Migration'ı Supabase MCP `apply_migration` ile uygula.

Ardından `c:\A\admin_panel\lib\features\invoices\screens\invoices_screen.dart` dosyasını oku. Mevcut PDF oluşturma butonlarını şu şekilde güncelle: Önce `invoices` tablosunda bu sipariş için kayıt var mı kontrol et. Varsa `pdf_url`'den indir; yoksa `InvoiceService.saveInvoice()` çağır (FIX 8'deki metod), ardından indir.

---

## FIX 10 — İade faturası akışı ekle

**Sorun (kod analizinden doğrulandı):**
`invoice_service.dart`'ta `exportPaymentsToExcel()` fonksiyonunda `refund_amount` ve `refund_reason` kolonları var — yani iade yapılabiliyor. Ama iade olduğunda karşı fatura (iade faturası) kesilmiyor.

**Görevin:**
`c:\A\admin_panel\lib\features\invoices\screens\invoices_screen.dart` dosyasını oku.

Ödeme tablosuna "İade Faturası Kes" butonu ekle — sadece `refund_amount > 0` ve daha önce iade faturası kesilmemiş satırlar için görünsün:

```dart
// Satır içinde, normal fatura butonunun yanına:
if ((double.tryParse(payment['refund_amount']?.toString() ?? '0') ?? 0) > 0)
  IconButton(
    icon: const Icon(Icons.assignment_return, size: 18, color: AppColors.warning),
    tooltip: 'İade Faturası Kes',
    onPressed: () => _createRefundInvoice(payment),
  ),
```

`_createRefundInvoice` metodunu şöyle yaz:

```dart
Future<void> _createRefundInvoice(Map<String, dynamic> payment) async {
  // Önce orijinal faturayı bul
  final supabase = ref.read(supabaseProvider);
  final original = await supabase
      .from('invoices')
      .select()
      .eq('source_type', 'taxi')
      .eq('source_id', payment['ride_id'] ?? payment['id'])
      .eq('invoice_type', 'sale')
      .maybeSingle();

  if (original == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce orijinal fatura oluşturulmalı')),
    );
    return;
  }

  // Zaten iade faturası kesilmiş mi?
  final existing = await supabase
      .from('invoices')
      .select()
      .eq('parent_invoice_id', original['id'])
      .eq('invoice_type', 'refund')
      .maybeSingle();

  if (existing != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu işlem için iade faturası zaten kesilmiş')),
    );
    return;
  }

  final refundAmount = double.tryParse(payment['refund_amount']?.toString() ?? '0') ?? 0;
  final kdvRate = 0.20;
  final kdvAmount = refundAmount * kdvRate / (1 + kdvRate);
  final subtotal = refundAmount - kdvAmount;

  await InvoiceService.saveInvoice(
    sourceType: 'taxi',
    sourceId: payment['ride_id'] ?? payment['id'],
    buyerName: payment['users']?['full_name'] ?? 'Müşteri',
    buyerEmail: payment['users']?['email'],
    subtotal: subtotal,
    kdvRate: kdvRate * 100,
    kdvAmount: kdvAmount,
    total: refundAmount,
    invoiceType: 'refund',
    parentInvoiceId: original['id'],
    items: [
      {
        'description': 'İade: ${payment['refund_reason'] ?? 'Hizmet iadesi'}',
        'quantity': 1,
        'unit_price': subtotal,
        'total': subtotal,
      }
    ],
  );

  // Orijinal faturayı 'cancelled' yap
  await supabase.from('invoices')
      .update({'status': 'cancelled', 'cancelled_at': DateTime.now().toIso8601String()})
      .eq('id', original['id']);

  ref.invalidate(paymentsProvider);
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('İade faturası oluşturuldu'), backgroundColor: Colors.green),
  );
}
```

---

## FIX 11 — Fatura arama, filtreleme ve arşiv ekranı

**Sorun (kod analizinden doğrulandı):**
`c:\A\admin_panel\lib\features\invoices\screens\invoices_screen.dart` dosyasında faturalar yalnızca ödeme tiplerine göre 2 tab halinde gösteriliyor (Ödemeler / Yemek Siparişleri). `invoices` tablosu artık var (FIX 6 sonrası), oradan merkezi bir arşiv ekranı yapılmalı.

**Görevin:**
`c:\A\admin_panel\lib\features\invoices\screens\invoices_screen.dart` dosyasını oku.

Mevcut `TabBar`'a üçüncü bir tab ekle: **"Fatura Arşivi"**

Bu tab için yeni bir provider yaz:

```dart
final invoiceArchiveProvider = FutureProvider.family<
    List<Map<String, dynamic>>, Map<String, dynamic>>((ref, filters) async {
  final supabase = ref.watch(supabaseProvider);

  var query = supabase
      .from('invoices')
      .select('*, invoice_items(*)')
      .order('created_at', ascending: false);

  if (filters['source_type'] != null)
    query = query.eq('source_type', filters['source_type']);
  if (filters['status'] != null)
    query = query.eq('status', filters['status']);
  if (filters['invoice_type'] != null)
    query = query.eq('invoice_type', filters['invoice_type']);
  if (filters['date_from'] != null)
    query = query.gte('created_at', filters['date_from']);
  if (filters['date_to'] != null)
    query = query.lte('created_at', filters['date_to']);
  if (filters['search'] != null && (filters['search'] as String).isNotEmpty)
    query = query.or(
      'invoice_number.ilike.%${filters['search']}%,'
      'buyer_name.ilike.%${filters['search']}%,'
      'buyer_email.ilike.%${filters['search']}%'
    );

  final response = await query.limit(200);
  return List<Map<String, dynamic>>.from(response);
});
```

Tab içeriğinde şunlar olsun:
- Arama kutusu (fatura no, müşteri adı, email)
- Filtre chip'leri: kaynak tipi (taxi/food/store), durum (issued/sent/cancelled), tür (sale/refund)
- DataTable2 ile liste: Fatura No | Tarih | Müşteri | Tutar | KDV | Toplam | Tür | Durum | İndir
- "İndir" butonuna basılınca: `pdf_url` varsa direkt aç; yoksa `InvoiceService.saveInvoice()` çağırıp sonra aç
- Toplamda kaç fatura, toplam ciro, toplam KDV gösteren özet satırı en üstte
