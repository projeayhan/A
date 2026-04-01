# Panel Auditörü — Test Raporu

Denetim Tarihi: 2026-03-15
Denetlenen Paneller: admin_panel, support_panel, merchant_panel
Metodoloji: Statik kod analizi (Read, Grep, Glob araçları)

---

## KRİTİK

- [ ] **Supabase Anon Key kaynak kodunda hardcoded (açık metin)** | `c:/A/admin_panel/lib/core/services/supabase_service.dart:30`, `c:/A/support_panel/lib/core/services/supabase_service.dart:24`, `c:/A/merchant_panel/lib/core/services/supabase_service.dart:44` — Tüm üç panelde aynı JWT anon key açık string literal olarak kaynak koduna gömülmüş. Kaynak kodu ele geçiren biri bu key ile Supabase projesine doğrudan erişim sağlayabilir.

- [ ] **Admin ban işlemi super_app'a yansımıyor — izolasyon eksikliği** | `c:/A/admin_panel/lib/features/users/screens/users_screen.dart:642-645`, `c:/A/admin_panel/lib/features/sanctions/services/sanction_service.dart:51-54` — Admin kullanıcıyı yasakladığında (ban) yalnızca `users` tablosunda `is_banned=true` güncelleniyor. super_app'ta `auth_provider.dart` veya oturum kontrol akışında `is_banned` alanı hiç kontrol edilmiyor (`grep` doğruladı: super_app/lib/core içinde `is_banned` eşleşmesi yok). Yasaklanan kullanıcı super_app'a girmeye ve işlem yapmaya devam edebilir.

- [ ] **Merchant deaktivasyon → merchant_panel erişim engeli eksik** | `c:/A/merchant_panel/lib/features/auth/screens/login_screen.dart:120-131` — Login ekranı sadece `is_approved` kontrolü yapıyor; admin `is_approved=false` yapsa dahi mevcut oturum token'ları geçerliliğini korur. Aktif oturumu olan bir merchant admin tarafından onayı kaldırıldıktan sonra oturumu otomatik sonlandırılmadan paneli kullanmaya devam edebilir (token invalidation mekanizması yok).

- [ ] **Admin router guard RBAC'ı yüksek admin yüklenene kadar boş geçiyor** | `c:/A/admin_panel/lib/core/router/app_router.dart:156-165` — `admin = adminAsync.valueOrNull` null döndüğünde (veri henüz yüklenmediyse) permission check atlanarak `null` return ediliyor. Bu kısa süreliğine yetki gerektiren sayfalara erişim imkânı tanıyabilir.

---

## YÜKSEK

- [ ] **support_panel — Tüm ticketlar tüm ajanlara açık; ajan izolasyonu yok** | `c:/A/support_panel/lib/core/services/ticket_service.dart:31-85`, `c:/A/support_panel/lib/features/tickets/screens/tickets_screen.dart:108-131` — `fetchTickets()` çağrısı herhangi bir `agent_id` filtresi olmadan tüm `support_tickets` tablosunu sorguluyor. Ajanlar kendi atanmamış ticketları da dahil olmak üzere tüm ticketları görebiliyor. Bu özellikle hassas müşteri bilgilerini içeren ticketlarda veri sızıntısı riski taşımaktadır. (Not: "Benim Ticketlarım" filtresi opsiyonel, varsayılan filtre değil.)

- [ ] **support_panel — chat_service.dart tüm aktif ticketları tüm ajanlara gösteriyor** | `c:/A/support_panel/lib/core/services/chat_service.dart:20-37` — `getActiveChats()` hiçbir ajan filtresi uygulamıyor; başka bir ajanın yürüttüğü canlı sohbetler de listeleniyor.

- [ ] **Merchant izolasyonu RLS'e tamamen bırakılmış; uygulama katmanında kontrol yok** | `c:/A/merchant_panel/lib/core/providers/merchant_provider.dart` — `ordersProvider`, `menuItemsProvider`, `productsProvider` vb. sorgular `merchant_id` ile filtreleniyor, ancak bu `merchant_id` değeri `currentMerchantProvider`'dan gelen değere dayanıyor. Eğer RLS politikaları Supabase'de düzgün yapılandırılmamışsa (bu denetim kapsamında doğrulanamadı), kötü niyetli kullanıcı kendi merchant_id'sini değiştirerek başka merchant verisine erişebilir. Uygulama katmanında sunucu taraflı izolasyon doğrulaması yapılmıyor.

