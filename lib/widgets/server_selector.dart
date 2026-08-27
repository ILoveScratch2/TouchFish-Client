import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../constants/app_constants.dart';
import '../services/api/tf_api_client.dart';
import '../services/api/tf_crypto.dart';
import '../services/auth_state.dart';
import '../services/chat_ws_service.dart';
import '../services/domain_trust_service.dart';
import '../services/rsa_key_trust_service.dart';
import '../services/server_branding_service.dart';
import 'code_block.dart';

class ServerInfo {
  final String displayName;
  final String address;
  final String apiPort;
  final String tcpPort;
  final bool useHttps;
  final bool tryWss;
  final bool autoDetectTcpPort;

  ServerInfo({
    required this.displayName,
    required this.address,
    required this.apiPort,
    required this.tcpPort,
    this.useHttps = false,
    this.tryWss = AppConstants.defaultTryWss,
    this.autoDetectTcpPort = AppConstants.defaultAutoDetectTcpPort,
  });

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'address': address,
    'apiPort': apiPort,
    'tcpPort': tcpPort,
    'useHttps': useHttps,
    'tryWss': tryWss,
    'autoDetectTcpPort': autoDetectTcpPort,
  };

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
    displayName: json['displayName'] ?? '',
    address: json['address'] ?? '',
    apiPort: json['apiPort'] ?? '',
    tcpPort: json['tcpPort'] ?? '',
    useHttps: json['useHttps'] as bool? ?? false,
    tryWss: json['tryWss'] as bool? ?? AppConstants.defaultTryWss,
    autoDetectTcpPort:
        json['autoDetectTcpPort'] as bool? ??
        AppConstants.defaultAutoDetectTcpPort,
  );

  ServerInfo copyWith({
    String? displayName,
    String? address,
    String? apiPort,
    String? tcpPort,
    bool? useHttps,
    bool? tryWss,
    bool? autoDetectTcpPort,
  }) => ServerInfo(
    displayName: displayName ?? this.displayName,
    address: address ?? this.address,
    apiPort: apiPort ?? this.apiPort,
    tcpPort: tcpPort ?? this.tcpPort,
    useHttps: useHttps ?? this.useHttps,
    tryWss: tryWss ?? this.tryWss,
    autoDetectTcpPort: autoDetectTcpPort ?? this.autoDetectTcpPort,
  );
}

class ServerSelector extends StatefulWidget {
  const ServerSelector({super.key});

  @override
  State<ServerSelector> createState() => _ServerSelectorState();
}

enum _ServerProbeStatus { loading, connected, failed }

class _ServerSelectorState extends State<ServerSelector> {
  List<ServerInfo> _servers = [
    ServerInfo(
      displayName: AppConstants.defaultServerDisplayName,
      address: AppConstants.defaultServerAddress,
      apiPort: AppConstants.defaultApiPort.toString(),
      tcpPort: AppConstants.defaultTcpPort.toString(),
      useHttps: AppConstants.defaultUseHttps,
    ),
  ];
  int _selectedIndex = 0;
  bool _isLoading = true;
  _ServerProbeStatus _probeStatus = _ServerProbeStatus.loading;
  int _probeToken = 0;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getStringList('serversV2');

