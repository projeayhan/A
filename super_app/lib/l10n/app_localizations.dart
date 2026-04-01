import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appName.
  ///
  /// In tr, this message translates to:
  /// **'SuperCyp'**
  String get appName;

  /// No description provided for @appSlogan.
  ///
  /// In tr, this message translates to:
  /// **'Kıbrıs\'ta her şey tek uygulamada'**
  String get appSlogan;

  /// No description provided for @home.
  ///
  /// In tr, this message translates to:
  /// **'Ana Sayfa'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @favorites.
  ///
  /// In tr, this message translates to:
  /// **'Favoriler'**
  String get favorites;

  /// No description provided for @orders.
  ///
  /// In tr, this message translates to:
  /// **'Siparişler'**
  String get orders;

  /// No description provided for @settings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settings;

  /// No description provided for @welcomeGreeting.
  ///
  /// In tr, this message translates to:
  /// **'HOŞ GELDİN,'**
  String get welcomeGreeting;

  /// No description provided for @userFallback.
  ///
  /// In tr, this message translates to:
  /// **'Kullanıcı'**
  String get userFallback;

  /// No description provided for @searchHint.
  ///
  /// In tr, this message translates to:
  /// **'Restoran, mağaza veya ürün ara...'**
  String get searchHint;

  /// No description provided for @searching.
  ///
  /// In tr, this message translates to:
  /// **'Aranıyor...'**
  String get searching;

  /// No description provided for @noResults.
  ///
  /// In tr, this message translates to:
  /// **'Sonuç bulunamadı'**
  String get noResults;

  /// No description provided for @noResultsFor.
  ///
  /// In tr, this message translates to:
  /// **'\"{query}\" için sonuç yok'**
  String noResultsFor(String query);

  /// No description provided for @ourServices.
  ///
  /// In tr, this message translates to:
  /// **'Hizmetlerimiz'**
  String get ourServices;

  /// No description provided for @food.
  ///
  /// In tr, this message translates to:
  /// **'Yemek'**
  String get food;

  /// No description provided for @foodSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Lezzet kapında'**
  String get foodSubtitle;

  /// No description provided for @stores.
  ///
  /// In tr, this message translates to:
  /// **'Mağazalar'**
  String get stores;

  /// No description provided for @storesSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Market & Alışveriş'**
  String get storesSubtitle;

  /// No description provided for @taxi.
  ///
  /// In tr, this message translates to:
  /// **'Taksi'**
  String get taxi;

  /// No description provided for @taxiSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hızlı ulaşım'**
  String get taxiSubtitle;

  /// No description provided for @carRental.
  ///
  /// In tr, this message translates to:
  /// **'Araç Kiralama'**
  String get carRental;

  /// No description provided for @carRentalSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Saatlik & Günlük'**
  String get carRentalSubtitle;

  /// No description provided for @realEstate.
  ///
  /// In tr, this message translates to:
  /// **'Emlak'**
  String get realEstate;

  /// No description provided for @realEstateSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Konut & Arsa'**
  String get realEstateSubtitle;

  /// No description provided for @carSales.
  ///
  /// In tr, this message translates to:
  /// **'Araç Satışı'**
  String get carSales;

  /// No description provided for @carSalesSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'2. El Fırsatlar'**
  String get carSalesSubtitle;

  /// No description provided for @jobListings.
  ///
  /// In tr, this message translates to:
  /// **'İş İlanları'**
  String get jobListings;

  /// No description provided for @jobListingsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Kariyer Fırsatları'**
  String get jobListingsSubtitle;

  /// No description provided for @grocery.
  ///
  /// In tr, this message translates to:
  /// **'Market'**
  String get grocery;

  /// No description provided for @grocerySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Taze ürünler kapında'**
  String get grocerySubtitle;

  /// No description provided for @restaurants.
  ///
  /// In tr, this message translates to:
  /// **'Restoranlar'**
  String get restaurants;

  /// No description provided for @meals.
  ///
  /// In tr, this message translates to:
  /// **'Yemekler'**
  String get meals;

  /// No description provided for @products.
  ///
  /// In tr, this message translates to:
  /// **'Ürünler'**
  String get products;

  /// No description provided for @exitTitle.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış'**
  String get exitTitle;

  /// No description provided for @exitMessage.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamadan çıkmak istiyor musunuz?'**
  String get exitMessage;

  /// No description provided for @yes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get cancel;

  /// No description provided for @send.
  ///
  /// In tr, this message translates to:
  /// **'Gönder'**
  String get send;

  /// No description provided for @save.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar Dene'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In tr, this message translates to:
  /// **'Yükleniyor...'**
  String get loading;

  /// No description provided for @errorOccurred.
  ///
  /// In tr, this message translates to:
  /// **'Bir hata oluştu'**
  String get errorOccurred;

  /// No description provided for @account.
  ///
  /// In tr, this message translates to:
  /// **'Hesap'**
  String get account;

  /// No description provided for @personalInfo.
  ///
  /// In tr, this message translates to:
  /// **'Kişisel Bilgiler'**
  String get personalInfo;

  /// No description provided for @personalInfoSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Ad, soyad, telefon'**
  String get personalInfoSubtitle;

  /// No description provided for @personalInfoSubtitleFull.
  ///
  /// In tr, this message translates to:
  /// **'Ad, soyad, e-posta, telefon'**
  String get personalInfoSubtitleFull;

  /// No description provided for @myAddresses.
  ///
  /// In tr, this message translates to:
  /// **'Adreslerim'**
  String get myAddresses;

  /// No description provided for @registeredAddressCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kayıtlı adres'**
  String registeredAddressCount(int count);

  /// No description provided for @myPaymentMethods.
  ///
  /// In tr, this message translates to:
  /// **'Ödeme Yöntemlerim'**
  String get myPaymentMethods;

  /// No description provided for @registeredCardCount.
  ///
  /// In tr, this message translates to:
  /// **'{count} kayıtlı kart'**
  String registeredCardCount(int count);

  /// No description provided for @emergencyContacts.
  ///
  /// In tr, this message translates to:
  /// **'Acil Durum Kişileri'**
  String get emergencyContacts;

  /// No description provided for @emergencyContactsSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'SOS mesajı gönderilecek kişiler'**
  String get emergencyContactsSubtitle;

  /// No description provided for @preferences.
  ///
  /// In tr, this message translates to:
  /// **'Tercihler'**
  String get preferences;

  /// No description provided for @notifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler'**
  String get notifications;

  /// No description provided for @darkMode.
  ///
  /// In tr, this message translates to:
  /// **'Karanlık Mod'**
  String get darkMode;

  /// No description provided for @themePreference.
  ///
  /// In tr, this message translates to:
  /// **'Tema tercihi'**
  String get themePreference;

  /// No description provided for @language.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get language;

  /// No description provided for @supportAndInfo.
  ///
  /// In tr, this message translates to:
  /// **'Destek ve Bilgi'**
  String get supportAndInfo;

  /// No description provided for @helpCenter.
  ///
  /// In tr, this message translates to:
  /// **'Yardım Merkezi'**
  String get helpCenter;

  /// No description provided for @helpCenterSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Sıkça sorulan sorular'**
  String get helpCenterSubtitle;

  /// No description provided for @liveSupport.
  ///
  /// In tr, this message translates to:
  /// **'Canlı Destek'**
  String get liveSupport;

  /// No description provided for @liveSupportSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'7/24 müşteri hizmetleri'**
  String get liveSupportSubtitle;

  /// No description provided for @reportBug.
  ///
  /// In tr, this message translates to:
  /// **'Hata Bildir'**
  String get reportBug;

  /// No description provided for @reportBugSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Sorunları bize iletin'**
  String get reportBugSubtitle;

  /// No description provided for @termsOfService.
  ///
  /// In tr, this message translates to:
  /// **'Kullanım Koşulları'**
  String get termsOfService;

  /// No description provided for @termsOfServiceSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hizmet şartları'**
  String get termsOfServiceSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik Politikası'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Veri koruma politikamız'**
  String get privacyPolicySubtitle;

  /// No description provided for @about.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get about;

  /// No description provided for @versionInfo.
  ///
  /// In tr, this message translates to:
  /// **'Versiyon {version}'**
  String versionInfo(String version);

  /// No description provided for @goldMember.
  ///
  /// In tr, this message translates to:
  /// **'Gold Üye'**
  String get goldMember;

  /// No description provided for @platinumMember.
  ///
  /// In tr, this message translates to:
  /// **'Platinum Üye'**
  String get platinumMember;

  /// No description provided for @premiumMember.
  ///
  /// In tr, this message translates to:
  /// **'Premium Üye'**
  String get premiumMember;

  /// No description provided for @standardMember.
  ///
  /// In tr, this message translates to:
  /// **'Standart Üye'**
  String get standardMember;

  /// No description provided for @unreadNotifications.
  ///
  /// In tr, this message translates to:
  /// **'okunmamış bildirim'**
  String get unreadNotifications;

  /// No description provided for @allNotificationsRead.
  ///
  /// In tr, this message translates to:
  /// **'Tüm bildirimler okundu'**
  String get allNotificationsRead;

  /// No description provided for @signOut.
  ///
  /// In tr, this message translates to:
  /// **'Çıkış Yap'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Hesabınızdan çıkış yapmak istediğinize emin misiniz?'**
  String get signOutConfirm;

  /// No description provided for @liveSupportDialogMessage.
  ///
  /// In tr, this message translates to:
  /// **'AI asistanımız size 7/24 yardımcı olabilir.'**
  String get liveSupportDialogMessage;

  /// No description provided for @getInstantAnswers.
  ///
  /// In tr, this message translates to:
  /// **'Anında yanıt alın'**
  String get getInstantAnswers;

  /// No description provided for @startChat.
  ///
  /// In tr, this message translates to:
  /// **'Sohbet Başlat'**
  String get startChat;

  /// No description provided for @reportBugDialogMessage.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştığınız sorunu detaylı bir şekilde açıklayın.'**
  String get reportBugDialogMessage;

  /// No description provided for @describeProblem.
  ///
  /// In tr, this message translates to:
  /// **'Sorunu açıklayın...'**
  String get describeProblem;

  /// No description provided for @pleaseDescribeProblem.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen sorunu açıklayın.'**
  String get pleaseDescribeProblem;

  /// No description provided for @bugReportSent.
  ///
  /// In tr, this message translates to:
  /// **'Hata raporu gönderildi. Teşekkür ederiz!'**
  String get bugReportSent;

  /// No description provided for @couldNotSend.
  ///
  /// In tr, this message translates to:
  /// **'Gönderilemedi:'**
  String get couldNotSend;

  /// No description provided for @allNeedsInOneApp.
  ///
  /// In tr, this message translates to:
  /// **'Tüm ihtiyaçlarınız için tek uygulama.\nYemek, market, kurye, taksi ve daha fazlası.'**
  String get allNeedsInOneApp;

  /// No description provided for @copyright.
  ///
  /// In tr, this message translates to:
  /// **'© 2025 SuperCyp. Tüm hakları saklıdır.'**
  String get copyright;

  /// No description provided for @terms.
  ///
  /// In tr, this message translates to:
  /// **'Koşullar'**
  String get terms;

  /// No description provided for @privacy.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik'**
  String get privacy;

  /// No description provided for @passwordAndSecurity.
  ///
  /// In tr, this message translates to:
  /// **'Şifre ve Güvenlik'**
  String get passwordAndSecurity;

  /// No description provided for @passwordAndSecuritySubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Şifre değiştir, 2FA ayarları'**
  String get passwordAndSecuritySubtitle;

  /// No description provided for @registeredDeliveryAddresses.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı teslimat adresleri'**
  String get registeredDeliveryAddresses;

  /// No description provided for @cardsAndPaymentOptions.
  ///
  /// In tr, this message translates to:
  /// **'Kartlar ve ödeme seçenekleri'**
  String get cardsAndPaymentOptions;

  /// No description provided for @pushNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Push Bildirimleri'**
  String get pushNotifications;

  /// No description provided for @getInstantNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Anlık bildirimler al'**
  String get getInstantNotifications;

  /// No description provided for @emailNotifications.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Bildirimleri'**
  String get emailNotifications;

  /// No description provided for @getEmailUpdates.
  ///
  /// In tr, this message translates to:
  /// **'Güncellemeleri e-posta ile al'**
  String get getEmailUpdates;

  /// No description provided for @smsNotifications.
  ///
  /// In tr, this message translates to:
  /// **'SMS Bildirimleri'**
  String get smsNotifications;

  /// No description provided for @getSmsAlerts.
  ///
  /// In tr, this message translates to:
  /// **'Önemli uyarıları SMS ile al'**
  String get getSmsAlerts;

  /// No description provided for @orderUpdates.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş Güncellemeleri'**
  String get orderUpdates;

  /// No description provided for @orderStatusChanges.
  ///
  /// In tr, this message translates to:
  /// **'Sipariş durumu değişiklikleri'**
  String get orderStatusChanges;

  /// No description provided for @campaigns.
  ///
  /// In tr, this message translates to:
  /// **'Kampanyalar'**
  String get campaigns;

  /// No description provided for @specialOffers.
  ///
  /// In tr, this message translates to:
  /// **'Özel fırsatlardan haberdar ol'**
  String get specialOffers;

  /// No description provided for @newFeatures.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Özellikler'**
  String get newFeatures;

  /// No description provided for @learnAboutUpdates.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama yeniliklerini öğren'**
  String get learnAboutUpdates;

  /// No description provided for @privacySection.
  ///
  /// In tr, this message translates to:
  /// **'Gizlilik'**
  String get privacySection;

  /// No description provided for @locationServices.
  ///
  /// In tr, this message translates to:
  /// **'Konum Servisleri'**
  String get locationServices;

  /// No description provided for @findNearbyBusinesses.
  ///
  /// In tr, this message translates to:
  /// **'Yakındaki işletmeleri bul'**
  String get findNearbyBusinesses;

  /// No description provided for @analyticsData.
  ///
  /// In tr, this message translates to:
  /// **'Analitik Veriler'**
  String get analyticsData;

  /// No description provided for @contributeToImprovements.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama iyileştirmelerine katkı'**
  String get contributeToImprovements;

  /// No description provided for @personalizedAds.
  ///
  /// In tr, this message translates to:
  /// **'Kişiselleştirilmiş Reklamlar'**
  String get personalizedAds;

  /// No description provided for @adsByInterest.
  ///
  /// In tr, this message translates to:
  /// **'İlgi alanlarına göre reklamlar'**
  String get adsByInterest;

  /// No description provided for @downloadData.
  ///
  /// In tr, this message translates to:
  /// **'Veri İndirme'**
  String get downloadData;

  /// No description provided for @getDataCopy.
  ///
  /// In tr, this message translates to:
  /// **'Verilerinin bir kopyasını al'**
  String get getDataCopy;

  /// No description provided for @deleteAccount.
  ///
  /// In tr, this message translates to:
  /// **'Hesabı Sil'**
  String get deleteAccount;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesabını kalıcı olarak kaldır'**
  String get deleteAccountSubtitle;

  /// No description provided for @appPreferences.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama Tercihleri'**
  String get appPreferences;

  /// No description provided for @biometricLogin.
  ///
  /// In tr, this message translates to:
  /// **'Biyometrik Giriş'**
  String get biometricLogin;

  /// No description provided for @biometricSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Parmak izi veya yüz tanıma'**
  String get biometricSubtitle;

  /// No description provided for @autoUpdate.
  ///
  /// In tr, this message translates to:
  /// **'Otomatik Güncelleme'**
  String get autoUpdate;

  /// No description provided for @autoUpdateSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Uygulamayı otomatik güncelle'**
  String get autoUpdateSubtitle;

  /// No description provided for @selectLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil Seçin'**
  String get selectLanguage;

  /// No description provided for @deliveryAddress.
  ///
  /// In tr, this message translates to:
  /// **'Teslimat Adresi'**
  String get deliveryAddress;

  /// No description provided for @addNewAddress.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Adres Ekle'**
  String get addNewAddress;

  /// No description provided for @markAllAsRead.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü Okundu İşaretle'**
  String get markAllAsRead;

  /// No description provided for @noNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim yok'**
  String get noNotifications;

  /// No description provided for @storeNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza Bildirimleri'**
  String get storeNotifications;

  /// No description provided for @generalNotifications.
  ///
  /// In tr, this message translates to:
  /// **'Genel Bildirimler'**
  String get generalNotifications;

  /// No description provided for @justNow.
  ///
  /// In tr, this message translates to:
  /// **'Az önce'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count} dakika önce'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count} saat önce'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In tr, this message translates to:
  /// **'{count} gün önce'**
  String daysAgo(int count);

  /// No description provided for @addedToFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilere eklendi'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In tr, this message translates to:
  /// **'Favorilerden çıkarıldı'**
  String get removedFromFavorites;

  /// No description provided for @searchMenu.
  ///
  /// In tr, this message translates to:
  /// **'Menüde ara...'**
  String get searchMenu;

  /// No description provided for @notSpecified.
  ///
  /// In tr, this message translates to:
  /// **'Belirtilmemiş'**
  String get notSpecified;

  /// No description provided for @restaurant.
  ///
  /// In tr, this message translates to:
  /// **'Restoran'**
  String get restaurant;

  /// No description provided for @free.
  ///
  /// In tr, this message translates to:
  /// **'Ücretsiz'**
  String get free;

  /// No description provided for @minimumOrder.
  ///
  /// In tr, this message translates to:
  /// **'Min. Sipariş'**
  String get minimumOrder;

  /// No description provided for @popular.
  ///
  /// In tr, this message translates to:
  /// **'Popüler'**
  String get popular;

  /// No description provided for @noComments.
  ///
  /// In tr, this message translates to:
  /// **'Yorum yok'**
  String get noComments;

  /// No description provided for @emailLogin.
  ///
  /// In tr, this message translates to:
  /// **'E-posta ile giriş yap'**
  String get emailLogin;

  /// No description provided for @phoneNumber.
  ///
  /// In tr, this message translates to:
  /// **'Telefon Numarası'**
  String get phoneNumber;

  /// No description provided for @verificationCode.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama Kodu'**
  String get verificationCode;

  /// No description provided for @email.
  ///
  /// In tr, this message translates to:
  /// **'E-posta'**
  String get email;

  /// No description provided for @password.
  ///
  /// In tr, this message translates to:
  /// **'Şifre'**
  String get password;

  /// No description provided for @storeNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Mağaza bulunamadı'**
  String get storeNotFound;

  /// No description provided for @productNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Ürün bulunamadı'**
  String get productNotFound;

  /// No description provided for @marketNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Market bulunamadı'**
  String get marketNotFound;

  /// No description provided for @vehicleNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Araç bulunamadı'**
  String get vehicleNotFound;

  /// No description provided for @listingNotFound.
  ///
  /// In tr, this message translates to:
  /// **'İlan bulunamadı'**
  String get listingNotFound;

  /// No description provided for @listingMayNotExist.
  ///
  /// In tr, this message translates to:
  /// **'Bu ilan artık mevcut olmayabilir.'**
  String get listingMayNotExist;

  /// No description provided for @pageNotFound.
  ///
  /// In tr, this message translates to:
  /// **'Sayfa bulunamadı'**
  String get pageNotFound;

  /// No description provided for @listingDetails.
  ///
  /// In tr, this message translates to:
  /// **'İlan Detayı'**
  String get listingDetails;

  /// No description provided for @marketDeals.
  ///
  /// In tr, this message translates to:
  /// **'Market Fırsatları'**
  String get marketDeals;

  /// No description provided for @markets.
  ///
  /// In tr, this message translates to:
  /// **'Marketler'**
  String get markets;

  /// No description provided for @recommended.
  ///
  /// In tr, this message translates to:
  /// **'Önerilen'**
  String get recommended;

  /// No description provided for @byRating.
  ///
  /// In tr, this message translates to:
  /// **'Puana Göre'**
  String get byRating;

  /// No description provided for @fastest.
  ///
  /// In tr, this message translates to:
  /// **'En Hızlı'**
  String get fastest;

  /// No description provided for @selectAddress.
  ///
  /// In tr, this message translates to:
  /// **'Adres seçin'**
  String get selectAddress;

  /// No description provided for @noMarketsInArea.
  ///
  /// In tr, this message translates to:
  /// **'Bölgenizde Market Yok'**
  String get noMarketsInArea;

  /// No description provided for @noMarketsDelivery.
  ///
  /// In tr, this message translates to:
  /// **'Seçili adresinize teslimat yapan market bulunmuyor'**
  String get noMarketsDelivery;

  /// No description provided for @changeAddress.
  ///
  /// In tr, this message translates to:
  /// **'Adres Değiştir'**
  String get changeAddress;

  /// No description provided for @marketsInYourArea.
  ///
  /// In tr, this message translates to:
  /// **'Bölgenize teslimat yapan marketler'**
  String get marketsInYourArea;

  /// No description provided for @sorting.
  ///
  /// In tr, this message translates to:
  /// **'Sıralama'**
  String get sorting;

  /// No description provided for @awaitingEmailVerification.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Doğrulama Bekleniyor'**
  String get awaitingEmailVerification;

  /// No description provided for @pending.
  ///
  /// In tr, this message translates to:
  /// **'Beklemede'**
  String get pending;

  /// No description provided for @addEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Ekle'**
  String get addEmail;

  /// No description provided for @addEmailSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'E-posta ekleyerek şifre ile de giriş yapabilirsiniz'**
  String get addEmailSubtitle;

  /// No description provided for @changePassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre Değiştir'**
  String get changePassword;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Hesap şifrenizi güncelleyin'**
  String get changePasswordSubtitle;

  /// No description provided for @setPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre Belirle'**
  String get setPassword;

  /// No description provided for @setPasswordSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'E-posta ile de giriş yapabilmek için şifre belirleyin'**
  String get setPasswordSubtitle;

  /// No description provided for @addEmailFirst.
  ///
  /// In tr, this message translates to:
  /// **'Önce e-posta ekleyin, ardından şifre belirleyebilirsiniz'**
  String get addEmailFirst;

  /// No description provided for @biometricLoginSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Parmak izi veya yüz tanıma ile giriş'**
  String get biometricLoginSubtitle;

  /// No description provided for @changeEmail.
  ///
  /// In tr, this message translates to:
  /// **'E-posta Değiştir'**
  String get changeEmail;

  /// No description provided for @emailVerificationMessage.
  ///
  /// In tr, this message translates to:
  /// **'Girdiğiniz adrese doğrulama linki gönderilecektir. Onayladıktan sonra e-posta ile giriş yapabilirsiniz.'**
  String get emailVerificationMessage;

  /// No description provided for @emailAddress.
  ///
  /// In tr, this message translates to:
  /// **'E-posta adresi'**
  String get emailAddress;

  /// No description provided for @sendVerificationLink.
  ///
  /// In tr, this message translates to:
  /// **'Doğrulama Linki Gönder'**
  String get sendVerificationLink;

  /// No description provided for @currentPassword.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut Şifre'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Şifre'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Şifre (Tekrar)'**
  String get confirmNewPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In tr, this message translates to:
  /// **'Şifreniz en az 8 karakter olmalıdır.'**
  String get passwordMinLength;

  /// No description provided for @changePasswordButton.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi Değiştir'**
  String get changePasswordButton;

  /// No description provided for @setPasswordMessage.
  ///
  /// In tr, this message translates to:
  /// **'Şifre belirleyerek e-posta adresinizle de giriş yapabilirsiniz.'**
  String get setPasswordMessage;

  /// No description provided for @confirmPassword.
  ///
  /// In tr, this message translates to:
  /// **'Şifre (Tekrar)'**
  String get confirmPassword;

  /// No description provided for @setPasswordButton.
  ///
  /// In tr, this message translates to:
  /// **'Şifreyi Belirle'**
  String get setPasswordButton;

  /// No description provided for @passwordMinError.
  ///
  /// In tr, this message translates to:
  /// **'Şifre en az 8 karakter olmalıdır'**
  String get passwordMinError;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In tr, this message translates to:
  /// **'Şifreler eşleşmiyor'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordChanged.
  ///
  /// In tr, this message translates to:
  /// **'Şifreniz başarıyla değiştirildi'**
  String get passwordChanged;

  /// No description provided for @passwordSet.
  ///
  /// In tr, this message translates to:
  /// **'Şifreniz başarıyla belirlendi! Artık e-posta ile de giriş yapabilirsiniz.'**
  String get passwordSet;

  /// No description provided for @enterValidEmail.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir e-posta adresi girin'**
  String get enterValidEmail;

  /// No description provided for @verificationLinkSent.
  ///
  /// In tr, this message translates to:
  /// **'{email} adresine doğrulama linki gönderildi. Onayladıktan sonra şifre belirleyebilirsiniz.'**
  String verificationLinkSent(String email);

  /// No description provided for @deviceNotSupportBiometric.
  ///
  /// In tr, this message translates to:
  /// **'Bu cihaz biyometrik kimlik doğrulamayı desteklemiyor.'**
  String get deviceNotSupportBiometric;

  /// No description provided for @authenticateToEnableBiometric.
  ///
  /// In tr, this message translates to:
  /// **'Biyometrik girişi etkinleştirmek için doğrulama yapın'**
  String get authenticateToEnableBiometric;

  /// No description provided for @biometricAuthFailed.
  ///
  /// In tr, this message translates to:
  /// **'Biyometrik doğrulama başarısız:'**
  String get biometricAuthFailed;

  /// No description provided for @verifyEmailFirst.
  ///
  /// In tr, this message translates to:
  /// **'Şifre belirlemek için önce e-posta adresinizi doğrulayın'**
  String get verifyEmailFirst;

  /// No description provided for @comingSoon.
  ///
  /// In tr, this message translates to:
  /// **'Yakında'**
  String get comingSoon;

  /// No description provided for @serviceComingSoon.
  ///
  /// In tr, this message translates to:
  /// **'Hizmet Servisi - Yakında'**
  String get serviceComingSoon;

  /// No description provided for @appointmentComingSoon.
  ///
  /// In tr, this message translates to:
  /// **'Randevu Servisi - Yakında'**
  String get appointmentComingSoon;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'tr':
      return STr();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
