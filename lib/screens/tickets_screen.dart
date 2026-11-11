import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/support_ticket.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/ticket_inbox_service.dart';
import '../utils/time_ago.dart';
import '../widgets/support/ticket_compose_sheet.dart';
import '../widgets/support/ticket_labels.dart';
import '../widgets/ui/empty_state.dart';
import 'ticket_detail_screen.dart';

/// 列表筛选条件
class _TicketFilters {
  final TicketType? type;
  final TicketPriority? priority;
  final int? creatorUid;
  final String? creatorLabel;

  const _TicketFilters({
    this.type,
    this.priority,
    this.creatorUid,
    this.creatorLabel,
  });

  int get activeCount =>
      (type == null ? 0 : 1) +
      (priority == null ? 0 : 1) +
      (creatorUid == null ? 0 : 1);

  _TicketFilters copyWith({
    TicketType? type,
    TicketPriority? priority,
    int? creatorUid,
    String? creatorLabel,
    bool clearType = false,
    bool clearPriority = false,
    bool clearCreator = false,
  }) {
    return _TicketFilters(
      type: clearType ? null : (type ?? this.type),
      priority: clearPriority ? null : (priority ?? this.priority),
      creatorUid: clearCreator ? null : (creatorUid ?? this.creatorUid),
      creatorLabel: clearCreator ? null : (creatorLabel ?? this.creatorLabel),
    );
  }
}

/// 工单列表
/// `adminMode` 为真时展示 xsfx view
class TicketsScreen extends StatefulWidget {
  final bool adminMode;

  const TicketsScreen({super.key, this.adminMode = false});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  static const _pollInterval = Duration(seconds: 60);

  List<SupportTicket> _tickets = const [];
  bool _loading = true;
  Timer? _pollTimer;

  bool _includeClosed = false;

  String _sort = 'priority';

  _TicketFilters _filters = const _TicketFilters();
  final Map<int, String> _names = {};

