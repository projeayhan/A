# RORK PART 3 - Taxi Service

Aşağıdaki prompt'u Rork'a ver. Part 1 ve Part 2 tamamlandıktan sonra.

---

```
Continue building the SuperCyp app. Parts 1-2 are done (Auth, Home, Food, Store, Grocery). Now add the Taxi Service module. Replace the taxi placeholder screen.

This is the most complex module - it needs maps, real-time tracking, and an Uber-like flow.

## SUPABASE
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY

## GOOGLE MAPS
- API Key: AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ
- Use for: map display, place search/autocomplete, geocoding, directions/polylines

## DESIGN
- Taxi accent: no special accent, use primary #256AF4
- All taxi screens are FULL SCREEN (no bottom tab bar)
- Bottom sheet pattern: slide up from bottom, 20px top radius, drag handle
- Map: fills entire screen behind bottom sheets

---

## TAXI FLOW (6 screens, Uber-like)

### Screen 1: Taxi Home (/taxi)
**Layout:**
- Full-screen Google Map centered on user's current location
- User location marker (blue pulsing dot)
- Top-left: back button (← to go back to home)
- Top-right: notification bell
- Bottom sheet (collapsed, ~180px visible):
  - "Nereye gidiyorsunuz?" (Where to?) large tappable input
  - Below: row of quick-access saved locations from `saved_locations`:
    - Query: `supabase.from('saved_locations').select('*').eq('user_id', userId).limit(3)`
    - Each: icon (🏠 home, 🏢 work, 📍 other) + title + short address
    - Tap saved location → skip to Vehicle Selection with this as dropoff
  - Recent rides section (last 3):
    - Query: `supabase.from('taxi_rides').select('dropoff_address').eq('user_id', userId).eq('status', 'completed').order('created_at', { ascending: false }).limit(3)`
    - Each: clock icon + dropoff_address, tap → use as destination

- Tap "Nereye gidiyorsunuz?" → navigate to Destination Selection

### Screen 2: Destination Selection (/taxi/destination)
**Layout:**
- Full screen (no map)
- Top section:
  - Pickup input: green dot + address text (auto-filled with current location, editable)
  - Dropoff input: red dot + placeholder "Nereye?" (auto-focused)
  - Vertical green dotted line connecting the two dots
- Search results below (as user types):
  - Use Google Places Autocomplete API
  - Each result: pin icon + place name + address
  - Tap result → set as dropoff
- Below search: saved locations section
  - "Kayıtlı Adresler" header
  - List from `saved_locations`
- "Haritadan Seç" (Pick from map) button → show map with draggable pin

**On destination selected:**
- Calculate route using Google Directions API (pickup → dropoff)
- Get distance_km and duration_minutes from response
- Navigate to Vehicle Selection with: pickup, dropoff, distance, duration

### Screen 3: Vehicle Selection (/taxi/vehicle-selection)
**Layout:**
- Map showing route polyline (pickup marker green, dropoff marker red)
- Map takes top 50% of screen
- Bottom sheet (expanded, takes bottom 50%):
  - "Araç Seçin" title
  - Vehicle type cards: horizontal scroll or vertical list
  - Query: `supabase.from('vehicle_types').select('*').eq('is_active', true).order('sort_order')`
  - For each vehicle type, get pricing:
    - Query: `supabase.from('taxi_pricing').select('*').eq('vehicle_type_id', vehicleType.id).eq('is_active', true).single()`

**Vehicle Type Card:**
- Icon/image (from icon_name field)
- display_name (e.g., "Economy", "Comfort", "Premium")
- Capacity: "👤 {capacity} kişi"
- Calculated fare: `Math.max(base_fare + (per_km_fare * distance_km) + (per_minute_fare * duration_minutes), minimum_fare) * surge_multiplier`
- Show fare as "₺XX.XX"
- Selected card: primary border + checkmark, slightly elevated

**Bottom:**
- Payment method selector: card icon + "Nakit" or card info
- "Taksi Çağır - ₺XX.XX" primary button, full width

**On "Taksi Çağır" pressed:**
Insert ride:
```javascript
const { data: ride } = await supabase.from('taxi_rides').insert({
  user_id: currentUser.id,
  pickup_address: pickup.address,
  pickup_lat: pickup.latitude,
  pickup_lng: pickup.longitude,
  dropoff_address: dropoff.address,
  dropoff_lat: dropoff.latitude,
  dropoff_lng: dropoff.longitude,
  distance_km: distance,
  duration_minutes: duration,
  fare: calculatedFare,
  status: 'pending',
  vehicle_type: selectedVehicleType.name,
  customer_name: user.full_name,
  customer_phone: user.phone
}).select().single()
```
Navigate to Searching screen with ride.id

### Screen 4: Searching for Driver (/taxi/searching)
**Layout:**
- Map with pickup location centered
- Animated expanding circles/ripple effect around pickup point (searching animation)
- Bottom sheet:
  - "Sürücü Aranıyor..." title with loading animation
  - Vehicle type + estimated fare shown
  - "İptal Et" (Cancel) button
    - On cancel: `supabase.from('taxi_rides').update({ status: 'cancelled', cancelled_at: new Date(), cancellation_reason: 'customer_cancelled' }).eq('id', rideId)`
    - Navigate back to Taxi Home

**Realtime subscription:**
```javascript
supabase.channel(`ride-${rideId}`)
  .on('postgres_changes', {
    event: 'UPDATE',
    schema: 'public',
    table: 'taxi_rides',
    filter: `id=eq.${rideId}`
  }, (payload) => {
    if (payload.new.status === 'accepted') {
      // Driver found! Navigate to Ride screen
      navigateToRide(rideId)
    }
    if (payload.new.status === 'cancelled') {
      // Ride cancelled, show message and go back
    }
  })
  .subscribe()
