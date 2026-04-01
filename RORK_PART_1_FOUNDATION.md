# RORK PART 1 - Foundation (Auth + Home + Profile + Navigation)

Aşağıdaki prompt'u Rork'a ver. Bu ilk parça: Temel yapı, auth, home screen, profil ve navigasyon.

---

```
Build a React Native (Expo) super app called "SuperCyp" with TypeScript. This app connects to an EXISTING Supabase backend - do NOT create any tables or modify the backend. Use exact table/column names I provide.

This is PART 1: Foundation - Authentication, Home Screen, Profile, Settings, and Navigation shell. Future parts will add service modules (Food, Taxi, Emlak, etc.) into this structure.

## SUPABASE CONNECTION
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY
- Use @supabase/supabase-js
- Auth uses PKCE flow

## STRIPE (setup now, used later)
- Publishable Key: pk_test_51SVdN5FDnYENSMiEmmn7zxiTQn8WLL6wqYr4xXnFMzVxfs1YkBLCqbGTivtYzQGBhrsbsLE2vzgXAbjp5Oj2rZcT00MzbxivbO

## GOOGLE MAPS (setup now, used later)
- API Key: AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ

---

## UI/UX DESIGN SYSTEM (Apply to ENTIRE app)

### Design Philosophy
Modern, clean, premium feel. Think Uber + Getir + Bolt combined. NOT a generic template. Lots of whitespace, smooth animations, glass-morphism touches on navigation.

### Colors
**Primary:** #256AF4 (Blue)
**Food Accent:** #EC6D13 (Orange) - for food screens later
**Store Accent:** #6366F1 (Indigo) - for store screens later
**Status:** Success #10B981, Warning #F59E0B, Error #EF4444, Info #3B82F6

**Light Theme:**
Background: #FFFFFF, Surface: #F8F9FC, Text: #0D121C, Text Secondary: #6B7280, Border: #E5E7EB

**Dark Theme:**
Background: #101622, Surface: #1A2230, Text: #FFFFFF, Text Secondary: #9CA3AF, Border: #374151

### Typography (System fonts)
- Page Title: 18px bold
- Section Title: 15px bold
- Card Title: 13px bold
- Body: 13px, Body Small: 12px, Caption: 11px
- Price: 14px bold
- Button: 14px semibold (600)
- Tab Label: 10px, bold when active

### Spacing
- Page padding: 12px horizontal
- Section gap: 16px
- Card padding: 8-12px
- List item gap: 8px

### Border Radius
- Badges/chips: 6px
- Inputs/buttons/cards: 10px
- Large cards/images: 12px
- Feature cards: 16px
- Bottom sheets: 20px top only

### Shadows
- Card: 0 2px 8px rgba(0,0,0,0.05)
- Elevated: 0 4px 12px rgba(0,0,0,0.1)
- Bottom nav: 0 -4px 20px rgba(0,0,0,0.05)
- Primary button: 0 4px 12px rgba(37,106,244,0.3)

### Buttons
**Primary:** #256AF4 bg, white text, 44px height, 10px radius, blue glow shadow, full width
**Secondary:** transparent bg, 1px border #E5E7EB, 40px height, 10px radius

### Inputs
- Filled style, surface bg, 10px radius, 1px border, 1.5px primary on focus, 12px padding, dense

### Loading States
- Skeleton/shimmer for all lists (NOT spinners)
- Shimmer: grey[300] → grey[100] pulse, 1.5s, match card dimensions

### Animations
- Card press: scale 0.98, 100ms
- Button press: scale 0.95, haptic
- Page transitions: slide from right
- Tab switch: cross-fade
- List items: fade in + slide up, staggered 50ms
- Bottom sheets: spring animation
- Favorite: heart bounce + color
- Images: fade-in on load with placeholder

---

## AUTHENTICATION

### Auth Methods (Supabase Auth):
1. **Email/Password** - supabase.auth.signUp / signInWithPassword
2. **Google OAuth** - supabase.auth.signInWithOAuth({ provider: 'google' })
3. **Apple OAuth** - supabase.auth.signInWithOAuth({ provider: 'apple' })
4. **Phone OTP** - Call edge function:
   - Send: supabase.functions.invoke('phone-verify', { body: { phone, action: 'send' } })
   - Verify: supabase.functions.invoke('phone-verify', { body: { phone, action: 'verify', code } })

### Auth Flow:
1. App launch → check supabase.auth.getSession()
2. No session → show Login screen
3. After login → fetch user from `users` table where id = auth.user.id
4. If user.is_banned === true → sign out, show "Hesabınız askıya alınmıştır" error
5. If user.first_name is null/empty → redirect to Personal Info screen
6. Otherwise → go to Home

### Auth Screens:

**Login Screen:**
- Logo + "SuperCyp" title at top
- Email input + Password input
- "Giriş Yap" primary button
- "Şifremi Unuttum" text link
- Divider with "veya" text
- Google sign-in button (white bg, Google logo, "Google ile Giriş")
- Apple sign-in button (black bg, Apple logo, "Apple ile Giriş")
- Bottom: "Hesabın yok mu? Kayıt Ol" link

**Register Screen:**
- First name + Last name inputs (side by side)
- Email input
- Phone input (with +90 prefix)
- Password input (with show/hide toggle)
- "Kayıt Ol" primary button
- Bottom: "Zaten hesabın var mı? Giriş Yap" link

**Forgot Password Screen:**
- Email input
- "Şifre Sıfırlama Linki Gönder" primary button
- Uses supabase.auth.resetPasswordForEmail(email)

### Auth Tables Used:

**users:**
id(uuid), email(text), first_name(text), last_name(text), phone(text), avatar_url(text), date_of_birth(date), gender(text), membership_type(text), total_orders(integer), total_favorites(integer), average_rating(numeric), loyalty_points(integer), created_at(timestamptz), updated_at(timestamptz), full_name(text), is_banned(boolean)

**fcm_tokens:**
id(uuid), user_id(uuid), token(text), platform(text), created_at(timestamptz), updated_at(timestamptz)

---

## NAVIGATION STRUCTURE

### Bottom Tab Bar (4 tabs):
- Height: 56px + safe area
- Background: surface with 0.95 opacity (frosted glass)
- Top border: 1px subtle
- Shadow: upward soft shadow
- Icons: 22px, outlined inactive / filled active
- Active: primary blue, Inactive: #9CA3AF
- Labels: 10px, always visible

**Tabs:**
1. **Ana Sayfa** (Home) - home icon → /
2. **Favoriler** (Favorites) - heart icon → /favorites
3. **Siparişler** (Orders) - receipt icon → /orders
4. **Profil** (Profile) - person icon → /profile

### Stack Navigation (full screen, no tabs):
- /login, /register, /forgot-password
- /taxi/* (all taxi screens - will be added in Part 3)
- /food/item/*, /food/cart, /store/cart, /store/checkout (detail screens - Part 2)
- /settings/*, /notifications

### Placeholder Screens:
Create placeholder screens for these routes that will be implemented in future parts. Each should show the service icon, name, and "Yakında" (Coming Soon) text:
- /food → Food Home (Part 2)
- /market → Store Home (Part 2)
- /grocery → Grocery Home (Part 2)
- /taxi → Taxi Home (Part 3)
- /rental → Rental Home (Part 5)
- /emlak → Emlak Home (Part 4)
- /car-sales → Car Sales Home (Part 4)
- /jobs → Jobs Home (Part 5)
- /support/ai-chat → AI Chat (Part 5)

---

## HOME SCREEN

### Layout (scrollable):

**1. Header:**
- Left: Delivery address with down arrow icon (tap to change)
  - Show user's default saved_location address, or "Konum Seç" if none
- Right: User avatar (40px circle, initials fallback if no avatar_url)
  - Tap → navigate to /profile

**2. Search Bar:**
- Rounded container, 10px radius, surface background
- Search icon left, placeholder: "Ne arıyorsunuz?"
- Tappable → navigate to a search screen (can be simple for now)

**3. Banner Carousel:**
- Height: 160px, 14px border radius
- Auto-scroll every 3 seconds
- Page indicator dots at bottom
- Viewport fraction: 0.9 (peek next/prev)
- Query: `supabase.from('banners').select('*').eq('is_active', true).order('sort_order')`
- Show image_url, tap → open link_url or navigate based on link_type

**4. Service Grid (4x2):**
Each service = gradient icon container (60px, 12px radius) + label (11px) below

| Icon | Label | Route | Gradient |
|------|-------|-------|----------|
| 🍽️ | Yemek | /food | Orange #EC6D13 → #F59E0B |
| 🛒 | Market | /market | Indigo #6366F1 → #818CF8 |
| 🥬 | Manav | /grocery | Green #10B981 → #34D399 |
| 🚕 | Taksi | /taxi | Yellow #F59E0B → #FBBF24 |
| 🚗 | Kiralık Araç | /rental | Blue #3B82F6 → #60A5FA |
| 🏠 | Emlak | /emlak | Teal #14B8A6 → #2DD4BF |
| 🚙 | Araba Satış | /car-sales | Red #EF4444 → #F87171 |
| 💼 | İş İlanları | /jobs | Purple #8B5CF6 → #A78BFA |

Small decorative circle on each icon container (ornament, 80% opacity, offset top-right)

**5. Section: "Yakınındaki Restoranlar"**
- Section header: "Yakınındaki Restoranlar" + "Tümü →" link
- Horizontal scroll list of restaurant cards
- Query: `supabase.from('merchants').select('*').eq('type', 'restaurant').eq('is_approved', true).eq('is_open', true).limit(10)`
- Card: vertical, 140px image top (12px radius top), logo overlay bottom-left of image, business_name (13px bold), rating star + rating number, delivery_time text, discount_badge if exists

**6. Section: "Öne Çıkan Mülkler"**
- Horizontal scroll property cards
- Query: `supabase.from('properties').select('*').eq('status', 'active').eq('is_featured', true).limit(10)`
- Card: horizontal layout, image left (120px, 12px radius left), right side: title, city+district, price (bold), rooms+bathrooms+sqm row

**7. Section: "Güncel İş İlanları"**
- Vertical list, max 3 items
- Query: `supabase.from('job_listings').select('*, companies(name, logo_url)').eq('status', 'active').order('created_at', { ascending: false }).limit(3)`
- Card: company logo (40px circle) left, title + company name + city, job_type chip, salary if not hidden

### Home Tables Used:

**banners:**
id(uuid), title(varchar), description(text), image_url(text), link_url(text), is_active(boolean), sort_order(integer), starts_at(timestamptz), ends_at(timestamptz), category(varchar), link_type(varchar), link_id(uuid), status(varchar)

**merchants** (preview only):
id(uuid), type(varchar), business_name(varchar), is_open(boolean), is_approved(boolean), logo_url(text), cover_url(text), rating(numeric), delivery_time(varchar), discount_badge(varchar)

**properties** (preview only):
id(uuid), title(text), listing_type(text), price(numeric), currency(text), city(text), district(text), rooms(integer), bathrooms(integer), square_meters(integer), images(ARRAY), is_featured(boolean), status(text)

**job_listings** (preview only):
id(uuid), title(varchar), city(varchar), job_type(enum), salary_min(numeric), salary_max(numeric), salary_currency(varchar), is_salary_hidden(boolean), status(enum), created_at(timestamptz), company_id(uuid)

**companies** (preview only):
id(uuid), name(varchar), logo_url(text)

---

## FAVORITES SCREEN (/favorites)

### Layout:
- Tab selector at top: "Restoranlar" | "Mülkler" | "Arabalar" | "İlanlar"
- Each tab shows favorites for that service
- For now, implement "Restoranlar" tab:
  - Query: `supabase.from('favorites').select('*, merchants(*)').eq('user_id', userId)`
  - Show restaurant cards in vertical list
  - Swipe to remove or heart toggle
- Other tabs: placeholder with "Yakında" message (will be wired in Parts 2-5)

**favorites:**
id(uuid), user_id(uuid), merchant_id(uuid), created_at(timestamptz)

---

## ORDERS SCREEN (/orders)

### Layout:
- Tab selector: "Aktif" (Active) | "Geçmiş" (Past)
- Active: orders where status NOT IN ('delivered', 'cancelled')
- Past: orders where status IN ('delivered', 'cancelled')
- Query: `supabase.from('orders').select('*').eq('user_id', userId).order('created_at', { ascending: false })`
- Realtime subscription for active orders: subscribe to `orders` table changes for user

### Order Card:
- Store name / merchant info
- Order number (#ORD-XXXX)
- Status badge (colored): pending=orange, confirmed=blue, preparing=indigo, ready=green, picked_up=teal, delivered=green, cancelled=red
- Total amount
- Date (relative: "2 saat önce", "Dün")
- Tap → order detail/tracking (placeholder for now)

**orders:**
id(uuid), order_number(varchar), user_id(uuid), merchant_id(uuid), items(jsonb), subtotal(numeric), delivery_fee(numeric), total_amount(numeric), delivery_address(text), status(varchar), created_at(timestamptz), updated_at(timestamptz), service_fee(numeric), discount_amount(numeric), payment_method(varchar), payment_status(varchar), customer_name(varchar), is_reviewed(boolean), store_name(text)

---

## PROFILE SCREEN (/profile)

### Layout:
- User avatar (large, 80px circle, with camera icon overlay for edit)
- Full name (18px bold)
- Email (13px secondary)
- Membership badge if membership_type exists
- Stats row: Total Orders | Loyalty Points | Rating (3 columns)

### Menu Items (list with icons):
Each item = icon (colored circle bg) + title + subtitle + arrow

| Icon | Title | Subtitle | Route | Color |
|------|-------|----------|-------|-------|
| 👤 | Kişisel Bilgiler | Ad, telefon, e-posta | /settings/personal-info | #3B82F6 |
| 📍 | Kayıtlı Adresler | Ev, iş, diğer | /settings/addresses | #10B981 |
| 💳 | Ödeme Yöntemleri | Kartlar | /settings/payment-methods | #8B5CF6 |
| 🔒 | Güvenlik | Şifre değiştir | /settings/security | #F59E0B |
| 🚨 | Acil Durum Kişileri | Acil durum | /settings/emergency-contacts | #EF4444 |
| 🔔 | Bildirim Ayarları | Bildirimler | /settings/notifications | #6366F1 |
| 🤖 | AI Asistan | Yardım al | /support/ai-chat | #14B8A6 |
| ❓ | Yardım Merkezi | SSS | /help-center | #9CA3AF |
| 🚪 | Çıkış Yap | - | (sign out) | #EF4444 |

Bottom: "Hesabı Sil" destructive text button → calls RPC `delete_user_account()`

---

## SETTINGS SCREENS

### Personal Info (/settings/personal-info):
- Avatar upload (tap avatar → pick image → upload to Supabase Storage bucket "images" at path `avatars/{userId}`)
- Editable fields: first_name, last_name, phone, email (read-only), date_of_birth (date picker), gender (dropdown: Erkek/Kadın/Diğer)
- "Kaydet" button → update `users` table
- Also update supabase.auth.updateUser for email/phone changes

### Saved Addresses (/settings/addresses):
- List of saved locations
- Each: icon (home/work/pin) + title + address + default badge
- Swipe to delete
- FAB "+" to add new
- Add/Edit form: title, address (with map picker), type (home/work/other), floor, apartment, directions
- Query: `supabase.from('saved_locations').select('*').eq('user_id', userId).order('sort_order')`

**saved_locations:**
id(uuid), user_id(uuid), title(varchar), address(text), latitude(numeric), longitude(numeric), type(varchar), is_default(boolean), name(varchar), address_details(text), floor(varchar), apartment(varchar), directions(text)

### Payment Methods (/settings/payment-methods):
- List payment methods
- Card icon + **** last_four + brand + default badge
- Query: `supabase.from('payment_methods').select('*').eq('user_id', userId).eq('is_active', true)`
- For now: display only (adding cards will use Stripe in Part 2)

**payment_methods:**
id(uuid), user_id(uuid), type(text), provider(text), card_last_four(text), card_brand(text), is_default(boolean), is_active(boolean)

### Security (/settings/security):
- Current password input
- New password input
- Confirm password input
- "Şifreyi Değiştir" button → supabase.auth.updateUser({ password: newPassword })

### Emergency Contacts (/settings/emergency-contacts):
- List from communication_preferences.emergency_contacts (jsonb array)
- Each: name + phone + relationship
- Add/edit/delete contacts
- Save: update `communication_preferences` table

**communication_preferences:**
id(uuid), user_id(uuid), allow_calls(boolean), allow_messages(boolean), emergency_contacts(jsonb)

### Notification Settings (/settings/notifications):
- Toggle switches for each preference
- Query: `supabase.from('notification_preferences').select('*').eq('user_id', userId).single()`
- Update on toggle change

**notification_preferences:**
id(uuid), user_id(uuid), push_enabled(boolean), email_enabled(boolean), sms_enabled(boolean), order_updates(boolean), campaigns(boolean), new_features(boolean)

---

## NOTIFICATIONS SCREEN (/notifications)
- Bell icon in header (top-right on home) with unread count badge (red dot + number)
- Full screen list of notifications
- Each: icon based on type + title (bold if unread) + body + time ago
- Tap → mark as read + navigate based on data.type
- Pull to refresh
- Query: `supabase.from('notifications').select('*').eq('user_id', userId).order('created_at', { ascending: false }).limit(50)`
- Realtime: subscribe to INSERT on notifications where user_id = current user
- Mark read: `supabase.from('notifications').update({ is_read: true }).eq('id', notifId)`

**notifications:**
id(uuid), user_id(uuid), title(text), body(text), type(text), data(jsonb), is_read(boolean), created_at(timestamptz)

---

## GLOBAL REQUIREMENTS
1. All screens support light + dark theme
2. Shimmer/skeleton loading on all data-fetching screens
3. Pull-to-refresh on all list screens
4. Empty states: centered icon + title + subtitle + action button
5. Error handling: toast/snackbar for errors, retry button
6. Session auto-refresh: supabase.auth.onAuthStateChange listener
7. Image uploads: use Supabase Storage bucket "images"
8. All tappable elements: scale 0.98 press animation
9. Bottom sheets: 20px top radius, drag handle (40px grey pill), spring animation
10. Turkish primary language throughout
11. Create a clean folder structure: /services, /screens, /components, /hooks, /types, /theme, /navigation
12. Create a Supabase client singleton in /services/supabase.ts
13. Create auth context/provider wrapping the app
14. Create theme context for light/dark switching

Build this foundation solid - Parts 2-5 will add Food, Taxi, Emlak, Car Sales, Jobs, Rental, and AI Chat into this structure.
```
