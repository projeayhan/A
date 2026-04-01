# RORK PART 6 - Eksik Özellikler, Düzeltmeler ve Final Polish

Part 1-5 tamamlandıktan sonra bu prompt'u ver. Tüm eksikleri, kırık butonları ve atlanmış özellikleri tamamlar.

---

```
The SuperCyp app has been built in Parts 1-5 but there are CRITICAL missing features, broken buttons, and incomplete screens. Fix ALL of the following. Do not skip anything.

## SUPABASE
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY

---

## FIX 1: SERVICE ICONS ON HOME SCREEN

The service grid icons are broken - names are truncated and icons are too small. Fix:

- Make grid 4 columns, 2 rows
- Each cell: 80px width minimum
- Icon container: 56px height, 56px width, 14px border radius
- Use ACTUAL emoji or vector icons, NOT text:
  - Yemek: 🍽️ (or utensils icon)
  - Market: 🛒 (or shopping cart icon)
  - Manav: 🥬 (or leaf icon)
  - Taksi: 🚕 (or car icon)
  - Kiralık Araç: 🚗 (or key+car icon)
  - Emlak: 🏠 (or building icon)
  - Araba Satış: 🚙 (or price tag icon)
  - İş İlanları: 💼 (or briefcase icon)
- Labels: FULL text, no truncation. Use 11px font, allow 2 lines if needed
- Each icon container: gradient background as specified in Part 1
- Gradient colors:
  - Yemek: linear-gradient(135deg, #EC6D13, #F59E0B)
  - Market: linear-gradient(135deg, #6366F1, #818CF8)
  - Manav: linear-gradient(135deg, #10B981, #34D399)
  - Taksi: linear-gradient(135deg, #F59E0B, #FBBF24)
  - Kiralık Araç: linear-gradient(135deg, #3B82F6, #60A5FA)
  - Emlak: linear-gradient(135deg, #14B8A6, #2DD4BF)
  - Araba Satış: linear-gradient(135deg, #EF4444, #F87171)
  - İş İlanları: linear-gradient(135deg, #8B5CF6, #A78BFA)

---

## FIX 2: ALL BROKEN NAVIGATION / DEAD BUTTONS

Go through EVERY screen and make sure EVERY button, card tap, and link navigates correctly:

### Home Screen:
- Each service icon tap → correct service screen (not placeholder)
- Banner tap → if link_url exists, open it; if link_type='screen' and link_id exists, navigate to that item
- Restaurant card tap → /food/restaurant/{id}
- Property card tap → /emlak/property/{id}
- Job card tap → /jobs/detail/{id}
- Notification bell → /notifications
- Avatar → /profile
- "Tümü →" links → corresponding list screen
- Search bar tap → global search screen
- Address selector tap → address selection bottom sheet

### Food Screens:
- Category chip tap → filter restaurants
- Restaurant card tap → restaurant detail
- Menu item tap → item detail bottom sheet or screen
- "+" button on menu item → add to cart (increment if exists)
- Cart floating bar tap → /food/cart
- Cart item quantity +/- → update quantity
- Cart item swipe left → remove
- "Siparişi Onayla" → create order + navigate to success
- Order success "Takip Et" → /food/order-tracking/{orderId}
- Order tracking screen → realtime status updates

### Store/Market Screens:
- Store category tap → filter stores by category
- Store card tap → /store/detail/{id}
- Follow button → toggle follow (insert/delete merchant_followers)
- Product card tap → /store/product/{id}
- Product "+" button → add to cart
- Product detail "Sepete Ekle" → add to cart
- Variant selector → update selected variant and price
- Store cart → checkout flow → order creation

### Taxi Screens:
- "Nereye gidiyorsunuz?" tap → destination screen
- Saved location tap → use as destination, skip to vehicle selection
- Recent ride tap → use as destination
- Search result tap → set destination
- "Haritadan Seç" → map with draggable pin
- Vehicle type card tap → select it (highlight)
- "Taksi Çağır" → create ride + navigate to searching
- "İptal Et" on searching → cancel ride + go back
- Driver found → auto-navigate to ride screen
- Call button → initiate call RPC
- Message button → open chat
- Share button → create share link
- SOS button → emergency alert
- Ride completed → auto-navigate to rating
- Rating stars tap → select rating
- Feedback tag tap → toggle selection
- Tip amount tap → select tip
- "Gönder" → submit rating + go home
- "Atla" → skip rating + go home

### Emlak Screens:
- Listing type tab tap → filter properties
- Property type chip tap → filter
- City/district dropdown → filter
- Property card tap → /emlak/property/{id}
- Favorite heart tap → toggle favorite (insert/delete property_favorites)
- "İletişime Geç" → create/open conversation
- Chat send button → send message
- "İlan Ver" floating button → /emlak/add
- Add property form steps → all next/back buttons work
- "Yayınla" → insert property + navigate to my listings
- My listings item tap → property detail
- Edit/Delete menu items → work correctly

### Car Sales Screens:
- Brand circle tap → filter by brand
- Car card tap → /car-sales/detail/{id}
- Favorite heart → toggle (insert/delete car_favorites)
- "Mesaj Gönder" → create/open car_conversation
- "Ara" (call) → show phone or initiate contact
- "İlan Ver" → /car-sales/add
- Add listing steps → all work
- Chat send → insert car_message

### Jobs Screens:
- Category card tap → filter by category
- Job card tap → /jobs/detail/{id}
- Favorite heart → toggle (insert/delete job_favorites)
- "Başvur" → open application form bottom sheet
- Application form "Gönder" → insert job_application
- Resume upload button → file picker + upload to storage
- "İlan Ver" → /jobs/add
- Add listing steps → all work

### Rental Screens:
- "Araç Ara" → filter cars by date/location
- Car card tap → /rental/car/{id}
- "Rezervasyon Yap" → booking form
- Service toggles → add/remove from total
- Package selection → update pricing
- "Onayla" → insert booking

### Profile & Settings:
- Every menu item → navigates to correct settings screen
- Avatar tap → image picker → upload → update users.avatar_url
- "Kaydet" on personal info → update users table
- Address add/edit/delete → CRUD on saved_locations
- Address "+" FAB → new address form
- Security "Şifreyi Değiştir" → supabase.auth.updateUser
- Notification toggles → update notification_preferences
- Emergency contact add/edit/delete → update communication_preferences
- "Çıkış Yap" → supabase.auth.signOut() + navigate to login
- "Hesabı Sil" → confirm dialog → supabase.rpc('delete_user_account') + sign out
- "AI Asistan" → /support/ai-chat
- "Yardım Merkezi" → help center screen

---

## FIX 3: IMAGES NOT LOADING

Images from Supabase Storage need correct URL format. Fix ALL image displays:

```javascript
// For images stored in Supabase Storage bucket "images":
// The URL is already a full public URL in the database
// Just use it directly: <Image source={{ uri: imageUrl }} />

