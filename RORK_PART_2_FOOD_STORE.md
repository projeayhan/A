# RORK PART 2 - Food Delivery + Store/Market + Grocery

Aşağıdaki prompt'u Rork'a ver. Part 1 tamamlandıktan sonra.

---

```
Continue building the SuperCyp app. Part 1 (Auth, Home, Profile, Navigation) is already built. Now add these 3 service modules: Food Delivery, Store/Marketplace, and Grocery. Replace the placeholder screens created in Part 1.

Keep the existing design system, Supabase connection, and navigation structure from Part 1.

## SUPABASE (same as Part 1)
- URL: https://mzgtvdgwxrlhgjboolys.supabase.co
- Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im16Z3R2ZGd3eHJsaGdqYm9vbHlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgwNTUyODUsImV4cCI6MjA4MzYzMTI4NX0.B8xL9pKDX76eVnu-s2K-TjvRyPUDx4kus85qDFWO8SY

## STRIPE
- Publishable Key: pk_test_51SVdN5FDnYENSMiEmmn7zxiTQn8WLL6wqYr4xXnFMzVxfs1YkBLCqbGTivtYzQGBhrsbsLE2vzgXAbjp5Oj2rZcT00MzbxivbO
- Payment via Edge Function: supabase.functions.invoke('create-payment-intent', { body: { amount, currency: 'TRY', metadata } })
- Returns { clientSecret } for Stripe Payment Sheet on mobile

## DESIGN REMINDERS
- Food screens accent color: #EC6D13 (Orange)
- Store screens accent color: #6366F1 (Indigo)
- Cards: 12px radius, subtle shadow, 1px border
- Shimmer loading, pull-to-refresh on all lists
- Press animation on all tappables (scale 0.98)
- Images: fade-in on load

---

## MODULE 1: FOOD DELIVERY (/food)

### Food Home Screen (/food):
**Layout:**
- Top: Search bar (same style as home)
- Category filter: horizontal scroll chips from `restaurant_categories`
  - Query: `supabase.from('restaurant_categories').select('*').eq('is_active', true).order('sort_order')`
  - Each chip: icon + name, selected = orange bg + white text, unselected = surface bg
- Restaurant list: vertical scroll, pull-to-refresh, infinite scroll (20 per page)
- Each restaurant = vertical card (described below)

**Restaurant Card (Vertical):**
- Cover image: 140px height, 12px radius top only
- If discount_badge exists: colored pill badge top-left on image
- Delivery time badge: top-right on image, surface bg, "~25 dk"
- Below image (8px padding):
  - Row: logo (32px circle, absolute positioned overlapping image bottom-left) + business_name (13px bold)
  - Row: star icon (#F59E0B) + rating (12px) + " · " + review_count + " değerlendirme"
  - Row: delivery_fee > 0 ? "₺{delivery_fee} teslimat" : "Ücretsiz teslimat" (green text)
  - Tags row: horizontal scroll small chips

**Queries:**
- All restaurants: `supabase.from('merchants').select('*').eq('type', 'restaurant').eq('is_approved', true).eq('is_frozen', false).order('rating', { ascending: false })`
- By category: use RPC `supabase.rpc('get_restaurants_by_menu_category', { category_id: selectedCategoryId })`
- Nearby: `supabase.rpc('get_restaurants_in_delivery_range', { user_lat, user_lng })`

### Restaurant Detail Screen (/food/restaurant/:id):
**Layout:**
- Cover image: full width, 200px, with gradient overlay at bottom
- Restaurant info overlay: logo (48px) + name + rating + delivery info
- Sticky category tabs below (horizontal scroll, synced with scroll position)
  - Query categories: `supabase.from('menu_categories').select('*').eq('merchant_id', id).eq('is_active', true).order('sort_order')`
- Menu items grouped by category, vertical scroll
  - Query: `supabase.from('menu_items').select('*, menu_item_option_groups(*, product_option_groups(*, product_options(*)))').eq('merchant_id', id).eq('is_available', true).order('sort_order')`

**Menu Item Row (Horizontal):**
- Left side: name (14px bold), description (12px secondary, 2 lines max), price row (discounted_price strikethrough original if exists)
- Right side: image 64px square, 8px radius
- Add button: 28px dark circle with "+" icon, overlapping image bottom-right
- Popular badge: "Popüler" small orange pill if is_popular
- Tap item → Food Item Detail

**Floating Cart Bar (fixed bottom):**
- Show only when cart has items
- Left: item count in circle + "Sepeti Gör"
- Right: total amount "₺XX.XX"
- Orange background (#EC6D13), white text, 12px radius, 12px margin from edges
- Tap → Cart screen

### Food Item Detail Screen (/food/item/:id) - Full screen, no tabs:
**Layout:**
- Large image: full width, 250px
- Close button: top-left, circular, semi-transparent
- Item name (18px bold) + description + price
- Option groups (from menu_item_option_groups → product_option_groups → product_options):
  - Each group: title + required/optional badge + min/max selections
  - Radio buttons if max_selections=1, checkboxes if max_selections>1
  - Each option: name + price ("+₺X.XX" if price > 0)
- Quantity selector: - / count / + (stepper style)
- "Sepete Ekle - ₺XX.XX" primary button (orange) fixed at bottom
  - Calculate: (item price + selected options prices) * quantity
  - Add to local cart state (store cart in app state/context)

### Cart Screen (/food/cart) - Full screen, no tabs:
**Layout:**
- Header: "Sepetim" + item count
- Cart items list:
  - Each: image (60px, 8px radius) + name + selected options text + price
  - Quantity stepper (28px buttons, orange increment, grey decrement)
  - Swipe to remove
- Divider
- Coupon input: text field + "Uygula" button
- Order summary:
  - Ara Toplam (subtotal): sum of items
  - Teslimat Ücreti: merchant delivery_fee (show "Ücretsiz" if 0 or above free_delivery_threshold)
  - Hizmet Bedeli (service_fee): fixed ₺2.99
  - İndirim (discount): if coupon applied
  - **Toplam** (total): bold, large
- Delivery address: show selected address, tap to change (navigate to address selection)
- Payment method: show selected card or "Kapıda Ödeme"
- "Siparişi Onayla - ₺XX.XX" primary button (orange)

### Order Placement:
When user confirms order:
1. Call `supabase.functions.invoke('create-payment-intent', { body: { amount: totalInKurus, currency: 'TRY', metadata: { order_type: 'food', merchant_id } } })` if paying by card
2. Insert into `orders`:
```javascript
supabase.from('orders').insert({
  user_id: currentUser.id,
  merchant_id: merchantId,
  items: cartItemsJson, // [{menu_item_id, name, price, quantity, options: [...]}]
  subtotal, delivery_fee, service_fee: 2.99,
  discount_amount, total_amount,
  delivery_address: selectedAddress.address,
  delivery_latitude: selectedAddress.latitude,
  delivery_longitude: selectedAddress.longitude,
  status: 'pending',
  payment_method: 'card' | 'cash',
  payment_status: paymentMethod === 'card' ? 'paid' : 'pending',
  customer_name: user.full_name,
  customer_phone: user.phone,
  store_name: merchant.business_name
})
```
3. Clear cart
4. Navigate to Order Success

### Order Success Screen (/food/order-success/:orderId):
- Green checkmark animation
- "Siparişiniz Alındı!" title
- Order number
- Estimated delivery time
- "Siparişi Takip Et" button → Order Tracking
- "Ana Sayfaya Dön" secondary button

### Order Tracking Screen (/food/order-tracking/:orderId):
- Status stepper (vertical timeline):
  - Sipariş Alındı (pending) ✓
  - Onaylandı (confirmed) ✓
  - Hazırlanıyor (preparing) ⏳
  - Hazır (ready)
  - Yolda (picked_up)
  - Teslim Edildi (delivered)
- Active step: primary color, pulsing dot
- Completed steps: green checkmarks
- Estimated time display
- Realtime subscription: `supabase.channel('order-{orderId}').on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders', filter: 'id=eq.{orderId}' }, handleUpdate).subscribe()`

