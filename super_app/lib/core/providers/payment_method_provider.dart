import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

// Promosyon Modeli
class Promotion {
  final String id;
  final String code;
  final String name;
  final String? description;
  final double value;
  final String type; // 'percentage' or 'fixed_amount'
  final double? minOrderAmount;

  const Promotion({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.value,
    required this.type,
    this.minOrderAmount,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      value: (json['value'] as num).toDouble(),
      type: json['type'] as String? ?? 'fixed_amount',
      minOrderAmount: json['min_order_amount'] != null
          ? (json['min_order_amount'] as num).toDouble()
          : null,
    );
  }
}

// Ödeme Kartı Modeli
class SavedPaymentCard {
  final String id;
  final String cardNumber; // Maskelenmiş: **** **** **** 1234
  final String cardHolder;
  final String expiryDate;
  final String type; // 'visa', 'mastercard', 'amex', 'troy'
  final bool isDefault;
  final Color cardColor;
  final int? expiryMonth;
  final int? expiryYear;

  const SavedPaymentCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolder,
    required this.expiryDate,
    required this.type,
    this.isDefault = false,
    this.cardColor = const Color(0xFF1F2937),
    this.expiryMonth,
    this.expiryYear,
  });

  // Supabase'den gelen veriyi parse et
  factory SavedPaymentCard.fromJson(Map<String, dynamic> json) {
    final lastFour = json['card_last_four'] as String? ?? '****';
    final brand = json['card_brand'] as String? ?? 'card';
    final expiryMonth = json['expiry_month'] as int?;
    final expiryYear = json['expiry_year'] as int?;

    return SavedPaymentCard(
      id: json['id'] as String,
      cardNumber: '**** **** **** $lastFour',
      cardHolder: json['card_holder_name'] as String? ?? '',
      expiryDate: expiryMonth != null && expiryYear != null
          ? '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear % 100).toString().padLeft(2, '0')}'
          : '',
      type: brand.toLowerCase(),
      isDefault: json['is_default'] as bool? ?? false,
      cardColor: _getCardColor(brand.toLowerCase()),
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
    );
  }

  static Color _getCardColor(String brand) {
    switch (brand) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
        return const Color(0xFF006FCF);
      case 'troy':
        return const Color(0xFF00529B);
      default:
        return const Color(0xFF1F2937);
    }
  }

  // Supabase'e kaydetmek için JSON'a çevir
  Map<String, dynamic> toJson(String userId) {
    final data = {
      'user_id': userId,
      'type': 'credit_card',
      'card_brand': type,
      'card_last_four': cardNumber
          .replaceAll(' ', '')
          .substring(cardNumber.replaceAll(' ', '').length - 4),
      'card_holder_name': cardHolder,
      'expiry_month': expiryMonth,
      'expiry_year': expiryYear,
      'is_default': isDefault,
      'is_active': true,
      'is_verified': true,
    };
    if (kDebugMode) print('Sending payload to payment_methods: $data');
    return data;
  }

  String get lastFourDigits {
    final digits = cardNumber.replaceAll(' ', '').replaceAll('*', '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  }

  String get displayName {
    switch (type) {
      case 'visa':
        return 'Visa';
      case 'mastercard':
        return 'Mastercard';
      case 'amex':
        return 'Amex';
      case 'troy':
        return 'Troy';
      default:
        return 'Kart';
    }
  }

  IconData get icon {
    switch (type) {
      case 'visa':
      case 'mastercard':
      case 'amex':
      case 'troy':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  SavedPaymentCard copyWith({
    String? id,
    String? cardNumber,
    String? cardHolder,
    String? expiryDate,
    String? type,
    bool? isDefault,
    Color? cardColor,
  }) {
    return SavedPaymentCard(
      id: id ?? this.id,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolder: cardHolder ?? this.cardHolder,
      expiryDate: expiryDate ?? this.expiryDate,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      cardColor: cardColor ?? this.cardColor,
    );
  }
}

// Ödeme Yöntemi Tipi
enum PaymentType { card, cash, wallet, creditCardOnDelivery }

// Genel Ödeme Yöntemi - kart, nakit veya cüzdan olabilir
class TaxiPaymentOption {
  final String id;
  final PaymentType type;
  final String name;
  final String? lastFourDigits;
  final String? cardBrand;
  final IconData icon;
  final bool isDefault;
  final SavedPaymentCard? savedCard;

  const TaxiPaymentOption({
    required this.id,
    required this.type,
    required this.name,
    this.lastFourDigits,
    this.cardBrand,
    required this.icon,
    this.isDefault = false,
    this.savedCard,
  });

  factory TaxiPaymentOption.fromSavedCard(SavedPaymentCard card) {
    return TaxiPaymentOption(
      id: card.id,
      type: PaymentType.card,
      name: card.displayName,
      lastFourDigits: card.lastFourDigits,
      cardBrand: card.displayName,
      icon: card.icon,
      isDefault: card.isDefault,
      savedCard: card,
    );
  }

  static TaxiPaymentOption get cash => const TaxiPaymentOption(
    id: 'cash',
    type: PaymentType.cash,
    name: 'Nakit',
    icon: Icons.money,
  );

  static TaxiPaymentOption get wallet => const TaxiPaymentOption(
    id: 'wallet',
    type: PaymentType.wallet,
    name: 'Cüzdan Bakiyesi',
    icon: Icons.account_balance_wallet,
  );

  static TaxiPaymentOption get creditCardOnDelivery => const TaxiPaymentOption(
    id: 'credit_card_on_delivery',
    type: PaymentType.creditCardOnDelivery,
    name: 'Kapıda Kredi Kartı',
    icon: Icons.credit_card,
  );
}

// Ödeme Yöntemleri State
// Ödeme Yöntemleri State
class PaymentMethodState {
  final List<SavedPaymentCard> cards;
  final List<Promotion> activePromotions;
  final bool isLoading;
  final bool cashEnabled;
  final bool walletEnabled;
  final bool creditCardOnDeliveryEnabled;
  final double walletBalance;

  const PaymentMethodState({
    this.cards = const [],
    this.activePromotions = const [],
    this.isLoading = false,
    this.cashEnabled = true,
    this.walletEnabled = true,
    this.creditCardOnDeliveryEnabled = true,
    this.walletBalance = 0,
  });

  SavedPaymentCard? get defaultCard {
    try {
      return cards.firstWhere((c) => c.isDefault);
    } catch (_) {
      return cards.isNotEmpty ? cards.first : null;
    }
  }

  List<TaxiPaymentOption> get allPaymentOptions {
    final options = <TaxiPaymentOption>[];

    // Kayıtlı kartları ekle
    for (final card in cards) {
      options.add(TaxiPaymentOption.fromSavedCard(card));
    }

    // Nakit ödeme
    if (cashEnabled) {
      options.add(TaxiPaymentOption.cash);
    }

    // Cüzdan
    if (walletEnabled) {
      options.add(TaxiPaymentOption.wallet);
    }

    // Kapıda Kredi Kartı
    if (creditCardOnDeliveryEnabled) {
      options.add(TaxiPaymentOption.creditCardOnDelivery);
    }

    return options;
  }

  PaymentMethodState copyWith({
    List<SavedPaymentCard>? cards,
    List<Promotion>? activePromotions,
    bool? isLoading,
    bool? cashEnabled,
    bool? walletEnabled,
    bool? creditCardOnDeliveryEnabled,
    double? walletBalance,
  }) {
    return PaymentMethodState(
      cards: cards ?? this.cards,
      activePromotions: activePromotions ?? this.activePromotions,
      isLoading: isLoading ?? this.isLoading,
      cashEnabled: cashEnabled ?? this.cashEnabled,
      walletEnabled: walletEnabled ?? this.walletEnabled,
      creditCardOnDeliveryEnabled:
          creditCardOnDeliveryEnabled ?? this.creditCardOnDeliveryEnabled,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}

// Ödeme Yöntemleri Notifier
class PaymentMethodNotifier extends StateNotifier<PaymentMethodState> {
  PaymentMethodNotifier() : super(const PaymentMethodState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    await _loadFromSupabase();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final cashEnabled = prefs.getBool('payment_cash_enabled') ?? true;
    final walletEnabled = prefs.getBool('payment_wallet_enabled') ?? true;
    final creditCardOnDeliveryEnabled =
        prefs.getBool('payment_cc_delivery_enabled') ?? true;

    state = state.copyWith(
      cashEnabled: cashEnabled,
      walletEnabled: walletEnabled,
      creditCardOnDeliveryEnabled: creditCardOnDeliveryEnabled,
    );
  }

  Future<void> _loadFromSupabase() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('is_default', ascending: false);

      final cards = (response as List)
          .map((json) => SavedPaymentCard.fromJson(json))
          .toList();

      state = state.copyWith(cards: cards, isLoading: false);
    } catch (e) {
      if (kDebugMode) print('Error loading payment methods: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> verifyPromoCode(String code) async {
    try {
      final response = await SupabaseService.client
          .from('promotions')
          .select()
          .eq('code', code)
          .eq('status', 'active')
          .single();

      final promo = Promotion.fromJson(response);

      // Promosyon zaten ekli mi kontrol et
      if (state.activePromotions.any((p) => p.id == promo.id)) {
        return false; // Zaten ekli
      }

      state = state.copyWith(
        activePromotions: [...state.activePromotions, promo],
      );

      return true;
    } catch (e) {
      if (kDebugMode) print('Error verifying promo code: $e');
      return false;
    }
  }

  void removePromotion(String promoId) {
    state = state.copyWith(
      activePromotions: state.activePromotions
          .where((p) => p.id != promoId)
          .toList(),
    );
  }

  Future<void> refreshCards() async {
    state = state.copyWith(isLoading: true);
    await _loadFromSupabase();
  }

  Future<bool> addCard(SavedPaymentCard card) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;

    try {
      // Eğer ilk kart ise varsayılan yap
      final isFirst = state.cards.isEmpty;
      final cardToSave = isFirst ? card.copyWith(isDefault: true) : card;

      final response = await SupabaseService.client
          .from('payment_methods')
          .insert(cardToSave.toJson(userId))
          .select()
          .single();

      final newCard = SavedPaymentCard.fromJson(response);

      state = state.copyWith(cards: [...state.cards, newCard]);

      return true;
    } catch (e) {
      if (kDebugMode) print('Error adding card: $e');
      return false;
    }
  }

  Future<bool> removeCard(String cardId) async {
    try {
      await SupabaseService.client
          .from('payment_methods')
          .update({'is_active': false})
          .eq('id', cardId);

      final updatedCards = state.cards.where((c) => c.id != cardId).toList();

      // Silinen kart varsayılandıysa ve başka kart varsa, ilkini varsayılan yap
      if (updatedCards.isNotEmpty && !updatedCards.any((c) => c.isDefault)) {
        await setDefaultCard(updatedCards[0].id);
      } else {
        state = state.copyWith(cards: updatedCards);
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('Error removing card: $e');
      return false;
    }
  }

  Future<void> setDefaultCard(String cardId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      // Önce tüm kartların is_default'unu false yap
      await SupabaseService.client
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Seçilen kartı varsayılan yap
      await SupabaseService.client
          .from('payment_methods')
          .update({'is_default': true})
          .eq('id', cardId);

      final updatedCards = state.cards.map((card) {
        return card.copyWith(isDefault: card.id == cardId);
      }).toList();

      state = state.copyWith(cards: updatedCards);
    } catch (e) {
      if (kDebugMode) print('Error setting default card: $e');
    }
  }

  Future<void> setCashEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payment_cash_enabled', enabled);
    state = state.copyWith(cashEnabled: enabled);
  }

  Future<void> setWalletEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payment_wallet_enabled', enabled);
    state = state.copyWith(walletEnabled: enabled);
  }

  Future<void> setCreditCardOnDeliveryEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payment_cc_delivery_enabled', enabled);
    state = state.copyWith(creditCardOnDeliveryEnabled: enabled);
  }

  void updateWalletBalance(double balance) {
    state = state.copyWith(walletBalance: balance);
  }
}

// Provider tanımları
final paymentMethodProvider =
    StateNotifierProvider<PaymentMethodNotifier, PaymentMethodState>((ref) {
      return PaymentMethodNotifier();
    });

// Convenience providers
final savedCardsProvider = Provider<List<SavedPaymentCard>>((ref) {
  return ref.watch(paymentMethodProvider).cards;
});

final activePromotionsProvider = Provider<List<Promotion>>((ref) {
  return ref.watch(paymentMethodProvider).activePromotions;
});

final defaultCardProvider = Provider<SavedPaymentCard?>((ref) {
  return ref.watch(paymentMethodProvider).defaultCard;
});

final allPaymentOptionsProvider = Provider<List<TaxiPaymentOption>>((ref) {
  return ref.watch(paymentMethodProvider).allPaymentOptions;
});

final walletBalanceProvider = Provider<double>((ref) {
  return ref.watch(paymentMethodProvider).walletBalance;
});
