// 前置前缀
import '../utils/format.dart' as fmt;

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  Future<int> getFlutterCacheSize() async => 0;

  Future<void> clearFlutterCache() async {}

  static String formatBytes(int bytes) =>
      fmt.formatBytes(bytes, binary: true);
}
