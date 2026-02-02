import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/orders/orders_screen.dart' as main_orders;
import '../../screens/profile/profile_screen.dart';
import '../../screens/food/food_home_screen.dart';
import '../../screens/food/restaurant_detail_screen.dart';
import '../../screens/food/food_item_detail_screen.dart';
import '../../screens/food/cart_screen.dart';
import '../../screens/food/order_success_screen.dart';
import '../../screens/food/order_tracking_screen.dart';
import '../../screens/food/order_review_screen.dart';
import '../../screens/food/orders_screen.dart' as food_orders;
import '../../screens/profile/settings_screen.dart';
import '../../screens/profile/personal_info_screen.dart';
import '../../screens/profile/addresses_screen.dart';
import '../../screens/profile/payment_methods_screen.dart';
import '../../screens/profile/security_screen.dart';
import '../../screens/profile/notifications_screen.dart';
import '../../screens/store/store_home_screen.dart';
import '../../screens/store/store_search_screen.dart';
import '../../screens/store/store_detail_screen.dart';
import '../../screens/store/store_product_detail_screen.dart';
import '../../screens/store/store_cart_screen.dart';
import '../../screens/store/store_checkout_screen.dart';
import '../../screens/taxi/taxi_home_screen.dart';
import '../../screens/rental/rental_home_screen.dart';
import '../../screens/emlak/emlak_home_screen.dart';
import '../../screens/emlak/property_detail_screen.dart';
import '../../screens/emlak/property_search_screen.dart';
import '../../screens/emlak/add_property_screen.dart';
import '../../screens/emlak/my_property_listings_screen.dart';
import '../../screens/emlak/emlak_favorites_screen.dart';
import '../../screens/emlak/chat_list_screen.dart';
import '../../screens/emlak/chat_screen.dart';
import '../../screens/car_sales/car_sales_home_screen.dart';
import '../../screens/car_sales/car_detail_screen.dart';
import '../../screens/car_sales/car_search_screen.dart';
import '../../screens/car_sales/add_car_listing_screen.dart';
import '../../screens/car_sales/my_car_listings_screen.dart';
import '../../models/car_sales/car_sales_models.dart';
import '../../screens/jobs/jobs_home_screen.dart';
import '../../screens/jobs/job_detail_screen.dart';
import '../../screens/jobs/job_search_screen.dart';
import '../../screens/jobs/add_job_listing_screen.dart';
import '../../screens/jobs/my_job_listings_screen.dart';
import '../../models/jobs/job_models.dart';
import '../../screens/support/ai_chat_screen.dart';
import '../../models/store/store_model.dart';
import '../../models/store/store_product_model.dart';
import '../../widgets/app_scaffold.dart';

// Route Names
class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/';

  // Main Tab Routes
  static const String favorites = '/favorites';
  static const String ordersMain = '/orders-main';
  static const String profile = '/profile';

  // Services
  static const String food = '/food';
  static const String restaurantDetail = '/food/restaurant/:id';
  static const String foodItemDetail = '/food/item/:id';
  static const String cart = '/food/cart';
  static const String orders = '/food/orders';
  static const String orderSuccess = '/food/order-success/:orderId';
  static const String orderTracking = '/food/order-tracking/:orderId';
  static const String market = '/market';
  static const String taxi = '/taxi';
  static const String rental = '/rental';
  static const String service = '/service';
  static const String appointment = '/appointment';

  // Emlak Routes
  static const String emlak = '/emlak';
  static const String emlakProperty = '/emlak/property/:id';
  static const String emlakSearch = '/emlak/search';
  static const String emlakAdd = '/emlak/add';
  static const String emlakMyListings = '/emlak/my-listings';
  static const String emlakFavorites = '/emlak/favorites';
  static const String emlakChats = '/emlak/chats';
  static const String emlakChat = '/emlak/chat/:conversationId';

  // Car Sales Routes
  static const String carSales = '/car-sales';
  static const String carDetail = '/car-sales/detail/:id';
  static const String carSearch = '/car-sales/search';
  static const String carAdd = '/car-sales/add';
  static const String carMyListings = '/car-sales/my-listings';

  // Jobs Routes
  static const String jobs = '/jobs';
  static const String jobDetail = '/jobs/detail/:id';
  static const String jobSearch = '/jobs/search';
  static const String jobAdd = '/jobs/add';
  static const String jobMyListings = '/jobs/my-listings';

  // Profile/Settings Routes
  static const String settings = '/settings';
  static const String personalInfo = '/settings/personal-info';
  static const String addresses = '/settings/addresses';
  static const String paymentMethods = '/settings/payment-methods';
  static const String security = '/settings/security';
  static const String notifications = '/notifications';

  // Support Routes
  static const String aiChat = '/support/ai-chat';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

