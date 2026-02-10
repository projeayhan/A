/// Supabase Storage görsel URL'lerini transform eder
/// width ve height parametreleri ile boyutlandırma yapılır
class ImageUtils {
  /// Supabase Storage URL'ini transform edilmiş versiyona çevirir
  static String getResizedImageUrl(
    String imageUrl, {
    int? width,
    int? height,
    String resize = 'cover',
    int quality = 75,
  }) {
    if (imageUrl.isEmpty) return imageUrl;

    // Unsplash URL'lerini direkt optimize et
    if (imageUrl.contains('images.unsplash.com')) {
      final uri = Uri.parse(imageUrl);
      final params = Map<String, String>.from(uri.queryParameters);
      if (width != null) params['w'] = width.toString();
      params['q'] = quality.toString();
      params['auto'] = 'format';
      return uri.replace(queryParameters: params).toString();
    }

    // Sadece Supabase Storage URL'lerini dönüştür
    if (!imageUrl.contains('supabase.co/storage/v1/object/public/')) {
      return imageUrl;
    }

    final transformedUrl = imageUrl.replaceFirst(
      '/storage/v1/object/public/',
      '/storage/v1/render/image/public/',
    );

    final params = <String>[];
    if (width != null) params.add('width=$width');
    if (height != null) params.add('height=$height');
    params.add('resize=$resize');
    params.add('quality=$quality');

    return '$transformedUrl?${params.join('&')}';
  }

  /// Ürün kartları için optimize edilmiş görsel (küçük)
  static String getProductThumbnail(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 200, height: 200, quality: 70);
  }

  /// Ürün detay sayfası için optimize edilmiş görsel (orta)
  static String getProductDetail(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 600, height: 600);
  }

  /// Restoran hero/cover görseli
  static String getHeroImage(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 800, height: 400, quality: 75);
  }

  /// Tam ekran görüntüleme için (büyük)
  static String getProductFullSize(String imageUrl) {
    return getResizedImageUrl(imageUrl, width: 1200, height: 1200, quality: 90);
  }
}
