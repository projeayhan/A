# RORK PART 5 - Jobs + Car Rental + AI Chat + Final Integration

Aşağıdaki prompt'u Rork'a ver. Part 1-4 tamamlandıktan sonra. Bu son parça.

---

```
Continue building the SuperCyp app. Parts 1-4 are done (Auth, Home, Food, Store, Grocery, Taxi, Emlak, Car Sales). Now add the final 3 modules: Jobs Platform, Car Rental, and AI Chat Support. Then do final integration to make everything work together seamlessly.

This is the FINAL part. After this, the app should be 100% complete and production-ready.

## SUPABASE
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY

## DESIGN REMINDERS
- Jobs accent: Purple #8B5CF6
- Rental accent: Blue #3B82F6
- AI Chat accent: Teal #14B8A6
- Shimmer loading, pull-to-refresh, infinite scroll
- All design tokens from Part 1 still apply

---

## MODULE 1: JOBS PLATFORM (/jobs)

### Jobs Home Screen (/jobs):
**Layout:**
- Search bar: "İş ara..."
- Listing type toggle: "İş İlanları" (hiring) | "İş Arayanlar" (seeking)
- Categories: horizontal scroll colored cards
  - Query: `supabase.from('job_categories').select('*').eq('is_active', true).order('sort_order')`
  - Each: icon + name, background from color field
- Urgent jobs section (if any): horizontal scroll, red "Acil" badge with pulsing dot
  - Query: `supabase.from('job_listings').select('*, companies(name, logo_url)').eq('status', 'active').eq('is_urgent', true).limit(5)`
- Featured jobs: horizontal scroll
  - Query: `supabase.from('job_listings').select('*, companies(name, logo_url)').eq('status', 'active').eq('is_featured', true).limit(10)`
- All listings: vertical list, infinite scroll
  - Query: `supabase.from('job_listings').select('*, job_posters(name, image_url, is_verified), companies(name, logo_url, is_verified)').eq('status', 'active').order('created_at', { ascending: false }).range(from, to)`

**Job Card (List item):**
- Left: company logo (40px circle) from companies.logo_url, or job_posters.image_url, or default icon
- Right content:
  - Title (14px bold, 2 lines max)
  - Company name (12px secondary) + verified checkmark if is_verified
  - Location: 📍 city (12px)
  - Tags row (colored chips, small):
    - Job type: full_time=green, part_time=blue, contract=orange, remote=purple, internship=teal
    - Experience: entry=light blue, senior=dark blue, etc.
    - Work arrangement badge if remote/hybrid
  - Salary (if !is_salary_hidden): green text "₺{salary_min} - ₺{salary_max} / {salary_period}"
  - Bottom row: posted time ago + application_count + "başvuru"
- Urgent badge: red pulsing dot top-right if is_urgent
- Premium badge: gold star if is_premium
- Favorite heart: top-right

### Job Detail Screen (/jobs/detail/:id):
**Layout:**
- Header: company logo (64px) + company name + verified badge
- Title (20px bold)
- Tags: job_type, work_arrangement, experience_level as colored chips
- Location: city + district
- Salary: large green text (if visible), or "Belirtilmemiş" grey text
- Posted date + deadline (if exists) + positions count

- **Section: "İş Tanımı"** - description (markdown-like rendering)
- **Section: "Sorumluluklar"** - responsibilities array as bullet list
- **Section: "Nitelikler"** - qualifications array as bullet list
- **Section: "Aranan Yetenekler"** - required_skills as chips
  - Cross-ref: `supabase.from('job_skills').select('*').in('id', required_skills)` if needed
- **Section: "Yan Haklar"** - manual_benefits as chips with icons
- **Section: "Şirket Hakkında"**
  - Company info from companies table
  - Industry, size, description (truncated)

- Track view: `supabase.rpc('increment_job_listing_view', { listing_id: id })`

**Sticky bottom bar:**
- "Başvur" (Apply) purple button - full width
- If already applied (check job_applications): show "Başvuruldu ✓" disabled

### Job Application Flow:
**On "Başvur" tap → Bottom sheet form:**
- Name (pre-filled from user profile)
- Email (pre-filled)
- Phone (pre-filled)
- Cover letter textarea
- Resume upload (file picker → upload to Storage)
- Portfolio links (dynamic add/remove text fields)
- "Başvuruyu Gönder" button:
```javascript
await supabase.from('job_applications').insert({
  listing_id: jobId,
  user_id: currentUser.id,
  poster_id: job.poster_id,
  applicant_name: name,
  applicant_email: email,
  applicant_phone: phone,
  cover_letter: coverLetter,
  resume_url: uploadedResumeUrl,
  portfolio_links: portfolioLinks,
  status: 'pending'
})
```
- Success → show "Başvurunuz gönderildi!" toast + update button to disabled

### Job Search (/jobs/search):
**Filter screen:**
- Category dropdown (from job_categories → job_subcategories cascading)
- Job type: multi-select (full_time, part_time, contract, internship, freelance, remote, temporary)
- Work arrangement: onsite / remote / hybrid
- Experience level: dropdown
- Salary range: min-max inputs
- City input
- Keywords text input
- "Ara" purple button

### Add Job Listing (/jobs/add):
**Multi-step form:**

**Step 1 - Temel Bilgiler:**
- Listing type: hiring / seeking toggle
- Title, description
- Category dropdown → subcategory dropdown
- Job type, work arrangement, experience level, education level selectors

**Step 2 - Detaylar:**
- Salary: min, max, currency (TRY default), period (monthly default)
- Hide salary toggle
- Negotiable toggle
- City, district, address
- Positions count
- Deadline date picker

**Step 3 - Gereksinimler:**
- Responsibilities: dynamic add text fields
- Qualifications: dynamic add text fields
- Required skills: searchable multi-select from job_skills
  - Query: `supabase.from('job_skills').select('*').order('usage_count', { ascending: false }).limit(50)`
- Benefits: multi-select from job_benefits
  - Query: `supabase.from('job_benefits').select('*').eq('is_active', true).order('sort_order')`
- Manual benefits: dynamic add text fields

**Step 4 - Önizleme & Yayınla:**
- Preview card
- "Yayınla" button:
```javascript
await supabase.from('job_listings').insert({
  user_id: currentUser.id,
  title, description, category_id, subcategory,
  job_type, work_arrangement, experience_level, education_level,
  salary_min, salary_max, salary_currency, salary_period,
  is_salary_hidden, is_salary_negotiable,
  city, district, address, positions,
  responsibilities, qualifications, required_skills, manual_benefits,
  deadline, listing_type,
  status: 'pending',
  view_count: 0, application_count: 0, favorite_count: 0
})
```

### My Job Listings (/jobs/my-listings):
- Query: `supabase.from('job_listings').select('*').eq('user_id', userId).order('created_at', { ascending: false })`
- Status badges, application count shown
- Menu: Edit / Close / Delete

### Job Favorites:
- Integrated into main Favorites screen "İlanlar" tab
- Query: `supabase.from('job_favorites').select('*, job_listings(*, companies(name, logo_url))').eq('user_id', userId)`
- Toggle: insert/delete from job_favorites

### Job Conversations (/jobs/chats):
- Same chat pattern as Emlak/Car Sales but using:
  - `job_conversations` table
  - `job_messages` table
  - Show job listing mini-card in header
  - Purple accent

---

## MODULE 2: CAR RENTAL (/rental)

### Rental Home Screen (/rental):
**Layout:**
- **Search Card (prominent, top):**
  - Pickup location dropdown (from rental_locations)
    - Query: `supabase.from('rental_locations').select('*').eq('is_active', true)`
  - Dropoff location dropdown (same list, or "Aynı Lokasyon" checkbox)
  - Pickup date+time picker
  - Dropoff date+time picker
  - "Araç Ara" blue button
- After search → show available cars filtered by location and dates

- **Categories:** horizontal scroll
  - Economy, Compact, Sedan, SUV, Luxury, Sports, Electric, Van
  - Each: icon + label
- **Featured cars:** horizontal scroll
- **All available cars:** vertical list
  - Base query: `supabase.from('rental_cars').select('*, rental_companies(company_name, logo_url, rating)').eq('is_active', true).eq('status', 'available').order('daily_price')`
  - Filter by category, location

**Rental Car Card:**
- Image: first from images jsonb, 160px height, 12px radius top
- Below:
  - Brand + Model + Year (14px bold)
  - Specs row: ⚙️ transmission + ⛽ fuel_type + 👤 seats + 🧳 luggage_capacity
  - Company: small logo + company_name
  - Rating: star + rental_companies.rating
  - Price: daily_price (18px bold blue) + "/gün"
  - If weeklyPrice or monthlyPrice exists: show smaller "₺X/hafta" text
  - Features chips: from features jsonb (AC, GPS, Bluetooth etc)

### Rental Car Detail (/rental/car/:id):
**Layout:**
- Image carousel: swipeable
- Brand + Model + Year (20px bold)
- Company info: logo + name + rating
- Price section:
  - Günlük: daily_price
  - Haftalık: weekly_price
  - Aylık: monthly_price
  - Depozito: deposit_amount

- **Specs grid (2 columns):**
  - Kategori: category
  - Vites: transmission
  - Yakıt: fuel_type
  - Koltuk: seats
  - Kapı: doors
  - Bagaj: luggage_capacity

- **Features list:** from features jsonb, checkmark + label
- **Rental Packages (if any):**
  - Query: `supabase.from('rental_packages').select('*').eq('company_id', car.company_id).eq('is_active', true).order('sort_order')`
  - Each package: tier name, daily_price, included_services, popular badge
- **Additional Services:**
  - Query: `supabase.from('rental_services').select('*').eq('company_id', car.company_id).eq('is_active', true)`
  - Each: toggle + name + price (daily/one-time)
- **Reviews:**
  - Query: `supabase.from('rental_reviews').select('*').eq('car_id', carId).eq('is_approved', true).order('created_at', { ascending: false }).limit(5)`
  - Each: user_name, rating stars, comment, date

**Sticky bottom: "Rezervasyon Yap - ₺{dailyPrice}/gün" blue button**

### Booking Flow:
**On "Rezervasyon Yap" → Booking screen:**
- Pickup location selector (from rental_locations)
- Dropoff location selector
- Pickup date/time
- Dropoff date/time
- Calculate rental_days from dates
- Select package tier (if packages available)
- Toggle additional services
- Customer info: name, phone, email, driver license

- **Price Summary:**
  - Araç: daily_rate × rental_days
  - Paket: package_total (if selected)
  - Ek Hizmetler: services_total
  - Depozito: deposit_amount
  - **Toplam:** total_amount

- "Rezervasyonu Onayla" button:
```javascript
await supabase.from('rental_bookings').insert({
  user_id: currentUser.id,
  company_id: car.company_id,
  car_id: car.id,
  pickup_location_id: pickupLocation.id,
  dropoff_location_id: dropoffLocation.id,
  pickup_date: pickupDateTime,
  dropoff_date: dropoffDateTime,
  daily_rate: dailyPrice,
  rental_days: days,
  subtotal: dailyPrice * days,
  services_total: servicesTotal,
  deposit_amount: car.deposit_amount,
  total_amount: totalAmount,
  selected_services: selectedServicesJson,
  customer_name: name,
  customer_phone: phone,
  customer_email: email,
  driver_license_no: licenseNo,
  status: 'pending',
  payment_status: 'pending',
  payment_method: 'card',
  package_id: selectedPackage?.id,
  package_tier: selectedPackage?.tier,
  package_name: selectedPackage?.name,
  package_daily_price: selectedPackage?.daily_price,
  package_total: packageTotal
})
```
- Success → "Rezervasyonunuz alındı!" screen

### My Bookings (/rental/my-bookings):
- Query: `supabase.from('rental_bookings').select('*, rental_cars(brand, model, year, image_url), rental_companies(company_name), rental_locations!pickup_location_id(name)').eq('user_id', userId).order('created_at', { ascending: false })`
- Tab: Aktif | Geçmiş
- Card: car image + name, dates, status badge, total
- Status colors: pending=orange, confirmed=blue, active=green, completed=grey, cancelled=red

---

## MODULE 3: AI CHAT SUPPORT (/support/ai-chat)

### AI Chat Screen:
**Layout (WhatsApp/ChatGPT-like):**
- Header: "AI Asistan" title + teal robot icon
- Messages area (scrollable):
  - Initial message: "Merhaba! Size nasıl yardımcı olabilirim?" from assistant
- Input bar: text field + send button (teal)

**Chat flow:**
1. Check/create session:
```javascript
// Check existing open session
let { data: session } = await supabase.from('support_chat_sessions')
  .select('*').eq('user_id', userId).eq('status', 'open')
  .order('created_at', { ascending: false }).limit(1).single()