  @override
  void initState() {
    super.initState();
    _load();
    TicketInboxService.instance.addListener(_onInboxChanged);
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted && !_loading) _load(silent: true);
    });
  }

  @override
  void dispose() {
    TicketInboxService.instance.removeListener(_onInboxChanged);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onInboxChanged() {
    // 推迟帧末
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loading) _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!silent) setState(() => _loading = true);
    final tickets = widget.adminMode
        ? await TfApiClient.instance.listTicketQueue(
            uid,
            password,
            includeClosed: _includeClosed,
            sort: _sort,
            type: _filters.type?.wire,
            priority: _filters.priority?.wire,
            creatorUid: _filters.creatorUid,
          )
        : await TfApiClient.instance.listMyTickets(uid, password);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
    _resolveNames(tickets);
  }

  /// 补齐创建者/负责人的显示名
  Future<void> _resolveNames(List<SupportTicket> tickets) async {
    final missing = <int>{};
    for (final ticket in tickets) {
      if (_nameOf(ticket.creatorName) == null) missing.add(ticket.uid);
      final assignee = ticket.assigneeUid;
      if (assignee != null && _nameOf(ticket.assigneeName) == null) {
        missing.add(assignee);
      }
    }
    missing.removeWhere(_names.containsKey);
    if (missing.isEmpty) return;
    for (final uid in missing) {
      final profile = await TfApiClient.instance.getUserByUid(uid);
      if (!mounted) return;
      final name = profile?.username;
      if (name == null || name.isEmpty) continue;
      setState(() => _names[uid] = name);
    }
  }

  static String? _nameOf(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _openCompose() async {
    final created = await showTicketComposeSheet(
      context,
      type: TicketType.consult,
    );
    if (created != null) await _load(silent: true);
  }

  Future<void> _openDetail(SupportTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(
          ticketId: ticket.id,
          initial: ticket,
          adminMode: widget.adminMode,
        ),
      ),
    );
    if (mounted) await _load(silent: true);
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_TicketFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _TicketFilterSheet(initial: _filters, allowCreator: widget.adminMode),
    );
    if (result == null || !mounted) return;
    setState(() => _filters = result);
    await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adminMode ? l10n.ticketQueue : l10n.ticketMyTickets),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: widget.adminMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(104),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: false,
                            label: Text(l10n.ticketQueue),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text(l10n.ticketAllTickets),
                          ),
                        ],
                        selected: {_includeClosed},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          setState(() => _includeClosed = selection.first);
                          _load(silent: true);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: [
                                ButtonSegment<String>(
                                  value: 'priority',
                                  label: Text(l10n.ticketSortByPriority),
                                  icon: const Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                  ),
                                ),
                                ButtonSegment<String>(
                                  value: 'time',
                                  label: Text(l10n.ticketSortByTime),
                                  icon: const Icon(Icons.schedule, size: 16),
                                ),
                              ],
                              selected: {_sort},
                              showSelectedIcon: false,
                              onSelectionChanged: (selection) {
                                setState(() => _sort = selection.first);
                                _load(silent: true);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Badge(
                            isLabelVisible: _filters.activeCount > 0,
                            label: Text('${_filters.activeCount}'),
                            child: IconButton(
                              tooltip: l10n.ticketFilter,
                              icon: const Icon(Icons.tune),
                              onPressed: _openFilters,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
      floatingActionButton: widget.adminMode
          ? null
          : FloatingActionButton(
              tooltip: l10n.ticketFeedback,
              onPressed: _openCompose,
              child: const Icon(Icons.add_comment_outlined),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _tickets.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_outlined,
                      title: l10n.ticketEmpty,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _TicketListTile(
                              ticket: _tickets[index],
                              adminMode: widget.adminMode,
                              l10n: l10n,
                              nameResolver: _displayName,
                              onOpen: _openDetail,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }

  String _displayName(int uid, String? provided) {
    return _nameOf(provided) ??
        _names[uid] ??
        AppLocalizations.of(context)!.ticketUnknownUser;
  }
}

/// 筛选
class _TicketFilterSheet extends StatefulWidget {
  final _TicketFilters initial;
  final bool allowCreator;

  const _TicketFilterSheet({required this.initial, required this.allowCreator});

  @override
  State<_TicketFilterSheet> createState() => _TicketFilterSheetState();
}

class _TicketFilterSheetState extends State<_TicketFilterSheet> {
  late _TicketFilters _draft = widget.initial;
  late final TextEditingController _creatorController = TextEditingController(
    text: widget.initial.creatorLabel ?? '',
  );
  bool _resolving = false;

  @override
  void dispose() {
    _creatorController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _creatorController.text.trim();
    if (!widget.allowCreator || raw.isEmpty) {
      Navigator.pop(context, _draft.copyWith(clearCreator: raw.isEmpty));
      return;
    }
    // 同一创建者
    if (_draft.creatorLabel == raw && _draft.creatorUid != null) {
      Navigator.pop(context, _draft);
      return;
    }

    setState(() => _resolving = true);
    final asUid = int.tryParse(raw);
    var uid = asUid;
    String? label = asUid == null ? null : raw;
    if (uid == null) {
      final profile = await TfApiClient.instance.getUserByUsername(raw);
      uid = int.tryParse(profile?.uid ?? '');
      label = profile?.username;
    }
    if (!mounted) return;
    setState(() => _resolving = false);
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.ticketCreatorNotFound)));
      return;
    }
    Navigator.pop(
      context,
      _draft.copyWith(creatorUid: uid, creatorLabel: label ?? raw),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.ticketFilter, style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _draft = const _TicketFilters()),
                  child: Text(l10n.ticketFilterReset),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.ticketTypeName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final type in TicketType.values)
                  FilterChip(
                    label: Text(ticketTypeLabel(l10n, type)),
                    selected: _draft.type == type,
                    onSelected: (selected) => setState(
                      () => _draft = selected
                          ? _draft.copyWith(type: type)
                          : _draft.copyWith(clearType: true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.ticketPriority,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final priority in TicketPriority.values)
                  FilterChip(
                    label: Text(ticketPriorityLabel(l10n, priority)),
                    selected: _draft.priority == priority,
                    onSelected: (selected) => setState(
                      () => _draft = selected
                          ? _draft.copyWith(priority: priority)
                          : _draft.copyWith(clearPriority: true),
                    ),
                  ),
              ],
            ),
            if (widget.allowCreator) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _creatorController,
                decoration: InputDecoration(
                  labelText: l10n.ticketCreatorFilter,
                  isDense: true,
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _resolving ? null : _apply,
                child: _resolving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.ticketFilterApply),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketListTile extends StatelessWidget {
  final SupportTicket ticket;
  final bool adminMode;
  final AppLocalizations l10n;
  final String Function(int uid, String? provided) nameResolver;
  final ValueChanged<SupportTicket> onOpen;

  const _TicketListTile({
    required this.ticket,
    required this.adminMode,
    required this.l10n,
    required this.nameResolver,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = ticket.title.isEmpty ? ticket.content : ticket.title;
    final snippet = ticket.title.isEmpty ? '' : ticket.content.trim();
    final unread = !adminMode && ticket.userUnread > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpen(ticket),
        child: ListTile(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          isThreeLine: snippet.isNotEmpty,
          leading: Badge(
            isLabelVisible: unread,
            label: Text('${ticket.userUnread}'),
            child: Icon(
              ticketStatusIcon(ticket.status),
              color: ticketStatusColor(scheme, ticket.status),
            ),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snippet.isNotEmpty)
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TicketTagChip(
                    label: ticketTypeLabel(l10n, ticket.type),
                    color: ticketTypeColor(scheme, ticket.type),
                  ),
                  TicketTagChip(
                    label: ticketStatusLabel(l10n, ticket.status),
                    color: ticketStatusColor(scheme, ticket.status),
                  ),
                  TicketTagChip(
                    label: ticketPriorityLabel(l10n, ticket.priority),
                    color: ticketPriorityColor(scheme, ticket.priority),
                  ),
                  Text(
                    formatTimeAgo(
                      l10n,
                      ticket.updatedAt.millisecondsSinceEpoch ~/ 1000,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (adminMode)
                    Text(
                      '· ${nameResolver(ticket.uid, ticket.creatorName)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (adminMode && ticket.assigneeUid != null)
                    Text(
                      '· ${l10n.ticketAssignee} ${nameResolver(ticket.assigneeUid!, ticket.assigneeName)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.secondary,
                      ),
                    ),
                  if (ticket.attachments.isNotEmpty)
                    Icon(
                      Icons.attach_file,
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
