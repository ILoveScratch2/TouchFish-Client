import 'package:flutter/foundation.dart';

enum IpOverrideMode { off, mixed, complete }

class IpOverrideEntry {
  final String ip;
  final int? port;

  const IpOverrideEntry({required this.ip, this.port});
}

class IpOverrideService extends ChangeNotifier {
  static final IpOverrideService instance = IpOverrideService._();
  IpOverrideService._();

  IpOverrideMode get mode => IpOverrideMode.off;
  List<String> get domains => const [];
  List<IpOverrideEntry> get entries => const [];
  bool shouldOverride(Uri uri) => false;
  Future<void> setMode(IpOverrideMode value) async {}
  Future<void> setDomains(List<String> values) async {}
  Future<void> setEntries(List<IpOverrideEntry> values) async {}
  Future<void> refreshGlobal() async {}
  Future<void> ensureDefaultDomain() async {}
}