### Order Review Screen (/food/order-review/:orderId):
- Show after order delivered (if is_reviewed = false)
- Star rating (1-5, tappable stars, animated)
- Comment text area
- "Değerlendir" button
- Insert into `reviews`: { order_id, merchant_id, user_id, rating, comment, customer_name }
- Update order: is_reviewed = true

---

## MODULE 2: STORE/MARKETPLACE (/market)

### Store Home Screen (/market):
**Layout:**
- Search bar
- Store categories: horizontal scroll cards
  - Query: `supabase.from('store_categories').select('*').eq('is_active', true).order('sort_order')`
  - Each: image/icon + name + store_count, colored bg from color field
- Featured stores: horizontal scroll
- All stores: vertical grid (2 columns)
  - Query: `supabase.from('merchants').select('*').eq('type', 'store').eq('is_approved', true).eq('is_frozen', false).order('rating', { ascending: false })`

**Store Card (Grid):**
- Logo image: square, 12px radius top
- Below: business_name (13px bold), rating, follower_count + "takipçi"
- Discount badge if exists

### Store Detail Screen (/store/detail/:id):
**Layout:**
- Cover image: full width, 180px
- Store info: logo + name + rating + follower count
- Follow button: toggle, outlined when not following, filled when following
  - Follow: `supabase.from('merchant_followers').insert({ user_id, merchant_id })`
  - Unfollow: `supabase.from('merchant_followers').delete().eq('user_id', userId).eq('merchant_id', merchantId)`
- Product categories: horizontal tabs
  - Query: `supabase.from('product_categories').select('*').eq('merchant_id', id).eq('is_active', true).order('sort_order')`
- Products grid (2 columns)
  - Query: `supabase.from('products').select('*').eq('merchant_id', id).eq('is_available', true).order('sort_order')`