```

- If no driver found in 60 seconds, show "Sürücü bulunamadı. Tekrar deneyin." message with retry button

### Screen 5: Active Ride (/taxi/ride)
**Layout - Changes based on ride status:**

**Status: "accepted" (Driver on the way to pickup)**
- Map: show driver location marker (car icon) + pickup marker (green)
- Driver location updates: subscribe to `taxi_drivers` table for driver's current_latitude/longitude
- Bottom sheet (collapsed ~200px):
  - Driver info card:
    - Get driver: `supabase.rpc('get_secure_driver_info', { ride_id: rideId })` or `supabase.from('taxi_drivers').select('*').eq('id', ride.driver_id).single()`
    - Avatar (48px circle) + full_name + rating (stars)
    - Vehicle: vehicle_brand + vehicle_model + vehicle_color
    - Plate: vehicle_plate (bold, large, bordered box)
  - ETA: "~X dakika uzakta"
  - Action buttons row:
    - 📞 Ara (Call): `supabase.rpc('initiate_ride_call', { ride_id: rideId })`
    - 💬 Mesaj (Message): open chat
    - 📤 Paylaş (Share): `supabase.rpc('create_ride_share_link', { ride_id: rideId })`

**Status: "arrived" (Driver waiting at pickup)**
- Same layout but:
- Top banner: "Sürücünüz bekliyor!" (Your driver is waiting!) - amber/yellow bg
- Show driver's exact location on map

**Status: "in_progress" (Ride started, going to destination)**
- Map: show route polyline from current position to dropoff
- Driver car marker moves along route (realtime from taxi_drivers location)
- Bottom sheet:
  - Driver info (compact)
  - Destination: dropoff_address
  - ETA to destination
  - Fare: ₺XX.XX
  - SOS button: red, top-right corner, always visible
    - On tap: confirm dialog → `supabase.rpc('create_emergency_alert', { ride_id: rideId, latitude: currentLat, longitude: currentLng })`

**Chat (expandable within bottom sheet):**
- Messages from `ride_communications` table
- Query: `supabase.from('ride_communications').select('*').eq('ride_id', rideId).order('created_at')`
- Realtime: subscribe to INSERT on ride_communications for this ride_id
- Send: `supabase.rpc('send_ride_message', { ride_id: rideId, message: text, sender_type: 'customer' })`
- Chat bubbles: right-aligned (user) blue, left-aligned (driver) grey
- Quick messages: "Geldim", "Bekliyorum", "5 dakika"

**Realtime subscription (throughout ride):**
```javascript
// Ride status changes
supabase.channel(`ride-${rideId}`)
  .on('postgres_changes', {
    event: 'UPDATE', schema: 'public', table: 'taxi_rides',
    filter: `id=eq.${rideId}`
  }, handleRideUpdate)
  .subscribe()

// Driver location updates
supabase.channel(`driver-${driverId}`)
  .on('postgres_changes', {
    event: 'UPDATE', schema: 'public', table: 'taxi_drivers',
    filter: `id=eq.${driverId}`
  }, (payload) => {
    updateDriverMarker(payload.new.current_latitude, payload.new.current_longitude)
  })
  .subscribe()