- [ ] **Admin Rental Dashboard'da TODO: booking aksiyonları hiç implement edilmemiş** | `c:/A/admin_panel/lib/features/rental/screens/rental_dashboard_screen.dart:538-544` — Booking görüntüleme, onaylama ve iptal etme fonksiyonları `// TODO:` comment'i olarak bırakılmış, hiçbir işlem kodu yok. Kiralama modülü admin tarafından yönetilemiyor.

- [ ] **Merchant kaydı auto_confirm_email RPC çağrısı sessizce başarısız olabiliyor** | `c:/A/merchant_panel/lib/features/auth/screens/register_screen.dart:66` — `auto_confirm_email` RPC'si `try { } catch (_) {}` bloğu ile çağrılıyor; hata tamamen yutulmaktadır. E-posta onaylanmadan kayıt ilerleyebilir.

- [ ] **PDF önizleme fonksiyonu implement edilmemiş (TODO)** | `c:/A/admin_panel/lib/features/invoices/screens/invoices_screen.dart:1590` — `_previewPdf()` içinde yalnızca `// TODO: Implement preview` var, kullanıcıya sadece snackbar gösteriliyor.

---

## ORTA

- [ ] **Users ekranı search filtresi client-side uygulanıyor; büyük veri setleri için performans sorunu** | `c:/A/admin_panel/lib/features/users/screens/users_screen.dart:290-300` — Search query debounce ile alınmasına rağmen `_fetchUsers()` fonksiyonu filtre uygulamıyor; filtering yüklenen sayfa verisi üzerinde client-side yapılıyor. Search değiştiğinde yeniden fetch çalışmıyor.

- [ ] **Merchant ban işleminde oturum sonlandırılmıyor** | `c:/A/admin_panel/lib/features/merchants/screens/merchants_screen.dart:742-770` — `_rejectMerchant()` sadece `is_approved=false` yapıyor. Mevcut oturumu sonlandırmak için Supabase `admin.auth.deleteUser` ya da token invalidation kullanılmıyor.

- [ ] **Sanctions ekranında ban süresi alanı sayı validasyonu yok** | `c:/A/admin_panel/lib/features/sanctions/screens/sanctions_screen.dart:309-315` — `_daysController` TextEditingController `keyboardType: TextInputType.number` kullanıyor ama `int.parse()` çağrısında (satır 378) hata yönetimi zayıf; negatif sayı veya sıfır girişi kontrol edilmiyor.

- [ ] **Admin RBAC redirect yalnızca `routePermissions` map'inde kayıtlı rotalar için çalışıyor** | `c:/A/admin_panel/lib/core/services/permission_config.dart` — `AppRoutes.carSalesDealerApplications` gibi bazı route'lar `routePermissions` map'inde eksik; bu route'lara yetkisiz admin erişebilir.

- [ ] **Support panel router'da agentState loading durumunda redirect davranışı belirsiz** | `c:/A/support_panel/lib/core/router/app_router.dart:36` — `agentState.value != null` kontrolü `AsyncValue.loading()` için `false` döndürüyor; sayfa yüklenirken kullanıcı login sayfasına yönlendirebilir.

- [ ] **Merchant shell route guard async yükleme sırasında çalışmıyor** | `c:/A/merchant_panel/lib/shared/widgets/merchant_shell.dart:78-97` — MerchantShell build metodunda `merchant.valueOrNull` null iken (yükleme sırasında) route guard tamamen atlanıyor. Kısa süreliğine tüm sayfalara erişim açılıyor.

- [ ] **Admin notifications ekranındaki "Tümünü Gör" butonu işlevsiz** | `c:/A/admin_panel/lib/features/finance/screens/finance_screen.dart:749` — `onPressed: () {}` — Boş callback, hiçbir navigasyon veya aksiyona bağlı değil.

- [ ] **Merchant kayıt ekranında adres bilgisi toplanmıyor** | `c:/A/merchant_panel/lib/features/auth/screens/register_screen.dart` — Kayıt formu yalnızca işletme adı, email, telefon, şifre ve tip alıyor. Adres, vergi numarası gibi zorunlu işletme bilgileri toplanmıyor.