// For new uploads, get public URL:
const { data } = supabase.storage.from('images').getPublicUrl(filePath)
const publicUrl = data.publicUrl
```

- ALL image components must have:
  - A loading placeholder (grey shimmer or surface color box)
  - Fade-in animation on load (opacity 0→1, 300ms)
  - Error fallback (grey box with broken image icon or first letter avatar)
  - Correct `resizeMode: 'cover'` for cards, `'contain'` for logos

- Fix specifically:
  - Restaurant cover images (from merchants.cover_url)
  - Restaurant logos (from merchants.logo_url)
  - Menu item images (from menu_items.image_url)
  - Product images (from products.image_url and products.images array)
  - Property images (from properties.images array)
  - Car listing images (from car_listings.images jsonb array - parse if needed)
  - Rental car images (from rental_cars.image_url and rental_cars.images jsonb)
  - Company logos (from companies.logo_url)
  - User avatars (from users.avatar_url)
  - Banner images (from banners.image_url)
  - Car brand logos (from car_brands.logo_url)
  - Store category images (from store_categories.image_url)
  - Restaurant category images (from restaurant_categories.image_url)

---

## FIX 4: ICON MAPPING FROM DATABASE

The database stores icon names as strings. Map them to actual icons:

```javascript
// store_categories.icon_name contains strings like: "toys", "menu_book", "watch", "face"
// These are Material Icons names. Map to your icon library:

const iconMap = {
  'toys': '🧸',        // or MaterialIcons name
  'menu_book': '📚',
  'watch': '⌚',
  'face': '💄',
  'sports_esports': '🎮',
  'home': '🏠',
  'restaurant': '🍽️',
  'local_grocery_store': '🛒',
  'checkroom': '👔',
  'devices': '📱',
  'pets': '🐾',
  'child_care': '👶',
  'fitness_center': '💪',
  // Add more as needed from the data
}

// Use react-native-vector-icons/MaterialIcons if available
// Or map to Expo's @expo/vector-icons MaterialIcons
```

- Apply this mapping to: store_categories.icon_name, restaurant_categories.icon, taxi_feedback_tags.icon_name, car_features.icon, car_body_types.icon, car_fuel_types.icon, car_transmissions.icon, emlak_property_types.icon, emlak_amenities.icon, job_categories.icon, job_benefits.icon, vehicle_types.icon_name, rental_services.icon

---

## FIX 5: ORDER NUMBER GENERATION

When creating orders, generate order_number on client side:
```javascript
const generateOrderNumber = () => {
  const timestamp = Date.now().toString(36).toUpperCase()
  const random = Math.random().toString(36).substring(2, 6).toUpperCase()
  return `ORD-${timestamp}-${random}`  // e.g., "ORD-LK5F2M-A8B3"
}
```
Use this for orders.order_number and rental_bookings.booking_number (prefix "RNT-") and taxi_rides don't need it (ride_number is set by backend).

---

## FIX 6: MISSING FEATURE - ORDER CHAT (Food/Store)

After placing a food or store order, users can chat with the merchant. Add this:

**In Order Tracking Screen:**
- Add "Mesaj" button
- Opens chat using `order_messages` table:
```javascript
// Load messages
const { data } = await supabase.from('order_messages')
  .select('*').eq('order_id', orderId).order('created_at')

// Send message
await supabase.from('order_messages').insert({
  order_id: orderId,
  merchant_id: merchantId,
  sender_type: 'customer',
  sender_id: currentUser.id,
  sender_name: currentUser.full_name,
  message: text
})

// Realtime subscribe
supabase.channel(`order-chat-${orderId}`)
  .on('postgres_changes', {
    event: 'INSERT', schema: 'public',
    table: 'order_messages', filter: `order_id=eq.${orderId}`
  }, handleNewMessage)
  .subscribe()
```

**order_messages:**
id(uuid), order_id(uuid), merchant_id(uuid), sender_type(text), sender_id(uuid), sender_name(text), message(text), is_read(boolean), created_at(timestamptz), is_ai_response(boolean)

---

## FIX 7: MISSING FEATURE - STORE MESSAGING

Users can message stores directly from store detail:

**In Store Detail Screen:**
- Add "Mesaj Gönder" button
- Opens chat using `store_messages` table:
```javascript
// Load messages
const { data } = await supabase.from('store_messages')
  .select('*').eq('merchant_id', merchantId).eq('customer_id', userId)
  .order('created_at')

// Send
await supabase.from('store_messages').insert({
  merchant_id: merchantId,
  customer_id: currentUser.id,
  sender_type: 'customer',
  sender_id: currentUser.id,
  sender_name: currentUser.full_name,
  message: text
})
```

**store_messages:**
id(uuid), merchant_id(uuid), customer_id(uuid), sender_type(text), sender_id(uuid), sender_name(text), message(text), is_read(boolean), created_at(timestamptz)

---

## FIX 8: MISSING FEATURE - COUPON SYSTEM

In Cart screens (Food and Store), the coupon input must actually work:

```javascript
// Validate coupon
const validateCoupon = async (code) => {
  const { data: coupon } = await supabase.from('user_coupons')
    .select('*')
    .eq('user_id', currentUser.id)
    .eq('code', code.toUpperCase())
    .eq('is_used', false)
    .gte('valid_until', new Date().toISOString())
    .lte('valid_from', new Date().toISOString())
    .single()

  if (!coupon) return { valid: false, message: 'Geçersiz kupon kodu' }

  if (subtotal < coupon.min_order_amount) {
    return { valid: false, message: `Minimum sipariş tutarı: ₺${coupon.min_order_amount}` }
  }

  let discount = 0
  if (coupon.discount_type === 'percentage') {
    discount = subtotal * (coupon.discount_value / 100)
    if (coupon.max_discount && discount > coupon.max_discount) {
      discount = coupon.max_discount
    }
  } else {
    discount = coupon.discount_value
  }

  return { valid: true, discount, coupon }
}

