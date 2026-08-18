import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_service.dart';
import '../widgets/server_selector.dart';
import 'api/tf_api_client.dart';
import 'media_proxy_service.dart';

enum IpOverrideMode { off, mixed, complete }

class IpOverrideEntry {
  final String ip;
  final int? port;

  const IpOverrideEntry({required this.ip, this.port});

  Map<String, dynamic> toJson() => {'ip': ip, if (port != null) 'port': port};

  factory IpOverrideEntry.fromJson(Map<String, dynamic> json) => IpOverrideEntry(
        ip: json['ip']?.toString() ?? '',
        port: json['port'] is num ? (json['port'] as num).toInt() : null,
      );
}

class IpOverrideService extends ChangeNotifier {
  static final IpOverrideService instance = IpOverrideService._();
  IpOverrideService._();

  static const modeKey = 'ipOverrideMode';
  static const domainsKey = 'ipOverrideDomains';
  static const entriesKey = 'ipOverrideEntries';

  IpOverrideMode get mode {
    final raw = SettingsService.instance.getValue<String>(modeKey, 'off');
    return IpOverrideMode.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => IpOverrideMode.off,
    );
  }

  List<String> get domains {
    final raw = SettingsService.instance.getJsonValue(domainsKey);
    final values = raw?['domains'];
    if (values is List) {
      return values.map((value) => value.toString().trim()).where((v) => v.isNotEmpty).toList();
    }
    return const [];
  }

  List<IpOverrideEntry> get entries {
    final raw = SettingsService.instance.getJsonValue(entriesKey);
    final values = raw?['entries'];
    if (values is List) {
      return values
          .whereType<Map>()
          .map((value) => IpOverrideEntry.fromJson(Map<String, dynamic>.from(value)))
          .where((value) => value.ip.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<void> setMode(IpOverrideMode value) async {
    await SettingsService.instance.setValue(modeKey, value.name);
    await refreshGlobal();
  }

  Future<void> setDomains(List<String> values) async {
    await SettingsService.instance.setJsonValue(domainsKey, {'domains': values});
    await refreshGlobal();
  }

  Future<void> setEntries(List<IpOverrideEntry> values) async {
    await SettingsService.instance.setJsonValue(
      entriesKey,
      {'entries': values.map((entry) => entry.toJson()).toList()},
    );
    await refreshGlobal();
  }

  Future<void> refreshGlobal() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
      HttpOverrides.global = buildOverrides();
    }
    TfApiClient.instance.rebuildHttpClient();
    MediaProxyService.instance.rebuildHttpClient();
    notifyListeners();
  }

  HttpOverrides? buildOverrides() {
    final override = entries.isEmpty ? null : entries.first;
    if (mode == IpOverrideMode.off || override == null) return null;
    final configuredDomains = domains;
    return _TouchFishHttpOverrides(
      mode: mode,
      domains: configuredDomains,
      entry: override,
    );
  }

  bool shouldOverride(Uri uri) {
    if (mode == IpOverrideMode.complete) return true;
    if (mode != IpOverrideMode.mixed) return false;
    return domains.any((domain) => matchesDomain(uri.host, domain));
  }

  static bool matchesDomain(String host, String domain) {
    final normalizedHost = host.toLowerCase().trim();
    final normalizedDomain = domain.toLowerCase().trim().replaceFirst(RegExp(r'^\.'), '');
    return normalizedDomain.isNotEmpty &&
        (normalizedHost == normalizedDomain || normalizedHost.endsWith('.$normalizedDomain'));
  }

  Future<void> ensureDefaultDomain() async {
    if (domains.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('serversV2');
    if (raw == null || raw.isEmpty) return;
    try {
      final selected = (prefs.getInt('selectedServerIndex') ?? 0).clamp(0, raw.length - 1);
      final server = ServerInfo.fromJson(jsonDecode(raw[selected]) as Map<String, dynamic>);
      final host = Uri.tryParse('${server.useHttps ? 'https' : 'http'}://${server.address}')?.host;
      if (host != null && host.isNotEmpty) await setDomains([host]);
    } catch (_) {}
  }
}

class _TouchFishHttpOverrides extends HttpOverrides {
  final IpOverrideMode mode;
  final List<String> domains;
  final IpOverrideEntry entry;

  _TouchFishHttpOverrides({required this.mode, required this.domains, required this.entry});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final useOverride = mode == IpOverrideMode.complete ||
          domains.any((domain) => IpOverrideService.matchesDomain(uri.host, domain));
      final targetHost = useOverride ? entry.ip : uri.host;
      final targetPort = useOverride
          ? (entry.port ?? (uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80)))
          : (uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80));
      final socket = Socket.connect(targetHost, targetPort).then<Socket>((raw) {
        if (uri.scheme == 'https') {
          return SecureSocket.secure(raw, host: uri.host);
        }
        return raw;
      });
      return ConnectionTask.fromSocket(socket, () {});
    };
    return client;
  }
}
