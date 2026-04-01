# RORK PART 4 - Real Estate (Emlak) + Car Sales

Aşağıdaki prompt'u Rork'a ver. Part 1-3 tamamlandıktan sonra.

---

```
Continue building the SuperCyp app. Parts 1-3 are done (Auth, Home, Food, Store, Grocery, Taxi). Now add Real Estate (Emlak) and Car Sales modules. Replace the placeholder screens.

## SUPABASE
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY

## GOOGLE MAPS
- API Key: AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ

## DESIGN REMINDERS
- Emlak accent: Teal #14B8A6
- Car Sales accent: Red/Crimson #EF4444
- Cards: 12px radius, shadow, 1px border
- Shimmer loading, pull-to-refresh, infinite scroll (20/page)
- Image carousels: swipeable, page counter, fade-in

---

## MODULE 1: REAL ESTATE - EMLAK (/emlak)

### Emlak Home Screen (/emlak):
**Layout:**
- Search bar: "Mülk ara..." placeholder
- Listing type filter: horizontal tabs
  - Query: `supabase.from('emlak_listing_types').select('*').eq('is_active', true).order('sort_order')`
  - Each tab: label text, colored underline from color field
  - "Tümü" (All) tab first
- Property type chips: horizontal scroll
  - Query: `supabase.from('emlak_property_types').select('*').eq('is_active', true).order('sort_order')`
  - Each: icon + label
- City/District filter dropdown:
  - Cities: `supabase.from('emlak_cities').select('*').eq('is_active', true).order('sort_order')`
  - Districts: `supabase.from('emlak_districts').select('*').eq('city_id', selectedCity).eq('is_active', true).order('sort_order')`
- Featured properties section: horizontal scroll
  - Query: `supabase.from('properties').select('*').eq('status', 'active').eq('is_featured', true).order('created_at', { ascending: false }).limit(10)`
- All properties: vertical list, infinite scroll
  - Query: `supabase.from('properties').select('*').eq('status', 'active').order('created_at', { ascending: false }).range(from, to)`
  - Apply filters: listing_type, property_type, city, district, price range

**Property Card (Horizontal):**
- Left: first image from images array, 120px width, full card height, 12px radius left
- If is_featured: gold "Öne Çıkan" badge on image
- If is_premium: purple "Premium" badge
- Listing type badge: top-left on image (Satılık=green, Kiralık=blue, Günlük=orange)
- Right side content:
  - Title (13px bold, 2 lines max)
  - Location: 📍 city + ", " + district (12px secondary)
  - Price: large bold, currency symbol (₺ or £ or $)
    - If listing_type='rent': append "/ay" (per month)
    - If listing_type='dailyRent': append "/gün" (per day)
  - Specs row: 🛏 rooms + " · " + 🚿 bathrooms + " · " + 📐 square_meters + " m²"
  - Favorite heart icon: top-right, tappable

### Property Detail Screen (/emlak/property/:id):
**Layout:**
- Image carousel: full width, 280px height, swipeable
  - Page counter: "3/12" top-right overlay
  - Favorite heart: top-right
  - Back button: top-left
  - Share button: second from right
- Listing type + property type badges
- Title (18px bold)
- Price (22px bold, teal colored)
- Location: 📍 full address
- Posted date: "X gün önce"

- **Specs Grid (3 columns, icon + label + value):**
  - Oda Sayısı: rooms
  - Banyo: bathrooms
  - m²: square_meters
  - Net m²: net_square_meters (if exists)
  - Kat: floor / total_floors
  - Bina Yaşı: building_age
  - Isıtma: heating_type
  - Cephe: facing_direction
  - İç Durum: interior_status

- **Description:** expandable text, "Devamını oku" button

- **Amenities section:** "Özellikler"
  - Group the boolean has_* fields by category
  - Show only true values as green checkmark + label chips
  - Categories: Genel, Iç Özellikler, Dış Özellikler, Manzara, Konum

- **Map Preview:**
  - 200px height, 12px radius, show property location pin
  - Tap → expand to full map

- **Owner/Contact section:**
  - If user_id is different from current user: show "İletişime Geç" teal button
  - Tap → create or open conversation

- **Track view:**
  - On screen open: `supabase.from('property_views').insert({ property_id: id, user_id: userId, device_info: platform })`

**Sticky bottom bar:**
- "İletişime Geç" teal button (full width)
- Or "Düzenle" if property belongs to current user

### Property Search / Filter Screen (/emlak/search):
**Full screen with filters:**
- Listing type: radio (Satılık, Kiralık, Günlük)
- Property type: multi-select chips
- City dropdown → District dropdown (cascading)
- Price range: min-max inputs
- Rooms: 1, 2, 3, 4, 5+ selector
- Square meters range: min-max
- Amenities: checkboxes grouped by category from `emlak_amenities`
  - Query: `supabase.from('emlak_amenities').select('*').eq('is_active', true).order('sort_order')`
- "Ara" (Search) teal button → navigate back to listing with filters applied

### Add Property Screen (/emlak/add) - Full screen:
**Multi-step form (progress bar at top):**

**Step 1 - Temel Bilgiler:**
- Listing type selector: Satılık / Kiralık / Günlük Kiralık
- Property type dropdown
- Title input
- Description textarea
- Price input + currency selector (TRY, GBP, EUR, USD)

**Step 2 - Detaylar:**
- Rooms, bathrooms, square_meters, net_square_meters inputs
- Floor / total_floors
- Building age
- Heating type dropdown
- Facing direction dropdown
- Interior status dropdown

**Step 3 - Özellikler:**
- Amenity toggles grouped by category
- Each amenity = switch toggle + label

**Step 4 - Konum:**
- City dropdown → District dropdown → Neighborhood input
- Address input
- Map picker: draggable pin to set latitude/longitude
- Or use current location button

**Step 5 - Fotoğraflar:**
- Image picker: multi-select from gallery or camera
- Upload to Supabase Storage: `supabase.storage.from('images').upload('properties/{userId}/{timestamp}_{index}', file)`
- Drag to reorder images
- First image = cover

**Step 6 - Önizleme & Yayınla:**
- Show preview of listing
- "Yayınla" button → insert into properties with status='pending'

```javascript
await supabase.from('properties').insert({
  user_id: currentUser.id,
  title, description, property_type, listing_type,
  price, currency, city, district, neighborhood, address,
  latitude, longitude, rooms, bathrooms, square_meters,
  floor, total_floors, building_age,
  images: uploadedImageUrls,
  // all has_* boolean fields from step 3
  status: 'pending',
  view_count: 0, favorite_count: 0
})
```

### My Listings (/emlak/my-listings):
- Query: `supabase.from('properties').select('*').eq('user_id', userId).order('created_at', { ascending: false })`
- Same property cards but with status badges (pending=orange, active=green, sold=grey)
- Tap → property detail
- Long press or menu: Edit / Mark as Sold / Delete

### Emlak Favorites (/emlak/favorites):
- Query: `supabase.from('property_favorites').select('*, properties(*)').eq('user_id', userId)`
- Property cards, heart filled
- Toggle favorite:
  - Add: `supabase.from('property_favorites').insert({ property_id, user_id })`
  - Remove: `supabase.from('property_favorites').delete().eq('property_id', id).eq('user_id', userId)`

### Emlak Chat (/emlak/chats, /emlak/chat/:conversationId):

**Chat List:**
- Query: `supabase.from('conversations').select('*, properties(title, images, price)').or('buyer_id.eq.{userId},seller_id.eq.{userId}').order('last_message_at', { ascending: false })`
- Each: property thumbnail + other person's name + last message preview + unread count badge + time

**Chat Screen:**
- Header: property mini-card (image + title + price)
- Messages list:
  - Query: `supabase.from('messages').select('*').eq('conversation_id', conversationId).order('created_at')`
  - Realtime: subscribe to INSERT on messages for this conversation
  - Bubbles: right=me (teal), left=other (grey surface)
- Input bar: text field + send button
- Send message:
```javascript
await supabase.from('messages').insert({
  conversation_id: conversationId,
  sender_id: currentUser.id,
  content: messageText,
  message_type: 'text'
})
// Update conversation last_message
await supabase.from('conversations').update({
  last_message: messageText,
  last_message_at: new Date(),
  last_message_sender_id: currentUser.id
}).eq('id', conversationId)
```

- Start new conversation (from property detail):
```javascript
// Check existing
const { data: existing } = await supabase.from('conversations')
  .select('id').eq('property_id', propertyId)
  .eq('buyer_id', currentUser.id).single()