// After order placed, mark coupon as used:
await supabase.from('user_coupons')
  .update({ is_used: true, used_at: new Date() })
  .eq('id', coupon.id)
```

**user_coupons:**
id(uuid), user_id(uuid), code(text), title(text), description(text), discount_type(text), discount_value(numeric), min_order_amount(numeric), max_discount(numeric), valid_from(timestamptz), valid_until(timestamptz), is_used(boolean), used_at(timestamptz)

---

## FIX 9: MISSING FEATURE - HELP CENTER

The help center screen (/help-center) needs actual content:

```javascript
// Load FAQ items
const { data: faqs } = await supabase.from('ai_knowledge_base')
  .select('*')
  .eq('app_source', 'customer_app')
  .eq('is_active', true)
  .order('priority', { ascending: false })
```

**Layout:**
- Search bar: "Nasıl yardımcı olabiliriz?"
- Categories from unique category values in results
- Each FAQ: expandable accordion (question → answer)
- Bottom: "AI Asistan ile Konuş" button → /support/ai-chat
- Bottom: "Destek Talebi Oluştur" → create support ticket

**Create support ticket:**
```javascript
await supabase.from('support_tickets').insert({
  customer_user_id: currentUser.id,
  customer_name: currentUser.full_name,
  customer_phone: currentUser.phone,
  category: selectedCategory,
  subject: subject,
  description: description,
  status: 'open',
  priority: 'medium'
})
```

**ai_knowledge_base:**
id(uuid), app_source(varchar), category(varchar), subcategory(varchar), question(text), answer(text), keywords(ARRAY), is_active(boolean), priority(integer)

**support_tickets:**
id(uuid), customer_user_id(uuid), customer_name(text), customer_phone(text), category(text), subject(text), description(text), status(text), priority(text), created_at(timestamptz)

---

## FIX 10: MISSING FEATURE - GLOBAL SEARCH

Create a proper global search screen:

**Layout:**
- Search input (auto-focus on open)
- Recent searches (stored locally)
- As user types (debounce 300ms), search across:

```javascript
const search = async (query) => {
  const [restaurants, stores, products, properties, cars, jobs] = await Promise.all([
    supabase.from('merchants').select('id, business_name, logo_url, type, rating')
      .eq('is_approved', true).ilike('business_name', `%${query}%`).limit(5),
    supabase.from('merchants').select('id, business_name, logo_url, type, rating')
      .eq('type', 'store').eq('is_approved', true).ilike('business_name', `%${query}%`).limit(5),
    supabase.from('products').select('id, name, price, image_url, merchant_id')
      .eq('is_available', true).ilike('name', `%${query}%`).limit(5),
    supabase.from('properties').select('id, title, price, city, images, listing_type')
      .eq('status', 'active').ilike('title', `%${query}%`).limit(5),
    supabase.from('car_listings').select('id, title, price, brand_name, images')
      .eq('status', 'active').ilike('title', `%${query}%`).limit(5),
    supabase.from('job_listings').select('id, title, city, company_id, companies(name)')
      .eq('status', 'active').ilike('title', `%${query}%`).limit(5),
  ])
  return { restaurants, stores, products, properties, cars, jobs }
}
```

- Results grouped by section: "Restoranlar", "Mağazalar", "Ürünler", "Mülkler", "Araçlar", "İş İlanları"
- Each result: icon/image + title + subtitle
- Tap → navigate to detail screen

---

## FIX 11: MULTI-CURRENCY SUPPORT

The app uses exchange_rates table for currency conversion:

```javascript
// Fetch exchange rates on app load
const { data: rates } = await supabase.from('exchange_rates').select('*')
// rates: [{ currency: 'TRY', rate_to_usd: 0.031 }, { currency: 'GBP', rate_to_usd: 1.27 }, ...]

