/// Kullanıcı isimlerini anonim hale getirmek için maskeleme fonksiyonu.
/// İsimden rastgele (ama deterministik) bir harf seçer ve "..." ekler.
/// Baş harf kullanılmaz.
String maskUserName(String? name) {
  if (name == null || name.trim().isEmpty) return 'Anonim';
  final cleaned = name.trim().replaceAll(RegExp(r'\s+'), '');
  if (cleaned.length <= 1) return '...';
  // Deterministik: aynı isim her zaman aynı harfi verir
  final hash = cleaned.hashCode.abs();
  final index = 1 + (hash % (cleaned.length - 1));
  return '${cleaned[index].toLowerCase()}...';
}
