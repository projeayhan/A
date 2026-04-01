// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class STr extends S {
  STr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'SuperCyp';

  @override
  String get appSlogan => 'Kıbrıs\'ta her şey tek uygulamada';

  @override
  String get home => 'Ana Sayfa';

  @override
  String get profile => 'Profil';

  @override
  String get favorites => 'Favoriler';

  @override
  String get orders => 'Siparişler';

  @override
  String get settings => 'Ayarlar';

  @override
  String get welcomeGreeting => 'HOŞ GELDİN,';

  @override
  String get userFallback => 'Kullanıcı';

  @override
  String get searchHint => 'Restoran, mağaza veya ürün ara...';

  @override
  String get searching => 'Aranıyor...';

  @override
  String get noResults => 'Sonuç bulunamadı';

  @override
  String noResultsFor(String query) {
    return '\"$query\" için sonuç yok';
  }

  @override
  String get ourServices => 'Hizmetlerimiz';

  @override
  String get food => 'Yemek';

  @override
  String get foodSubtitle => 'Lezzet kapında';

  @override
  String get stores => 'Mağazalar';

  @override
  String get storesSubtitle => 'Market & Alışveriş';

  @override
  String get taxi => 'Taksi';

  @override
  String get taxiSubtitle => 'Hızlı ulaşım';

  @override
  String get carRental => 'Araç Kiralama';

  @override
  String get carRentalSubtitle => 'Saatlik & Günlük';

  @override
  String get realEstate => 'Emlak';

  @override
  String get realEstateSubtitle => 'Konut & Arsa';

  @override
  String get carSales => 'Araç Satışı';

  @override
  String get carSalesSubtitle => '2. El Fırsatlar';

  @override
  String get jobListings => 'İş İlanları';

  @override
  String get jobListingsSubtitle => 'Kariyer Fırsatları';

  @override
  String get grocery => 'Market';

  @override
  String get grocerySubtitle => 'Taze ürünler kapında';

  @override
  String get restaurants => 'Restoranlar';

  @override
  String get meals => 'Yemekler';

  @override
  String get products => 'Ürünler';

  @override
  String get exitTitle => 'Çıkış';

  @override
  String get exitMessage => 'Uygulamadan çıkmak istiyor musunuz?';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get ok => 'Tamam';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get send => 'Gönder';

  @override
  String get save => 'Kaydet';

  @override
  String get delete => 'Sil';

  @override
  String get edit => 'Düzenle';

  @override
  String get close => 'Kapat';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get errorOccurred => 'Bir hata oluştu';

  @override
  String get account => 'Hesap';

  @override
  String get personalInfo => 'Kişisel Bilgiler';

  @override
  String get personalInfoSubtitle => 'Ad, soyad, telefon';

  @override
  String get personalInfoSubtitleFull => 'Ad, soyad, e-posta, telefon';

  @override
  String get myAddresses => 'Adreslerim';

  @override
  String registeredAddressCount(int count) {
    return '$count kayıtlı adres';
  }

  @override
  String get myPaymentMethods => 'Ödeme Yöntemlerim';

  @override
  String registeredCardCount(int count) {
    return '$count kayıtlı kart';
  }

  @override
  String get emergencyContacts => 'Acil Durum Kişileri';

  @override
  String get emergencyContactsSubtitle => 'SOS mesajı gönderilecek kişiler';

  @override
  String get preferences => 'Tercihler';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get darkMode => 'Karanlık Mod';

  @override
  String get themePreference => 'Tema tercihi';

  @override
  String get language => 'Dil';

  @override
  String get supportAndInfo => 'Destek ve Bilgi';

  @override
  String get helpCenter => 'Yardım Merkezi';

  @override
  String get helpCenterSubtitle => 'Sıkça sorulan sorular';

  @override
  String get liveSupport => 'Canlı Destek';

  @override
  String get liveSupportSubtitle => '7/24 müşteri hizmetleri';

  @override
  String get reportBug => 'Hata Bildir';

  @override
  String get reportBugSubtitle => 'Sorunları bize iletin';

  @override
  String get termsOfService => 'Kullanım Koşulları';

  @override
  String get termsOfServiceSubtitle => 'Hizmet şartları';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get privacyPolicySubtitle => 'Veri koruma politikamız';

  @override
  String get about => 'Hakkında';

  @override
  String versionInfo(String version) {
    return 'Versiyon $version';
  }

  @override
  String get goldMember => 'Gold Üye';

  @override
  String get platinumMember => 'Platinum Üye';

  @override
  String get premiumMember => 'Premium Üye';

  @override
  String get standardMember => 'Standart Üye';

  @override
  String get unreadNotifications => 'okunmamış bildirim';

  @override
  String get allNotificationsRead => 'Tüm bildirimler okundu';

  @override
  String get signOut => 'Çıkış Yap';

  @override
  String get signOutConfirm =>
      'Hesabınızdan çıkış yapmak istediğinize emin misiniz?';

  @override
  String get liveSupportDialogMessage =>
      'AI asistanımız size 7/24 yardımcı olabilir.';

  @override
  String get getInstantAnswers => 'Anında yanıt alın';

  @override
  String get startChat => 'Sohbet Başlat';

  @override
  String get reportBugDialogMessage =>
      'Karşılaştığınız sorunu detaylı bir şekilde açıklayın.';

  @override
  String get describeProblem => 'Sorunu açıklayın...';

  @override
  String get pleaseDescribeProblem => 'Lütfen sorunu açıklayın.';

  @override
  String get bugReportSent => 'Hata raporu gönderildi. Teşekkür ederiz!';

  @override
  String get couldNotSend => 'Gönderilemedi:';

  @override
  String get allNeedsInOneApp =>
      'Tüm ihtiyaçlarınız için tek uygulama.\nYemek, market, kurye, taksi ve daha fazlası.';

  @override
  String get copyright => '© 2025 SuperCyp. Tüm hakları saklıdır.';

  @override
  String get terms => 'Koşullar';

  @override
  String get privacy => 'Gizlilik';

  @override
  String get passwordAndSecurity => 'Şifre ve Güvenlik';

  @override
  String get passwordAndSecuritySubtitle => 'Şifre değiştir, 2FA ayarları';

  @override
  String get registeredDeliveryAddresses => 'Kayıtlı teslimat adresleri';

  @override
  String get cardsAndPaymentOptions => 'Kartlar ve ödeme seçenekleri';

  @override
  String get pushNotifications => 'Push Bildirimleri';

  @override
  String get getInstantNotifications => 'Anlık bildirimler al';

  @override
  String get emailNotifications => 'E-posta Bildirimleri';

  @override
  String get getEmailUpdates => 'Güncellemeleri e-posta ile al';

  @override
  String get smsNotifications => 'SMS Bildirimleri';

  @override
  String get getSmsAlerts => 'Önemli uyarıları SMS ile al';

  @override
  String get orderUpdates => 'Sipariş Güncellemeleri';

  @override
  String get orderStatusChanges => 'Sipariş durumu değişiklikleri';

  @override
  String get campaigns => 'Kampanyalar';

  @override
  String get specialOffers => 'Özel fırsatlardan haberdar ol';

  @override
  String get newFeatures => 'Yeni Özellikler';

  @override
  String get learnAboutUpdates => 'Uygulama yeniliklerini öğren';

  @override
  String get privacySection => 'Gizlilik';

  @override
  String get locationServices => 'Konum Servisleri';

  @override
  String get findNearbyBusinesses => 'Yakındaki işletmeleri bul';

  @override
  String get analyticsData => 'Analitik Veriler';

  @override
  String get contributeToImprovements => 'Uygulama iyileştirmelerine katkı';

  @override
  String get personalizedAds => 'Kişiselleştirilmiş Reklamlar';

  @override
  String get adsByInterest => 'İlgi alanlarına göre reklamlar';

  @override
  String get downloadData => 'Veri İndirme';

  @override
  String get getDataCopy => 'Verilerinin bir kopyasını al';

  @override
  String get deleteAccount => 'Hesabı Sil';

  @override
  String get deleteAccountSubtitle => 'Hesabını kalıcı olarak kaldır';

  @override
  String get appPreferences => 'Uygulama Tercihleri';

  @override
  String get biometricLogin => 'Biyometrik Giriş';

  @override
  String get biometricSubtitle => 'Parmak izi veya yüz tanıma';

  @override
  String get autoUpdate => 'Otomatik Güncelleme';

  @override
  String get autoUpdateSubtitle => 'Uygulamayı otomatik güncelle';

  @override
  String get selectLanguage => 'Dil Seçin';

  @override
  String get deliveryAddress => 'Teslimat Adresi';

  @override
  String get addNewAddress => 'Yeni Adres Ekle';

  @override
  String get markAllAsRead => 'Tümünü Okundu İşaretle';

  @override
  String get noNotifications => 'Bildirim yok';

  @override
  String get storeNotifications => 'Mağaza Bildirimleri';

  @override
  String get generalNotifications => 'Genel Bildirimler';

  @override
  String get justNow => 'Az önce';

  @override
  String minutesAgo(int count) {
    return '$count dakika önce';
  }

  @override
  String hoursAgo(int count) {
    return '$count saat önce';
  }

  @override
  String daysAgo(int count) {
    return '$count gün önce';
  }

  @override
  String get addedToFavorites => 'Favorilere eklendi';

  @override
  String get removedFromFavorites => 'Favorilerden çıkarıldı';

  @override
  String get searchMenu => 'Menüde ara...';

  @override
  String get notSpecified => 'Belirtilmemiş';

  @override
  String get restaurant => 'Restoran';

  @override
  String get free => 'Ücretsiz';

  @override
  String get minimumOrder => 'Min. Sipariş';

  @override
  String get popular => 'Popüler';

  @override
  String get noComments => 'Yorum yok';

  @override
  String get emailLogin => 'E-posta ile giriş yap';

  @override
  String get phoneNumber => 'Telefon Numarası';

  @override
  String get verificationCode => 'Doğrulama Kodu';

  @override
  String get email => 'E-posta';

  @override
  String get password => 'Şifre';

  @override
  String get storeNotFound => 'Mağaza bulunamadı';

  @override
  String get productNotFound => 'Ürün bulunamadı';

  @override
  String get marketNotFound => 'Market bulunamadı';

  @override
  String get vehicleNotFound => 'Araç bulunamadı';

  @override
  String get listingNotFound => 'İlan bulunamadı';

  @override
  String get listingMayNotExist => 'Bu ilan artık mevcut olmayabilir.';

  @override
  String get pageNotFound => 'Sayfa bulunamadı';

  @override
  String get listingDetails => 'İlan Detayı';

  @override
  String get marketDeals => 'Market Fırsatları';

  @override
  String get markets => 'Marketler';

  @override
  String get recommended => 'Önerilen';

  @override
  String get byRating => 'Puana Göre';

  @override
  String get fastest => 'En Hızlı';

  @override
  String get selectAddress => 'Adres seçin';

  @override
  String get noMarketsInArea => 'Bölgenizde Market Yok';

  @override
  String get noMarketsDelivery =>
      'Seçili adresinize teslimat yapan market bulunmuyor';

  @override
  String get changeAddress => 'Adres Değiştir';

  @override
  String get marketsInYourArea => 'Bölgenize teslimat yapan marketler';

  @override
  String get sorting => 'Sıralama';

  @override
  String get awaitingEmailVerification => 'E-posta Doğrulama Bekleniyor';

  @override
  String get pending => 'Beklemede';

  @override
  String get addEmail => 'E-posta Ekle';

  @override
  String get addEmailSubtitle =>
      'E-posta ekleyerek şifre ile de giriş yapabilirsiniz';

  @override
  String get changePassword => 'Şifre Değiştir';

  @override
  String get changePasswordSubtitle => 'Hesap şifrenizi güncelleyin';

  @override
  String get setPassword => 'Şifre Belirle';

  @override
  String get setPasswordSubtitle =>
      'E-posta ile de giriş yapabilmek için şifre belirleyin';

  @override
  String get addEmailFirst =>
      'Önce e-posta ekleyin, ardından şifre belirleyebilirsiniz';

  @override
  String get biometricLoginSubtitle => 'Parmak izi veya yüz tanıma ile giriş';

  @override
  String get changeEmail => 'E-posta Değiştir';

  @override
  String get emailVerificationMessage =>
      'Girdiğiniz adrese doğrulama linki gönderilecektir. Onayladıktan sonra e-posta ile giriş yapabilirsiniz.';

  @override
  String get emailAddress => 'E-posta adresi';

  @override
  String get sendVerificationLink => 'Doğrulama Linki Gönder';

  @override
  String get currentPassword => 'Mevcut Şifre';

  @override
  String get newPassword => 'Yeni Şifre';

  @override
  String get confirmNewPassword => 'Yeni Şifre (Tekrar)';

  @override
  String get passwordMinLength => 'Şifreniz en az 8 karakter olmalıdır.';

  @override
  String get changePasswordButton => 'Şifreyi Değiştir';

  @override
  String get setPasswordMessage =>
      'Şifre belirleyerek e-posta adresinizle de giriş yapabilirsiniz.';

  @override
  String get confirmPassword => 'Şifre (Tekrar)';

  @override
  String get setPasswordButton => 'Şifreyi Belirle';

  @override
  String get passwordMinError => 'Şifre en az 8 karakter olmalıdır';

  @override
  String get passwordsDoNotMatch => 'Şifreler eşleşmiyor';

  @override
  String get passwordChanged => 'Şifreniz başarıyla değiştirildi';

  @override
  String get passwordSet =>
      'Şifreniz başarıyla belirlendi! Artık e-posta ile de giriş yapabilirsiniz.';

  @override
  String get enterValidEmail => 'Geçerli bir e-posta adresi girin';

  @override
  String verificationLinkSent(String email) {
    return '$email adresine doğrulama linki gönderildi. Onayladıktan sonra şifre belirleyebilirsiniz.';
  }

  @override
  String get deviceNotSupportBiometric =>
      'Bu cihaz biyometrik kimlik doğrulamayı desteklemiyor.';

  @override
  String get authenticateToEnableBiometric =>
      'Biyometrik girişi etkinleştirmek için doğrulama yapın';

  @override
  String get biometricAuthFailed => 'Biyometrik doğrulama başarısız:';

  @override
  String get verifyEmailFirst =>
      'Şifre belirlemek için önce e-posta adresinizi doğrulayın';

  @override
  String get comingSoon => 'Yakında';

  @override
  String get serviceComingSoon => 'Hizmet Servisi - Yakında';

  @override
  String get appointmentComingSoon => 'Randevu Servisi - Yakında';
}