// Format price based on currency
const formatPrice = (amount, currency = 'TRY') => {
  const symbols = { TRY: '₺', USD: '$', EUR: '€', GBP: '£' }
  const symbol = symbols[currency] || currency
  return `${symbol}${amount.toLocaleString('tr-TR', { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`
}
```

Apply formatPrice to ALL price displays:
- Properties: use property.currency
- Car listings: use car_listing.currency
- Job salaries: use salary_currency
- Food/store orders: always TRY
- Rental: always TRY

---

## FIX 12: FAVORITES SCREEN - ALL 4 TABS MUST WORK

The Favorites screen needs 4 working tabs:

**Tab 1: "Restoranlar"**
```javascript
const { data } = await supabase.from('favorites')
  .select('*, merchants(id, business_name, logo_url, cover_url, rating, delivery_time, discount_badge)')
  .eq('user_id', userId)
```
- Show restaurant cards
- Heart filled, tap to unfavorite

**Tab 2: "Mülkler"**
```javascript
const { data } = await supabase.from('property_favorites')
  .select('*, properties(id, title, price, currency, city, district, rooms, bathrooms, square_meters, images, listing_type)')
  .eq('user_id', userId)
```

**Tab 3: "Arabalar"**
```javascript
const { data } = await supabase.from('car_favorites')
  .select('*, car_listings(id, title, brand_name, model_name, year, price, currency, mileage, fuel_type, images)')
  .eq('user_id', userId)
```

**Tab 4: "İş İlanları"**
```javascript
const { data } = await supabase.from('job_favorites')
  .select('*, job_listings(id, title, city, job_type, salary_min, salary_max, salary_currency, is_salary_hidden, companies(name, logo_url))')
  .eq('user_id', userId)
```

Each tab: pull-to-refresh, empty state if no favorites, remove on heart tap.

---

## FIX 13: ORDERS SCREEN - ALL 3 TABS MUST WORK

**Tab 1: "Siparişler" (Food/Store/Grocery orders)**
```javascript
const { data } = await supabase.from('orders')
  .select('*')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
```
- Card: store_name, order_number, status badge, total_amount, created_at
- Active vs completed filter
- Tap → order detail/tracking

**Tab 2: "Yolculuklar" (Taxi rides)**
```javascript
const { data } = await supabase.from('taxi_rides')
  .select('*, taxi_drivers(full_name, vehicle_brand, vehicle_model, vehicle_plate, profile_photo_url, rating)')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
```
- Card: pickup → dropoff, fare, status, driver info, date
- Tap → ride detail

**Tab 3: "Kiralamalar" (Rental bookings)**
```javascript
const { data } = await supabase.from('rental_bookings')
  .select('*, rental_cars(brand, model, year, image_url), rental_companies(company_name)')
  .eq('user_id', userId)
  .order('created_at', { ascending: false })
```
- Card: car image + name, dates, status, total
- Tap → booking detail

---

## FIX 14: DARK MODE ON EVERY SCREEN

Go through ALL screens and ensure:
- Background uses theme background color (not hardcoded white)
- Cards use theme surface color
- Text uses theme text colors
- Borders use theme border colors
- Shadows adjust for dark mode (darker/more subtle)
- Status bar: light content on dark, dark content on light
- Modal/bottom sheet backgrounds: theme surface
- Input fields: theme surface background
- Dividers: theme divider color

Test by toggling dark mode - no white flashes, no invisible text, no hardcoded colors.

---

## FIX 15: SHIMMER LOADING ON ALL SCREENS

Every screen that fetches data must show shimmer skeleton while loading:

- Home: shimmer for banners, service grid (optional), restaurant cards, property cards, job cards
- Food home: shimmer for categories + restaurant list
- Restaurant detail: shimmer for menu items
- Store home: shimmer for categories + store grid
- Product list: shimmer for product grid
- Taxi: shimmer for vehicle types
- Emlak home: shimmer for property list
- Car sales home: shimmer for brands + listings
- Jobs home: shimmer for categories + job list
- Rental home: shimmer for car list
- Favorites: shimmer per tab
- Orders: shimmer per tab
- Notifications: shimmer for list
- Chat screens: shimmer for message history

Shimmer must match the exact card/item dimensions of the real content.

---

## FIX 16: MISSING - REALTIME SUBSCRIPTIONS

Ensure ALL these realtime subscriptions are active:

```javascript
// 1. Notifications (global, always active when logged in)
supabase.channel('user-notifications')
  .on('postgres_changes', {
    event: 'INSERT', schema: 'public', table: 'notifications',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    incrementNotificationBadge()
    showInAppNotification(payload.new)
  })
  .subscribe()

