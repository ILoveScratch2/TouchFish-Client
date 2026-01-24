import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerSelector extends StatefulWidget {
  const ServerSelector({super.key});

  @override
  State<ServerSelector> createState() => _ServerSelectorState();
}

class _ServerSelectorState extends State<ServerSelector> {
  List<String> _servers = ['touchfish.xin'];
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final servers = prefs.getStringList('servers') ?? ['touchfish.xin'];
    final selectedIndex = prefs.getInt('selectedServerIndex') ?? 0;
    
    setState(() {
      _servers = servers;
      _selectedIndex = selectedIndex.clamp(0, servers.length - 1);
      _isLoading = false;
    });
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('servers', _servers);
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

    final displayName = _extractDisplayName(_servers[_selectedIndex]);
    
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
  final List<String> servers;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onAdd;
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
  late List<String> _servers;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _servers = List.from(widget.servers);
    _selectedIndex = widget.selectedIndex;
  }

  String _extractDisplayName(String url) {
    var display = url.replaceFirst(RegExp(r'^https?://'), '');
    display = display.replaceFirst(RegExp(r'/$'), '');
    return display;
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加服务器'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '服务器地址',
            hintText: '例如: api.example.com:8080',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              setState(() {
                _servers.add(value.trim());
                _selectedIndex = _servers.length - 1;
              });
              widget.onAdd(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(context);
                setState(() {
                  _servers.add(value);
                  _selectedIndex = _servers.length - 1;
                });
                widget.onAdd(value);
              }
            },
            child: const Text('添加'),
          ),
        ],
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
                    '选择服务器',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
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
                  final displayName = _extractDisplayName(_servers[index]);
                  
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
                        displayName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected 
                              ? colorScheme.onPrimaryContainer 
                              : colorScheme.onSurface,
                        ),
                      ),
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
                              tooltip: '删除',
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
