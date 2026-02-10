/// Generic TTL-based in-memory cache utility.
///
/// Usage:
/// ```dart
/// final cache = CacheManager();
/// final result = await cache.getOrFetch<List<Restaurant>>(
///   'restaurants',
///   ttl: Duration(minutes: 5),
///   fetcher: () => _fetchRestaurants(),
/// );
/// cache.invalidate('restaurants'); // Manual invalidation
/// cache.invalidatePrefix('store_'); // Bulk invalidation
/// ```
class CachedValue<T> {
  final T value;
  final DateTime cachedAt;
  final Duration ttl;

  CachedValue({
    required this.value,
    required this.ttl,
  }) : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, CachedValue<dynamic>> _cache = {};

  /// Get cached value or fetch from source.
  Future<T> getOrFetch<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() fetcher,
  }) async {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired && cached.value is T) {
      return cached.value as T;
    }
    final value = await fetcher();
    _cache[key] = CachedValue<T>(value: value, ttl: ttl);
    return value;
  }

  /// Get cached value synchronously (returns null if not cached or expired).
  T? get<T>(String key) {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired && cached.value is T) {
      return cached.value as T;
    }
    return null;
  }

  /// Set a value in cache.
  void set<T>(String key, T value, {required Duration ttl}) {
    _cache[key] = CachedValue<T>(value: value, ttl: ttl);
  }

  /// Invalidate a specific cache key.
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all keys starting with a prefix.
  void invalidatePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Invalidate all cached data.
  void invalidateAll() {
    _cache.clear();
  }

  /// Check if a key exists and is not expired.
  bool has(String key) {
    final cached = _cache[key];
    return cached != null && !cached.isExpired;
  }
}