// 2. Active orders (when on orders/tracking screen)
supabase.channel('order-updates')
  .on('postgres_changes', {
    event: 'UPDATE', schema: 'public', table: 'orders',
    filter: `user_id=eq.${userId}`
  }, handleOrderUpdate)
  .subscribe()

// 3. Active ride (when on taxi ride screen)
// Already covered in Part 3

// 4. Chat messages (when in any chat screen)
// Subscribe to the specific messages table for that chat type

// 5. AI chat (when on AI chat screen)
// Subscribe to support_chat_messages for session
```

Also: unsubscribe from channels when leaving screens to prevent memory leaks.

---

## FIX 17: PULL-TO-REFRESH ON EVERY LIST

Every screen with a list/grid must have pull-to-refresh:
- Use RefreshControl component
- On refresh: re-fetch data from Supabase
- Show refresh indicator with primary color
- Screens: Home, Food Home, Restaurant Detail, Store Home, Store Detail, Grocery Home, Emlak Home, Car Sales Home, Jobs Home, Rental Home, Favorites (each tab), Orders (each tab), Notifications, My Listings (all types), Chat lists, Search results

---

## FIX 18: EMPTY STATES

Every list that can be empty needs a proper empty state:
```
[centered on screen]
[80px icon or emoji]
[Title - 16px bold]
[Subtitle - 13px secondary]
[Action button if applicable]
```

Examples:
- No favorites: ❤️ "Henüz favorin yok" "Beğendiğin yerleri favorilere ekle" [Keşfet →]
- No orders: 📦 "Henüz siparişin yok" "İlk siparişini hemen ver" [Sipariş Ver →]
- No notifications: 🔔 "Bildirim yok" "Yeni bildirimler burada görünecek"
- No search results: 🔍 "Sonuç bulunamadı" "Farklı kelimelerle aramayı dene"
- No messages: 💬 "Henüz mesaj yok" "İlk mesajı gönder"
- No properties: 🏠 "İlan bulunamadı" "Filtreleri değiştirmeyi dene"

---

## FIX 19: ERROR HANDLING

Every Supabase call must handle errors:
```javascript
const { data, error } = await supabase.from('table').select('*')
if (error) {
  // Show toast: "Bir hata oluştu. Tekrar deneyin."
  // Log error for debugging
  console.error('Supabase error:', error.message)
  return
}
```

- Network errors: "İnternet bağlantınızı kontrol edin"
- Auth errors: redirect to login
- Show retry button on error states

---

## FIX 20: MISSING PRESS ANIMATIONS

Every tappable element must have press feedback:
```javascript
// Wrap with Pressable or TouchableOpacity
<Pressable
  onPress={handlePress}
  style={({ pressed }) => [
    styles.card,
    pressed && { transform: [{ scale: 0.98 }], opacity: 0.9 }
  ]}
>
```

Apply to: ALL cards, ALL buttons, ALL list items, ALL chips, ALL tabs, ALL icons that are tappable.

---

## FINAL VERIFICATION

After applying ALL fixes above, verify:

1. Open app → Login screen appears
2. Register new account → works
3. Login → Home screen loads with banners, services, restaurants, properties, jobs
4. Tap each of 8 service icons → correct screen opens
5. Food: browse → add to cart → checkout → order placed → tracking works
6. Store: browse → add to cart → checkout → order placed
7. Taxi: set destination → select vehicle → request ride → (ride flow works with realtime)
8. Emlak: browse → detail → favorite → chat with seller → add listing
9. Car Sales: browse → detail → favorite → chat → add listing
10. Jobs: browse → detail → apply → add listing
11. Rental: search → detail → book
12. AI Chat: send message → get response
13. Profile: edit info → upload avatar → change password
14. Addresses: add/edit/delete
15. Favorites: all 4 tabs show data
16. Orders: all 3 tabs show data
17. Notifications: receive and display
18. Dark mode: toggle → everything looks correct
19. Pull-to-refresh: works on all list screens
20. Back navigation: works correctly from all screens

EVERY button must do something. EVERY screen must load data. ZERO dead ends.
```