if (existing) {
  navigateToChat(existing.id)
} else {
  const { data: conv } = await supabase.from('conversations').insert({
    property_id: propertyId,
    buyer_id: currentUser.id,
    seller_id: property.user_id
  }).select().single()
  navigateToChat(conv.id)
}
```

---

## MODULE 2: CAR SALES (/car-sales)

### Car Sales Home Screen (/car-sales):
**Layout:**
- Search bar: "Araç ara..."
- Brands section: horizontal scroll, circular logos
  - Query: `supabase.from('car_brands').select('*').eq('is_active', true).order('sort_order')`
  - Each: logo_url in 56px circle + name below
  - Tap brand → search filtered by brand
- Featured listings: horizontal scroll
  - Query: `supabase.from('car_listings').select('*').eq('status', 'active').eq('is_featured', true).order('created_at', { ascending: false }).limit(10)`
- Quick filters: body type chips
  - Query: `supabase.from('car_body_types').select('*').eq('is_active', true).order('sort_order')`
- All listings: vertical list, infinite scroll
  - Query: `supabase.from('car_listings').select('*').eq('status', 'active').order('created_at', { ascending: false }).range(from, to)`

**Car Listing Card:**
- Full-width image: first from images jsonb array, 180px height, 12px radius top
- Featured badge: gold, top-right
- Condition badge: top-left (Sıfır=green, İkinci El=blue)
- Below image (10px padding):
  - Title: brand_name + " " + model_name + " " + year (15px bold)
  - Specs row (chips): year | mileage + " km" | fuel_type | transmission
    - Use icons from car_fuel_types and car_transmissions
  - Location: 📍 city + ", " + district (12px secondary)
  - Price row: price (18px bold, right-aligned) + currency
    - If is_price_negotiable: "Pazarlık" badge
    - If is_exchange_accepted: "Takas" badge
  - Favorite heart: top-right of card

### Car Detail Screen (/car-sales/detail/:id):
**Layout:**
- Image gallery: full-screen swipeable carousel, page counter
  - Images from images jsonb array
- Back + share + favorite buttons overlaid on images

- **Header section:**
  - Title: brand_name + model_name (18px bold)
  - Year badge
  - Price: large (24px bold), red accent
  - Badges row: negotiable, exchange, condition

- **Quick specs grid (2x3):**
  - Yıl: year
  - KM: mileage (formatted with dots: 45.000)
  - Yakıt: fuel_type
  - Vites: transmission
  - Motor: engine_cc + " cc"
  - Güç: horsepower + " HP"

- **Detailed specs table (alternating row colors):**
  - Kasa Tipi: body_type
  - Çekiş: traction
  - Dış Renk: exterior_color
  - İç Renk: interior_color
  - Hasar Kaydı: has_accident_history ? "Var" (red) : "Yok" (green)
  - Boya: has_original_paint ? "Orijinal" (green) : "Boyalı" (orange)
  - Önceki Sahip: previous_owners
  - Garanti: has_warranty ? warranty_details : "Yok"
  - Plaka: plate_city

- **Features section:** "Donanımlar"
  - Parse features jsonb (array of feature IDs)
  - Cross-reference with car_features table: `supabase.from('car_features').select('*').in('id', featureIds)`
  - Group by category (Güvenlik, Konfor, Multimedya, etc.)
  - Each: ✓ checkmark + feature name, grouped under category headers

- **Description:** expandable
- **Location:** city + district on mini map

- **Seller info:**
  - If dealer_id exists: show dealer info
    - Query: `supabase.from('car_dealers').select('*').eq('id', dealerId).single()`
    - Dealer name, logo, rating, verified badge
  - If individual: show basic user info

**Sticky bottom bar (2 buttons side by side):**
- 📞 "Ara" (Call) - outlined button
- 💬 "Mesaj Gönder" - primary red button → open chat

**Track view:**
- `supabase.from('car_listing_views').insert({ listing_id: id, user_id: userId })`

### Car Search Screen (/car-sales/search):
**Advanced filter screen:**
- Brand dropdown (from car_brands, searchable)
- Model text input
- Year range: min year - max year sliders
- Price range: min - max inputs
- Body type: multi-select chips (from car_body_types)
- Fuel type: multi-select chips (from car_fuel_types)
- Transmission: multi-select chips (from car_transmissions)
- Mileage range: 0-10K, 10-50K, 50-100K, 100K+ chips
- Condition: Sıfır / İkinci El
- City dropdown
- "Ara" red button → apply filters

### Add Car Listing (/car-sales/add):
**Multi-step form:**

**Step 1:** Brand (searchable dropdown) → Model → Year → Body type
**Step 2:** Fuel, Transmission, Traction, Engine CC, Horsepower, Mileage
**Step 3:** Condition, Colors (exterior/interior), Previous owners, Accident history, Original paint, Warranty
**Step 4:** Features multi-select (grouped by category from car_features)
**Step 5:** Title, Description, Price, Currency, Negotiable toggle, Exchange toggle, City, District
**Step 6:** Photos (upload to Storage bucket "images" at `car-listings/{userId}/{timestamp}_{index}`)
**Step 7:** Preview → "İlan Ver" button

Insert:
```javascript
await supabase.from('car_listings').insert({
  user_id: currentUser.id,
  title, description, brand_id, brand_name, model_name, year,
  body_type, fuel_type, transmission, traction,
  engine_cc, horsepower, mileage,
  exterior_color, interior_color, condition,
  previous_owners, has_original_paint, has_accident_history,
  has_warranty, warranty_details,
  price, currency, is_price_negotiable, is_exchange_accepted,
  images: uploadedImageUrls, features: selectedFeatureIds,
  city, district, status: 'pending',
  view_count: 0, favorite_count: 0, contact_count: 0
})
```

### My Car Listings (/car-sales/my-listings):
- Query: `supabase.from('car_listings').select('*').eq('user_id', userId).order('created_at', { ascending: false })`
- Status badges: active=green, pending=orange, sold=grey, expired=red
- Menu: Edit / Mark Sold / Delete

### Car Favorites (/car-sales/favorites):
- Query: `supabase.from('car_favorites').select('*, car_listings(*)').eq('user_id', userId)`
- Toggle: insert/delete from car_favorites

### Car Chat (/car-sales/chats, /car-sales/chat/:conversationId):
- Same pattern as Emlak chat but using:
  - `car_conversations` instead of `conversations`
  - `car_messages` instead of `messages`
  - Show listing mini-card in header (car image + title + price)
  - Red accent instead of teal

---

## DATABASE TABLES

### properties
id(uuid), user_id(uuid), title(text), description(text), property_type(text), listing_type(text), status(text), price(numeric), currency(text), city(text), district(text), neighborhood(text), address(text), latitude(float8), longitude(float8), rooms(integer), bathrooms(integer), square_meters(integer), net_square_meters(integer), floor(integer), total_floors(integer), building_age(integer), heating_type(text), facing_direction(text), interior_status(text), images(ARRAY), view_count(integer), favorite_count(integer), is_featured(boolean), is_premium(boolean), created_at(timestamptz), has_parking(boolean), has_balcony(boolean), has_furniture(boolean), has_pool(boolean), has_gym(boolean), has_security(boolean), has_elevator(boolean), has_garden(boolean), has_terrace(boolean), has_storage(boolean), has_fireplace(boolean), has_air_conditioning(boolean), has_generator(boolean), has_natural_gas(boolean), has_steel_door(boolean), has_video_intercom(boolean), has_alarm(boolean), has_builtin_kitchen(boolean), has_jacuzzi(boolean), has_sauna(boolean), has_doorman(boolean), is_in_complex(boolean), has_garage(boolean), has_sea_view(boolean), has_city_view(boolean), has_mountain_view(boolean), has_nature_view(boolean), owner_type(text), room_type(text), furniture_status(text)

### emlak_cities
id(uuid), name(text), code(text), is_active(boolean), sort_order(integer)

### emlak_districts
id(uuid), city_id(uuid), name(text), is_active(boolean), sort_order(integer)

### emlak_property_types
id(uuid), name(text), label(text), icon(text), is_active(boolean), sort_order(integer)

### emlak_listing_types
id(uuid), name(text), label(text), color(text), is_active(boolean), sort_order(integer)

### emlak_amenities
id(uuid), name(text), label(text), icon(text), category(text), is_active(boolean), sort_order(integer)

### conversations
id(uuid), property_id(uuid), buyer_id(uuid), seller_id(uuid), last_message(text), last_message_at(timestamptz), last_message_sender_id(uuid), buyer_unread_count(integer), seller_unread_count(integer)

### messages
id(uuid), conversation_id(uuid), sender_id(uuid), content(text), message_type(text), is_read(boolean), created_at(timestamptz)

### property_favorites
id(uuid), property_id(uuid), user_id(uuid), created_at(timestamptz)

### property_views
id(uuid), property_id(uuid), user_id(uuid), device_info(text), viewed_at(timestamptz)

### appointments
id(uuid), property_id(uuid), requester_id(uuid), owner_id(uuid), appointment_date(date), appointment_time(time), status(text), note(text), response_note(text)

### car_listings
id(uuid), dealer_id(uuid), user_id(uuid), title(varchar), description(text), brand_id(varchar), brand_name(varchar), model_name(varchar), year(integer), body_type(varchar), fuel_type(varchar), transmission(varchar), traction(varchar), engine_cc(integer), horsepower(integer), mileage(integer), exterior_color(varchar), interior_color(varchar), condition(varchar), previous_owners(integer), has_original_paint(boolean), has_accident_history(boolean), has_warranty(boolean), warranty_details(text), plate_city(varchar), price(numeric), currency(varchar), is_price_negotiable(boolean), is_exchange_accepted(boolean), images(jsonb), features(jsonb), city(varchar), district(varchar), status(varchar), is_featured(boolean), is_premium(boolean), view_count(integer), favorite_count(integer), contact_count(integer), created_at(timestamptz)

### car_brands
id(varchar), name(varchar), logo_url(text), country(varchar), is_premium(boolean), is_popular(boolean), sort_order(integer), is_active(boolean)

### car_body_types
id(varchar), name(varchar), icon(varchar), sort_order(integer), is_active(boolean)

### car_fuel_types
id(varchar), name(varchar), icon(varchar), color(varchar), sort_order(integer), is_active(boolean)

### car_transmissions
id(varchar), name(varchar), icon(varchar), sort_order(integer), is_active(boolean)

### car_features
id(varchar), name(varchar), category(varchar), icon(varchar), sort_order(integer), is_active(boolean)

### car_favorites
id(uuid), listing_id(uuid), user_id(uuid), created_at(timestamptz)

### car_conversations
id(uuid), listing_id(uuid), buyer_id(uuid), seller_id(uuid), last_message(text), last_message_at(timestamptz), last_message_sender_id(uuid), buyer_unread_count(integer), seller_unread_count(integer), status(text)

### car_messages
id(uuid), conversation_id(uuid), sender_id(uuid), content(text), message_type(text), is_read(boolean), created_at(timestamptz)

### car_listing_views
id(uuid), listing_id(uuid), user_id(uuid), ip_address(text), viewed_at(timestamptz)

### car_contact_requests
id(uuid), listing_id(uuid), dealer_id(uuid), name(varchar), phone(varchar), email(varchar), message(text), status(text)

### car_dealers
id(uuid), user_id(uuid), dealer_type(varchar), business_name(varchar), phone(varchar), email(varchar), city(varchar), district(varchar), logo_url(text), average_rating(numeric), total_reviews(integer), is_verified(boolean), is_premium_dealer(boolean)

---

## INTEGRATION WITH PREVIOUS PARTS
- Home screen: "Öne Çıkan Mülkler" section now links to real property detail
- Favorites screen: wire "Mülkler" and "Arabalar" tabs to show property_favorites and car_favorites
- Update navigation: /emlak and /car-sales routes replace placeholders
- Emlak and Car chats should be accessible from profile or within the modules

Build all screens with complete CRUD functionality. Exact table/column names must match.
```