if (!session) {
  const { data } = await supabase.from('support_chat_sessions').insert({
    user_id: userId,
    app_source: 'customer_app',
    user_type: 'customer',
    status: 'open',
    category: 'general'
  }).select().single()
  session = data
}
```

2. Load messages:
```javascript
const { data: messages } = await supabase.from('support_chat_messages')
  .select('*').eq('session_id', session.id)
  .order('created_at')
```

3. Send message:
```javascript
// Save user message
await supabase.from('support_chat_messages').insert({
  session_id: session.id,
  role: 'user',
  content: messageText
})

// Call AI edge function
const response = await supabase.functions.invoke('ai-chat', {
  body: {
    message: messageText,
    sessionId: session.id,
    context: {
      screen: 'ai-chat',
      userId: currentUser.id
    }
  }
})

// Save AI response
await supabase.from('support_chat_messages').insert({
  session_id: session.id,
  role: 'assistant',
  content: response.data.message
})
```

4. Realtime: subscribe to INSERT on support_chat_messages for session

**Message Bubbles:**
- User: right-aligned, teal background, white text
- Assistant: left-aligned, surface background, primary text
- Timestamp below each message (11px, secondary)
- Typing indicator: animated dots when waiting for AI response

**Features:**
- New session button (top-right): create fresh chat session
- Scroll to bottom on new message
- Copy message on long press
- Markdown rendering in AI responses

---

## DATABASE TABLES FOR THIS PART

### job_listings
id(uuid), user_id(uuid), poster_id(uuid), company_id(uuid), title(varchar), description(text), category_id(varchar), subcategory(varchar), job_type(enum), work_arrangement(enum), experience_level(enum), education_level(enum), salary_min(numeric), salary_max(numeric), salary_currency(varchar), salary_period(enum), is_salary_hidden(boolean), is_salary_negotiable(boolean), city(varchar), district(varchar), address(text), positions(integer), responsibilities(ARRAY), qualifications(ARRAY), required_skills(ARRAY), manual_benefits(ARRAY), deadline(timestamptz), status(enum), is_featured(boolean), is_premium(boolean), is_urgent(boolean), view_count(integer), application_count(integer), favorite_count(integer), created_at(timestamptz), listing_type(text)

### job_categories
id(varchar), name(varchar), icon(varchar), color(varchar), sort_order(integer), is_active(boolean)

### job_subcategories
id(uuid), category_id(varchar), name(varchar), sort_order(integer), is_active(boolean)

### job_skills
id(varchar), name(varchar), category(varchar), is_popular(boolean), usage_count(integer)

### job_benefits
id(varchar), name(varchar), icon(varchar), category(varchar), sort_order(integer), is_active(boolean)

### job_applications
id(uuid), listing_id(uuid), user_id(uuid), poster_id(uuid), applicant_name(varchar), applicant_email(varchar), applicant_phone(varchar), cover_letter(text), resume_url(text), portfolio_links(ARRAY), status(enum), applied_at(timestamptz)

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

### rental_cars
id(uuid), company_id(uuid), location_id(uuid), brand(varchar), model(varchar), year(integer), category(varchar), transmission(varchar), fuel_type(varchar), seats(integer), doors(integer), luggage_capacity(integer), daily_price(numeric), weekly_price(numeric), monthly_price(numeric), deposit_amount(numeric), image_url(text), images(jsonb), features(jsonb), status(varchar), is_active(boolean)

### rental_companies
id(uuid), company_name(varchar), logo_url(text), phone(varchar), email(varchar), rating(numeric), is_approved(boolean), is_active(boolean)

### rental_locations
id(uuid), company_id(uuid), name(varchar), address(text), city(varchar), district(varchar), latitude(numeric), longitude(numeric), is_airport(boolean), is_active(boolean)

### rental_bookings
id(uuid), booking_number(varchar), user_id(uuid), company_id(uuid), car_id(uuid), pickup_location_id(uuid), dropoff_location_id(uuid), pickup_date(timestamptz), dropoff_date(timestamptz), daily_rate(numeric), rental_days(integer), subtotal(numeric), services_total(numeric), deposit_amount(numeric), total_amount(numeric), selected_services(jsonb), customer_name(varchar), customer_phone(varchar), customer_email(varchar), driver_license_no(varchar), status(varchar), payment_status(varchar), payment_method(varchar), package_id(uuid), package_tier(varchar), package_name(varchar), package_daily_price(numeric), package_total(numeric)

### rental_services
id(uuid), company_id(uuid), name(varchar), description(text), price_type(varchar), price(numeric), icon(varchar), is_active(boolean)

### rental_packages
id(uuid), company_id(uuid), tier(varchar), name(varchar), description(text), daily_price(numeric), included_services(jsonb), is_popular(boolean), is_active(boolean), sort_order(integer)

### rental_reviews
id(uuid), booking_id(uuid), company_id(uuid), car_id(uuid), user_id(uuid), overall_rating(integer), car_condition_rating(integer), cleanliness_rating(integer), service_rating(integer), value_rating(integer), comment(text), pros(ARRAY), cons(ARRAY), is_approved(boolean), created_at(timestamptz), user_name(text)

### support_chat_sessions
id(uuid), user_id(uuid), app_source(varchar), user_type(varchar), status(varchar), subject(varchar), category(varchar), created_at(timestamptz)

### support_chat_messages
id(uuid), session_id(uuid), role(varchar), content(text), created_at(timestamptz)

---

## FINAL INTEGRATION CHECKLIST

After building these 3 modules, make sure EVERYTHING works together:

### Home Screen:
- ✅ All 8 service icons navigate to real screens (not placeholders)
- ✅ Banner carousel loads from banners table
- ✅ "Yakınındaki Restoranlar" shows real restaurants → tap → restaurant detail
- ✅ "Öne Çıkan Mülkler" shows real properties → tap → property detail
- ✅ "Güncel İş İlanları" shows real jobs → tap → job detail
- ✅ Search bar navigates to global search

### Favorites Screen (4 tabs):
- ✅ "Restoranlar" tab: from favorites table (merchant favorites)
- ✅ "Mülkler" tab: from property_favorites table
- ✅ "Arabalar" tab: from car_favorites table
- ✅ "İş İlanları" tab: from job_favorites table

### Orders Screen (tabs):
- ✅ "Siparişler" tab: food/store/grocery orders from orders table
- ✅ "Yolculuklar" tab: taxi rides from taxi_rides table
- ✅ "Kiralamalar" tab: rental bookings from rental_bookings table
- ✅ Active orders have realtime subscription
- ✅ Each order card navigates to detail/tracking

### Profile Screen:
- ✅ All settings screens work (personal info, addresses, payment, security, notifications, emergency)
- ✅ "AI Asistan" navigates to chat
- ✅ Sign out works
- ✅ Delete account calls RPC

### Cross-Module Features:
- ✅ Notifications: realtime subscription shows new notification badge
- ✅ All chat modules work: Emlak chat, Car Sales chat, Job conversations
- ✅ Image uploads work for: avatar, car listings, property listings
- ✅ Favorite toggle works consistently across all modules
- ✅ Pull-to-refresh on every list screen
- ✅ Shimmer loading on every data screen
- ✅ Empty states on all screens when no data
- ✅ Error states with retry
- ✅ Dark mode works on ALL screens
- ✅ Navigation: back buttons work, deep linking consistent
- ✅ Auth: protected routes redirect to login
- ✅ Banned users are blocked

### Realtime Subscriptions Active:
- ✅ orders table → order status updates
- ✅ taxi_rides table → ride status updates
- ✅ notifications table → new notifications
- ✅ messages table → emlak chat
- ✅ car_messages table → car sales chat
- ✅ job_messages table → job chat
- ✅ ride_communications → taxi chat
- ✅ support_chat_messages → AI chat
- ✅ taxi_drivers → driver location during ride

### RPC Functions Used Across App:
1. get_restaurants_in_delivery_range(user_lat, user_lng)
2. get_stores_in_delivery_range(user_lat, user_lng)
3. get_restaurants_by_menu_category(category_id)
4. get_secure_driver_info(ride_id)
5. send_ride_message(ride_id, message, sender_type)
6. create_ride_share_link(ride_id)
7. initiate_ride_call(ride_id)
8. create_emergency_alert(ride_id, latitude, longitude)
9. increment_job_listing_view(listing_id)
10. check_login_blocked(email)
11. delete_user_account()
12. export_user_data()

### Edge Functions Used:
1. create-payment-intent → food/store orders, rental payments
2. ai-chat → AI support chat
3. phone-verify → phone OTP authentication
4. moderate-listing → car and property listing moderation

This completes the SuperCyp super app. Every feature, every screen, every query must work with the real Supabase backend. The app should feel like a polished, production-ready product - like using Uber, Bolt, or Getir.
```
