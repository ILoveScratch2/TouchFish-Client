import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class ServerInfo {
  final String displayName;
  final String address;
  final String apiPort;
  final String tcpPort;

  ServerInfo({
    required this.displayName,
    required this.address,
    required this.apiPort,
    required this.tcpPort,
  });

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'address': address,
    'apiPort': apiPort,
    'tcpPort': tcpPort,
  };

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
    displayName: json['displayName'] ?? '',
    address: json['address'] ?? '',
    apiPort: json['apiPort'] ?? '',
    tcpPort: json['tcpPort'] ?? '',
  );
}

class ServerSelector extends StatefulWidget {
  const ServerSelector({super.key});

  @override
  State<ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends State<ServerSelector> {
  List<ServerInfo> _servers = [
    ServerInfo(
      displayName: 'touchfish.xin',
      address: 'touchfish.xin',
      apiPort: '8080',
      tcpPort: '9090',
    )
  ];
  int _selectedIndex = 0;
  bool _isLoading = true;

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
        onSelect: (index) {
          setState(() => _selectedIndex = index);
          _saveServers();
          Navigator.pop(context);
        },
        onAdd: (server) {
          setState(() {
            _servers.add(server);
            _selectedIndex = _servers.length - 1;
          });
          _saveServers();
        },
        onDelete: (index) {
          if (_servers.length > 1) {
            setState(() {
              _servers.removeAt(index);
              if (_selectedIndex >= _servers.length) {
                _selectedIndex = _servers.length - 1;
              }
            });
            _saveServers();
          }
        },
      ),
    );
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
            Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
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
  final ValueChanged<int> onDelete;

  const _ServerBottomSheet({
    required this.servers,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
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
    
    String? addressError;
    String? apiPortError;
    String? tcpPortError;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool validateAddress(String address) {
            if (address.isEmpty) return true;
            final regex = RegExp(r'.+\..{2,}');
            return regex.hasMatch(address);
          }
          
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
              final address = addressController.text.trim();
              final apiPort = apiPortController.text.trim();
              final tcpPort = tcpPortController.text.trim();
              
              addressError = validateAddress(address) ? null : l10n.serverErrorInvalidAddress;
              if (!validatePort(apiPort)) {
                apiPortError = l10n.serverErrorInvalidPort;
              } else if (checkDuplicatePorts(apiPort, tcpPort)) {
                apiPortError = l10n.serverErrorDuplicatePort;
              } else {
                apiPortError = null;
              }
              if (!validatePort(tcpPort)) {
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
                        errorText: addressError,
                      ),
                      onChanged: (_) => validate(),
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
                  final tcpPort = tcpPortController.text.trim();
                  if (!validateAddress(address)) {
                    setDialogState(() => addressError = l10n.serverErrorInvalidAddress);
                    return;
                  }
                  if (!validatePort(apiPort)) {
                    setDialogState(() => apiPortError = l10n.serverErrorInvalidPort);
                    return;
                  }
                  if (!validatePort(tcpPort)) {
                    setDialogState(() => tcpPortError = l10n.serverErrorInvalidPort);
                    return;
                  }
                  if (checkDuplicatePorts(apiPort, tcpPort)) {
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
