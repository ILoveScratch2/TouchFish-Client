class MediaProxyService {
  static final MediaProxyService instance = MediaProxyService._();
  MediaProxyService._();

  bool get isSupported => false;
  bool get isRunning => false;

  Future<String> resolveUrl(String remoteUrl) async => remoteUrl;
  Future<void> stop() async {}
  Future<void> clearCache() async {}
  Future<int> cacheSize() async => 0;
  void rebuildHttpClient() {}
}
