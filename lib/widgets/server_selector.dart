import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../constants/app_constants.dart';
import '../services/api/tf_api_client.dart';

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
        json['autoDetectTcpPort'] as bool? ?? AppConstants.defaultAutoDetectTcpPort,
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
    )
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
            .map((url) => ServerInfo(
                  displayName: _extractDisplayName(url),
                  address: url,
                  apiPort: '',
                  tcpPort: '',
                ))
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
          setState(() => _selectedIndex = index);
          await _saveServers();
          TfApiClient.instance.invalidateCache();
          _probeSelectedServer();
          if (context.mounted) Navigator.pop(context);
        },
        onAdd: (server) async {
          setState(() {
            _servers.add(server);
            _selectedIndex = _servers.length - 1;
          });
          await _saveServers();
          TfApiClient.instance.invalidateCache();
          _probeSelectedServer();
        },
        onEdit: (index, server) async {
          setState(() => _servers[index] = server);
          await _saveServers();
          if (index == _selectedIndex) {
            TfApiClient.instance.invalidateCache();
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
        return Icon(
          Icons.cancel_rounded,
          size: 18,
          color: colorScheme.error,
        );
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

  void _showAddDialog() {
    final displayNameController = TextEditingController();
    final addressController = TextEditingController();
    final apiPortController = TextEditingController();
    final tcpPortController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    
    bool useHttps = false;
    bool tryWss = AppConstants.defaultTryWss;
    bool autoDetectTcpPort = AppConstants.defaultAutoDetectTcpPort;
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
                      useHttps
                          ? l10n.serverUseHttpsOn
                          : l10n.serverUseHttpsOff,
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
                      tryWss
                          ? l10n.serverTryWssOn
                          : l10n.serverTryWssOff,
                    ),
                    value: tryWss,
                    onChanged: (value) {
                      setDialogState(() => tryWss = value);
                    },
                    contentPadding: EdgeInsets.zero,
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
                onPressed: () {
                  final displayName = displayNameController.text.trim();
                  final address = addressController.text.trim();
                  final apiPort = apiPortController.text.trim();
                  final tcpPort =
                      autoDetectTcpPort ? '' : tcpPortController.text.trim();
                  if (!validatePort(apiPort)) {
                    setDialogState(() => apiPortError = l10n.serverErrorInvalidPort);
                    return;
                  }
                  if (!autoDetectTcpPort && !validatePort(tcpPort)) {
                    setDialogState(() => tcpPortError = l10n.serverErrorInvalidPort);
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
    final displayNameController = TextEditingController(text: server.displayName);
    final l10n = AppLocalizations.of(context)!;

    bool useHttps = server.useHttps;
    bool tryWss = server.tryWss;
    bool autoDetectTcpPort = server.autoDetectTcpPort;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                      useHttps
                          ? l10n.serverUseHttpsOn
                          : l10n.serverUseHttpsOff,
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
                      tryWss
                          ? l10n.serverTryWssOn
                          : l10n.serverTryWssOff,
                    ),
                    value: tryWss,
                    onChanged: (value) {
                      setDialogState(() => tryWss = value);
                    },
                    contentPadding: EdgeInsets.zero,
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
                onPressed: () {
                  final displayName = displayNameController.text.trim();
                  Navigator.pop(context);
                  final updated = server.copyWith(
                    displayName:
                        displayName.isEmpty ? server.address : displayName,
                    useHttps: useHttps,
                    tryWss: tryWss,
                    autoDetectTcpPort: autoDetectTcpPort,
                  );
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
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                                    ? colorScheme.onPrimaryContainer.withOpacity(0.7)
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
                              tooltip: AppLocalizations.of(context)!.serverDelete,
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