    if (serversJson != null && serversJson.isNotEmpty) {
      final servers = serversJson
          .map((json) => ServerInfo.fromJson(jsonDecode(json)))
          .toList();
      final selectedIndex = prefs.getInt('selectedServerIndex') ?? 0;

      setState(() {
        _servers = servers;
        _selectedIndex = selectedIndex.clamp(0, servers.length - 1);
        _isLoading = false;
      });
    } else {
      final oldServers = prefs.getStringList('servers');
      if (oldServers != null && oldServers.isNotEmpty) {
        final migratedServers = oldServers
            .map(
              (url) => ServerInfo(
                displayName: _extractDisplayName(url),
                address: url,
                apiPort: '',
                tcpPort: '',
              ),
            )
            .toList();
        setState(() {
          _servers = migratedServers;
          _isLoading = false;
        });
        await _saveServers();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
    _probeSelectedServer();
  }

  Future<void> _probeSelectedServer() async {
    final token = ++_probeToken;
    if (mounted) {
      setState(() => _probeStatus = _ServerProbeStatus.loading);
    }
    final target = (_selectedIndex >= 0 && _selectedIndex < _servers.length)
        ? _servers[_selectedIndex]
        : null;
    final reachable = await TfApiClient.instance.probeServer(target);
    if (!mounted || token != _probeToken) return;
    setState(() {
      _probeStatus = reachable
          ? _ServerProbeStatus.connected
          : _ServerProbeStatus.failed;
    });
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = _servers
        .map((server) => jsonEncode(server.toJson()))
        .toList();
    await prefs.setStringList('serversV2', serversJson);
    await prefs.setInt('selectedServerIndex', _selectedIndex);
  }

  String _extractDisplayName(String url) {
    var display = url.replaceFirst(RegExp(r'^https?://'), '');
    display = display.replaceFirst(RegExp(r'/$'), '');
    return display;
  }

  void _showServerDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ServerBottomSheet(
        servers: _servers,
        selectedIndex: _selectedIndex,
        onSelect: (index) async {
          if (AuthState.instance.isLoggedIn) {
            await ChatWsService.instance.disconnect();
            await AuthState.instance.logout();
          }
          setState(() => _selectedIndex = index);
          await _saveServers();
          TfApiClient.instance.invalidateCache();
          DomainTrustService.instance.refreshServerHost();
          unawaited(ServerBrandingService.instance.refresh());
          _probeSelectedServer();
          if (context.mounted) Navigator.pop(context);
        },
        onAdd: (server) async {
          if (AuthState.instance.isLoggedIn) {
            await ChatWsService.instance.disconnect();
            await AuthState.instance.logout();
          }
          setState(() {
            _servers.add(server);
            _selectedIndex = _servers.length - 1;
          });
          await _saveServers();
          TfApiClient.instance.invalidateCache();
          DomainTrustService.instance.refreshServerHost();
          unawaited(ServerBrandingService.instance.refresh());
          _probeSelectedServer();
        },
        onEdit: (index, server) async {
          if (index == _selectedIndex && AuthState.instance.isLoggedIn) {
            await ChatWsService.instance.disconnect();
            await AuthState.instance.logout();
          }
          setState(() => _servers[index] = server);
          await _saveServers();
          if (index == _selectedIndex) {
            TfApiClient.instance.invalidateCache();
            DomainTrustService.instance.refreshServerHost();
            unawaited(ServerBrandingService.instance.refresh());
            _probeSelectedServer();
          }
        },
        onDelete: (index) async {
          if (_servers.length > 1) {
            setState(() {
              _servers.removeAt(index);
              if (_selectedIndex >= _servers.length) {
                _selectedIndex = _servers.length - 1;
              }
            });
            await _saveServers();
            TfApiClient.instance.invalidateCache();
            DomainTrustService.instance.refreshServerHost();
            unawaited(ServerBrandingService.instance.refresh());
            _probeSelectedServer();
          }
        },
      ),
    );
  }

  Widget _buildStatusIndicator(ColorScheme colorScheme) {
    switch (_probeStatus) {
      case _ServerProbeStatus.loading:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
      case _ServerProbeStatus.connected:
        return Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: colorScheme.primary,
        );
      case _ServerProbeStatus.failed:
        return Icon(Icons.cancel_rounded, size: 18, color: colorScheme.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const SizedBox(height: 40);
    }

    final displayName = _servers[_selectedIndex].displayName;

    return InkWell(
      onTap: _showServerDialog,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            _buildStatusIndicator(colorScheme),
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerBottomSheet extends StatefulWidget {
  final List<ServerInfo> servers;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<ServerInfo> onAdd;
  final void Function(int index, ServerInfo server) onEdit;
  final ValueChanged<int> onDelete;

  const _ServerBottomSheet({
    required this.servers,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ServerBottomSheet> createState() => _ServerBottomSheetState();
}

class _ServerBottomSheetState extends State<_ServerBottomSheet> {
  late List<ServerInfo> _servers;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _servers = List.from(widget.servers);
    _selectedIndex = widget.selectedIndex;
  }

  /// 服务器用于 RSA 密钥寻址的 authority（与解析后的 baseUrl 保持一致）。
  String _serverAuthority(ServerInfo server) {
    final port = server.apiPort.trim().isEmpty
        ? AppConstants.defaultApiPort.toString()
        : server.apiPort.trim();
    final uri = Uri.tryParse('http://${server.address.trim()}:$port');
    if (uri != null && uri.hasAuthority) return uri.authority;
    return '${server.address.trim()}:$port';
  }

  void _showAddDialog() {
    final displayNameController = TextEditingController();
    final addressController = TextEditingController();
    final apiPortController = TextEditingController();
    final tcpPortController = TextEditingController();
    final rsaPemController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    bool useHttps = false;
    bool tryWss = AppConstants.defaultTryWss;
    bool autoDetectTcpPort = AppConstants.defaultAutoDetectTcpPort;
    bool rsaPemValid = true;
    String? apiPortError;
    String? tcpPortError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool validatePort(String port) {
            if (port.isEmpty) return true;
            final portNum = int.tryParse(port);
            return portNum != null && portNum >= 0 && portNum <= 65535;
          }

          bool checkDuplicatePorts(String apiPort, String tcpPort) {
            if (apiPort.isEmpty || tcpPort.isEmpty) return false;
            return apiPort == tcpPort;
          }

          void validate() {
            setDialogState(() {
              final apiPort = apiPortController.text.trim();
              final tcpPort = tcpPortController.text.trim();

              if (!validatePort(apiPort)) {
                apiPortError = l10n.serverErrorInvalidPort;
              } else if (!autoDetectTcpPort &&
                  checkDuplicatePorts(apiPort, tcpPort)) {
                apiPortError = l10n.serverErrorDuplicatePort;
              } else {
                apiPortError = null;
              }
              if (autoDetectTcpPort) {
                tcpPortError = null;
              } else if (!validatePort(tcpPort)) {
                tcpPortError = l10n.serverErrorInvalidPort;
              } else if (checkDuplicatePorts(apiPort, tcpPort)) {
                tcpPortError = l10n.serverErrorDuplicatePort;
              } else {
                tcpPortError = null;
              }
            });
          }

          return AlertDialog(
            title: Text(l10n.serverAdd),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: displayNameController,
                      decoration: InputDecoration(
                        labelText: l10n.serverDisplayName,
                        hintText: l10n.serverDisplayNameHint,
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: l10n.serverAddress,
                        hintText: l10n.serverAddressHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: apiPortController,
                      decoration: InputDecoration(
                        labelText: l10n.serverApiPort,
                        hintText: l10n.serverApiPortHint,
                        border: const OutlineInputBorder(),
                        errorText: apiPortError,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => validate(),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: tcpPortController,
                      enabled: !autoDetectTcpPort,
                      decoration: InputDecoration(
                        labelText: l10n.serverTcpPort,
                        hintText: l10n.serverTcpPortHint,
                        border: const OutlineInputBorder(),
                        errorText: tcpPortError,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => validate(),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(l10n.serverAutoDetectTcpPort),
                    subtitle: Text(l10n.serverAutoDetectTcpPortDesc),
                    value: autoDetectTcpPort,
                    onChanged: (value) {
                      setDialogState(() {
                        autoDetectTcpPort = value;
                        validate();
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(l10n.serverUseHttps),
                    subtitle: Text(
                      useHttps ? l10n.serverUseHttpsOn : l10n.serverUseHttpsOff,
                    ),
                    value: useHttps,
                    onChanged: (value) {
                      setDialogState(() => useHttps = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(l10n.serverTryWss),
                    subtitle: Text(
                      tryWss ? l10n.serverTryWssOn : l10n.serverTryWssOff,
                    ),
                    value: tryWss,
                    onChanged: (value) {
                      setDialogState(() => tryWss = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  _RsaPemField(
                    controller: rsaPemController,
                    onValidityChanged: (valid) => rsaPemValid = valid,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.serverCancel),
              ),
              FilledButton(
                onPressed: () async {
                  final displayName = displayNameController.text.trim();
                  final address = addressController.text.trim();
                  final apiPort = apiPortController.text.trim();
                  final tcpPort = autoDetectTcpPort
                      ? ''
                      : tcpPortController.text.trim();
                  final rsaPem = rsaPemController.text.trim();
                  if (!validatePort(apiPort)) {
                    setDialogState(
                      () => apiPortError = l10n.serverErrorInvalidPort,
                    );
                    return;
                  }
                  if (!autoDetectTcpPort && !validatePort(tcpPort)) {
                    setDialogState(
                      () => tcpPortError = l10n.serverErrorInvalidPort,
                    );
                    return;
                  }
                  if (!autoDetectTcpPort &&
                      checkDuplicatePorts(apiPort, tcpPort)) {
                    setDialogState(() {
                      apiPortError = l10n.serverErrorDuplicatePort;
                      tcpPortError = l10n.serverErrorDuplicatePort;
                    });
                    return;
                  }
                  if (rsaPem.isNotEmpty && !rsaPemValid) {
                    return;
                  }

                  if (displayName.isNotEmpty || address.isNotEmpty) {
                    Navigator.pop(context);
                    final server = ServerInfo(
                      displayName: displayName.isEmpty ? address : displayName,
                      address: address,
                      apiPort: apiPort,
                      tcpPort: tcpPort,
                      useHttps: useHttps,
                      tryWss: tryWss,
                      autoDetectTcpPort: autoDetectTcpPort,
                    );
                    if (rsaPem.isNotEmpty && address.isNotEmpty) {
                      await RsaKeyTrustService.instance.saveKey(
                        rsaPem,
                        _serverAuthority(server),
                      );
                    }
                    setState(() {
                      _servers.add(server);
                      _selectedIndex = _servers.length - 1;
                    });
                    widget.onAdd(server);
                  }
                },
                child: Text(l10n.serverAddServer),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(int index) {
    final server = _servers[index];
    final displayNameController = TextEditingController(
      text: server.displayName,
    );
    final rsaPemController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final authority = _serverAuthority(server);

    bool useHttps = server.useHttps;
    bool tryWss = server.tryWss;
    bool autoDetectTcpPort = server.autoDetectTcpPort;
    bool rsaPemValid = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> loadSavedPem() async {
            final saved = await RsaKeyTrustService.instance.savedKeyFor(
              authority,
            );
            if (saved != null && saved.trim().isNotEmpty) {
              final normalized = TfCrypto.normalizePem(saved);
              if (context.mounted && rsaPemController.text.trim().isEmpty) {
                setDialogState(() => rsaPemController.text = normalized);
              }
            }
          }

          unawaited(loadSavedPem());

          return AlertDialog(
            title: Text(l10n.serverEdit),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: displayNameController,
                      decoration: InputDecoration(
                        labelText: l10n.serverDisplayName,
                        hintText: l10n.serverDisplayNameHint,
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: TextEditingController(text: server.address),
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: l10n.serverAddress,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: TextEditingController(text: server.apiPort),
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: l10n.serverApiPort,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: TextField(
                      controller: TextEditingController(text: server.tcpPort),
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: l10n.serverTcpPort,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: Text(l10n.serverAutoDetectTcpPort),
                    subtitle: Text(l10n.serverAutoDetectTcpPortDesc),
                    value: autoDetectTcpPort,
                    onChanged: (value) {
                      setDialogState(() => autoDetectTcpPort = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(l10n.serverUseHttps),
                    subtitle: Text(
                      useHttps ? l10n.serverUseHttpsOn : l10n.serverUseHttpsOff,
                    ),
                    value: useHttps,
                    onChanged: (value) {
                      setDialogState(() => useHttps = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: Text(l10n.serverTryWss),
                    subtitle: Text(
                      tryWss ? l10n.serverTryWssOn : l10n.serverTryWssOff,
                    ),
                    value: tryWss,
                    onChanged: (value) {
                      setDialogState(() => tryWss = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  _RsaPemField(
                    controller: rsaPemController,
                    onValidityChanged: (valid) => rsaPemValid = valid,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.serverCancel),
              ),
              FilledButton(
                onPressed: () async {
                  final displayName = displayNameController.text.trim();
                  final rsaPem = rsaPemController.text.trim();
                  if (rsaPem.isNotEmpty && !rsaPemValid) {
                    return;
                  }
                  Navigator.pop(context);
                  final updated = server.copyWith(
                    displayName: displayName.isEmpty
                        ? server.address
                        : displayName,
                    useHttps: useHttps,
                    tryWss: tryWss,
                    autoDetectTcpPort: autoDetectTcpPort,
                  );
                  if (rsaPem.isEmpty) {
                    await RsaKeyTrustService.instance.deleteKey(authority);
                  } else if (rsaPemValid) {
                    await RsaKeyTrustService.instance.saveKey(
                      rsaPem,
                      authority,
                    );
                  }
                  setState(() => _servers[index] = updated);
                  widget.onEdit(index, updated);
                },
                child: Text(l10n.serverSave),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.serverSelect,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context)!.serverAdd),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Server list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _servers.length,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedIndex;
                  final server = _servers[index];

                  return Card(
                    elevation: 0,
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.dns_outlined,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        server.displayName,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                      subtitle: server.address.isNotEmpty
                          ? Text(
                              server.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? colorScheme.onPrimaryContainer
                                          .withOpacity(0.7)
                                    : colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
                            ),
                          IconButton(
                            onPressed: () => _showEditDialog(index),
                            icon: Icon(
                              Icons.edit_outlined,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                            tooltip: AppLocalizations.of(context)!.serverEdit,
                          ),
                          if (_servers.length > 1)
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _servers.removeAt(index);
                                  if (_selectedIndex >= _servers.length) {
                                    _selectedIndex = _servers.length - 1;
                                  } else if (_selectedIndex > index) {
                                    _selectedIndex--;
                                  }
                                });
                                widget.onDelete(index);
                              },
                              icon: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error,
                              ),
                              tooltip: AppLocalizations.of(
                                context,
                              )!.serverDelete,
                            ),
                        ],
                      ),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        widget.onSelect(index);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 服务器配置中的可选 RSA 公钥绑定输入框（不通过服务器拉取）。
class _RsaPemField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool> onValidityChanged;

  const _RsaPemField({
    required this.controller,
    required this.onValidityChanged,
  });

  @override
  State<_RsaPemField> createState() => _RsaPemFieldState();
}

class _RsaPemFieldState extends State<_RsaPemField> {
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    _valid = _isValidPem(widget.controller.text);
    widget.onValidityChanged(_valid);
  }

  static bool _isValidPem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    try {
      TfCrypto.parseRsaPublicKey(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onChanged(String text) {
    setState(() => _valid = _isValidPem(text));
    widget.onValidityChanged(_valid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? sha;
    final text = widget.controller.text.trim();
    if (text.isNotEmpty && _valid) {
      try {
        sha = TfCrypto.rsaPublicKeyFingerprint(text);
      } catch (_) {
        sha = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(
            fontFamily: codeFontFamily,
            fontFamilyFallback: codeFontFamilyFallback,
            fontSize: 12,
          ),
          decoration: InputDecoration(
            labelText: l10n.rsaPemFieldLabel,
            hintText: l10n.rsaPemFieldHint,
            border: const OutlineInputBorder(),
            errorText: text.isNotEmpty && !_valid ? l10n.rsaInvalidPem : null,
            alignLabelWithHint: true,
          ),
          onChanged: _onChanged,
        ),
        if (sha != null) ...[
          const SizedBox(height: 8),
          Text(
            '${l10n.rsaKeySha}:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          CodeBlock(text: sha, fontSize: 11),
        ],
      ],
    );
  }
}
