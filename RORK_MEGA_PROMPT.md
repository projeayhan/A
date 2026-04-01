# SuperCyp - Rork Mega Prompt

Bu prompt'u Rork'a vererek mevcut Supabase backend'ine bağlanan süper uygulamanın tam klonunu oluşturabilirsin.

---

## PROMPT BAŞLANGIÇ

```
Build a complete React Native (Expo) super app called "SuperCyp" that connects to an EXISTING Supabase backend. The app must work immediately with the existing database - do NOT create any new tables or modify the backend. Use the exact table names, column names, and data types I provide below.

## APP IDENTITY
- App Name: SuperCyp
- Tagline: "Everything in Cyprus in one app"
- Support both light and dark themes

## UI/UX DESIGN SYSTEM (FOLLOW THIS EXACTLY)

### Design Philosophy
Modern, clean, premium feel. Think Uber + Getir + Bolt combined. Minimal but functional. Lots of whitespace, smooth animations, glass-morphism touches. The app should feel like a top-tier startup product, NOT a template.

### Color System
**Primary:** #256AF4 (Blue) - main actions, links, selected states
**Food Service Accent:** #EC6D13 (Orange) - use on food-related screens
**Store/Market Accent:** #6366F1 (Indigo) - use on store/market screens
**Status:** Success #10B981, Warning #F59E0B, Error #EF4444, Info #3B82F6

**Light Theme:**
- Background: #FFFFFF
- Surface/Card: #F8F9FC
- Text Primary: #0D121C
- Text Secondary: #6B7280
- Border: #E5E7EB
- Divider: rgba(0,0,0,0.05)

**Dark Theme:**
- Background: #101622
- Surface/Card: #1A2230
- Text Primary: #FFFFFF
- Text Secondary: #9CA3AF
- Border: #374151
- Divider: rgba(255,255,255,0.08)

### Typography (Mobile-First)
- Page Title: 18px bold
- Section Title: 15px bold
- Card Title: 13px bold
- Body: 13px regular
- Body Small: 12px regular
- Caption: 11px regular
- Price Text: 14px bold
- Button Text: 14px semibold (600)
- Tab Label: 10px, bold when selected

Use system font (San Francisco on iOS, Roboto on Android). No custom fonts needed.

### Spacing & Layout
- Page horizontal padding: 12px
- Section gap: 16px
- Card padding: 8-12px
- Item gap in lists: 8px
- Standard margin between elements: 8px
- Grid gap: 8px

### Border Radius
- Small (badges, chips): 6px
- Medium (inputs, buttons, cards): 10px
- Large (cards, images): 12px
- XL (feature cards, service grid): 16px
- Bottom sheets/modals: 20px (top corners only)

### Shadows (Subtle, Premium Feel)
- Card shadow: `0 2px 8px rgba(0,0,0,0.05)` (light), `0 2px 8px rgba(0,0,0,0.2)` (dark)
- Elevated shadow: `0 4px 12px rgba(0,0,0,0.1)`
- Bottom nav shadow: `0 -4px 20px rgba(0,0,0,0.05)`
- Primary button shadow: `0 4px 12px rgba(37,106,244,0.3)`
- Floating elements: `0 8px 24px rgba(0,0,0,0.15)`

### Button Styles
**Primary Button:**
- Background: #256AF4, text: white
- Height: 44px, border radius: 10px
- Shadow: primary color shadow (blue glow effect)
- Padding: 12px vertical, 16px horizontal
- Full width on mobile, centered text

**Secondary/Outlined Button:**
- Background: transparent, border: 1px #E5E7EB
- Height: 40px, border radius: 10px
- Text: primary text color

**Small Action Button (Add to Cart etc):**
- Size: 28px circular
- Background: dark surface, icon: white
- Shadow: subtle drop shadow
- Position: overlapping card corner

### Input Fields
- Filled style, background: surface color
- Border radius: 10px
- Border: 1px border color, 1.5px primary on focus
- Padding: 12px all sides
- Dense mode (compact height)
- Placeholder: text secondary color

### Card Patterns

**Restaurant/Store Card (Vertical):**
- Image on top: 140px height, 12px border radius (top only)
- Content padding: 8px
- Title: 13px bold, 1 line max
- Subtitle: 12px secondary, 1 line
- Rating badge: star icon + number, small
- Delivery time badge: top-left overlay, 6px radius
- Discount badge: colored pill, top-left

**Menu Item Card (Horizontal Row):**
- Image on RIGHT side: 64px square, 8px radius
- Content on left: title (14px), description (12px, 2 lines max), price
- Add button: 28px circle, overlapping image bottom-right
- Bottom border or subtle divider between items

**Product Card (Grid):**
- Square aspect ratio (1:1)
- Image fills top, 10px radius top only
- Price: bold, original price strikethrough if discounted
- Discount percentage badge: top-left

**Property Card:**
- Horizontal image: 120px width, full height, 12px radius left
- Right side: title, location, price, specs row (rooms/bath/sqm)
- Featured badge: gold/amber colored

**Car Listing Card:**
- Full-width image: 180px, 12px radius top
- Specs row below: year | mileage | fuel | transmission (icon + text chips)
- Price: large, bold, right-aligned

**Job Card:**
- No image, icon/logo only
- Company logo: 40px circle
- Tags: job type, experience level as colored chips
- Salary range: green text if visible
- Urgent badge: red pulsing dot

### Navigation

**Bottom Tab Bar:**
- Height: 56px + safe area
- Background: surface color with 0.95 opacity (frosted glass effect)
- Top border: 1px subtle
- Shadow: upward soft shadow
- 4 tabs: Home, Favorites, Orders, Profile
- Icons: 22px, outlined when inactive, filled when active
- Active color: primary blue
- Inactive color: #9CA3AF
- Label: 10px, show always
- Active tab: subtle scale animation

**Top App Bar / Header:**
- Transparent or surface color
- Back button: left arrow, 40px touch target
- Title: centered, 15px bold
- Actions: right-aligned icon buttons

### Home Screen Layout (Critical - This is the first impression)

1. **Header:** Delivery address selector with down arrow, user avatar right
2. **Search Bar:** Rounded, 10px radius, search icon, placeholder "Ne arıyorsunuz?" (What are you looking for?), tappable (navigates to search screen)
3. **Banner Carousel:** 160px height, auto-scroll every 3s, page indicator dots, 0.9 viewport fraction (shows peek of next slide), 14px border radius
4. **Service Grid:** 4 columns x 2 rows grid
   - Each service: 60px icon container (gradient background matching service color) + label below
   - Icon containers: 12px border radius, subtle gradient (e.g., Food: orange gradient, Taxi: yellow gradient, Emlak: green gradient)
   - Labels: 11px, centered
   - Decorative: small circle ornament on icon container
5. **Section: "Yakınındaki Restoranlar"** (Nearby Restaurants) - horizontal scroll, restaurant cards
6. **Section: "Öne Çıkan Mülkler"** (Featured Properties) - horizontal scroll, property cards
7. **Section: "Güncel İş İlanları"** (Latest Jobs) - vertical list, 3 items

### Screen-Specific Design Notes

**Taxi Screens (Uber-like):**
- Full-screen map background
- Bottom sheet overlay for controls (slide up/down)
- Pickup/dropoff: pill-shaped input, green dot for pickup, red dot for dropoff
- Vehicle selection: horizontal scroll cards, selected has primary border + check
- Driver card: slide up from bottom, avatar + name + rating + vehicle info + plate
- Ride tracking: polyline route on map, driver marker moves in real-time
- SOS button: red, top-right, always visible during ride

**Food Ordering (Getir/Uber Eats-like):**
- Restaurant list: vertical scroll with horizontal category filter chips on top
- Menu: sticky category tabs at top, scroll synced with sections
- Cart: floating bottom bar showing item count + total + "Sepeti Gör" button
- Cart screen: item list with quantity steppers, coupon input, address, payment summary

**Emlak (Property - Sahibinden-like):**
- Property detail: full-width image carousel with page counter
- Specs grid: 3 columns (Oda, Banyo, m²), icon + value
- Amenity chips: scrollable row of small pills
- Map preview: 200px height, rounded, tappable to expand
- Contact button: sticky bottom, full-width, primary color

**Car Sales (Arabam.com-like):**
- Listing detail: full-screen image gallery with swipe
- Specs table: alternating row colors, icon + label + value
- Features: grouped by category (Güvenlik, Konfor), checkmark list
- Price: large, right-aligned, negotiable badge if applicable
- Contact actions: Call + Message buttons side by side

**Jobs (LinkedIn-like):**
- Clean card-based list
- Company logo prominent
- Colored chips for job type (green: full_time, blue: remote, orange: contract)
- Apply button: primary, full-width at bottom of detail
- Application form: multi-step with progress indicator

### Loading States
- Skeleton/shimmer loading for all lists and cards
- Shimmer: base grey[300] to highlight grey[100] animation
- Match exact card dimensions for skeleton placeholders
- Pulse animation, 1.5s duration, infinite

### Empty States
- Centered illustration area (use emoji or simple icon, 80px)
- Title: 16px bold
- Subtitle: 13px secondary
- Action button if applicable

### Pull-to-Refresh
- All list screens must have pull-to-refresh
- Use platform-native refresh indicator
- Primary color spinner

### Animations & Micro-interactions
- Page transitions: slide from right (default stack navigation)
- Tab switch: cross-fade
- Card press: subtle scale down to 0.98, 100ms
- Button press: scale down to 0.95, haptic feedback
- Add to cart: flying item animation (item flies to cart icon, 800ms, parabolic path)
- List item appear: fade in + slide up, staggered 50ms delay
- Bottom sheet: spring animation from bottom
- Favorite toggle: heart scale bounce + color change
- Notification badge: pulse animation on new count

## SUPABASE CONNECTION
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY
- Use @supabase/supabase-js library
- Auth uses PKCE flow

## GOOGLE MAPS
- API Key: AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ
- Used for taxi pickup/dropoff, restaurant/store locations, property locations

## STRIPE PAYMENTS
- Publishable Key: pk_test_51SVdN5FDnYENSMiEmmn7zxiTQn8WLL6wqYr4xXnFMzVxfs1YkBLCqbGTivtYzQGBhrsbsLE2vzgXAbjp5Oj2rZcT00MzbxivbO
- Payment is processed via Edge Function "create-payment-intent"
- For mobile: returns client_secret for Stripe Payment Sheet
- For web: returns checkout session URL

## AUTHENTICATION
The app must support these auth methods using Supabase Auth:
1. **Email/Password** - signUp, signIn with email+password
2. **Google OAuth** - signInWithOAuth provider: 'google'
3. **Apple OAuth** - signInWithOAuth provider: 'apple'
4. **Phone OTP** - Call edge function "phone-verify" to send OTP, then verify

After login, fetch user profile from `users` table where id = auth.user.id
If user has no first_name, redirect to profile edit screen.

Block login if user role is 'support_agent' (this is admin-only role).

## NAVIGATION STRUCTURE

### Bottom Tab Navigation (4 tabs):
1. **Home** (/) - Service discovery grid + banners carousel
2. **Favorites** (/favorites) - Saved items across all services
3. **Orders** (/orders) - Order history across all services
4. **Profile** (/profile) - User account & settings

### Service Modules (accessible from Home):

#### 1. FOOD DELIVERY (/food)
Tables used: `merchants` (where type='restaurant'), `menu_categories`, `menu_items`, `menu_item_option_groups`, `product_option_groups`, `product_options`, `orders`, `reviews`, `restaurant_categories`, `favorites`

Screens:
- Food Home: List restaurants with categories, search, filters
- Restaurant Detail: Menu categories, menu items with options
- Food Item Detail: Item details with option groups (size, toppings etc)
- Cart: Items with quantities, options, delivery address, total calculation
- Order placement: Create order in `orders` table
- Order Tracking: Real-time status updates (pending→confirmed→preparing→ready→picked_up→delivered)
- Order Review: Rate order after delivery

Key queries:
- Get restaurants: `supabase.from('merchants').select('*').eq('type', 'restaurant').eq('is_approved', true).eq('is_open', true)`
- Get menu: `supabase.from('menu_items').select('*, menu_item_option_groups(*, product_option_groups(*, product_options(*)))').eq('merchant_id', id).eq('is_available', true)`
- RPC for nearby: `supabase.rpc('get_restaurants_in_delivery_range', { user_lat, user_lng })`

#### 2. STORE/MARKETPLACE (/market)
Tables used: `merchants` (where type='store'), `products`, `product_categories`, `store_categories`, `orders`, `merchant_followers`, `store_messages`

Screens:
- Store Home: Store categories grid, featured stores
- Store Detail: Products by category, store info, follow button
- Product Detail: Images, variants, price, add to cart
- Store Cart: Multi-store cart management
- Checkout: Address, payment, order creation

Key queries:
- Get stores: `supabase.from('merchants').select('*').eq('type', 'store').eq('is_approved', true)`
- Get products: `supabase.from('products').select('*').eq('merchant_id', storeId).eq('is_available', true)`
- RPC: `supabase.rpc('get_stores_in_delivery_range', { user_lat, user_lng })`

#### 3. GROCERY (/grocery)
Same as Store but filtered for grocery type merchants. Uses same tables.

#### 4. TAXI SERVICE (/taxi) - FULL SCREEN (no bottom tabs)
Tables used: `taxi_rides`, `taxi_drivers`, `vehicle_types`, `taxi_pricing`, `taxi_feedback_tags`, `driver_review_details`, `ride_communications`, `saved_locations`

Screens:
- Taxi Home: Map with pickup location, "Where to?" button
- Destination Selection: Search places, saved locations, recent locations
- Vehicle Selection: Show vehicle types with estimated fares
- Searching: Animation while finding driver
- Ride Screen: Real-time map tracking, driver info, chat, SOS button
- Rating: Star rating + feedback tags after ride

Key queries:
- Get vehicle types: `supabase.from('vehicle_types').select('*').eq('is_active', true).order('sort_order')`
- Get pricing: `supabase.from('taxi_pricing').select('*').eq('is_active', true)`
- Create ride: Insert into `taxi_rides` with status='pending'
- Subscribe to ride updates: `supabase.channel('ride-updates').on('postgres_changes', { event: '*', schema: 'public', table: 'taxi_rides', filter: 'id=eq.{rideId}' })`
- RPC calls: `get_secure_driver_info`, `send_ride_message`, `create_ride_share_link`

Fare calculation: baseFare + (perKmRate * distanceKm) + (perMinuteRate * durationMinutes), minimum minimumFare

Vehicle Types: Economy, Comfort, Premium, XL, VIP, Kulis

#### 5. CAR RENTAL (/rental)
Tables used: `rental_cars`, `rental_companies`, `rental_locations`, `rental_bookings`, `rental_services`, `rental_reviews`, `rental_packages`

Screens:
- Rental Home: Search by dates, location, filter by category
- Car Detail: Images, specs, pricing, reviews, book button
- My Bookings: List user's rental bookings

Key queries:
- Get cars: `supabase.from('rental_cars').select('*, rental_companies(*)').eq('is_active', true).eq('status', 'available')`
- Get locations: `supabase.from('rental_locations').select('*').eq('is_active', true)`
- Create booking: Insert into `rental_bookings`

#### 6. REAL ESTATE - EMLAK (/emlak)
Tables used: `properties`, `conversations`, `messages`, `property_views`, `property_favorites`, `emlak_cities`, `emlak_districts`, `emlak_property_types`, `emlak_listing_types`, `emlak_amenities`, `emlak_settings`, `appointments`

Screens:
- Emlak Home: Featured properties, search, listing types (Sale/Rent)
- Property Detail: Image gallery, details, amenities, map, contact seller
- Property Search: Advanced filters (type, price range, rooms, city, district, amenities)
- Add Property: Multi-step form to create listing
- My Listings: User's property listings
- Favorites: Saved properties
- Chat: Buyer-seller messaging via `conversations` + `messages` tables

Key queries:
- Get properties: `supabase.from('properties').select('*').eq('status', 'active').order('created_at', { ascending: false })`
- Get cities: `supabase.from('emlak_cities').select('*').eq('is_active', true).order('sort_order')`
- Get districts: `supabase.from('emlak_districts').select('*').eq('city_id', cityId).eq('is_active', true)`

Property types: apartment, villa, twinVilla, residence, penthouse, bungalow, detachedHouse, land, office, shop
Listing types: sale (Satılık), rent (Kiralık), dailyRent (Günlük Kiralık)

#### 7. CAR SALES (/car-sales)
Tables used: `car_listings`, `car_brands`, `car_body_types`, `car_fuel_types`, `car_transmissions`, `car_features`, `car_favorites`, `car_conversations`, `car_messages`, `car_contact_requests`, `car_dealers`

Screens:
- Car Sales Home: Featured listings, brands, search
- Car Detail: Image gallery, specs, features, price, seller info, message button
- Car Search: Filters (brand, model, year range, price range, fuel, transmission, body type)
- Add Listing: Create car listing with images
- My Listings: User's car listings
- Favorites: Saved car listings
- Chat: Buyer-seller messaging via `car_conversations` + `car_messages`

Key queries:
- Get listings: `supabase.from('car_listings').select('*').eq('status', 'active').order('created_at', { ascending: false })`
- Get brands: `supabase.from('car_brands').select('*').eq('is_active', true).order('sort_order')`
- Get features: `supabase.from('car_features').select('*').eq('is_active', true)`

#### 8. JOBS PLATFORM (/jobs)
Tables used: `job_listings`, `job_categories`, `job_subcategories`, `job_skills`, `job_benefits`, `job_applications`, `job_favorites`, `job_conversations`, `job_messages`, `job_posters`, `companies`, `job_promotion_prices`

Screens:
- Jobs Home: Categories, featured/urgent jobs, search
- Job Detail: Full description, requirements, skills, benefits, apply button
- Job Search: Filters (category, type, experience, salary range, city)
- Add Listing: Post new job listing
- My Listings: User's job postings

Key queries:
- Get listings: `supabase.from('job_listings').select('*, job_posters(*), companies(*)').eq('status', 'active').order('created_at', { ascending: false })`
- Get categories: `supabase.from('job_categories').select('*').eq('is_active', true).order('sort_order')`
- Apply: Insert into `job_applications`

Job types: full_time, part_time, contract, internship, freelance, remote, temporary
Work arrangements: onsite, remote, hybrid
Experience levels: entry, junior, mid_level, senior, lead, director, executive

#### 9. SUPPORT & AI (/support)
Tables used: `support_chat_sessions`, `support_chat_messages`, `ai_knowledge_base`

Screens:
- AI Chat: Streaming chat with AI assistant
  - Call edge function "ai-chat" with POST, stream response
  - Save messages to `support_chat_messages`

#### 10. PROFILE & SETTINGS (/profile, /settings)
Tables used: `users`, `saved_locations`, `payment_methods`, `notification_preferences`, `communication_preferences`

Screens:
- Profile: Avatar, name, stats
- Personal Info: Edit first_name, last_name, phone, email, date_of_birth, gender
- Saved Addresses: CRUD on `saved_locations` table
- Payment Methods: List from `payment_methods`
- Security: Password change via supabase.auth.updateUser
- Notifications: Toggle preferences in `notification_preferences`
- Emergency Contacts: Stored in `communication_preferences.emergency_contacts` (jsonb)

#### 11. NOTIFICATIONS
Tables used: `notifications`
- Fetch: `supabase.from('notifications').select('*').eq('user_id', userId).order('created_at', { ascending: false })`
- Real-time: Subscribe to new notifications
- Mark read: Update `is_read` to true

## HOME SCREEN LAYOUT
1. **Banners Carousel** - From `banners` table where is_active=true, ordered by sort_order
2. **Service Grid** - 8 service icons in a 4x2 grid:
   - 🍽️ Yemek (Food) → /food
   - 🛒 Market → /market
   - 🥬 Manav (Grocery) → /grocery
   - 🚕 Taksi → /taxi
   - 🚗 Kiralık Araç (Rental) → /rental
   - 🏠 Emlak → /emlak
   - 🚙 Araba Satış (Car Sales) → /car-sales
   - 💼 İş İlanları (Jobs) → /jobs
3. **Nearby Restaurants** - Top rated restaurants nearby
4. **Featured Properties** - Premium/featured properties
5. **Recent Job Listings** - Latest job postings

## REALTIME SUBSCRIPTIONS
Use Supabase Realtime for:
1. `taxi_rides` - Ride status changes
2. `orders` - Order status changes
3. `notifications` - New notifications
4. `messages` / `car_messages` / `job_messages` - Chat messages
5. `ride_communications` - Taxi ride chat

Pattern:
```javascript
supabase.channel('channel-name')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'public',
    table: 'table_name',
    filter: 'column=eq.value'
  }, (payload) => { /* handle */ })
  .subscribe()