- [ ] **Sipariş status güncellemesi (Kanban drag-drop) başarısız olunca kullanıcıya bildirim yok** | `c:/A/merchant_panel/lib/shared/screens/orders_kanban_screen.dart:466-484` — `_updateOrderStatus()` hata yakalamıyor; provider güncelleme başarısız olsa bile snackbar başarı mesajı gösteriyor.

---

## DÜŞÜK

- [ ] **Invoice PDF'de şirket iletişim bilgisi (email) hardcoded placeholder** | `c:/A/admin_panel/lib/core/services/invoice_service.dart:23` — `'email': 'fatura@odabase.com'` sabit değer; bu alan dinamik olarak yapılandırılmış ayarlardan gelmeli.

- [ ] **Merchant panel PDF raporu export hatalarını sessizce yutabiliyor** | `c:/A/merchant_panel/lib/core/services/report_export_service.dart:55-58` — `catch (e)` bloğu `debugPrint` yapıp `false` döndürüyor; kullanıcıya hata mesajı gösterilmiyor.

- [ ] **Admin panel kullanıcı listesi export tüm kullanıcıları çekiyor (limit yok)** | `c:/A/admin_panel/lib/features/users/screens/users_screen.dart:515` — `supabase.from('users').select().order(...)` çağrısı limit veya pagination içermiyor; çok büyük kullanıcı setlerinde bellek problemi ve zaman aşımı riski.

- [ ] **Finance raporu "Tümünü Gör" butonu işlevsiz** | `c:/A/admin_panel/lib/features/finance/screens/finance_screen.dart:749` — `onPressed: () {}` — Boş callback.

- [ ] **Destek paneli login ekranı forgot-password rotası tanımlı değil** | `c:/A/support_panel/lib/core/router/app_router.dart` — Admin panel ve merchant panelin aksine support_panel'de şifremi-unuttum rotası yok.

- [ ] **Merchant export hizmeti iOS/macOS dışında (web/linux) test edilmemiş olabilir** | `c:/A/merchant_panel/lib/core/services/report_export_service.dart:1` — `dart:io` import içeriyor; web platform için `path_provider` çalışmaz. Bu web deployment için sorun oluşturur.

- [ ] **Admin rental_dashboard_screen booking aksiyonlarında TODO olan 3 kritik fonksiyon** | `c:/A/admin_panel/lib/features/rental/screens/rental_dashboard_screen.dart:538,541,544` — Rezervasyon görüntüleme, onaylama ve iptal fonksiyonları tamamen eksik.

- [ ] **Merchant kanban ekranı: _KanbanOrderMessagesCard sender_name hardcoded 'Restoran'** | `c:/A/merchant_panel/lib/shared/screens/orders_kanban_screen.dart:696` — Gerçek merchant adı yerine "Restoran" yazıyor; market ve mağaza türü merchant'lar için tutarsız UX.

---

## ÖZET

- **Toplam sorun: 22 (Kritik: 4, Yüksek: 7, Orta: 9, Düşük: 7)**

### En Önemli 3 Bulgu

1. **Supabase Anon Key kaynak kodunda açık (tüm 3 panel)** — Üç panelde de (`admin_panel`, `support_panel`, `merchant_panel`) aynı Supabase anon JWT token kaynak koduna string literal olarak gömülmüş. Bu key versiyon kontrolüne ve derlenen APK/web bundle'a sızıyor. Bir saldırgan bu key ile Supabase REST API'sine doğrudan erişip RLS politikalarını bypass edebilir. Acilen environment variable veya secret management çözümüne geçilmeli.

2. **Admin ban işlemi super_app'a yansımıyor** — Admin panelden kullanıcıyı yasaklamak yalnızca veritabanındaki `is_banned` alanını güncelliyor; ancak super_app auth akışında bu alan kontrol edilmiyor. Yasaklanan kullanıcılar mevcut token'ları ile platformu kullanmaya devam edebiliyor. Ban işleminin aktif oturumları sonlandırması ve super_app'ta `is_banned` kontrolünün eklenmesi gerekiyor.

3. **Support panel — ajan izolasyonu yok; tüm ticketlar tüm ajanlara görünür** — `fetchTickets()` ve `getActiveChats()` fonksiyonları ajan bazlı filtreleme yapmıyor. Varsayılan görünümde tüm ajanların tüm ticketları görmesi veri gizliliği açısından risk teşkil ediyor. Ticketlar yalnızca ilgili ajana gösterilmeli ve erişim Supabase RLS politikalarıyla kısıtlanmalı.
