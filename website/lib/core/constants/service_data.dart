import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum RobotPose { idle, talking, walking, celebrating, pointing, waving, holding }

class ServiceInfo {
  final String id;
  final String name;
  final String shortDesc;
  final String longDesc;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final List<String> features;
  final String robotMessage;

  const ServiceInfo({
    required this.id,
    required this.name,
    required this.shortDesc,
    required this.longDesc,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.features,
    required this.robotMessage,
  });
}

class PanelInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final String url;
  final List<String> features;

  const PanelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.url,
    required this.features,
  });
}

class AppInfo {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<String> features;
  final String apkUrl;

  const AppInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.features,
    required this.apkUrl,
  });
}

class ServiceData {
  static const List<ServiceInfo> services = [
    ServiceInfo(
      id: 'food',
      name: 'Yemek Siparişi',
      shortDesc: 'Restoranlardan online sipariş',
      longDesc:
          'Binlerce restorandan AI asistanla konuşarak sipariş verin. '
          'Sesli komutla yemek seçin, canlı takip edin, favori restoranlarınızı kaydedin.',
      icon: Icons.restaurant_rounded,
      color: AppColors.food,
      gradient: AppColors.foodGradient,
      features: [
        'AI asistan ile sesli sipariş',
        'Canlı sipariş takibi',
        'Akıllı restoran önerileri',
        'Favori ve kampanyalar',
      ],
      robotMessage: 'Bugün ne yemek istersiniz?',
    ),
    ServiceInfo(
      id: 'market',
      name: 'Market & Mağaza',
      shortDesc: 'Market ürünleri, hızlı teslimat',
      longDesc:
          'Market ve mağaza alışverişinizi kapınıza getiriyoruz. '
          'Binlerce ürün, kategoriler, kampanyalar ve hızlı teslimat.',
      icon: Icons.shopping_cart_rounded,
      color: AppColors.market,
      gradient: AppColors.marketGradient,
      features: [
        'Binlerce mağaza ve ürün',
        'Kategori bazlı alışveriş',
        'Kampanya ve indirimler',
        'Hızlı teslimat',
      ],
      robotMessage: 'Market alışverişi kapınıza gelsin!',
    ),
    ServiceInfo(
      id: 'taxi',
      name: 'Taksi',
      shortDesc: 'Anlık taksi çağırma, canlı takip',
      longDesc:
          'Tek tuşla taksi çağırın, şoförünüzü canlı haritada takip edin. '
          'Güvenli yolculuk, şeffaf fiyatlandırma, şoför değerlendirme.',
      icon: Icons.local_taxi_rounded,
      color: AppColors.taxi,
      gradient: AppColors.taxiGradient,
      features: [
        'Anlık taksi çağırma',
        'Canlı harita takibi',
        'Şeffaf fiyatlandırma',
        'Şoför değerlendirme',
      ],
      robotMessage: 'Anında taksi çağır, canlı takip et!',
    ),
    ServiceInfo(
      id: 'courier',
      name: 'Kurye Teslimat',
      shortDesc: 'Hızlı kurye teslimatı',
      longDesc:
          'Acil gönderi mi var? Kuryemiz kapınıza gelsin. '
          'Canlı takip, teslimat onayı ve güvenli taşıma garantisi.',
      icon: Icons.delivery_dining_rounded,
      color: AppColors.courier,
      gradient: AppColors.courierGradient,
      features: [
        'Hızlı teslimat',
        'Canlı kurye takibi',
        'Teslimat onayı',
        'Güvenli taşıma',
      ],
      robotMessage: 'Hızlı ve güvenilir teslimat!',
    ),
    ServiceInfo(
      id: 'emlak',
      name: 'Emlak',
      shortDesc: 'Satılık/kiralık ilan ve randevu',
      longDesc:
          'Hayalinizdeki evi bulun. Satılık ve kiralık ilanlar, '
          'detaylı filtreler, fotoğraflar, harita üzerinde konum ve emlakçıyla mesajlaşma.',
      icon: Icons.home_work_rounded,
      color: AppColors.emlak,
      gradient: AppColors.emlakGradient,
      features: [
        'Satılık & kiralık ilanlar',
        'Detaylı filtreler',
        'Harita üzerinde konum',
        'Emlakçı ile mesajlaşma',
      ],
      robotMessage: 'Hayalinizdeki evi bulalım!',
    ),
    ServiceInfo(
      id: 'car_sales',
      name: 'Araç Satışı',
      shortDesc: 'Araç ilan verme ve arama',
      longDesc:
          'Araç alım-satım platformu. 40+ filtre ile arama, '
          'galeri profilleri, detaylı araç özellikleri ve satıcıyla mesajlaşma.',
      icon: Icons.directions_car_rounded,
      color: AppColors.carSales,
      gradient: AppColors.carSalesGradient,
      features: [
        '40+ detaylı filtre',
        'Galeri profilleri',
        'Araç karşılaştırma',
        'Satıcı ile mesajlaşma',
      ],
      robotMessage: 'Satılık araç mı arıyorsunuz?',
    ),
    ServiceInfo(
      id: 'car_rental',
      name: 'Araç Kiralama',
      shortDesc: 'Günlük/aylık araç kiralama',
      longDesc:
          'Günlük veya uzun süreli araç kiralama. Lüks, SUV, ekonomik — '
          'tüm kategorilerde araçlar, online rezervasyon ve esnek teslimat noktaları.',
      icon: Icons.car_rental_rounded,
      color: AppColors.carRental,
      gradient: AppColors.carRentalGradient,
      features: [
        'Günlük & uzun süreli kiralama',
        'Lüks, SUV, ekonomik seçenekler',
        'Online rezervasyon',
        'Esnek teslim noktaları',
      ],
      robotMessage: 'Günlük veya uzun süreli kiralama!',
    ),
    ServiceInfo(
      id: 'jobs',
      name: 'İş İlanları',
      shortDesc: 'İş arama ve ilan verme',
      longDesc:
          'Kuzey Kıbrıs\'ın iş arama platformu. Kategorilere göre ilanlar, '
          'şirket profilleri, maaş bilgileri ve kolay başvuru.',
      icon: Icons.work_rounded,
      color: AppColors.jobs,
      gradient: AppColors.jobsGradient,
      features: [
        'Kategoriye göre ilanlar',
        'Şirket profilleri',
        'Maaş bilgileri',
        'Kolay başvuru',
      ],
      robotMessage: 'İş fırsatları burada!',
    ),
  ];