// Router Provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;

      // If not logged in and not on auth page, redirect to login
      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      // If logged in and on auth page, redirect to home
      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Auth Routes (without bottom nav)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Shell Route - Tüm sayfalarda bottom navigation bar gösterilecek
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          // Ana Sayfa Tab
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),

          // Favoriler Tab
          GoRoute(
            path: AppRoutes.favorites,
            name: 'favorites',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FavoritesScreen()),
          ),

          // Siparişlerim Tab
          GoRoute(
            path: AppRoutes.ordersMain,
            name: 'ordersMain',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: main_orders.OrdersScreen()),
          ),

          // Profil Tab
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),

          // Service Routes - Hepsi bottom nav ile
          GoRoute(
            path: AppRoutes.food,
            name: 'food',
            builder: (context, state) => const FoodHomeScreen(),
          ),
          GoRoute(
            path: '/food/restaurant/:id',
            name: 'restaurantDetail',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return RestaurantDetailScreen(
                restaurantId: id,
                name: extra['name'] ?? 'Restaurant',
                imageUrl: extra['imageUrl'] ?? '',
                rating: extra['rating'] ?? 4.5,
                categories: extra['categories'] ?? '',
                deliveryTime: extra['deliveryTime'] ?? '30-40 dk',
              );
            },
          ),
          GoRoute(
            path: '/food/item/:id',
            name: 'foodItemDetail',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return FoodItemDetailScreen(
                itemId: id,
                name: extra['name'] ?? 'Ürün',
                description: extra['description'] ?? '',
                price: extra['price'] ?? 0.0,
                imageUrl: extra['imageUrl'] ?? '',
                rating: extra['rating'] ?? 4.5,
                restaurantName: extra['restaurantName'] ?? '',
                deliveryTime: extra['deliveryTime'] ?? '30-40 dk',
              );
            },
          ),
          GoRoute(
            path: AppRoutes.cart,
            name: 'cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: AppRoutes.orders,
            name: 'foodOrders',
            builder: (context, state) => const food_orders.OrdersScreen(),
          ),
          GoRoute(
            path: '/food/order-success/:orderId',
            name: 'orderSuccess',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return OrderSuccessScreen(
                orderId: orderId,
                totalAmount: extra['totalAmount'] ?? 0.0,
              );
            },
          ),
          GoRoute(
            path: '/food/order-tracking/:orderId',
            name: 'orderTracking',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              return OrderTrackingScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: '/food/order-review/:orderId',
            name: 'orderReview',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId'] ?? '';
              return OrderReviewScreen(orderId: orderId);
            },
          ),
          GoRoute(
            path: AppRoutes.market,
            name: 'market',
            builder: (context, state) => const StoreHomeScreen(),
          ),
          // Store Routes
          GoRoute(
            path: '/store/search',
            name: 'storeSearch',
            builder: (context, state) => const StoreSearchScreen(),
          ),
          GoRoute(
            path: '/store/detail/:id',
            name: 'storeDetail',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final store = extra?['store'] as Store?;
              if (store != null) {
                return StoreDetailScreen(store: store);
              }
              return const Center(child: Text('Mağaza bulunamadı'));
            },
          ),
          GoRoute(
            path: '/store/product/:id',
            name: 'storeProduct',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final product = extra?['product'] as StoreProduct?;
              if (product != null) {
                return StoreProductDetailScreen(product: product);
              }
              return const Center(child: Text('Ürün bulunamadı'));
            },
          ),
          GoRoute(
            path: '/store/cart',
            name: 'storeCart',
            builder: (context, state) => const StoreCartScreen(),
          ),
          GoRoute(
            path: '/store/checkout',
            name: 'storeCheckout',
            builder: (context, state) => const StoreCheckoutScreen(),
          ),
          GoRoute(
            path: AppRoutes.taxi,
            name: 'taxi',
            builder: (context, state) => const TaxiHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.rental,
            name: 'rental',
            builder: (context, state) => const RentalHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.service,
            name: 'service',
            builder: (context, state) =>
                const Center(child: Text('Hizmet Servisi - Yakında')),
          ),
          GoRoute(
            path: AppRoutes.appointment,
            name: 'appointment',
            builder: (context, state) =>
                const Center(child: Text('Randevu Servisi - Yakında')),
          ),

          // Emlak Routes
          GoRoute(
            path: AppRoutes.emlak,
            name: 'emlak',
            builder: (context, state) => const EmlakHomeScreen(),
          ),
          GoRoute(
            path: '/emlak/property/:id',
            name: 'emlakProperty',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return PropertyDetailScreen(propertyId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.emlakSearch,
            name: 'emlakSearch',
            builder: (context, state) => const PropertySearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.emlakAdd,
            name: 'emlakAdd',
            builder: (context, state) => const AddPropertyScreen(),
          ),
          GoRoute(
            path: '/emlak/edit/:id',
            name: 'emlakEdit',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return AddPropertyScreen(propertyId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.emlakMyListings,
            name: 'emlakMyListings',
            builder: (context, state) => const MyPropertyListingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.emlakFavorites,
            name: 'emlakFavorites',
            builder: (context, state) => const EmlakFavoritesScreen(),
          ),
          GoRoute(
            path: AppRoutes.emlakChats,
            name: 'emlakChats',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/emlak/chat/:conversationId',
            name: 'emlakChat',
            builder: (context, state) {
              final conversationId = state.pathParameters['conversationId'] ?? '';
              return ChatScreen(conversationId: conversationId);
            },
          ),

          // Car Sales Routes
          GoRoute(
            path: AppRoutes.carSales,
            name: 'carSales',
            builder: (context, state) => const CarSalesHomeScreen(),
          ),
          GoRoute(
            path: '/car-sales/detail/:id',
            name: 'carDetail',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final car = extra?['car'] as CarListing?;
              if (car != null) {
                return CarDetailScreen(car: car);
              }
              // Fallback - find by id from demo data
              final id = state.pathParameters['id'] ?? '';
              final foundCar = CarSalesDemoData.listings.firstWhere(
                (c) => c.id == id,
                orElse: () => CarSalesDemoData.listings.first,
              );
              return CarDetailScreen(car: foundCar);
            },
          ),
          GoRoute(
            path: AppRoutes.carSearch,
            name: 'carSearch',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CarSearchScreen(
                initialBrandId: extra?['brandId'],
                initialBodyType: extra?['bodyType'],
              );
            },
          ),
          GoRoute(
            path: AppRoutes.carAdd,
            name: 'carAdd',
            builder: (context, state) => const AddCarListingScreen(),
          ),
          GoRoute(
            path: AppRoutes.carMyListings,
            name: 'carMyListings',
            builder: (context, state) => const MyCarListingsScreen(),
          ),

          // Jobs Routes
          GoRoute(
            path: AppRoutes.jobs,
            name: 'jobs',
            builder: (context, state) => const JobsHomeScreen(),
          ),
          GoRoute(
            path: '/jobs/detail/:id',
            name: 'jobDetail',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              final job = extra?['job'] as JobListing?;
              if (job != null) {
                return JobDetailScreen(job: job);
              }
              // Fallback - find by id from demo data
              final id = state.pathParameters['id'] ?? '';
              final foundJob = JobsDemoData.listings.firstWhere(
                (j) => j.id == id,
                orElse: () => JobsDemoData.listings.first,
              );
              return JobDetailScreen(job: foundJob);
            },
          ),
          GoRoute(
            path: AppRoutes.jobSearch,
            name: 'jobSearch',
            builder: (context, state) => const JobSearchScreen(),
          ),
          GoRoute(
            path: AppRoutes.jobAdd,
            name: 'jobAdd',
            builder: (context, state) => const AddJobListingScreen(),
          ),
          GoRoute(
            path: AppRoutes.jobMyListings,
            name: 'jobMyListings',
            builder: (context, state) => const MyJobListingsScreen(),
          ),

          // Profile/Settings Routes
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.personalInfo,
            name: 'personalInfo',
            builder: (context, state) => const PersonalInfoScreen(),
          ),
          GoRoute(
            path: AppRoutes.addresses,
            name: 'addresses',
            builder: (context, state) => const AddressesScreen(),
          ),
          GoRoute(
            path: AppRoutes.paymentMethods,
            name: 'paymentMethods',
            builder: (context, state) => const PaymentMethodsScreen(),
          ),
          GoRoute(
            path: AppRoutes.security,
            name: 'security',
            builder: (context, state) => const SecurityScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),

          // Support Routes
          GoRoute(
            path: AppRoutes.aiChat,
            name: 'aiChat',
            builder: (context, state) => const AiChatScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Sayfa bulunamadı: ${state.matchedLocation}')),
    ),
  );
});
