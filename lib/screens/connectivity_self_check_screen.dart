import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api/tf_api_client.dart';
import '../services/ip_override_service.dart';

class ConnectivitySelfCheckScreen extends StatefulWidget {
  const ConnectivitySelfCheckScreen({super.key});

  @override
  State<ConnectivitySelfCheckScreen> createState() => _ConnectivitySelfCheckScreenState();
}

class _ConnectivitySelfCheckScreenState extends State<ConnectivitySelfCheckScreen> {
  bool _running = false;
  List<_CheckResult> _results = const [];

  Future<void> _run() async {
    if (kIsWeb) return;
    setState(() => _running = true);
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final uri = Uri.parse(baseUrl);
    final targets = <String>{uri.host, ...IpOverrideService.instance.entries.map((e) => e.ip)};
    final results = <_CheckResult>[];
    for (final target in targets) {
      final watch = Stopwatch()..start();
      try {
        final socket = await Socket.connect(target, uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80), timeout: const Duration(seconds: 5));
        await socket.close();
        results.add(_CheckResult(target, true, watch.elapsed));
      } catch (_) {
        results.add(_CheckResult(target, false, watch.elapsed));
      }
    }
    if (mounted) setState(() { _results = results; _running = false; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsConnectivitySelfCheckTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _running ? null : _run,
                icon: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.network_check),
                label: Text(l10n.settingsConnectivitySelfCheckTitle),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text(l10n.settingsConnectivitySelfCheckDesc))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return ListTile(
                        leading: Icon(result.ok ? Icons.check_circle : Icons.error, color: result.ok ? Colors.green : Theme.of(context).colorScheme.error),
                        title: Text(result.target),
                        subtitle: Text(result.ok ? '${result.elapsed.inMilliseconds} ms' : l10n.settingsConnectivityFailed),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CheckResult {
  final String target;
  final bool ok;
  final Duration elapsed;
  const _CheckResult(this.target, this.ok, this.elapsed);
}
