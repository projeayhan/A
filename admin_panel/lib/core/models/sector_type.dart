import 'package:flutter/material.dart';

/// Tüm sektör tiplerini tanımlayan enum.
/// Her sektörün label, icon, baseRoute, tableName ve idField bilgisi vardır.
enum SectorType {
  food(
    label: 'Yemek',
    icon: Icons.restaurant_rounded,
    baseRoute: '/yemek',
    tableName: 'merchants',
    idField: 'id',
  ),
  market(
    label: 'Market',
    icon: Icons.local_grocery_store_rounded,
    baseRoute: '/market',
    tableName: 'merchants',
    idField: 'id',
  ),
  store(
    label: 'Mağaza',
    icon: Icons.storefront_rounded,
    baseRoute: '/magaza',
    tableName: 'merchants',
    idField: 'id',
  ),
  realEstate(
    label: 'Emlak',
    icon: Icons.home_work_rounded,
    baseRoute: '/emlak',
    tableName: 'realtors',
    idField: 'id',
  ),
  taxi(
    label: 'Taksi',
    icon: Icons.local_taxi_rounded,
    baseRoute: '/taksi',
    tableName: 'taxi_drivers',
    idField: 'id',
  ),
  carSales(
    label: 'Galeri',
    icon: Icons.directions_car_filled_rounded,
    baseRoute: '/galeri',
    tableName: 'car_dealers',
    idField: 'id',
  ),
  jobs(
    label: 'İş İlanları',
    icon: Icons.work_rounded,
    baseRoute: '/is-ilanlari',
    tableName: 'companies',
    idField: 'id',
  ),
  carRental(
    label: 'Araç Kiralama',
    icon: Icons.car_rental_rounded,
    baseRoute: '/arac-kiralama',
    tableName: 'rental_companies',
    idField: 'id',
  );

  const SectorType({
    required this.label,
    required this.icon,
    required this.baseRoute,
    required this.tableName,
    required this.idField,
  });

  final String label;
  final IconData icon;
  final String baseRoute;
  final String tableName;
  final String idField;

  /// Sektör tipine göre tab listesini döner
  List<SectorTab> get tabs {
    switch (this) {
      case SectorType.food:
      case SectorType.market:
      case SectorType.store:
        return [
          SectorTab('Genel', Icons.info_outline, 'genel'),
          SectorTab('Siparişler', Icons.receipt_long_outlined, 'siparisler'),
          SectorTab(this == SectorType.food ? 'Menü' : 'Ürünler', Icons.menu_book_outlined, 'urunler'),
          SectorTab('Stok', Icons.inventory_2_outlined, 'stok'),
          SectorTab('Finans', Icons.account_balance_wallet_outlined, 'finans'),
          SectorTab('Yorumlar', Icons.star_outline, 'yorumlar'),
          SectorTab('Kuryeler', Icons.delivery_dining_outlined, 'kuryeler'),
          SectorTab('Mesajlar', Icons.chat_outlined, 'mesajlar'),
          SectorTab('Ayarlar', Icons.settings_outlined, 'ayarlar'),
        ];
      case SectorType.realEstate:
        return [
          SectorTab('Genel', Icons.info_outline, 'genel'),
          SectorTab('İlanlar', Icons.list_alt_outlined, 'ilanlar'),
          SectorTab('CRM', Icons.people_outline, 'crm'),
          SectorTab('Randevular', Icons.event_outlined, 'randevular'),
          SectorTab('Analitik', Icons.analytics_outlined, 'analitik'),
          SectorTab('Yorumlar', Icons.star_outline, 'yorumlar'),
          SectorTab('Sohbet', Icons.chat_outlined, 'sohbet'),
          SectorTab('Ayarlar', Icons.settings_outlined, 'ayarlar'),
        ];
      case SectorType.taxi:
        return [
          SectorTab('Genel', Icons.info_outline, 'genel'),
          SectorTab('Seferler', Icons.route_outlined, 'seferler'),
          SectorTab('Kazançlar', Icons.payments_outlined, 'kazanclar'),
          SectorTab('Yorumlar', Icons.star_outline, 'yorumlar'),
          SectorTab('Ayarlar', Icons.settings_outlined, 'ayarlar'),
        ];
      case SectorType.carSales:
        return [
          SectorTab('Genel', Icons.info_outline, 'genel'),
          SectorTab('İlanlar', Icons.list_alt_outlined, 'ilanlar'),
          SectorTab('Mesajlar', Icons.chat_outlined, 'mesajlar'),
          SectorTab('Performans', Icons.trending_up_outlined, 'performans'),
          SectorTab('Yorumlar', Icons.star_outline, 'yorumlar'),
          SectorTab('Ayarlar', Icons.settings_outlined, 'ayarlar'),
        ];
      case SectorType.jobs:
        return [
          SectorTab('Genel', Icons.info_outline, 'genel'),
          SectorTab('İlanlar', Icons.list_alt_outlined, 'ilanlar'),
          SectorTab('Başvurular', Icons.assignment_outlined, 'basvurular'),
          SectorTab('Ayarlar', Icons.settings_outlined, 'ayarlar'),
        ];
      case SectorType.carRental:
        return [
          SectorTab('Genel', Icons.info_outline, 'genel'),
          SectorTab('Araçlar', Icons.directions_car_outlined, 'araclar'),
          SectorTab('Rezervasyonlar', Icons.event_note_outlined, 'rezervasyonlar'),
          SectorTab('Takvim', Icons.calendar_month_outlined, 'takvim'),
          SectorTab('Lokasyonlar', Icons.location_on_outlined, 'lokasyonlar'),
          SectorTab('Paketler', Icons.card_giftcard_outlined, 'paketler'),
          SectorTab('Finans', Icons.account_balance_wallet_outlined, 'finans'),
          SectorTab('Yorumlar', Icons.star_outline, 'yorumlar'),
          SectorTab('Ayarlar', Icons.settings_outlined, 'ayarlar'),
        ];
    }
  }

  /// Merchant type filter for shared tables (food/market/store share merchants table)
  String? get merchantTypeFilter {
    switch (this) {
      case SectorType.food:
        return 'restaurant';
      case SectorType.market:
        return 'market';
      case SectorType.store:
        return 'store';
      default:
        return null;
    }
  }

  /// Sektörün sipariş/ilan sayısı için kullanılan kolon adı
  String get countLabel {
    switch (this) {
      case SectorType.food:
      case SectorType.market:
      case SectorType.store:
        return 'Sipariş';
      case SectorType.realEstate:
      case SectorType.carSales:
      case SectorType.jobs:
        return 'İlan';
      case SectorType.taxi:
        return 'Sefer';
      case SectorType.carRental:
        return 'Rezervasyon';
    }
  }
}

class SectorTab {
  final String label;
  final IconData icon;
  final String routeSegment;

  const SectorTab(this.label, this.icon, this.routeSegment);
}