```

## IMAGE UPLOADS
Use Supabase Storage bucket "images":
```javascript
const { data } = await supabase.storage.from('images').upload(path, file)
const { data: { publicUrl } } = supabase.storage.from('images').getPublicUrl(path)
```
Used for: car listing photos, property photos, profile pictures

## EDGE FUNCTIONS USED BY THE APP
1. **create-payment-intent** - POST with { amount, currency, metadata }
2. **ai-chat** - POST with { message, sessionId, context } - returns streaming response
3. **phone-verify** - POST with { phone, action: 'send'|'verify', code? }
4. **moderate-listing** - POST with { listingType, listingId, content }

## RPC FUNCTIONS USED BY THE APP
1. `get_restaurants_in_delivery_range(user_lat, user_lng)` - Returns nearby restaurants
2. `get_stores_in_delivery_range(user_lat, user_lng)` - Returns nearby stores
3. `get_restaurants_by_menu_category(category_id)` - Filter by food category
4. `get_secure_driver_info(ride_id)` - Masked driver contact for customer
5. `send_ride_message(ride_id, message, sender_type)` - Send message during ride
6. `create_ride_share_link(ride_id)` - Generate live tracking link
7. `increment_job_listing_view(listing_id)` - Track job views
8. `check_login_blocked(email)` - Check rate limiting
9. `delete_user_account()` - GDPR account deletion
10. `export_user_data()` - GDPR data export

## IMPORTANT RULES
1. Do NOT create any database tables - use ONLY the existing tables listed above
2. Match column names EXACTLY as specified
3. All IDs are UUID type
4. Use TypeScript throughout
5. Implement pull-to-refresh on all list screens
6. Implement infinite scroll pagination (limit 20 per page)
7. Handle loading states with shimmer/skeleton screens (NOT spinners)
8. Handle empty states with centered icon + message + action button
9. All monetary values use `numeric` type in DB
10. Implement proper error handling for all Supabase calls
11. Use Supabase Auth session management with auto-refresh
12. Turkish is the primary language, but support English too
13. The `users` table has `is_banned` field - block banned users from logging in
14. FOLLOW THE DESIGN SYSTEM EXACTLY - border radius, shadows, colors, spacing as specified
15. Every screen must support both light and dark themes
16. Use shimmer loading states that match the exact card/list dimensions
17. Add subtle press animations on all tappable elements (scale to 0.98)
18. Bottom sheets must have spring animation and drag handle (40px wide, 4px height, grey pill)
19. All images must have placeholder/fallback and fade-in animation on load
20. Use platform-native haptic feedback on button presses
21. Cards must have subtle shadow and 1px border for depth
22. The app must look like Uber/Bolt quality, NOT a generic template

## COMPLETE DATABASE SCHEMA

### users
id(uuid), email(text), first_name(text), last_name(text), phone(text), avatar_url(text), date_of_birth(date), gender(text), membership_type(text), total_orders(integer), total_favorites(integer), average_rating(numeric), loyalty_points(integer), created_at(timestamptz), updated_at(timestamptz), full_name(text), is_banned(boolean)

### merchants
id(uuid), user_id(uuid), type(varchar) ['restaurant'|'store'|'grocery'], business_name(varchar), phone(varchar), email(varchar), is_open(boolean), is_approved(boolean), created_at(timestamptz), description(text), logo_url(text), cover_url(text), address(text), latitude(numeric), longitude(numeric), rating(numeric), review_count(integer), total_orders(integer), delivery_time(varchar), min_order_amount(numeric), delivery_fee(numeric), free_delivery_threshold(numeric), avg_preparation_time(integer), commission_rate(numeric), tags(ARRAY), category_tags(ARRAY), discount_badge(varchar), updated_at(timestamptz), follower_count(integer), store_category_ids(ARRAY), working_hours(jsonb), is_frozen(boolean)

### menu_categories
id(uuid), merchant_id(uuid), name(varchar), description(text), image_url(text), sort_order(integer), is_active(boolean)

### menu_items
id(uuid), merchant_id(uuid), name(varchar), description(text), price(numeric), category(varchar), image_url(text), is_available(boolean), sort_order(integer), discounted_price(numeric), is_popular(boolean), category_id(uuid), preparation_time(integer), review_count(integer), average_rating(numeric)

### product_option_groups
id(uuid), merchant_id(uuid), name(varchar), description(text), is_required(boolean), min_selections(integer), max_selections(integer), sort_order(integer)

### product_options
id(uuid), option_group_id(uuid), name(varchar), price(numeric), is_available(boolean), sort_order(integer)

### menu_item_option_groups
id(uuid), menu_item_id(uuid), option_group_id(uuid)

### orders
id(uuid), order_number(varchar), user_id(uuid), merchant_id(uuid), items(jsonb), subtotal(numeric), delivery_fee(numeric), total_amount(numeric), delivery_address(text), status(varchar) ['pending'|'confirmed'|'preparing'|'ready'|'picked_up'|'delivered'|'cancelled'], created_at(timestamptz), updated_at(timestamptz), service_fee(numeric), discount_amount(numeric), delivery_latitude(numeric), delivery_longitude(numeric), payment_method(varchar), payment_status(varchar), customer_name(varchar), customer_phone(varchar), is_reviewed(boolean), store_name(text)

### reviews
id(uuid), order_id(uuid), merchant_id(uuid), user_id(uuid), rating(integer), comment(text), merchant_reply(text), replied_at(timestamptz), created_at(timestamptz), customer_name(varchar)

### restaurant_categories
id(uuid), name(varchar), image_url(text), icon(varchar), sort_order(integer), is_active(boolean)

### store_categories
id(uuid), name(varchar), icon_name(varchar), color(varchar), store_count(integer), sort_order(integer), is_active(boolean), image_url(text)

### products
id(uuid), merchant_id(uuid), category_id(uuid), name(varchar), description(text), price(numeric), original_price(numeric), image_url(text), images(ARRAY), stock(integer), sold_count(integer), rating(numeric), review_count(integer), is_available(boolean), is_featured(boolean), variants(jsonb), brand(varchar)

### favorites
id(uuid), user_id(uuid), merchant_id(uuid), created_at(timestamptz)

### saved_locations
id(uuid), user_id(uuid), title(varchar), address(text), latitude(numeric), longitude(numeric), type(varchar) ['home'|'work'|'other'], is_default(boolean), name(varchar), address_details(text), floor(varchar), apartment(varchar), directions(text)

### taxi_rides
id(uuid), ride_number(varchar), user_id(uuid), driver_id(uuid), pickup_address(text), pickup_lat(numeric), pickup_lng(numeric), dropoff_address(text), dropoff_lat(numeric), dropoff_lng(numeric), distance_km(numeric), duration_minutes(integer), fare(numeric), status(varchar) ['pending'|'accepted'|'arrived'|'in_progress'|'completed'|'cancelled'], created_at(timestamptz), accepted_at(timestamptz), arrived_at(timestamptz), picked_up_at(timestamptz), completed_at(timestamptz), cancelled_at(timestamptz), cancellation_reason(text), rating(integer), rating_comment(text), tip_amount(numeric), vehicle_type(varchar)

### taxi_drivers
id(uuid), user_id(uuid), full_name(varchar), phone(varchar), profile_photo_url(text), vehicle_brand(varchar), vehicle_model(varchar), vehicle_year(integer), vehicle_plate(varchar), vehicle_color(varchar), status(varchar), is_online(boolean), current_latitude(numeric), current_longitude(numeric), rating(numeric), total_ratings(integer), total_rides(integer), vehicle_types(ARRAY)

### vehicle_types
id(uuid), name(varchar), display_name(varchar), icon_name(varchar), default_base_fare(numeric), default_per_km(numeric), default_per_minute(numeric), default_minimum_fare(numeric), capacity(integer), is_active(boolean), sort_order(integer)

### taxi_pricing
id(uuid), vehicle_type_id(uuid), base_fare(numeric), per_km_fare(numeric), per_minute_fare(numeric), minimum_fare(numeric), surge_multiplier(numeric), is_active(boolean)

### taxi_feedback_tags
id(uuid), tag_key(varchar), tag_text_tr(varchar), tag_text_en(varchar), category(varchar), icon_name(varchar), sort_order(integer), is_active(boolean)

### ride_communications
id(uuid), ride_id(uuid), sender_type(varchar), sender_id(uuid), message_type(varchar), content(text), is_read(boolean), created_at(timestamptz)

### rental_cars
id(uuid), company_id(uuid), location_id(uuid), brand(varchar), model(varchar), year(integer), category(varchar), transmission(varchar), fuel_type(varchar), seats(integer), doors(integer), luggage_capacity(integer), daily_price(numeric), weekly_price(numeric), monthly_price(numeric), deposit_amount(numeric), image_url(text), images(jsonb), features(jsonb), status(varchar), is_active(boolean)

### rental_companies
id(uuid), company_name(varchar), logo_url(text), phone(varchar), email(varchar), rating(numeric), is_approved(boolean), is_active(boolean)

### rental_locations
id(uuid), company_id(uuid), name(varchar), address(text), city(varchar), district(varchar), latitude(numeric), longitude(numeric), is_airport(boolean), is_active(boolean)

### rental_bookings
id(uuid), booking_number(varchar), user_id(uuid), company_id(uuid), car_id(uuid), pickup_location_id(uuid), dropoff_location_id(uuid), pickup_date(timestamptz), dropoff_date(timestamptz), daily_rate(numeric), rental_days(integer), subtotal(numeric), total_amount(numeric), selected_services(jsonb), customer_name(varchar), customer_phone(varchar), status(varchar) ['pending'|'confirmed'|'active'|'completed'|'cancelled'], payment_status(varchar), payment_method(varchar)

### rental_services
id(uuid), company_id(uuid), name(varchar), description(text), price_type(varchar), price(numeric), icon(varchar), is_active(boolean)

### rental_packages
id(uuid), company_id(uuid), tier(varchar), name(varchar), description(text), daily_price(numeric), included_services(jsonb), is_popular(boolean), is_active(boolean), sort_order(integer)

### properties
id(uuid), user_id(uuid), title(text), description(text), property_type(text), listing_type(text) ['sale'|'rent'|'dailyRent'], status(text) ['active'|'pending'|'sold'|'rented'], price(numeric), currency(text), city(text), district(text), neighborhood(text), address(text), latitude(float8), longitude(float8), rooms(integer), bathrooms(integer), square_meters(integer), floor(integer), total_floors(integer), building_age(integer), images(ARRAY), view_count(integer), favorite_count(integer), is_featured(boolean), is_premium(boolean), created_at(timestamptz), [50+ boolean amenity fields like has_parking, has_balcony, has_pool, has_elevator, etc.]

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

### conversations (emlak chat)
id(uuid), property_id(uuid), buyer_id(uuid), seller_id(uuid), last_message(text), last_message_at(timestamptz), buyer_unread_count(integer), seller_unread_count(integer)

### messages (emlak chat)
id(uuid), conversation_id(uuid), sender_id(uuid), content(text), message_type(text), is_read(boolean), created_at(timestamptz)

### property_favorites
id(uuid), property_id(uuid), user_id(uuid), created_at(timestamptz)

### car_listings
id(uuid), dealer_id(uuid), user_id(uuid), title(varchar), description(text), brand_id(varchar), brand_name(varchar), model_name(varchar), year(integer), body_type(varchar), fuel_type(varchar), transmission(varchar), traction(varchar), engine_cc(integer), horsepower(integer), mileage(integer), exterior_color(varchar), interior_color(varchar), condition(varchar), price(numeric), currency(varchar), is_price_negotiable(boolean), is_exchange_accepted(boolean), images(jsonb), features(jsonb), city(varchar), district(varchar), status(varchar) ['active'|'pending'|'sold'|'reserved'|'expired'], is_featured(boolean), is_premium(boolean), view_count(integer), favorite_count(integer), created_at(timestamptz)

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
id(uuid), listing_id(uuid), buyer_id(uuid), seller_id(uuid), last_message(text), last_message_at(timestamptz), buyer_unread_count(integer), seller_unread_count(integer), status(text)

### car_messages
id(uuid), conversation_id(uuid), sender_id(uuid), content(text), message_type(text), is_read(boolean), created_at(timestamptz)

### car_contact_requests
id(uuid), listing_id(uuid), dealer_id(uuid), name(varchar), phone(varchar), email(varchar), message(text), status(text)

### job_listings
id(uuid), user_id(uuid), poster_id(uuid), company_id(uuid), title(varchar), description(text), category_id(varchar), subcategory(varchar), job_type(enum) ['full_time'|'part_time'|'contract'|'internship'|'freelance'|'remote'|'temporary'], work_arrangement(enum) ['onsite'|'remote'|'hybrid'], experience_level(enum) ['entry'|'junior'|'mid_level'|'senior'|'lead'|'director'|'executive'], salary_min(numeric), salary_max(numeric), salary_currency(varchar), is_salary_hidden(boolean), city(varchar), district(varchar), positions(integer), responsibilities(ARRAY), qualifications(ARRAY), required_skills(ARRAY), manual_benefits(ARRAY), status(enum) ['pending'|'active'|'closed'|'filled'|'expired'], is_featured(boolean), is_premium(boolean), is_urgent(boolean), view_count(integer), application_count(integer), created_at(timestamptz), listing_type(text) ['hiring'|'seeking']

### job_categories
id(varchar), name(varchar), icon(varchar), color(varchar), sort_order(integer), is_active(boolean)

### job_subcategories
id(uuid), category_id(varchar), name(varchar), sort_order(integer), is_active(boolean)

### job_skills
id(varchar), name(varchar), category(varchar), is_popular(boolean), usage_count(integer)

### job_benefits
id(varchar), name(varchar), icon(varchar), category(varchar), sort_order(integer), is_active(boolean)

### job_applications
id(uuid), listing_id(uuid), user_id(uuid), poster_id(uuid), applicant_name(varchar), applicant_email(varchar), applicant_phone(varchar), cover_letter(text), resume_url(text), portfolio_links(ARRAY), status(enum) ['pending'|'reviewed'|'shortlisted'|'interview'|'offered'|'hired'|'rejected']

### job_favorites
id(uuid), listing_id(uuid), user_id(uuid), created_at(timestamptz)

### job_conversations
id(uuid), job_listing_id(uuid), applicant_id(uuid), poster_id(uuid), last_message(text), last_message_at(timestamptz), applicant_unread_count(integer), poster_unread_count(integer)

### job_messages
id(uuid), conversation_id(uuid), sender_id(uuid), content(text), message_type(text), is_read(boolean), created_at(timestamptz)

### companies
id(uuid), user_id(uuid), name(varchar), logo_url(text), website(varchar), industry(varchar), size(varchar), description(text), city(varchar), rating(numeric), is_verified(boolean), is_premium(boolean), status(varchar)

### job_posters
id(uuid), user_id(uuid), company_id(uuid), name(varchar), title(varchar), image_url(text), is_verified(boolean), status(varchar)

### banners
id(uuid), title(varchar), description(text), image_url(text), link_url(text), is_active(boolean), sort_order(integer), starts_at(timestamptz), ends_at(timestamptz), category(varchar), link_type(varchar), link_id(uuid), status(varchar)

### notifications
id(uuid), user_id(uuid), title(text), body(text), type(text), data(jsonb), is_read(boolean), created_at(timestamptz)

### payment_methods
id(uuid), user_id(uuid), type(text), provider(text), card_last_four(text), card_brand(text), is_default(boolean), is_active(boolean)

### notification_preferences
id(uuid), user_id(uuid), push_enabled(boolean), email_enabled(boolean), sms_enabled(boolean), order_updates(boolean), campaigns(boolean), new_features(boolean)

### communication_preferences
id(uuid), user_id(uuid), allow_calls(boolean), allow_messages(boolean), emergency_contacts(jsonb)

### support_chat_sessions
id(uuid), user_id(uuid), status(varchar), subject(varchar), category(varchar), created_at(timestamptz)

### support_chat_messages
id(uuid), session_id(uuid), role(varchar) ['user'|'assistant'], content(text), created_at(timestamptz)

### exchange_rates
currency(text), rate_to_usd(numeric), updated_at(timestamptz)

### fcm_tokens
id(uuid), user_id(uuid), token(text), platform(text)

Build ALL of these screens and features. The app should be production-ready, connecting to the real Supabase backend with real data. Make sure every query uses the exact table and column names I specified.
```

## PROMPT SONU

---

## NOTLAR

1. **API Key Güvenliği**: Bu prompt'ta Supabase anon key var - bu public key olduğu için güvenli. Ama Stripe ve Google Maps keylerini Rork'un environment variables özelliği varsa oraya koy.

2. **RLS (Row Level Security)**: Tüm tablolarda RLS aktif. Supabase anon key ile sadece yetkili verilere erişilebilir.

3. **Edge Functions**: Bunlar Supabase tarafında zaten çalışıyor. Rork sadece bunları çağırmalı, yeniden oluşturmamalı.

4. **Rork Limitleri**: Rork'un tek seferde bu kadar büyük bir uygulamayı oluşturma kapasitesi sınırlı olabilir. Bu durumda prompt'u modüllere bölerek parça parça ver:
   - İlk prompt: Auth + Home + Profile + Navigation yapısı
   - İkinci prompt: Food + Store + Grocery
   - Üçüncü prompt: Taxi
   - Dördüncü prompt: Emlak + Car Sales
   - Beşinci prompt: Jobs + Rental + AI Chat
