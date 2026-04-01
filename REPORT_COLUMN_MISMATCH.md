# Admin Panel - Veritabanı Kolon Uyumsuzlukları Raporu

**Tarih:** 2026-03-17
**Analiz:** 4 paralel agent ile admin_panel/ altındaki tüm servis, ekran, provider, widget ve model dosyaları tarandı ve Supabase veritabanı şemasıyla karşılaştırıldı.

---

## ÖZET

| Kategori | Adet |
|----------|------|
| Var olmayan tablo referansları | 5 |
| Var olmayan kolona YAZMA (insert/update) | ~30 |
| Var olmayan kolondan OKUMA (select/read) | ~35 |
| **Toplam uyumsuzluk** | **~70** |

---

## 1. VAR OLMAYAN TABLOLAR (Runtime Crash)

Bu tablolar veritabanında hiç yok, tüm işlemler çökecek:

### 1.1 `sanctions`
- **Dosya:** `features/sanctions/services/sanction_service.dart`
- **Kullanım:** CRUD işlemleri (select, insert, update, delete)
- **Referans edilen kolonlar:** `id, user_id, reason, type, status, expires_at, created_at, lifted_at`
- **Çözüm:** Bu tablo oluşturulmalı veya mevcut bir tabloya (ör. `users` üzerinde ban sistemi) taşınmalı

### 1.2 `surge_rules`
- **Dosya:** `features/surge/screens/surge_screen.dart`
- **Kullanım:** CRUD işlemleri
- **Referans edilen kolonlar:** `id, name, start_time, end_time, demand_threshold, current_multiplier, created_at`
- **Çözüm:** Mevcut `surge_zones` tablosu var ama farklı yapıda. Ya `surge_rules` oluşturulmalı ya da kod `surge_zones` kullanacak şekilde düzeltilmeli

### 1.3 `sector_settings`
- **Dosya:** `features/business/screens/sector_settings_screen.dart`
- **Kullanım:** select, upsert
- **Referans edilen kolonlar:** `sector, key, value`
- **Çözüm:** Tablo oluşturulmalı veya `system_settings` tablosu kullanılmalı

### 1.4 `courier_assignments`
- **Dosya:** `features/merchant_management/screens/admin_couriers_screen.dart`
- **Kullanım:** insert, delete
- **Referans edilen kolonlar:** `id, merchant_id, courier_id`
- **Çözüm:** Mevcut `merchant_couriers` tablosu aynı amaca hizmet ediyor, kod o tabloya yönlendirilmeli

### 1.5 `profiles`
- **Dosya:** `features/notifications/services/notification_service.dart:29`
- **Kullanım:** `.from('profiles').select('id, full_name, email, phone')`
- **Çözüm:** `users` tablosu kullanılmalı

---

## 2. KRİTİK KOLON UYUMSUZLUKLARI (Veri Kaybı / Hatalı Yazma)

### 2.1 `notifications` tablosu
**Dosya:** `features/notifications/services/notification_service.dart:49-57`

| Kodda kullanılan | DB'de gerçek kolon | Durum |
|---|---|---|
| `target_type` | - | YOK |
| `target_id` | - | YOK |
| `notification_type` | `type` | YANLIŞ İSİM |
| `scheduled_at` | - | YOK |
| `status` | - | YOK |

**Etki:** Bildirim gönderme tamamen bozuk.

### 2.2 `finance_entries` tablosu
**Dosya:** `features/finance/services/accounting_service.dart:290-402`

| Kodda kullanılan | DB'de gerçek kolon | Durum |
|---|---|---|
| `type` | `entry_type` | YANLIŞ İSİM |
| `source` | `source_type` | YANLIŞ İSİM |
| `reference_id` | `source_id` | YANLIŞ İSİM |

**Etki:** Finans kayıtları oluşturulamıyor ve okunamıyor. Hem insert hem select hem filter etkileniyor.

### 2.3 `users` tablosu
**Dosya:** `features/sanctions/services/sanction_service.dart:53,87` ve screen dosyaları

| Kodda kullanılan | DB'de gerçek kolon | Durum |
|---|---|---|
| `is_banned` | - | YOK |
| `status` | - | YOK |

**Etki:** Kullanıcı yasaklama/ban sistemi tamamen çalışmıyor.

### 2.4 `invoices` tablosu
**Dosya:** `features/finance/services/accounting_service.dart:413`

| Kodda kullanılan | DB'de gerçek kolon | Durum |
|---|---|---|
| `paid_at` | - | YOK |

### 2.5 `invoice_items` tablosu
**Dosya:** `features/finance/services/accounting_service.dart`

| Kodda kullanılan | DB'de gerçek kolon | Durum |
|---|---|---|
| `item_description` | `description` | YANLIŞ İSİM |