```

When status changes to "completed" → navigate to Rating screen

### Screen 6: Rating (/taxi/rating)
**Layout:**
- "Yolculuk Tamamlandı!" title with checkmark
- Ride summary: pickup → dropoff, distance, duration, fare
- Driver info: avatar + name
- Star rating: 5 large tappable stars (animated scale on select)
- Feedback tags (multi-select):
  - Query: `supabase.from('taxi_feedback_tags').select('*').eq('is_active', true).order('sort_order')`
  - Each tag: pill button with icon_name + tag_text_tr
  - Selected: primary bg + white text
  - Categories: positive and negative tags
- Comment text input (optional): "Yorum ekleyin..."
- Tip section: "Bahşiş bırakmak ister misiniz?"
  - Quick amounts: ₺5, ₺10, ₺20, Custom
  - Selected tip: primary bg
- "Gönder" (Submit) primary button:
  ```javascript
  await supabase.from('taxi_rides').update({
    rating: selectedStars,
    rating_comment: comment,
    tip_amount: tipAmount
  }).eq('id', rideId)

  // Save detailed review if feedback tags selected
  await supabase.from('driver_review_details').insert({
    ride_id: rideId,
    driver_id: driverId,
    customer_id: currentUser.id,
    customer_name: currentUser.full_name,
    feedback_tags: selectedTags // jsonb array of { tag_key, tag_text, category }
  })
  ```
- "Atla" (Skip) text button → go to home without rating

---

## DATABASE TABLES FOR TAXI

### taxi_rides
id(uuid), ride_number(varchar), user_id(uuid), driver_id(uuid), pickup_address(text), pickup_lat(numeric), pickup_lng(numeric), dropoff_address(text), dropoff_lat(numeric), dropoff_lng(numeric), distance_km(numeric), duration_minutes(integer), fare(numeric), status(varchar) ['pending'|'accepted'|'arrived'|'in_progress'|'completed'|'cancelled'], created_at(timestamptz), accepted_at(timestamptz), arrived_at(timestamptz), picked_up_at(timestamptz), completed_at(timestamptz), cancelled_at(timestamptz), cancellation_reason(text), customer_name(varchar), customer_phone(varchar), rating(integer), rating_comment(text), tip_amount(numeric), vehicle_type(varchar)

### taxi_drivers
id(uuid), user_id(uuid), full_name(varchar), phone(varchar), profile_photo_url(text), vehicle_brand(varchar), vehicle_model(varchar), vehicle_year(integer), vehicle_plate(varchar), vehicle_color(varchar), status(varchar), is_online(boolean), current_latitude(numeric), current_longitude(numeric), rating(numeric), total_ratings(integer), total_rides(integer), vehicle_types(ARRAY)

### vehicle_types
id(uuid), name(varchar), display_name(varchar), icon_name(varchar), default_base_fare(numeric), default_per_km(numeric), default_per_minute(numeric), default_minimum_fare(numeric), capacity(integer), is_active(boolean), sort_order(integer)

### taxi_pricing
id(uuid), vehicle_type_id(uuid), base_fare(numeric), per_km_fare(numeric), per_minute_fare(numeric), minimum_fare(numeric), surge_multiplier(numeric), is_active(boolean)

### taxi_feedback_tags
id(uuid), tag_key(varchar), tag_text_tr(varchar), tag_text_en(varchar), category(varchar), icon_name(varchar), sort_order(integer), is_active(boolean)

### driver_review_details
id(uuid), ride_id(uuid), driver_id(uuid), customer_id(uuid), customer_name(varchar), feedback_tags(jsonb), driver_reply(text), driver_replied_at(timestamptz), is_visible(boolean), created_at(timestamptz)

### ride_communications
id(uuid), ride_id(uuid), sender_type(varchar), sender_id(uuid), message_type(varchar), content(text), is_read(boolean), created_at(timestamptz)

### saved_locations (already exists from Part 1)
id(uuid), user_id(uuid), title(varchar), address(text), latitude(numeric), longitude(numeric), type(varchar), is_default(boolean), name(varchar)

---

## RPC FUNCTIONS USED
- `get_secure_driver_info(ride_id)` - Get masked driver contact info
- `send_ride_message(ride_id, message, sender_type)` - Send chat message
- `initiate_ride_call(ride_id)` - Start call
- `create_ride_share_link(ride_id)` - Generate share link
- `create_emergency_alert(ride_id, latitude, longitude)` - SOS alert

---

## INTEGRATION WITH PREVIOUS PARTS
- Home screen: update taxi service grid item to navigate to /taxi
- Orders screen: add "Yolculuklar" (Rides) tab showing taxi_rides history
  - Query: `supabase.from('taxi_rides').select('*, taxi_drivers(full_name, vehicle_brand, vehicle_model, vehicle_plate, rating, profile_photo_url)').eq('user_id', userId).order('created_at', { ascending: false })`
  - Ride card: pickup → dropoff, date, fare, status badge, driver info
- Profile: Saved addresses are shared with taxi pickup/dropoff
- Ensure all taxi screens have NO bottom tab bar (full screen)
- Back button on taxi home goes back to main home

## IMPORTANT
- All map interactions must be smooth (60fps)
- Driver marker should animate smoothly between position updates (not jump)
- Polyline route should be drawn with primary color, slight transparency
- Use proper map padding so markers aren't hidden under bottom sheets
- Handle location permissions gracefully (request, denied state, settings link)
- If location not available, let user type pickup address manually

Build the complete taxi flow. It must feel like using Uber/Bolt.
```