**Product Card (Grid):**
- Image: square aspect, 10px radius top
- Discount badge: if original_price > price, show "-%XX" top-left
- Name (13px, 2 lines max)
- Price row: current price (bold) + original_price strikethrough if discounted
- Add button: small "+" circle bottom-right
- Rating: small star + number

### Product Detail Screen (/store/product/:id):
- Image carousel (full width, swipeable, page dots)
- Name (18px bold) + brand if exists
- Price: large, bold + original strikethrough
- Rating + review count + sold count
- Description (expandable)
- Variants: if variants jsonb has data, show variant selectors (e.g., size, color)
- Stock indicator: "Stokta {stock} adet" or "Tükendi" (red) if stock=0
- Quantity stepper
- "Sepete Ekle" indigo button, fixed bottom, disabled if stock=0

### Store Cart (/store/cart) - Full screen:
- Similar to food cart but indigo themed
- Group items by store (merchant)
- Per-store subtotals + delivery fees
- Total calculation
- "Siparişi Onayla" indigo button

### Store Checkout (/store/checkout):
- Address selection
- Payment method selection
- Order summary
- Place order → same flow as food (insert into `orders` table, call create-payment-intent)
- Navigate to order success/tracking

### Store Search (/store/search):
- Search input (auto-focus)
- Search products across all stores: `supabase.from('products').select('*, merchants(business_name)').ilike('name', '%{query}%').eq('is_available', true).limit(20)`
- Results: product cards in grid

---

## MODULE 3: GROCERY (/grocery)

### Grocery Home Screen (/grocery):
- Almost identical to Store Home but filtered for grocery merchants
- Query: `supabase.from('merchants').select('*').eq('type', 'grocery').eq('is_approved', true).eq('is_frozen', false)`
- Green accent instead of indigo (#10B981)
- Same product detail, cart, and checkout flows as Store
- Grocery cards show delivery_time prominently ("15-20 dk" badge)

---

## SHARED TABLES FOR THIS PART

### merchants
id(uuid), user_id(uuid), type(varchar), business_name(varchar), phone(varchar), email(varchar), is_open(boolean), is_approved(boolean), description(text), logo_url(text), cover_url(text), address(text), latitude(numeric), longitude(numeric), rating(numeric), review_count(integer), total_orders(integer), delivery_time(varchar), min_order_amount(numeric), delivery_fee(numeric), free_delivery_threshold(numeric), avg_preparation_time(integer), tags(ARRAY), category_tags(ARRAY), discount_badge(varchar), follower_count(integer), store_category_ids(ARRAY), working_hours(jsonb), is_frozen(boolean)

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

### restaurant_categories
id(uuid), name(varchar), image_url(text), icon(varchar), sort_order(integer), is_active(boolean)

### store_categories
id(uuid), name(varchar), icon_name(varchar), color(varchar), store_count(integer), sort_order(integer), is_active(boolean), image_url(text)

### products
id(uuid), merchant_id(uuid), category_id(uuid), name(varchar), description(text), price(numeric), original_price(numeric), image_url(text), images(ARRAY), stock(integer), sold_count(integer), rating(numeric), review_count(integer), is_available(boolean), is_featured(boolean), variants(jsonb), brand(varchar)

### product_categories
id(uuid), merchant_id(uuid), name(varchar), description(text), image_url(text), sort_order(integer), is_active(boolean)

### orders
id(uuid), order_number(varchar), user_id(uuid), merchant_id(uuid), items(jsonb), subtotal(numeric), delivery_fee(numeric), total_amount(numeric), delivery_address(text), status(varchar), created_at(timestamptz), updated_at(timestamptz), service_fee(numeric), discount_amount(numeric), delivery_latitude(numeric), delivery_longitude(numeric), payment_method(varchar), payment_status(varchar), customer_name(varchar), customer_phone(varchar), is_reviewed(boolean), store_name(text)

### reviews
id(uuid), order_id(uuid), merchant_id(uuid), user_id(uuid), rating(integer), comment(text), merchant_reply(text), replied_at(timestamptz), created_at(timestamptz), customer_name(varchar)

### favorites
id(uuid), user_id(uuid), merchant_id(uuid), created_at(timestamptz)

### merchant_followers
id(uuid), user_id(uuid), merchant_id(uuid), created_at(timestamptz)

### store_messages
id(uuid), merchant_id(uuid), customer_id(uuid), sender_type(text), sender_id(uuid), sender_name(text), message(text), is_read(boolean), created_at(timestamptz)

## INTEGRATION WITH PART 1
- Update Home screen "Yakınındaki Restoranlar" section to use the new restaurant card design
- Update Favorites screen "Restoranlar" tab to show actual restaurant favorites
- Update Orders screen to show food/store orders with proper status tracking
- Food cart state should persist across screens (use context or state management)
- Wire the notification bell badge to show unread count from notifications table

Build all screens with full functionality. Every query must use exact table and column names above.
```
