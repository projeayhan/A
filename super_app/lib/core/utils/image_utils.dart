/// Supabase Storage görsel URL'lerini transform eder
/// width ve height parametreleri ile boyutlandırma yapılır
class ImageUtils {
  /// Supabase Storage URL'ini transform edilmiş versiyona çevirir
  /// Örnek: https://xxx.supabase.co/storage/v1/object/public/images/products/xxx.jpeg
  /// Dönüşür: https://xxx.supabase.co/storage/v1/render/image/public/images/products/xxx.jpeg?width=400&height=400&resize=contain
  static String getResizedImageUrl(
    String imageUrl, {
    int? width,
    int? height,
    String resize = 'contain', // contain, cover, fill
    int quality = 80,
  }) {
    // Boş URL kontrolü
    if (imageUrl.isEmpty) return imageUrl;

    // Sadece Supabase Storage URL'lerini dönüştür
    if (!imageUrl.contains('supabase.co/storage/v1/object/public/')) {
      return imageUrl;
    }

    // URL'i transform endpoint'ine çevir
    final transformedUrl = imageUrl.replaceFirst(
      '/storage/v1/object/public/',
      '/storage/v1/render/image/public/',
    );

    // Query parametreleri ekle
    final params = <String>[];
    if (width != null) params.add('width=$width');
    if (height != null) params.add('height=$height');
    params.add('resize=$resize');
    params.add('quality=$quality');

    return '$transformedUrl?${params.join('&')}';
  }

  /// Ürün kartları için optimize edilmiş görsel (küçük)
  static String getProductThumbnail(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 300, height: 300);
  }

  /// Ürün detay sayfası için optimize edilmiş görsel (orta)
  static String getProductDetail(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 800, height: 800);
  }

  /// Tam ekran görüntüleme için (büyük)
  static String getProductFullSize(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 1200, height: 1200, quality: 90);
  }
}
