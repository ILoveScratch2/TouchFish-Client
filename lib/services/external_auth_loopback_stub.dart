class ExternalAuthLoopback {
  ExternalAuthLoopback._();

  String get redirectUri => '';

  static Future<ExternalAuthLoopback?> start() async => null;

  Future<String?> waitForTicket(
    String state, {
    Duration timeout = const Duration(minutes: 5),
  }) async => null;

  Future<void> close() async {}
}