---

## 3. SEKTÖR BAZLI KOLON UYUMSUZLUKLARI

### 3.1 `merchants` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `merchant_type` | `type` | `global_search_overlay.dart`, `dashboard_screen.dart` |
| `total_revenue` | - (YOK) | `business_service.dart:127` |
| `status` | `is_approved` | `merchants_screen.dart`, `applications_screen.dart` |
| `rejection_reason` | - (YOK) | `applications_screen.dart` |
| `reviewed_at` | - (YOK) | `applications_screen.dart` |
| `estimated_delivery_time` | `avg_preparation_time` | `applications_screen.dart` |
| `opening_time` | `working_hours` (JSON) | `applications_screen.dart` |
| `closing_time` | `working_hours` (JSON) | `applications_screen.dart` |

### 3.2 `car_dealers` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `notify_email` | - (YOK) | `admin_dealer_settings_screen.dart` |
| `notify_sms` | - (YOK) | `admin_dealer_settings_screen.dart` |
| `is_approved` | `status` + `is_verified` | `admin_dealer_settings_screen.dart` |
| `commission_rate` | - (YOK) | `admin_dealer_settings_screen.dart` |
| `is_active` | - (YOK) | `admin_dealer_settings_screen.dart` |
| `admin_notes` | - (YOK) | `admin_dealer_settings_screen.dart` |
| `rating` | `average_rating` | `business_service.dart` |
| `review_count` | `total_reviews` | `business_service.dart` |
| `total_revenue` | - (YOK) | `business_service.dart` |

### 3.3 `realtors` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `full_name` | - (YOK) | `global_search_overlay.dart` |
| `about` | `bio` | `admin_realtor_settings_screen.dart` |
| `contact_email` | `email` | `admin_realtor_settings_screen.dart` |
| `contact_phone` | `phone` | `admin_realtor_settings_screen.dart` |
| `push_notifications` | `notifications_enabled` | `admin_realtor_settings_screen.dart` |
| `email_notifications` | - (YOK) | `admin_realtor_settings_screen.dart` |
| `sms_notifications` | - (YOK) | `admin_realtor_settings_screen.dart` |
| `commission_rate` | - (YOK) | `admin_realtor_settings_screen.dart` |
| `admin_notes` | - (YOK) | `admin_realtor_settings_screen.dart` |
| `latitude` / `longitude` | - (YOK) | `admin_realtor_settings_screen.dart` |
| `rating` | `average_rating` | `business_service.dart` |
| `review_count` | `total_reviews` | `business_service.dart` |
| `total_listings` | - (YOK) | `business_service.dart`, `sector_type.dart` |

### 3.4 `rental_companies` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `push_notifications` | - (YOK) | `admin_rental_settings_screen.dart` |
| `email_notifications` | - (YOK) | `admin_rental_settings_screen.dart` |
| `sms_notifications` | - (YOK) | `admin_rental_settings_screen.dart` |
| `admin_notes` | - (YOK) | `admin_rental_settings_screen.dart` |
| `latitude` / `longitude` | - (YOK) | `admin_rental_settings_screen.dart` |
| `total_revenue` | - (YOK) | `business_service.dart` |

### 3.5 `rental_cars` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `vehicle_color` | - (YOK) | `rental_service.dart` |
| `rating` | - (YOK) | `rental_service.dart` |
| `review_count` | - (YOK) | `rental_service.dart` |
| `mileage` | `mileage_limit` | `rental_service.dart` |
| `fuel_level` | - (YOK) | `rental_service.dart` |
| `discount_percentage` | - (YOK) | `rental_service.dart` |

### 3.6 `rental_locations` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `available_car_count` | - (YOK) | `rental_service.dart` |
| `total_car_count` | - (YOK) | `rental_service.dart` |
| `working_hours` | `opening_time` + `closing_time` | `admin_rental_locations_screen.dart` |

### 3.7 `taxi_drivers` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `commission_rate` | - (YOK, `platform_commissions`'da) | `taxi_management_providers.dart` |
| `suspend_reason` | - (YOK) | `admin_driver_settings_screen.dart` |
| `admin_notes` | - (YOK) | `admin_driver_settings_screen.dart` |

### 3.8 `taxi_rides` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `toll_amount` | - (YOK, `payments`'da) | `taxi_management_providers.dart` |

### 3.9 `taxi_reviews` tablosu (VAR OLMAYAN TABLO)
- **Dosya:** `sector_type.dart:204`
- Taksi review'ları ayrı tabloda değil, `taxi_rides` tablosunda `rating` + `rating_comment` olarak tutuluyor

---

## 4. DİĞER UYUMSUZLUKLAR