  static const List<PanelInfo> panels = [
    PanelInfo(
      id: 'admin',
      name: 'Admin Panel',
      description: 'Tüm platformun merkezi yönetim paneli',
      icon: Icons.admin_panel_settings_rounded,
      color: AppColors.primary,
      gradient: [AppColors.primary, AppColors.primaryLight],
      url: 'https://admin.supercyp.com',
      features: [
        'Merkezi yönetim',
        'Başvuru onayları',
        'Finansal raporlar',
        'Sistem sağlığı',
      ],
    ),
    PanelInfo(
      id: 'merchant',
      name: 'Restoran & Mağaza Paneli',
      description: 'Restoran ve mağaza sahipleri için yönetim paneli',
      icon: Icons.storefront_rounded,
      color: AppColors.food,
      gradient: AppColors.foodGradient,
      url: 'https://panel.supercyp.com',
      features: [
        'Menü yönetimi',
        'Sipariş takibi',
        'Müşteri yönetimi',
        'Satış raporları',
      ],
    ),
    PanelInfo(
      id: 'emlakci',
      name: 'Emlakçı Paneli',
      description: 'Emlak ofisleri için portföy ve ilan yönetimi',
      icon: Icons.apartment_rounded,
      color: AppColors.emlak,
      gradient: AppColors.emlakGradient,
      url: 'https://emlakci.supercyp.com',
      features: [
        'İlan yönetimi',
        'Portföy takibi',
        'Randevu yönetimi',
        'Müşteri mesajları',
      ],
    ),
    PanelInfo(
      id: 'arac_satis',
      name: 'Araç Satış Paneli',
      description: 'Galericiler için araç ilan ve satış yönetimi',
      icon: Icons.directions_car_filled_rounded,
      color: AppColors.carSales,
      gradient: AppColors.carSalesGradient,
      url: 'https://arac.supercyp.com',
      features: [
        'Araç ilanları',
        'Galeri profili',
        'Müşteri mesajları',
        'İlan istatistikleri',
      ],
    ),
    PanelInfo(
      id: 'rentacar',
      name: 'Rent a Car Paneli',
      description: 'Araç kiralama firmaları için filo ve rezervasyon yönetimi',
      icon: Icons.car_rental_rounded,
      color: AppColors.carRental,
      gradient: AppColors.carRentalGradient,
      url: 'https://rentacar.supercyp.com',
      features: [
        'Filo yönetimi',
        'Rezervasyonlar',
        'Finansal raporlar',
        'Lokasyon yönetimi',
      ],
    ),
  ];

  static const List<AppInfo> apps = [
    AppInfo(
      id: 'super_app',
      name: 'SuperCyp',
      description:
          'Tüketici uygulaması — 8 hizmet, AI asistan, sesli komut, biyometrik giriş',
      icon: Icons.apps_rounded,
      gradient: [AppColors.primary, AppColors.cyan],
      features: [
        '8 farklı hizmet',
        'AI asistan & sesli komut',
        'Canlı takip',
        'Biyometrik giriş',
        'Push bildirimler',
      ],
      apkUrl: '#',
    ),
    AppInfo(
      id: 'driver_app',
      name: 'SuperCyp Şoför',
      description:
          'Taksi şoförleri için — biniş yönetimi, kazanç takibi, rota navigasyonu',
      icon: Icons.local_taxi_rounded,
      gradient: AppColors.taxiGradient,
      features: [
        'Biniş talepleri',
        'Kazanç takibi',
        'Rota navigasyonu',
        'Müşteri değerlendirme',
      ],
      apkUrl: '#',
    ),
    AppInfo(
      id: 'courier_app',
      name: 'SuperCyp Kurye',
      description:
          'Kuryeler için — sipariş yönetimi, teslimat onayı, kazanç takibi',
      icon: Icons.delivery_dining_rounded,
      gradient: AppColors.courierGradient,
      features: [
        'Teslimat talepleri',
        'Navigasyon haritası',
        'Kazanç raporu',
        'Anlık bildirimler',
      ],
      apkUrl: '#',
    ),
  ];
}
