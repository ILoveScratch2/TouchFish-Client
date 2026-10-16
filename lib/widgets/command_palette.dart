import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../models/settings_service.dart';
import '../routes/app_routes.dart';
import '../services/auth_state.dart';
import '../services/chat_data_service.dart';
import '../services/feature_flags.dart';
import 'app_alert_dialog.dart' show isDesktopWindowed;


class CommandPaletteItem {
  final IconData icon;
  final String title;
  final String? subtitle;

  final List<String> keywords;
  final VoidCallback onSelect;

  const CommandPaletteItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.keywords = const [],
    required this.onSelect,
  });
}


@visibleForTesting
List<CommandPaletteItem> filterCommands(
  List<CommandPaletteItem> items,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final scored = <_ScoredCommand>[];
  for (final item in items) {
    final score = _scoreCommand(item, q);
    if (score > 0) scored.add(_ScoredCommand(item, score));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.item.title.compareTo(b.item.title);
  });
  return [for (final s in scored) s.item];
}

class _ScoredCommand {
  final CommandPaletteItem item;
  final int score;

  const _ScoredCommand(this.item, this.score);
}

int _scoreCommand(CommandPaletteItem item, String q) {
  final title = item.title.toLowerCase();
  if (title == q) return 120;
  if (title.startsWith(q)) return 100;
  if (title.contains(q)) return 80;
  for (final keyword in item.keywords) {
    final k = keyword.toLowerCase();
    if (k.startsWith(q)) return 70;
    if (k.contains(q)) return 60;
  }
  final subtitle = item.subtitle?.toLowerCase();
  if (subtitle != null && subtitle.contains(q)) return 40;
  if (_isSubsequence(q, title)) return 20;
  return 0;
}

bool _isSubsequence(String needle, String haystack) {
  var i = 0;
  for (var j = 0; j < haystack.length && i < needle.length; j++) {
    if (haystack[j] == needle[i]) i++;
  }
  return i == needle.length;
}

const String commandPaletteEnabledKey = 'commandPaletteEnabled';

bool get commandPaletteEnabled =>
    SettingsService.instance.getValue<bool>(commandPaletteEnabledKey, true);

List<CommandPaletteItem> buildDefaultCommands(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final flags = FeatureFlags.instance;
  final items = <CommandPaletteItem>[];

  void nav(String route, IconData icon, String title, {bool section = false}) {
    items.add(
      CommandPaletteItem(
        icon: icon,
        title: title,
        onSelect: () {
          if (section) {
            context.go(route);
          } else {
            context.push(route);
          }
        },
      ),
    );
  }

  nav(AppRoutes.chat, Icons.chat_bubble_outline, l10n.navChat, section: true);
  if (flags.announcement) {
    nav(
      AppRoutes.announcement,
      Icons.campaign_outlined,
      l10n.navAnnouncement,
      section: true,
    );
  }
  if (flags.forum) {
    nav(AppRoutes.forum, Icons.forum_outlined, l10n.navForum, section: true);
  }
  nav(
    AppRoutes.account,
    Icons.account_circle_outlined,
    l10n.navAccount,
    section: true,
  );
  if (AuthState.instance.currentUser?.hasAdminAccess == true) {
    nav(
      AppRoutes.admin,
      Icons.admin_panel_settings_outlined,
      l10n.navAdmin,
      section: true,
    );
  }
  nav(AppRoutes.universalSearch, Icons.search, l10n.searchTitle);
  nav(AppRoutes.groupSearch, Icons.groups_outlined, l10n.groupSearchTitle);
  nav(AppRoutes.friendRequests, Icons.person_add_alt, l10n.friendRequestsTitle);
  nav(AppRoutes.settings, Icons.settings_outlined, l10n.settingsTitle);
  nav(AppRoutes.about, Icons.info_outline, l10n.aboutTitle);

  for (final room in ChatDataService.instance.rooms) {
    items.add(
      CommandPaletteItem(
        icon: room.type == ChatType.group
            ? Icons.group_outlined
            : Icons.person_outline,
        title: room.name,
        subtitle: room.lastMessage,
        onSelect: () => context.go('${AppRoutes.chat}/${room.id}'),
      ),
    );
  }

  return items;
}

Future<void> showCommandPalette(
  BuildContext context, {
  List<CommandPaletteItem>? items,
  String? initialQuery,
}) {
  if (!commandPaletteEnabled) return Future<void>.value();
  final commands = items ?? buildDefaultCommands(context);
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, _, _) =>
        _CommandPaletteDialog(items: commands, initialQuery: initialQuery),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  final List<CommandPaletteItem> items;
  final String? initialQuery;

  const _CommandPaletteDialog({required this.items, this.initialQuery});

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  var _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() => _focusedIndex = 0);
  }

  List<CommandPaletteItem> get _results =>
      filterCommands(widget.items, _controller.text);

  void _moveFocus(int delta) {
    final results = _results;
    if (results.isEmpty) return;
    setState(() {
      final next = _focusedIndex + delta;
      _focusedIndex = next.clamp(0, results.length - 1);
    });
  }

  void _activate() {
    final results = _results;
    if (results.isEmpty) return;
    final index = _focusedIndex.clamp(0, results.length - 1);
    _select(results[index]);
  }

  void _select(CommandPaletteItem item) {
    Navigator.of(context).pop();
    item.onSelect();
  }

  void _dismiss() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final results = _results;
    final focusIndex = results.isEmpty
        ? -1
        : _focusedIndex.clamp(0, results.length - 1);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height * 0.16,
          left: 16,
          right: 16,
        ),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _moveFocus(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _moveFocus(-1),
            const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
          },
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.search),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _activate(),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: l10n.commandPaletteHint,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (isDesktopWindowed) const _EscHintChip(),
                        ],
                      ),
                    ),
                    if (results.isNotEmpty) ...[
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: results.length,
                          itemBuilder: (context, index) => _CommandTile(
                            item: results[index],
                            selected: index == focusIndex,
                            onTap: () => _select(results[index]),
                            onHover: () {
                              if (_focusedIndex != index) {
                                setState(() => _focusedIndex = index);
                              }
                            },
                          ),
                        ),
                      ),
                    ] else if (_controller.text.trim().isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.commandPaletteEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EscHintChip extends StatelessWidget {
  const _EscHintChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Esc',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CommandTile extends StatelessWidget {
  final CommandPaletteItem item;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _CommandTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: ColoredBox(
        color: selected
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.transparent,
        child: ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            child: Icon(item.icon, size: 20),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: item.subtitle == null || item.subtitle!.isEmpty
              ? null
              : Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onTap: onTap,
        ),
      ),
    );
  }
}