### 4.1 `admin_users` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `phone` | - (YOK) | `admin_auth_service.dart:46` |
| `avatar_url` | - (YOK) | `admin_auth_service.dart:47` |
| `two_factor_enabled` | - (YOK) | `admin_auth_service.dart:53` |

### 4.2 `properties` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `area_sqm` | `square_meters` | `admin_property_listings_screen.dart` |
| `floor_number` | `floor` | `admin_property_listings_screen.dart` |
| `facing` | `facing_direction` | `admin_property_listings_screen.dart` |
| `features` | - (ayrı boolean kolonlar) | `admin_property_listings_screen.dart` |
| `user_email` | - (YOK) | `emlak_admin_service.dart` |
| `user_phone` | - (YOK) | `emlak_admin_service.dart` |

### 4.3 `job_listings` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `location` | `city` + `district` + `address` | `admin_company_jobs_screen.dart` |
| `employment_type` | `job_type` | `admin_company_jobs_screen.dart` |
| `requirements` | `qualifications` | `admin_company_jobs_screen.dart` |
| `benefits` | `manual_benefits` | `admin_company_jobs_screen.dart` |
| `rejection_reason` | - (YOK) | `admin_company_jobs_screen.dart` |

### 4.4 `job_skills` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `is_active` | - (YOK) | `job_listings_admin_service.dart` |
| `sort_order` | - (YOK) | `job_listings_admin_service.dart` |

### 4.5 `partner_applications` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `first_name` / `last_name` | `full_name` | `applications_screen.dart` |
| `national_id` | `tc_no` | `applications_screen.dart` |
| `date_of_birth` | - (YOK) | `applications_screen.dart` |
| `avatar_url` | `profile_photo_url` | `applications_screen.dart` |

### 4.6 `realtor_applications` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `city` | `working_cities` | `applications_screen.dart` |
| `tc_no` | - (YOK) | `applications_screen.dart` |
| `service_cities` | `working_cities` | `applications_screen.dart` |

### 4.7 `couriers` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `avatar_url` | `profile_photo_url` | `admin_couriers_screen.dart` |

### 4.8 `companies` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `company_name` | `name` | `admin_company_settings_screen.dart` |
| `sector` | `industry` | `admin_company_settings_screen.dart` |
| `suspension_reason` | - (YOK) | `admin_company_settings_screen.dart` |
| `job_limit` | - (YOK) | `admin_company_settings_screen.dart` |
| `package_type` | - (YOK) | `admin_company_settings_screen.dart` |
| `package_name` | - (YOK) | `admin_company_settings_screen.dart` |
| `package_expires_at` | - (YOK) | `admin_company_settings_screen.dart` |

### 4.9 `products` tablosu

| Kodda kullanılan | DB'de gerçek kolon | Dosya |
|---|---|---|
| `unit_type` | `weight_unit` | `admin_products_screen.dart` |

### 4.10 `driver_documents` tablosu (VAR OLMAYAN TABLO)
- **Dosya:** `taxi_management_providers.dart:135`
- En yakın tablo: `partner_documents`

---

## 5. ÖNCELİK SIRASI

### Acil Düzeltilmesi Gerekenler (Crash / Veri Kaybı):
1. `sanctions` tablosu oluşturulmalı veya alternatif mekanizma kurulmalı
2. `notifications` insert kolon isimleri düzeltilmeli
3. `finance_entries` kolon isimleri düzeltilmeli (`type`→`entry_type`, `source`→`source_type`, `reference_id`→`source_id`)
4. `users.is_banned` mekanizması oluşturulmalı
5. `surge_rules` → `surge_zones` kullanmalı
6. `sector_settings` tablosu oluşturulmalı veya `system_settings` kullanılmalı
7. `courier_assignments` → `merchant_couriers` kullanmalı
8. `profiles` → `users` kullanmalı

### Yüksek Öncelikli (Ayarlar Kaydedilemiyor):
9. `car_dealers` ayar ekranı - 6 phantom kolon
10. `realtors` ayar ekranı - 9+ phantom kolon
11. `rental_companies` ayar ekranı - 5 phantom kolon
12. `taxi_drivers` ayar ekranı - 2 phantom kolon
13. `companies` ayar ekranı - 7 phantom kolon

### Orta Öncelikli (Yanlış Veri Gösterimi):
14. `merchants.merchant_type` → `type`
15. `car_dealers.rating` → `average_rating`, `review_count` → `total_reviews`
16. `realtors.rating` → `average_rating`, `review_count` → `total_reviews`
17. `properties.area_sqm` → `square_meters`, `floor_number` → `floor`
18. `job_listings` kolon düzeltmeleri
19. `partner_applications` kolon düzeltmeleri
20. `couriers.avatar_url` → `profile_photo_url`
