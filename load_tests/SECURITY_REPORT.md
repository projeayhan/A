# 🔒 Supabase Güvenlik Raporu

**Tarih:** 2026-01-22
**Proje:** Super App

---

## 🔴 KRİTİK GÜVENLİK UYARILARI

### 1. Auth Users Exposed (ERROR)

**Sorun:** `user_profiles` view'ı `auth.users` tablosunu `anon` rolüne açıyor.

**Risk:** Kimliği doğrulanmamış kullanıcılar hassas kullanıcı verilerine erişebilir.

**Çözüm:**
```sql
-- user_profiles view'ını güvenli hale getir
DROP VIEW IF EXISTS public.user_profiles;

CREATE VIEW public.user_profiles AS
SELECT
  id,
  -- Sadece gerekli ve güvenli alanları seç
  COALESCE(raw_user_meta_data->>'full_name', '') as full_name,
  COALESCE(raw_user_meta_data->>'avatar_url', '') as avatar_url
FROM auth.users;

-- Sadece authenticated kullanıcılar erişebilsin
REVOKE ALL ON public.user_profiles FROM anon;
GRANT SELECT ON public.user_profiles TO authenticated;

-- RLS ekle
ALTER VIEW public.user_profiles SET (security_invoker = on);
```

---

### 2. Security Definer Views (ERROR)

**Etkilenen View'lar:**
- `public.company_rating_summary`
- `public.properties_with_promotion_status`

**Sorun:** SECURITY DEFINER ile tanımlı view'lar, view'ı oluşturan kullanıcının yetkilerini kullanır, sorgulayan kullanıcının değil.

**Risk:** RLS politikaları bypass edilebilir.

**Çözüm:**
```sql
-- Her view için SECURITY INVOKER'a geç
ALTER VIEW public.company_rating_summary SET (security_invoker = on);
ALTER VIEW public.properties_with_promotion_status SET (security_invoker = on);
```

---

## ⚠️ ÖNERİLEN DÜZELTMELER

### Migration ile Düzeltme

Aşağıdaki migration'ı uygulayarak tüm güvenlik sorunlarını düzeltebiliriz:

```sql
-- 1. user_profiles view güvenliği
DO $$
BEGIN
  -- Anon erişimini kaldır
  REVOKE ALL ON public.user_profiles FROM anon;
  GRANT SELECT ON public.user_profiles TO authenticated;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 2. Security definer view'ları düzelt
ALTER VIEW public.company_rating_summary SET (security_invoker = on);
ALTER VIEW public.properties_with_promotion_status SET (security_invoker = on);
```

---

## 📊 Güvenlik Özeti

| Kategori | Sayı | Öncelik |
|----------|------|---------|
| Auth Users Exposed | 1 | 🔴 Kritik |
| Security Definer Views | 2+ | 🔴 Kritik |
| Diğer | - | - |

---

## ✅ Yapılacaklar

- [ ] `user_profiles` view'ından anon erişimini kaldır
- [ ] Security definer view'ları security invoker'a çevir
- [ ] Tüm tablolarda RLS aktif mi kontrol et
- [ ] Hassas tablolara (orders, payments) anon erişimi var mı kontrol et

---

## 🔗 Referanslar

- [Supabase Database Linter](https://supabase.com/docs/guides/database/database-linter)
- [Auth Users Exposed](https://supabase.com/docs/guides/database/database-linter?lint=0002_auth_users_exposed)
- [Security Definer View](https://supabase.com/docs/guides/database/database-linter?lint=0010_security_definer_view)
