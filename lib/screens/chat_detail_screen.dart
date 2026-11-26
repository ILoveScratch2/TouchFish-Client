import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart' show lookupMimeType;
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/settings_service.dart';
import '../models/user_profile.dart';
import '../widgets/chat/failed_messages_bar.dart';
import '../widgets/chat/ws_connection_strip.dart';
import '../widgets/chat_input_bar.dart';
import '../routes/app_routes.dart';
import 'chat_detail/widgets/chat_detail_banners.dart';
import 'chat_detail/widgets/message_list_view.dart';
import 'chat_detail/chat_scroll_follower.dart';
import '../l10n/app_localizations.dart';
import '../widgets/mention_text_field.dart';
import '../services/auth_state.dart';
import '../services/api/tf_api_client.dart';
import '../services/file_service.dart';
import '../services/image_compression_service.dart';
import '../services/snackbar_service.dart';
import '../services/chat_ws_service.dart';
import '../services/app_foreground_service.dart';
import '../services/chat_data_service.dart';
import '../services/feature_flags.dart';
import '../services/call_service.dart';
import '../services/draft_service.dart';
import '../services/local_message_store.dart';
import '../services/message_sync_service.dart';
import '../services/notification_service.dart';
import '../theme/tokens.dart';
import '../utils/message_text.dart';
import '../utils/wide_screen_helper.dart';
import '../utils/talker.dart';
import '../utils/read_receipt_throttle.dart';
import '../services/message_clipboard_service.dart';
import 'chat_room_settings_screen.dart';
import 'group_essence_screen.dart';
import '../widgets/pinned_messages_sheet.dart';
import '../widgets/ui/loading_indicator.dart';
import '../widgets/room_selection_mode.dart';
import '../widgets/optimized_image.dart';
import '../widgets/account/online_avatar_badge.dart';
import '../services/presence_service.dart';
import '../widgets/sync_indicator.dart';
import '../models/typing_status.dart';
import '../models/file_task.dart';
import '../widgets/typing_indicator.dart';
import '../providers/chat/message_provider.dart';
import '../providers/chat/chat_room_state_provider.dart';
import '../providers/chat/image_gallery_provider.dart';
import '../providers/task/task_manager_provider.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final String roomId;

  const ChatDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  ScrollController? _scrollListenerAttached;
  bool _treeActive = true;

  final Map<String, Timer> _pendingWsTimers = {};
  int _jumpToken = 0;
  Timer? _jumpGuard;
  static const int _jumpMaxPages = 400;
  static const int _jumpWaitFrames = 60;
  static const Duration _jumpLocateBudget = Duration(seconds: 20);
  static const Duration _jumpGuardDuration = Duration(seconds: 30);

  final Set<String> _restFallbackAttempted = {};
  ChatRoom? _currentRoom;
  final List<MentionUser> _mentionUsers = [];
  bool _isInitialized = false;
  bool _wsConnected = false;
  bool _avatarLoadFailed = false;
  bool _isLoadingOlder = false;
  bool _isLoadingMessages = false;
  bool _hasMoreMessages = true;

  String? _messagesError;

  int? _flashMid;
  Timer? _flashTimer;
  bool _realtimeListenersAttached = false;
  StreamSubscription? _ackErrorSub;
  String _groupEnterHint = '';
  bool _showGroupEnterHint = true;

  /// 跟随底部
  late final ChatScrollFollower _follower = ChatScrollFollower(
    isActive: () => mounted && _treeActive,
  );
  bool _showBackToBottom = false;
  bool _canModerateGroup = false;
  Timer? _draftTimer;
  bool _suppressDraftSave = false;
  int _roomGeneration = 0;
  final ValueNotifier<Set<String>> _entranceKeys = ValueNotifier<Set<String>>(
    const {},
  );
  Timer? _entranceKeysTimer;
  Timer? _groupMetaRefreshTimer;
  List<PinnedMessage> _pinnedMessages = [];
  final Map<int, ChatMessage?> _pinnedMessageContents = {};
  List<ChatMessage>? _pinIndexSource;
  Map<int, int> _pinMidIndex = const {};
  final GlobalKey _pinnedBarKey = GlobalKey();
  List<int> _essenceMids = [];
  bool _essenceEnabled = true;
  String? _fetchingEssenceRoomId;
  StreamSubscription<int>? _essenceSub;
  String? _fetchingPinsRoomId;
  Timer? _weakNetworkTimer;
  final Map<String, TypingStatus> _activityStatuses = {};
  final ValueNotifier<int> _activityRevision = ValueNotifier<int>(0);
  StreamSubscription<ChatWsEvent>? _typingSub;
  Timer? _typingCleanupTimer;
  ProviderSubscription<List<FileTask>>? _uploadProgressSub;
  DateTime? _lastUploadProgressSentAt;
  final Map<String, double> _lastUploadProgressByRoom = {};

  final ReadReceiptThrottle _readReceiptThrottle = ReadReceiptThrottle();
  int? _lastReportedReadMid;

  String get _contactUid {
    final id = widget.roomId;
    if (id.startsWith('U') || id.startsWith('G')) return id;
    // 修复 dev ID
    final parsed = int.tryParse(id);
    if (parsed != null) return 'U$parsed';
    return id;
  }

  // Riverpod
  List<ChatMessage> get _messages => ref.read(roomMessagesProvider(_contactUid));

  ChatRoomUiState get _uiState => ref.read(chatRoomStateProvider(_contactUid));

  ScrollController get _scrollController => _uiState.scrollController;

  /// 消息列表的索引跳转控制
  final ListController _messageListController = ListController();

  ChatMessage? get _replyingTo => _uiState.replyingTo;

  ChatMessage? get _forwardingTo => _uiState.forwardingTo;

  int get _pinCurrentPage => _uiState.pinnedCurrentPage;

  bool get _isJumpingToMessage => _uiState.isJumpingToMessage;

  Set<String> get _selectedMessageKeys => _uiState.selectedMessageIds;

  ChatRoomState get _chatRoomStateNotifier =>
      ref.read(chatRoomStateProvider(_contactUid).notifier);

  String _stableKey(ChatMessage m) =>
      m.clientMid ?? m.mid?.toString() ?? m.id;

  List<ChatMessage> get _selectedMessages {
    final keys = _selectedMessageKeys;
    return _messages
        .where((m) => keys.contains(_stableKey(m)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _enterSelection(ChatMessage message) {
    _chatRoomStateNotifier.enterSelectionMode(_stableKey(message));
  }

  void _toggleSelection(ChatMessage message) {
    _chatRoomStateNotifier.toggleMessageSelection(_stableKey(message));
  }

  void _exitSelection() {
    _chatRoomStateNotifier.exitSelectionMode();
  }

  QuotedMessagePreview _quotePreviewFor(ChatMessage target) {
    final type = target.type;
    final isMedia =
        type == MessageType.file ||
        type == MessageType.image ||
        type == MessageType.video ||
        type == MessageType.audio;
    return QuotedMessagePreview(
      mid: target.mid,
      senderUid: target.senderUid,
      senderName: target.isMe
          ? AuthState.instance.currentUser?.username
          : target.senderName,
      content: type == MessageType.text ? target.text : '',
      contentType: type == MessageType.mergedForward
          ? 'redirect'
          : isMedia
          ? 'file'
          : 'plain',
      fileHash: isMedia ? target.media?.fileHash : null,
      fileName: isMedia ? target.media?.fileName : null,
      isDeleted: target.isDeleted,
    );
  }

  void _setReplyingTo(ChatMessage? message) =>
      ref.read(chatRoomStateProvider(_contactUid).notifier).setReplyingTo(message);

  void _setForwardingTo(ChatMessage? message) =>
      ref.read(chatRoomStateProvider(_contactUid).notifier).setForwardingTo(message);

  void _clearReplyAction() {
    final notifier = ref.read(chatRoomStateProvider(_contactUid).notifier);
    notifier.setReplyingTo(null);
    notifier.setForwardingTo(null);
  }

  void _setPinCurrentPage(int page) =>
      ref.read(chatRoomStateProvider(_contactUid).notifier).setPinnedPage(page);

  void _setJumpingToMessage(bool jumping) =>
      ref.read(chatRoomStateProvider(_contactUid).notifier)
          .setJumpingToMessage(jumping);

  void _attachScrollListener() {
    final controller = _scrollController;
    if (_scrollListenerAttached == controller) return;
    _scrollListenerAttached?.removeListener(_onScroll);
    controller.addListener(_onScroll);
    _scrollListenerAttached = controller;
    _follower.attach(controller);
  }

  @override
  void initState() {
    super.initState();
    _attachScrollListener();
    _messageController.addListener(_scheduleDraftSave);
    _typingCleanupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activityStatuses.isEmpty) return;
      final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
      final expired = _activityStatuses.entries
          .where((entry) => entry.value.updatedAt.isBefore(cutoff))
          .map((entry) => entry.key)
          .toList();
      if (expired.isEmpty || !mounted) return;
      for (final key in expired) {
        _activityStatuses.remove(key);
      }
      _activityRevision.value++;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initRoom();
      _isInitialized = true;
    }
  }

  @override
  void didUpdateWidget(covariant ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _draftTimer?.cancel();
      unawaited(_saveDraftForRoom(oldWidget.roomId));
      _initRoom();
    }
  }

  @override
  void deactivate() {
    _treeActive = false;
    _detachRealtimeListeners();
    _ackErrorSub?.cancel();
    _ackErrorSub = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _treeActive = true;
    if (!_isInitialized) return;
    _attachRealtimeListeners();
    if (AuthState.instance.isLoggedIn && _ackErrorSub == null) {
      _ackErrorSub = ChatDataService.instance.ackErrorStream.listen(_onAckError);
    }
    _wsConnected = ChatWsService.instance.isAuthenticated;
  }

  void _initRoom() {
    _roomGeneration++;
    _attachScrollListener();
    for (final timer in _pendingWsTimers.values) {
      timer.cancel();
    }
    _pendingWsTimers.clear();
    _restFallbackAttempted.clear();
    _currentRoom = null;
    _avatarLoadFailed = false;
    _isLoadingOlder = false;
    _isLoadingMessages = false;
    _hasMoreMessages = true;
    _groupEnterHint = '';
    _showGroupEnterHint = true;
    _follower.reset();
    _showBackToBottom = false;
    _canModerateGroup = false;
    _essenceMids = [];
    _essenceEnabled = true;
    _fetchingEssenceRoomId = null;
    if (_activityStatuses.isNotEmpty) {
      _activityStatuses.clear();
      _activityRevision.value++;
    }
    _readReceiptThrottle.reset();
    _lastReportedReadMid = null;
    _entranceKeysTimer?.cancel();
    _entranceKeys.value = const {};
    _groupMetaRefreshTimer?.cancel();
    _groupMetaRefreshTimer = null;
    _suppressDraftSave = true;
    _messageController.clear();
    _suppressDraftSave = false;
    unawaited(_restoreDraft(_contactUid));
    ChatDataService.instance.clearUnread(_contactUid);
    _loadChatRoom();
    _startRealMessaging();
    _initMessageSync();
    _weakNetworkTimer?.cancel();
    // 注意
    // 这里不能取消 _typingSub/_typingCleanupTimer
    _activityStatuses.clear();
    if (SettingsService.instance.getValue<bool>('weakNetworkMode', false)) {
      _weakNetworkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(
          MessageSyncService.instance.resyncAfterReconnect([_contactUid]),
        );
      });
    }
  }

  void _initMessageSync() {
    final roomId = _contactUid;
    MessageSyncService.instance.activeRoomId = roomId;
    unawaited(MessageSyncService.instance.markRoomFullySynced(roomId));
    unawaited(_syncRoomIfNeeded(roomId));
  }

  Future<void> _syncRoomIfNeeded(String roomId) async {
    final syncService = MessageSyncService.instance;
    if (syncService.lastSeqOf(roomId) != null) {
      final settings = SettingsService.instance;
      final forceExplicit = settings.getValue<bool>('forceExplicitSync', false);
      final cooldownSeconds =
          int.tryParse(
            settings.getValue<String>('explicitSyncCooldownSeconds', '30'),
          ) ??
          30;
      final cooldown = Duration(seconds: cooldownSeconds);
      if (forceExplicit ||
          syncService.hasPendingGapsFor(roomId) ||
          !syncService.isWithinSyncCooldown(roomId, cooldown)) {
        syncService.recordEntrySync(roomId);
        await syncService.resyncAfterReconnect();
      } else {
        await syncService.silentSyncRoom(roomId);
      }
      return;
    }
    final syncMid =
        await LocalMessageStore.instance.getRoomSyncMid(roomId) ??
        ChatDataService.instance.rooms
            .where((room) => room.id == roomId)
            .map((room) => room.lastMessageMid)
            .firstWhere((mid) => mid != null, orElse: () => null);
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    try {
      if (syncMid != null && syncMid > 0) {
        await syncService.syncRoomFromMid(roomId, syncMid);
      } else {
        await syncService.establishBaseline(roomId);
      }
    } catch (e, stack) {
      talker.error('ChatDetailScreen sync init failed for $roomId', e, stack);
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    for (final timer in _pendingWsTimers.values) {
      timer.cancel();
    }
    _pendingWsTimers.clear();
    _restFallbackAttempted.clear();
    if (MessageSyncService.instance.activeRoomId == _contactUid) {
      MessageSyncService.instance.activeRoomId = null;
    }
    _detachRealtimeListeners();
    _ackErrorSub?.cancel();
    _essenceSub?.cancel();
    _draftTimer?.cancel();
    _weakNetworkTimer?.cancel();
    _typingCleanupTimer?.cancel();
    _entranceKeysTimer?.cancel();
    _groupMetaRefreshTimer?.cancel();
    _jumpGuard?.cancel();
    unawaited(_saveDraft());
    _messageController.dispose();
    // ListController 也是 ChangeNotifier
    _messageListController.dispose();
    _entranceKeys.dispose();
    _activityRevision.dispose();
    _scrollListenerAttached?.removeListener(_onScroll);
    _scrollListenerAttached = null;
    super.dispose();
  }

  void _scheduleDraftSave() {
    if (_suppressDraftSave) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
  }

  Future<void> _restoreDraft(String roomId) async {
    final draft = await DraftService.instance.loadDraft('chat', roomId);
    if (!mounted ||
        _contactUid != roomId ||
        _messageController.text.isNotEmpty) {
      return;
    }
    final text = draft?['text'] as String? ?? '';
    if (text.isNotEmpty) _messageController.text = text;
  }

  Future<void> _saveDraft() => DraftService.instance.saveDraft(
    'chat',
    _contactUid,
    {'text': _messageController.text},
  );

  Future<void> _saveDraftForRoom(String roomId) => DraftService.instance
      .saveDraft('chat', roomId, {'text': _messageController.text});

  void _onAckError(({String clientMid, String error}) info) {
    if (!mounted) return;

    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final idx = msgs.indexWhere((m) => m.clientMid == info.clientMid);
    if (idx != -1 && msgs[idx].media != null) {
      final media = msgs[idx].media!;
      unawaited(
        _wsAckFallback(
          clientMid: info.clientMid,
          content: media.fileHash ?? media.path,
          contentType: 'file',
          fileHash: media.fileHash,
          quoteMid: msgs[idx].quoteMid ?? -1,
          forwardedMid: -1,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(
      _sendFailureText(l10n, info.error),
    );
  }

  /// 发送失败
  String _sendFailureText(AppLocalizations l10n, String? reason) {
    return switch (reason) {
      'banned' || 'account_banned' => l10n.chatSendFailedBanned,
      'account_readonly' => l10n.chatSendFailedReadonly,
      'account_muted' => l10n.chatSendFailedMuted,
      'rate_limited' => l10n.chatSendFailedRateLimited,
      'not_friends' => l10n.chatSendFailedNotFriends,
      'not_group_member' => l10n.chatSendFailedNotGroupMember,
      'message_too_long' => l10n.chatSendFailedTooLong,
      _ => l10n.chatSendFailed,
    };
  }

  void _attachRealtimeListeners() {
    if (_realtimeListenersAttached) return;
    ChatWsService.instance.addListener(_onWsStateChanged);
    ChatDataService.instance.addListener(_onChatDataChanged);
    AppForegroundService.instance.addListener(_onForegroundChanged);
    _essenceSub = NotificationService.instance.essenceChanges.listen(
      _onEssenceChanged,
    );
    _typingSub = ChatWsService.instance.eventStream.listen(_onRealtimeWsEvent);
    _attachUploadProgressListener();
    _realtimeListenersAttached = true;
  }

  void _detachRealtimeListeners() {
    if (!_realtimeListenersAttached) return;
    ChatWsService.instance.removeListener(_onWsStateChanged);
    ChatDataService.instance.removeListener(_onChatDataChanged);
    AppForegroundService.instance.removeListener(_onForegroundChanged);
    _essenceSub?.cancel();
    _essenceSub = null;
    _typingSub?.cancel();
    _typingSub = null;
    _activityStatuses.clear();
    _detachUploadProgressListener();
    _realtimeListenersAttached = false;
  }

  void _onRealtimeWsEvent(ChatWsEvent event) {
    _pruneRecalledEssence(event);
    _onTypingEvent(event);
  }

  void _pruneRecalledEssence(ChatWsEvent event) {
    if (_essenceMids.isEmpty) return;
    if (event.type != 'MESSAGE.NEW' && event.type != 'NOTIFICATION.NEW') return;
    final data = event.notification;
    if (data == null) return;
    final info = NotificationInfo.fromServerMessageInfo(data);
    if (info.event != 'message.recalled' && info.event != 'message.recall') {
      return;
    }
    final mid = info.recalledMid;
    if (mid == null || !_essenceMids.contains(mid)) return;
    if (!mounted) return;
    setState(() => _essenceMids.remove(mid));
  }

  void _onTypingEvent(ChatWsEvent event) {
    if (!mounted ||
        (event.type != 'typing.start' && event.type != 'typing.stop')) {
      return;
    }
    final data = event.notification;
    if (data == null || data['room_id']?.toString() != _contactUid) return;
    final uid = (data['uid'] as num?)?.toInt();
    if (uid == null || uid == AuthState.instance.uid) return;

    final scope = (data['scope'] as String?) ?? 'typing';
    final tsMs = (data['ts'] as num?)?.toInt();
    final progress = (data['progress'] as num?)?.toDouble();

    final serverTime = tsMs != null
        ? DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true)
        : DateTime.now();

    final compositeKey = '$uid:$scope';

    if (event.type == 'typing.start') {
      // 乱序保护！！！！！
      final existing = _activityStatuses[compositeKey];
      if (existing != null && serverTime.isBefore(existing.timestamp)) {
        // 提前返回
        return;
      }
      _activityStatuses[compositeKey] = TypingStatus(
        uid: uid,
        scope: scope,
        updatedAt: DateTime.now(),
        timestamp: serverTime,
        progress: scope == 'uploading' ? progress : null,
      );
    } else {
      if (_activityStatuses.remove(compositeKey) == null) return;
    }
    _activityRevision.value++;
  }

  List<TypingStatus> get _typingStatuses => _activityStatuses.values
      .where((s) => s.scope == 'typing')
      .toList();

  List<TypingStatus> get _uploadingStatuses => _activityStatuses.values
      .where((s) => s.scope == 'uploading')
      .toList();

  List<ChatMessage> _buildUploadPlaceholderMessages() {
    final chatData = ChatDataService.instance;
    return [
      for (final s in _uploadingStatuses)
        () {
          final profile = chatData.getUser('U${s.uid}');
          return ChatMessage(
            id: 'upload-placeholder-${s.uid}',
            senderUid: s.uid,
            text: '',
            timestamp: DateTime.now(),
            isMe: false,
            senderName: profile?.username ?? 'User ${s.uid}',
            senderAvatar: profile?.avatar,
            type: MessageType.text,
            isPlaceholder: true,
            uploadProgress: s.progress ?? 0.0,
          );
        }(),
    ];
  }

  void _attachUploadProgressListener() {
    _uploadProgressSub = ref.listenManual<List<FileTask>>(
      taskManagerProvider,
      (previous, next) => _forwardUploadProgress(),
    );
  }

  void _detachUploadProgressListener() {
    _uploadProgressSub?.close();
    _uploadProgressSub = null;
    _lastUploadProgressSentAt = null;
    _lastUploadProgressByRoom.clear();
  }

  void _forwardUploadProgress() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastUploadProgressSentAt != null &&
        now.difference(_lastUploadProgressSentAt!) <
            const Duration(seconds: 1)) {
      return;
    }
    final tasks = ref.read(taskManagerProvider);
    for (final task in tasks) {
      if (task.type != FileTaskType.upload ||
          task.roomId == null ||
          task.roomId != _contactUid) {
        continue;
      }
      final progress = task.progress;
      if (progress == null) continue;
      final lastProgress = _lastUploadProgressByRoom[task.roomId!];
      if (lastProgress != null && (lastProgress - progress).abs() < 0.01) {
        continue;
      }
      _lastUploadProgressByRoom[task.roomId!] = progress;
      _lastUploadProgressSentAt = now;
      ChatWsService.instance.sendTyping(
        _contactUid,
        progress < 1.0,
        scope: 'uploading',
        progress: progress.clamp(0.0, 1.0),
      );
    }
  }

  bool get _isRoomSyncing =>
      MessageSyncService.instance.isSyncingFor(_contactUid);

  String? get _syncHint {
    final sync = MessageSyncService.instance;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return null;
    if (_isRoomSyncing) {
      final count = sync.syncedCountFor(_contactUid);
      if (count > 0) {
        return l10n.chatSyncHistoryProgress(
          count,
          sync.batchRoundFor(_contactUid),
        );
      }
      return l10n.chatSyncHistory;
    }
    if (sync.syncJustCompletedFor(_contactUid)) {
      return l10n.chatSyncComplete(sync.syncedCountFor(_contactUid));
    }
    return null;
  }

  void _startRealMessaging() {
    if (!AuthState.instance.isLoggedIn) return;

    final ws = ChatWsService.instance;
    _wsConnected = ws.isAuthenticated;
    _attachRealtimeListeners();
    if (!ws.isAuthenticated) ws.connect();

    _ackErrorSub?.cancel();
    _ackErrorSub = ChatDataService.instance.ackErrorStream.listen(_onAckError);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadAndShowMessages();
    });
  }

  /// 消息是否真的被看到
  bool get _readReportAllowed =>
      AppForegroundService.instance.isForeground &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      _isNearBottom;

  void _reportVisibleRead() {
    if (!_readReportAllowed) return;
    final last = _messages.isNotEmpty ? _messages.last : null;
    if (last == null || last.isMe || last.mid == null) return;
    final mid = last.mid!;
    if (_lastReportedReadMid != null && mid <= _lastReportedReadMid!) return;
    if (_clearRoomUnread(mid)) _lastReportedReadMid = mid;
  }

  /// 尾部消息变化时
  void _markVisibleMessagesRead({String? previousLastId}) {
    if (_messages.isEmpty) return;
    if (previousLastId != null && _messages.last.id == previousLastId) return;
    _reportVisibleRead();
  }

  void _onForegroundChanged() {
    if (!mounted || !_treeActive) return;
    if (!AppForegroundService.instance.isForeground) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _refreshReadReceipt();
    _reportVisibleRead();
  }

  /// 本地清未读 + 上报回执。返回回执是否真的发出（断线时为 false）。
  bool _clearRoomUnread(int? lastMid) {
    ChatDataService.instance.clearUnread(_contactUid);
    if (!_wsConnected || lastMid == null) return false;
    return ChatWsService.instance.sendReadReceipt(_contactUid, lastMid);
  }

  Future<void> _loadAndShowMessages() async {
    if (_isLoadingMessages || _isLoadingOlder) return;
    final chatData = ChatDataService.instance;
    final roomId = _contactUid;
    final roomGeneration = _roomGeneration;

    setState(() {
      _isLoadingMessages = true;
      _messagesError = null;
    });

    try {
      final page = await chatData.refreshMessagesForContact(roomId);
      if (!mounted ||
          roomGeneration != _roomGeneration ||
          roomId != _contactUid) {
        return;
      }
      _refreshRoom();

      setState(() {
        _isLoadingMessages = false;
        _hasMoreMessages = page.hasMore;
      });
      _follower.reset();
      _markVisibleMessagesRead();
      _refreshReadReceipt();
      _refreshPresence();
      _scheduleViewportFill();
    } catch (e) {
      if (!mounted ||
          roomGeneration != _roomGeneration ||
          roomId != _contactUid) {
        return;
      }
      talker.error('load messages failed', e);
      setState(() {
        _isLoadingMessages = false;
        _messagesError = AppLocalizations.of(context)?.chatMessagesLoadFailed;
      });
    }
  }
  void _scheduleViewportFill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isLoadingMessages || _isLoadingOlder || !_hasMoreMessages) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        _loadOlder();
      }
    });
  }

  void _refreshPresence() {
    if (_currentRoom?.type != ChatType.direct) return;
    final peerUid = int.tryParse(_contactUid.replaceFirst('U', ''));
    if (peerUid == null) return;
    unawaited(PresenceService.instance.refreshFriends(uids: [peerUid]));
  }

  /// 按需查询自己最后一条消息的已读情况
  /// 群聊无实时推送，兼离线补拉
  void _refreshReadReceipt() {
    if (!FeatureFlags.instance.readReceipt) return;
    final mid = _lastOwnMessageMid;
    if (mid == null) return;
    if (!_readReceiptThrottle.shouldQuery(mid, DateTime.now())) return;
    unawaited(
      ChatDataService.instance
          .refreshReadReceipt(_contactUid, mid)
          .whenComplete(_readReceiptThrottle.done),
    );
  }

  int? get _lastOwnMessageMid {
    for (final message in _messages.reversed) {
      if (message.isMe && !message.isDeleted && message.mid != null) {
        return message.mid;
      }
    }
    return null;
  }

  Future<void> _onRefresh() async {
    await _loadAndShowMessages();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final showBackToBottom = !_isNearBottom;
    if (_showBackToBottom != showBackToBottom && mounted) {
      setState(() => _showBackToBottom = showBackToBottom);
    }
    _follower.notePosition();
    _reportVisibleRead();

    _updatePinnedPageFromScroll();

    // 跳转过程中禁用自动加载更早消息
    if (_isJumpingToMessage ||
        _isLoadingMessages ||
        _isLoadingOlder ||
        !_hasMoreMessages) {
      return;
    }
    final position = _scrollController.position;
    // maxScrollExtent == 0 说明历史没铺满一屏
    if (position.maxScrollExtent <= 0 ||
        position.pixels > position.maxScrollExtent - 50) {
      _loadOlder();
    }
  }

  void _updatePinnedPageFromScroll() {
    if (_pinnedMessages.length <= 1 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 || _messages.length <= 1) return;

    // reverse:true 列表中 index=0 为最新消息，pixels=0 为底部（最新）
    // pixels=max 为顶部（最旧）。
    // 因此消息在滚动坐标中的近似位置与其列表 index 同向
    final total = _messages.length;
    final extentPerItem = position.maxScrollExtent / (total - 1);
    final viewportTop = position.pixels;

    if (!identical(_pinIndexSource, _messages)) {
      _pinIndexSource = _messages;
      _pinMidIndex = {
        for (var i = 0; i < _messages.length; i++)
          if (_messages[i].mid != null) _messages[i].mid!: i,
      };
    }

    int? aheadPage; // 前方 pin 中 msgIndex 最小的（最新）
    int aheadMsgIndex = total;
    int? behindPage; // 后方 pin 中 msgIndex 最大的（最旧）
    int behindMsgIndex = -1;

    for (int i = 0; i < _pinnedMessages.length; i++) {
      final msgIndex = _pinMidIndex[_pinnedMessages[i].messageId] ?? -1;
      if (msgIndex < 0) continue;

      final itemPosition = msgIndex * extentPerItem;

      if (itemPosition >= viewportTop) {
        // 前方（尚未滑过）
        if (msgIndex < aheadMsgIndex) {
          aheadMsgIndex = msgIndex;
          aheadPage = i;
        }
      } else {
        // 后方（已滑过）
        if (msgIndex > behindMsgIndex) {
          behindMsgIndex = msgIndex;
          behindPage = i;
        }
      }
    }

    final page = aheadPage ?? behindPage ?? 0;
    if (page != _pinCurrentPage && mounted) {
      _setPinCurrentPage(page);
    }
  }

  bool _onUserScroll(ScrollNotification notification) {
    _follower.handleScrollNotification(notification);
    return false;
  }

  bool _onScrollMetricsChanged(ScrollMetricsNotification notification) {
    // 跳转过程中
    if (_isJumpingToMessage) return false;
    if (_follower.shouldFollowContentChange) {
      _follower.scrollToBottom(animated: false);
    }
    return false;
  }

  Future<void> _loadOlder() async {
    if (_isLoadingMessages || _isLoadingOlder || !_hasMoreMessages) return;

    final lengthBefore = _messages.length;
    setState(() => _isLoadingOlder = true);
    final roomId = _contactUid;
    final roomGeneration = _roomGeneration;

    bool hasMore;
    try {
      hasMore = await ref
          .read(roomMessagesProvider(roomId).notifier)
          .loadOlder();
    } catch (e) {
      talker.error('load older messages failed', e);
      if (mounted) setState(() => _isLoadingOlder = false);
      return;
    }

    if (!mounted ||
        roomGeneration != _roomGeneration ||
        roomId != _contactUid) {
      return;
    }
    setState(() {
      _isLoadingOlder = false;
      _hasMoreMessages = hasMore;
    });

    // 本轮确实翻到了新内容、且还有更早
    if (_hasMoreMessages && _messages.length > lengthBefore) {
      _scheduleViewportFill();
    }
  }

  void _refreshRoom() {
    final chatData = ChatDataService.instance;
    final profile = chatData.getUser(_contactUid);
    if (profile != null) {
      final updated = ChatRoom(
        id: _contactUid,
        name: chatData.displayNameForRoom(_contactUid, profile.username),
        avatar: profile.avatar,
        type: _currentRoom?.type ?? ChatType.direct,
      );
      if (_currentRoom?.name != updated.name ||
          _currentRoom?.avatar != updated.avatar) {
        _avatarLoadFailed = false;
        _currentRoom = updated;
        if (mounted) setState(() {});
      }
    } else if (!_contactUid.startsWith('G')) {
      final targetUid = _contactUid.startsWith('U')
          ? int.tryParse(_contactUid.substring(1))
          : null;
      if (targetUid != null) {
        TfApiClient.instance.getUserByUid(targetUid).then((p) {
          if (p != null && mounted) {
            talker.info(
              'ChatDetail: refreshRoom fetched uid=${p.uid} avatar=${p.avatar}',
            );
            chatData.cacheUserProfile(p);
            _avatarLoadFailed = false;
            setState(() {
              _currentRoom = ChatRoom(
                id: _contactUid,
                name: chatData.displayNameForRoom(_contactUid, p.username),
                avatar: p.avatar,
                type: _contactUid.startsWith('G')
                    ? ChatType.group
                    : ChatType.direct,
              );
            });
          }
        });
      }
    } else {
      final gid = int.tryParse(_contactUid.substring(1));
      if (gid != null) {
        unawaited(ChatDataService.instance.ensureGroupInfo(gid));
      }
    }
  }

  void _onWsStateChanged() {
    if (!mounted) return;
    final connected = ChatWsService.instance.isAuthenticated;
    final wasConnected = _wsConnected;
    setState(() => _wsConnected = connected);
    if (!connected || wasConnected) return;
    _lastReportedReadMid = null;
    _reportVisibleRead();
    _refreshReadReceipt();
  }

  bool get _isNearBottom => _follower.isNearBottom;

  void _onChatDataChanged() {
    if (!mounted || !_treeActive) return;
    // 跳转过程中
    if (_isJumpingToMessage) return;
    _refreshRoom();
  }

  void _onProviderMessagesChanged(
    List<ChatMessage>? prev,
    List<ChatMessage> next,
  ) {
    if (!mounted || !_treeActive) return;

    // 入场动画
    final entranceKeys = newlyAppendedMessageKeys(prev ?? const [], next);
    if (entranceKeys.isNotEmpty) {
      _entranceKeys.value = entranceKeys;
      _entranceKeysTimer?.cancel();
      _entranceKeysTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted || !_treeActive) return;
        _entranceKeys.value = const {};
      });
    }

    if (_isJumpingToMessage) return;

    final previousLastId = prev != null && prev.isNotEmpty ? prev.last.id : null;
    final countChanged = next.length != (prev?.length ?? 0);
    final lastIdChanged = next.isNotEmpty && next.last.id != previousLastId;
    final wasNearBottom = _isNearBottom;

    if ((countChanged || lastIdChanged) && wasNearBottom) {
      _scrollToBottom();
    }
    if (countChanged || lastIdChanged) {
      _markVisibleMessagesRead(previousLastId: previousLastId);
    }
    // 消息 key
    if (_currentRoom?.type == ChatType.group) {
      _scheduleGroupMetaRefresh();
    }
  }

  void _scheduleGroupMetaRefresh() {
    _groupMetaRefreshTimer?.cancel();
    _groupMetaRefreshTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_treeActive) return;
      unawaited(_fetchPinnedMessages());
      unawaited(_fetchEssenceMessages());
      _refreshReadReceipt();
    });
  }

  void _loadChatRoom() {
    final chatData = ChatDataService.instance;
    final profile = chatData.getUser(_contactUid);
    _mentionUsers.clear();
    _pinnedMessages.clear();
    _pinnedMessageContents.clear();
    _fetchingPinsRoomId = null;
    if (profile != null && _contactUid.startsWith('U')) {
      _mentionUsers.add(
        MentionUser(
          id: profile.uid.replaceFirst('U', ''),
          username: profile.username,
          avatarUrl: profile.avatar,
        ),
      );
    }

    _currentRoom = ChatRoom(
      id: _contactUid,
      name: chatData.displayNameForRoom(
        _contactUid,
        profile?.username ??
            (_contactUid.startsWith('G')
                ? 'Group ${_contactUid.substring(1)}'
                : _contactUid),
      ),
      avatar: profile?.avatar,
      type: _contactUid.startsWith('G') ? ChatType.group : ChatType.direct,
    );
    _avatarLoadFailed = false;
    setState(() {});

    final targetUid = _contactUid.startsWith('U')
        ? int.tryParse(_contactUid.substring(1))
        : null;
    if (targetUid != null) {
      TfApiClient.instance.getUserByUid(targetUid).then((p) {
        if (p != null && mounted) {
          talker.info(
            'ChatDetail: fetched profile uid=${p.uid} avatar=${p.avatar}',
          );
          chatData.cacheUserProfile(p);
          _mentionUsers
            ..clear()
            ..add(
              MentionUser(id: p.uid, username: p.username, avatarUrl: p.avatar),
            );
          _avatarLoadFailed = false;
          setState(() {
            _currentRoom = ChatRoom(
              id: _contactUid,
              name: chatData.displayNameForRoom(_contactUid, p.username),
              avatar: p.avatar,
              type: _contactUid.startsWith('G')
                  ? ChatType.group
                  : ChatType.direct,
            );
          });
        }
      });
    } else if (_contactUid.startsWith('G')) {
      final gid = int.tryParse(_contactUid.substring(1));
      if (gid != null) {
        unawaited(ChatDataService.instance.ensureGroupInfo(gid));
      }
      unawaited(_loadMentionUsers());
      unawaited(_fetchEssenceMessages());
    }
  }

  Future<void> _loadMentionUsers() async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    if (uid == null || password == null || gid == null) return;

    final result = await TfApiClient.instance.getGroupMembers(
      uid,
      password,
      gid,
    );
    final members = result?['members'] as List<dynamic>?;
    if (members == null) return;
    final settings = result?['settings'] as Map<String, dynamic>?;
    final enterHint = settings?['enter_hint'] as String? ?? '';
    final normalizedEnterHint = enterHint.trim();
    final showEnterHint =
        normalizedEnterHint.isNotEmpty &&
        !await DraftService.instance.isAcknowledged(
          'group_enter_hint',
          gid.toString(),
          normalizedEnterHint,
        );
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    final chatData = ChatDataService.instance;
    for (final raw in members) {
      final member = Map<String, dynamic>.from(raw as Map);
      final memberUid = (member['uid'] as num).toInt();
      if (memberUid == uid) continue;
      chatData.cacheUserProfile(
        UserProfile(
          uid: 'U$memberUid',
          username: member['username'] as String? ?? 'User $memberUid',
          email: '',
          stat: 'user',
          createTime: '0',
          avatar: '$baseUrl/avatar/get_avatar/user/$memberUid',
        ),
      );
    }
    final mentionUsers = members
        .map((raw) {
          final member = Map<String, dynamic>.from(raw as Map);
          final memberUid = (member['uid'] as num).toInt();
          return MentionUser(
            id: memberUid.toString(),
            username: member['username'] as String? ?? 'User $memberUid',
            avatarUrl: '$baseUrl/avatar/get_avatar/user/$memberUid',
          );
        })
        .where((member) => member.id != uid.toString())
        .toList();
    final currentMember = members.cast<dynamic>().firstWhere(
      (raw) => raw is Map && (raw['uid'] as num?)?.toInt() == uid,
      orElse: () => null,
    );
    final currentRole = currentMember is Map
        ? currentMember['role']?.toString().toLowerCase()
        : null;
    if (!mounted || _contactUid != 'G$gid') return;
    setState(() {
      _mentionUsers
        ..clear()
        ..addAll(mentionUsers);
      _groupEnterHint = normalizedEnterHint;
      _showGroupEnterHint = showEnterHint;
      _canModerateGroup = currentRole == 'owner' || currentRole == 'admin';
    });
    unawaited(_fetchPinnedMessages());
  }

  void _startReply(ChatMessage message) {
    if (message.mid == null || message.isDeleted) return;
    _setReplyingTo(message);
    _setForwardingTo(null);
  }

  void _startForward(ChatMessage message) {
    if (message.mid == null || message.isDeleted) return;
    context.push(AppRoutes.forward, extra: message);
  }

  Future<void> _copySelectedMessages() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedMessages;
    if (selected.isEmpty) {
      TouchFishSnackbarService.instance.show(l10n.copySelectedEmpty);
      return;
    }
    final hasMedia = selected.any((m) => !m.isDeleted && m.media != null);
    final result = await MessageClipboardService.instance.copyMessages(
      selected,
      l10n: l10n,
    );
    if (!mounted) return;
    switch (result) {
      case MessageCopyResult.empty:
        TouchFishSnackbarService.instance.show(l10n.copySelectedEmpty);
      case MessageCopyResult.files:
        TouchFishSnackbarService.instance.show(l10n.messageCopiedAsFile);
      case MessageCopyResult.text:
        TouchFishSnackbarService.instance.show(
          hasMedia ? l10n.messageCopyFileFallback : l10n.aboutCopiedToClipboard,
          type: hasMedia ? SnackbarType.warning : SnackbarType.info,
        );
      case MessageCopyResult.failed:
        TouchFishSnackbarService.instance.show(
          l10n.copyFailedText,
          type: SnackbarType.error,
        );
    }
  }

  Future<void> _mergeForwardSelected() async {
    final target = await _pickMergeForwardTarget();
    if (target == null || !mounted) return;
    await _redirectSelected(target.roomId, target.name);
  }

  Future<void> _redirectToCurrentChat() async {
    final room = _currentRoom;
    if (room == null) return;
    await _redirectSelected(_contactUid, room.name);
  }

  Future<bool> _redirectSelected(
    String destinationRoomId,
    String destinationName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedMessages;
    if (selected.isEmpty) return false;
    if (selected.length > 100) {
      TouchFishSnackbarService.instance.show(l10n.mergeForwardTooMany);
      return false;
    }
    if (selected.any((m) => m.type != MessageType.text || m.isDeleted)) {
      TouchFishSnackbarService.instance.show(l10n.mergeForwardTextOnly);
      return false;
    }
    final mids = selected
        .map((m) => m.mid)
        .whereType<int>()
        .toList();
    if (mids.isEmpty) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mergeForwardConfirmTitle),
        content: Text(
          l10n.mergeForwardConfirmBody(selected.length, destinationName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return false;

    final result = await TfApiClient.instance.redirectMessages(
      uid,
      password,
      recipient: destinationRoomId,
      mids: mids,
      clientMid: 'c${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!mounted) return false;
    if (result != null) {
      _exitSelection();
      TouchFishSnackbarService.instance.show(l10n.mergeForwardSuccess);
      return true;
    }
    TouchFishSnackbarService.instance.show(l10n.mergeForwardFailed);
    return false;
  }

  Future<_MergeForwardTarget?> _pickMergeForwardTarget() async {
    final l10n = AppLocalizations.of(context)!;
    final data = ChatDataService.instance;
    final targets = <_MergeForwardTarget>[];
    for (final contact in data.contacts) {
      targets.add(
        _MergeForwardTarget(roomId: contact.id, name: contact.name),
      );
    }
    for (final room in data.rooms) {
      if (room.id.startsWith('G')) {
        targets.add(_MergeForwardTarget(roomId: room.id, name: room.name));
      }
    }
    final seen = <String>{};
    final unique = targets.where((t) => seen.add(t.roomId)).toList();

    return showModalBottomSheet<_MergeForwardTarget>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.forwardSearchTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in unique)
                      ListTile(
                        leading: Icon(
                          t.roomId.startsWith('G') ? Icons.group : Icons.person,
                          color: colorScheme.primary,
                        ),
                        title: Text(t.name),
                        onTap: () => Navigator.pop(ctx, t),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canRecall(ChatMessage message) {
    if (message.mid == null || message.isDeleted) return false;
    if (message.isMe) return true;
    if (AuthState.instance.currentUser?.hasAdminAccess == true) return true;
    return _currentRoom?.type == ChatType.group && _canModerateGroup;
  }

  /// 仅本机未发送/发送失败的消息
  bool _canDeleteLocally(ChatMessage message) {
    return message.isMe &&
        message.mid == null &&
        !message.isDeleted &&
        (message.status == MessageStatus.failed ||
            message.status == MessageStatus.pending);
  }

  Future<void> _startVideoCall() async {
    if (_currentRoom?.type != ChatType.direct) return;
    final uid = int.tryParse(_contactUid.startsWith('U')
        ? _contactUid.substring(1)
        : '');
    if (uid == null) return;
    final ok = await CallService.instance.startCall(uid);
    if (ok && mounted) {
      context.push(AppRoutes.callPath(uid));
    }
  }

  void _deleteLocalMessage(ChatMessage message) {
    final clientMid = message.clientMid;
    if (clientMid != null) {
      _pendingWsTimers.remove(clientMid)?.cancel();
    }
    if (_replyingTo?.clientMid == clientMid || _replyingTo?.id == message.id) {
      _setReplyingTo(null);
    }
    if (_forwardingTo?.clientMid == clientMid ||
        _forwardingTo?.id == message.id) {
      _setForwardingTo(null);
    }
    // deleteLocalMessage 通知房间
    ChatDataService.instance.deleteLocalMessage(_contactUid, message);
  }

  Future<void> _recallMessage(ChatMessage message) async {
    if (!_canRecall(message)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.messageRecallConfirmTitle),
        content: Text(l10n.messageRecallConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.messageActionRecall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final mid = message.mid;
    if (uid == null || password == null || mid == null) return;
    final recalled = await TfApiClient.instance.recallMessage(
      uid,
      password,
      mid,
    );
    if (!mounted) return;
    if (recalled != null) {
      final deletedAtRaw = recalled['deleted_at'];
      final deletedAt = deletedAtRaw is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (deletedAtRaw.toDouble() * 1000).toInt(),
            )
          : DateTime.tryParse(deletedAtRaw?.toString() ?? '');
      ChatDataService.instance.markMessageRecalled(
        mid,
        roomId: _contactUid,
        deletedAt: deletedAt,
        deletedBy: (recalled['deleted_by'] as num?)?.toInt() ?? uid,
      );
      if (_replyingTo?.mid == mid) _setReplyingTo(null);
      if (_currentRoom?.type == ChatType.group) {
        unawaited(_fetchPinnedMessages());
        unawaited(_fetchEssenceMessages());
      }
    } else {
      TouchFishSnackbarService.instance.show(l10n.messageRecallFailed);
    }
  }

  Future<void> _fetchEssenceMessages() async {
    final roomId = _contactUid;
    if (!roomId.startsWith('G') || _fetchingEssenceRoomId == roomId) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(roomId.substring(1));
    if (uid == null || password == null || gid == null) return;

    _fetchingEssenceRoomId = roomId;
    try {
      final result = await TfApiClient.instance.queryEssence(
        uid,
        password,
        gid,
      );
      if (mounted && roomId == _contactUid && result != null) {
        setState(() {
          _essenceMids = result.mids;
          _essenceEnabled = result.essenceEnabled;
        });
      }
    } finally {
      if (_fetchingEssenceRoomId == roomId) {
        _fetchingEssenceRoomId = null;
      }
    }
  }

  Future<void> _fetchPinnedMessages() async {
    // 按房去重
    final roomId = _contactUid;
    if (_fetchingPinsRoomId == roomId) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(roomId.substring(1));
    if (uid == null || password == null || gid == null) return;

    _fetchingPinsRoomId = roomId;
    try {
      final pins = await TfApiClient.instance.getPinnedMessages(
        uid,
        password,
        gid,
      );
      if (!mounted || roomId != _contactUid) return;
      final currentMessageId =
          _pinnedMessages.isNotEmpty &&
              _pinCurrentPage >= 0 &&
              _pinCurrentPage < _pinnedMessages.length
          ? _pinnedMessages[_pinCurrentPage].messageId
          : null;
      setState(() {
        _pinnedMessages = pins;
      });
      if (pins.isNotEmpty) {
        final retainedPage = currentMessageId == null
            ? -1
            : pins.indexWhere((pin) => pin.messageId == currentMessageId);
        _setPinCurrentPage(retainedPage >= 0 ? retainedPage : pins.length - 1);
      } else {
        _setPinCurrentPage(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updatePinnedPageFromScroll();
      });
      unawaited(_resolvePinnedContents(pins));
    } catch (_) {
      // server eror 不能一直 retry 啦
    } finally {
      if (_fetchingPinsRoomId == roomId) _fetchingPinsRoomId = null;
    }
  }

  Future<void> _resolvePinnedContents(List<PinnedMessage> pins) async {
    for (final pin in pins) {
      final messageId = pin.messageId;
      if (_pinnedMessageContents.containsKey(messageId)) continue;
      final msg = await ChatDataService.instance.findMessageByMid(
        _contactUid,
        messageId,
      );
      if (!mounted) return;
      if (_pinnedMessageContents.containsKey(messageId) || msg == null) {
        continue;
      }
      // 置顶消息已被撤回/删除时不再展示
      if (msg.isDeleted) {
        if (_pinnedMessages.any((p) => p.messageId == messageId)) {
          unawaited(_fetchPinnedMessages());
        }
        continue;
      }
      setState(() {
        _pinnedMessageContents[messageId] = msg;
      });
    }
  }

  Future<void> _toggleEssence(ChatMessage message) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    final mid = message.mid;
    if (uid == null || password == null || gid == null || mid == null) return;
    if (_essenceMids.contains(mid)) {
      final ok = await TfApiClient.instance.removeEssence(
        uid,
        password,
        gid,
        mid,
      );
      if (ok && mounted && _contactUid == 'G$gid') {
        setState(() {
          _essenceMids.remove(mid);
        });
      } else if (!ok && mounted) {
        _showEssenceOperationFailed();
      }
    } else {
      final ok = await TfApiClient.instance.addEssence(uid, password, gid, mid);
      if (ok && mounted && _contactUid == 'G$gid') {
        setState(() {
          if (!_essenceMids.contains(mid)) _essenceMids.add(mid);
        });
      } else if (!ok && mounted) {
        _showEssenceOperationFailed();
      }
    }
  }

  void _showEssenceOperationFailed() {
    TouchFishSnackbarService.instance.show(
      AppLocalizations.of(context)!.commonFailedOperation,
    );
  }

  Future<void> _togglePin(ChatMessage message) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    final gid = int.tryParse(_contactUid.substring(1));
    final mid = message.mid;
    if (uid == null || password == null || gid == null || mid == null) return;

    final existingPin = _pinnedMessages.cast<PinnedMessage?>().firstWhere(
      (p) => p?.messageId == mid,
      orElse: () => null,
    );

    if (existingPin != null) {
      final ok = await TfApiClient.instance.unpinMessage(
        uid,
        password,
        gid,
        existingPin.pinId,
      );
      if (ok && mounted) {
        setState(() {
          _pinnedMessages.removeWhere((p) => p.pinId == existingPin.pinId);
        });
      }
    } else {
      final ok = await TfApiClient.instance.pinMessage(uid, password, gid, mid);
      if (ok && mounted) {
        unawaited(_fetchPinnedMessages());
      }
    }
  }

  /// 本地插入待发消息
  void _appendLocalMessage(ChatMessage message) {
    try {
      ChatDataService.instance.addSentMessage(_contactUid, message);
    } catch (error, stackTrace) {
      talker.error(
        'ChatDetail: append local message failed',
        error,
        stackTrace,
      );
      unawaited(_loadAndShowMessages());
    }
  }

  void _sendMessage() {
    unawaited(_sendMessageAsync());
  }

  Future<void> _sendMessageAsync() async {
    final text = _messageController.text.trim();
    final forwardTarget = _forwardingTo;
    if (text.isEmpty && forwardTarget == null) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;
    final forwardedMid = forwardTarget?.mid ?? -1;
    final outgoingText = forwardTarget?.text ?? text;
    final outgoingType = forwardTarget?.type ?? MessageType.text;

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      mid: null,
      text: outgoingText,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.pending,
      type: outgoingType,
      media: forwardTarget?.media,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : _quotePreviewFor(replyTarget),
      forwardedMid: forwardedMid >= 0 ? forwardedMid : null,
      forwardPreview: forwardTarget == null
          ? null
          : _quotePreviewFor(forwardTarget),
    );

    _clearReplyAction();
    _messageController.clear();
    unawaited(DraftService.instance.clearDraft('chat', _contactUid));
    _scrollToBottom();

    _appendLocalMessage(userMessage);

    try {
      // WS，启动！
      bool wsSent = false;
      if (_wsConnected && forwardTarget == null) {
        if (_contactUid.startsWith('G')) {
          final gid = int.tryParse(_contactUid.substring(1));
          if (gid != null) {
            wsSent = await ChatWsService.instance.sendGroupTextMessage(
              gid,
              text,
              clientMid: clientMid,
              quote: quoteMid,
            );
          }
        } else {
          final targetUid = int.tryParse(_contactUid.substring(1));
          if (targetUid != null) {
            wsSent = await ChatWsService.instance.sendTextMessage(
              targetUid.toString(),
              text,
              clientMid: clientMid,
              quote: quoteMid,
            );
          }
        }
      }
      if (!wsSent) {
        // REST
        final recipient = _contactUid;
        final result = await TfApiClient.instance.sendMessage(
          uid,
          password,
          recipient: recipient,
          content: outgoingText,
          contentType: outgoingType == MessageType.file ? 'file' : 'plain',
          fileHash: forwardTarget?.media?.fileHash,
          clientMid: clientMid,
          quote: quoteMid,
          forwarded: forwardedMid,
        );
        if (result != null) {
          final mid = (result['mid'] as num?)?.toInt();
          _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
        } else {
          _failMessage(clientMid, reason: 'send.rejected');
          _restoreFailedDraft(text);
          if (mounted) {
            final l10n = AppLocalizations.of(context)!;
            TouchFishSnackbarService.instance.show(
              _sendFailureText(l10n, TfApiClient.instance.lastContentError),
            );
          }
        }
      } else {
        // 准备 restful api 回退
        _pendingWsTimers[clientMid]?.cancel();
        _pendingWsTimers[clientMid] = Timer(
          const Duration(seconds: 15),
          () => _wsAckFallback(
            clientMid: clientMid,
            content: outgoingText,
            contentType: outgoingType == MessageType.file ? 'file' : 'plain',
            fileHash: forwardTarget?.media?.fileHash,
            quoteMid: quoteMid,
            forwardedMid: forwardedMid,
          ),
        );
      }
    } catch (e) {
      talker.error('ChatDetail text send failed', e);
      _failMessage(clientMid, reason: 'send.network');
      _restoreFailedDraft(text);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        TouchFishSnackbarService.instance.show(l10n.chatSendFailed);
      }
    }
  }

  void _restoreFailedDraft(String text) {
    if (text.isEmpty || _messageController.text.isNotEmpty) return;
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
  }

  /// 重发失败的消息
  List<ChatMessage> get _failedMessages => _messages
      .where(
        (m) => m.status == MessageStatus.failed && m.clientMid != null,
      )
      .toList(growable: false);

  /// 逐条重发
  Future<void> _retryAllFailed() async {
    final pending = _failedMessages;
    if (pending.isEmpty) return;
    for (final message in pending) {
      if (!mounted) return;
      await _resendMessage(message);
    }
  }

  Future<void> _resendMessage(ChatMessage message) async {
    final clientMid = message.clientMid;
    if (clientMid == null || message.status != MessageStatus.failed) return;
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    _pendingWsTimers.remove(clientMid)?.cancel();
    _restFallbackAttempted.remove(clientMid);
    _updateMessageStatus(clientMid, status: MessageStatus.pending);

    final quoteMid = message.quoteMid ?? -1;
    final forwardedMid = message.forwardedMid ?? -1;

    try {
      final media = message.media;
      if (media != null) {
        final existingHash = media.fileHash;
        if (existingHash != null && existingHash.isNotEmpty) {
          // 文件已在服务器
          await _dispatchFileSend(
            clientMid: clientMid,
            hash: existingHash,
            quoteMid: quoteMid,
            durationMs: media.durationMs,
            forwardedMid: forwardedMid,
          );
        } else {
          await _reuploadFailedMedia(
            message,
            clientMid: clientMid,
            quoteMid: quoteMid,
            forwardedMid: forwardedMid,
          );
        }
        return;
      }

      final text = message.text;
      bool wsSent = false;
      // 转发消息 REST
      // why no ws
      if (_wsConnected && forwardedMid < 0) {
        if (_contactUid.startsWith('G')) {
          final gid = int.tryParse(_contactUid.substring(1));
          if (gid != null) {
            wsSent = await ChatWsService.instance.sendGroupTextMessage(
              gid,
              text,
              clientMid: clientMid,
              quote: quoteMid,
            );
          }
        } else {
          final targetUid = int.tryParse(_contactUid.substring(1));
          if (targetUid != null) {
            wsSent = await ChatWsService.instance.sendTextMessage(
              targetUid.toString(),
              text,
              clientMid: clientMid,
              quote: quoteMid,
            );
          }
        }
      }
      if (!wsSent) {
        final result = await TfApiClient.instance.sendMessage(
          uid,
          password,
          recipient: _contactUid,
          content: text,
          contentType: 'plain',
          clientMid: clientMid,
          quote: quoteMid,
          forwarded: forwardedMid,
        );
        if (result != null) {
          final mid = (result['mid'] as num?)?.toInt();
          _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
        } else {
          _failMessage(clientMid, reason: 'send.rejected');
          _showSendFailedSnackBar();
        }
      } else {
        _pendingWsTimers[clientMid]?.cancel();
        _pendingWsTimers[clientMid] = Timer(
          const Duration(seconds: 15),
          () => _wsAckFallback(
            clientMid: clientMid,
            content: text,
            contentType: 'plain',
            quoteMid: quoteMid,
            forwardedMid: forwardedMid,
          ),
        );
      }
    } catch (e) {
      talker.error('ChatDetail resend failed', e);
      _failMessage(clientMid, reason: 'send.network');
      _showSendFailedSnackBar();
    }
  }

  /// 媒体消息上传失败
  Future<void> _reuploadFailedMedia(
    ChatMessage message, {
    required String clientMid,
    required int quoteMid,
    int forwardedMid = -1,
  }) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final media = message.media;
    if (media == null) return;

    List<int>? bytes = media.bytes;
    if (bytes == null && !kIsWeb && media.path.isNotEmpty) {
      final file = File(media.path);
      if (await file.exists()) bytes = await file.readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      _failMessage(clientMid, reason: 'send.upload');
      _showSendFailedSnackBar();
      return;
    }

    final taskManager = ref.read(taskManagerProvider.notifier);
    final hash = await FileService.instance.uploadFile(
      uid: uid,
      password: password,
      fileName: media.fileName ?? 'file',
      bytes: bytes,
      filePath: kIsWeb ? null : media.path,
      clientMid: clientMid,
      roomId: _contactUid,
      taskManager: taskManager,
    );
    if (hash == null) {
      _failMessage(clientMid, reason: 'send.upload');
      _showSendFailedSnackBar();
      return;
    }

    final baseUrl = await TfApiClient.instance.getBaseUrl();
    _updateMessageMedia(
      clientMid,
      media.copyWith(path: '$baseUrl/file/get_file/$hash', fileHash: hash),
    );
    await _dispatchFileSend(
      clientMid: clientMid,
      hash: hash,
      quoteMid: quoteMid,
      durationMs: media.durationMs,
      forwardedMid: forwardedMid,
    );
  }

  Future<void> _wsAckFallback({
    required String clientMid,
    required String content,
    required String contentType,
    String? fileHash,
    required int quoteMid,
    required int forwardedMid,
    int? durationMs,
  }) async {
    _pendingWsTimers.remove(clientMid);
    if (!mounted) return;
    if (!_restFallbackAttempted.add(clientMid)) return;

    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final idx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (idx == -1 || msgs[idx].status == MessageStatus.sent) return;
    if (msgs[idx].status == MessageStatus.failed && msgs[idx].media == null) {
      return;
    }

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    final result = await TfApiClient.instance.sendMessage(
      uid,
      password,
      recipient: _contactUid,
      content: content,
      contentType: contentType,
      fileHash: fileHash,
      clientMid: clientMid,
      quote: quoteMid,
      forwarded: forwardedMid,
      durationMs: durationMs,
    );
    if (!mounted) return;
    if (result != null) {
      final serverMid = (result['mid'] as num?)?.toInt();
      _updateMessageStatus(
        clientMid,
        mid: serverMid,
        status: MessageStatus.sent,
      );
    } else {
      _failMessage(clientMid, reason: 'send.rejected');
      _showSendFailedSnackBar();
    }
  }

  void _updateMessageStatus(
    String clientMid, {
    int? mid,
    MessageStatus? status,
    String? ackError,
    bool clearAckError = false,
  }) {
    _pendingWsTimers.remove(clientMid)?.cancel();
    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final cIdx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (cIdx != -1) {
      final updated = msgs.toList();
      updated[cIdx] = updated[cIdx].copyWith(
        id: mid?.toString() ?? updated[cIdx].id,
        mid: mid ?? updated[cIdx].mid,
        status: status ?? updated[cIdx].status,
        ackError: ackError,
        clearAckError:
            clearAckError ||
            (status == MessageStatus.sent && ackError == null),
      );
      ChatDataService.instance.setMessages(_contactUid, updated);
    }
  }

  /// 消息标记为发送失败
  void _failMessage(String clientMid, {required String reason}) {
    _updateMessageStatus(
      clientMid,
      status: MessageStatus.failed,
      ackError: reason,
    );
  }

  void _updateMessageMedia(String clientMid, MessageMedia media) {
    final msgs = ChatDataService.instance.getMessages(_contactUid);
    final cIdx = msgs.indexWhere((m) => m.clientMid == clientMid);
    if (cIdx != -1) {
      final updated = msgs.toList();
      updated[cIdx] = updated[cIdx].copyWith(media: media);
      ChatDataService.instance.setMessages(_contactUid, updated);
    }
  }

  Future<void> _sendVoiceMessage(String filePath, int durationMs) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;

    final file = File(filePath);
    if (!await file.exists()) return;
    final ext = path.extension(filePath).replaceFirst('.', '').toLowerCase();
    final resolvedExt = ext.isEmpty ? 'm4a' : ext;
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.$resolvedExt';
    final mimeType = lookupMimeType(fileName) ??
        (resolvedExt == 'wav' ? 'audio/wav' : 'audio/mp4');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final maxSize = await TfApiClient.instance.getMaxFileSize();
    if (maxSize != null && bytes.length > maxSize) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        TouchFishSnackbarService.instance.show(
          l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
        );
      }
      return;
    }

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final media = MessageMedia(
      path: filePath,
      fileName: fileName,
      fileSize: bytes.length,
      mimeType: mimeType,
      bytes: bytes,
      durationMs: durationMs,
    );
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      text: '[AUDIO]',
      timestamp: DateTime.now(),
      isMe: true,
      type: MessageType.audio,
      media: media,
      status: MessageStatus.pending,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : _quotePreviewFor(replyTarget),
    );

    if (!mounted) return;
    _setReplyingTo(null);
    _appendLocalMessage(userMessage);
    _scrollToBottom();

    try {
      final taskManager = ref.read(taskManagerProvider.notifier);
      final hash = await FileService.instance.uploadFile(
        uid: uid,
        password: password,
        fileName: fileName,
        bytes: bytes,
        filePath: filePath,
        clientMid: clientMid,
        roomId: _contactUid,
        taskManager: taskManager,
      );
      if (hash == null) {
        _failMessage(clientMid, reason: 'send.upload');
        return;
      }
      final baseUrl = await TfApiClient.instance.getBaseUrl();
      _updateMessageMedia(
        clientMid,
        MessageMedia(
          path: '$baseUrl/file/get_file/$hash',
          fileName: fileName,
          fileSize: bytes.length,
          mimeType: mimeType,
          bytes: bytes,
          fileHash: hash,
          durationMs: durationMs,
        ),
      );
      await _dispatchFileSend(
        clientMid: clientMid,
        hash: hash,
        quoteMid: quoteMid,
        durationMs: durationMs,
      );
    } catch (e) {
      talker.error('ChatDetail voice send failed', e);
      _failMessage(clientMid, reason: 'send.network');
      _showSendFailedSnackBar();
    }
  }

  Future<void> _sendMediaMessage(
    PlatformFile platformFile,
    MessageType type,
  ) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;

    String filePath;
    String fileName;
    int fileSize;
    List<int>? bytes;

    if (kIsWeb) {
      fileName = platformFile.name;
      filePath =
          'web_upload_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      fileSize = platformFile.bytes?.length ?? 0;
      bytes = platformFile.bytes;
    } else if (platformFile.bytes != null) {
      // 从剪贴板粘贴
      fileName = platformFile.name;
      filePath = 'clipboard_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      fileSize = platformFile.bytes!.length;
      bytes = platformFile.bytes;
    } else {
      filePath = platformFile.path!;
      fileName = path.basename(filePath);
      final file = File(filePath);
      // 获取文件大小
      fileSize = await file.length();
    }

    final maxSize = await TfApiClient.instance.getMaxFileSize();
    if (maxSize != null && fileSize > maxSize) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        TouchFishSnackbarService.instance.show(
          l10n.storageFileTooLarge((maxSize / (1024 * 1024)).round()),
        );
      }
      return;
    }

    // 读文件到内存中（Web 在 platformFile.bytes 中）
    if (!kIsWeb) {
      bytes = platformFile.bytes ?? await File(filePath).readAsBytes();
    }

    if (bytes == null) return;

    String messageText = '';
    switch (type) {
      case MessageType.image:
        messageText = '[IMAGE]';
        break;
      case MessageType.video:
        messageText = '[VIDEO]';
        break;
      case MessageType.audio:
        messageText = '[AUDIO]';
        break;
      case MessageType.file:
        messageText = '[FILE] $fileName';
        break;
      default:
        messageText = fileName;
    }

    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final media = MessageMedia(
      path: filePath,
      fileName: fileName,
      fileSize: fileSize,
      bytes: bytes,
    );
    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      text: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      media: media,
      status: MessageStatus.pending,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : _quotePreviewFor(replyTarget),
    );

    _setReplyingTo(null);
    _appendLocalMessage(userMessage);
    _scrollToBottom();

    try {
      final taskManager = ref.read(taskManagerProvider.notifier);
      // 图片先本地压缩
      var uploadBytes = bytes;
      var uploadName = fileName;
      if (type == MessageType.image) {
        final prepared = await ImageCompressionService.instance
            .prepareForUpload(bytes: bytes, fileName: fileName);
        if (prepared != null) {
          uploadBytes = prepared.bytes;
          uploadName = prepared.fileName;
        }
      }
      final hash = await FileService.instance.uploadFile(
        uid: uid,
        password: password,
        fileName: uploadName,
        bytes: uploadBytes,
        filePath: kIsWeb ? null : filePath,
        clientMid: clientMid,
        roomId: _contactUid,
        taskManager: taskManager,
      );
      if (hash == null) {
        _failMessage(clientMid, reason: 'send.upload');
        return;
      }

      final baseUrl = await TfApiClient.instance.getBaseUrl();
      _updateMessageMedia(
        clientMid,
        MessageMedia(
          path: '$baseUrl/file/get_file/$hash',
          fileName: uploadName,
          fileSize: uploadBytes.length,
          mimeType: lookupMimeType(uploadName),
          // 本地预览继续用原图
          bytes: bytes,
          fileHash: hash,
        ),
      );

      await _dispatchFileSend(
        clientMid: clientMid,
        hash: hash,
        quoteMid: quoteMid,
      );
    } catch (e) {
      talker.error('ChatDetail file send failed', e);
      _failMessage(clientMid, reason: 'send.network');
      _showSendFailedSnackBar();
    }
  }

  /// 按 hash 发送文件消息
  Future<void> _dispatchFileSend({
    required String clientMid,
    required String hash,
    required int quoteMid,
    int? durationMs,
    int forwardedMid = -1,
  }) async {
    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;

    bool wsSent = false;
    if (_wsConnected && forwardedMid < 0) {
      if (_contactUid.startsWith('G')) {
        final gid = int.tryParse(_contactUid.substring(1));
        if (gid != null) {
          wsSent = await ChatWsService.instance.sendGroupFileMessage(
            gid,
            hash,
            clientMid: clientMid,
            quote: quoteMid,
            durationMs: durationMs,
          );
        }
      } else {
        final peerUid = int.tryParse(_contactUid.substring(1));
        if (peerUid != null) {
          wsSent = await ChatWsService.instance.sendFileMessage(
            peerUid.toString(),
            hash,
            clientMid: clientMid,
            quote: quoteMid,
            durationMs: durationMs,
          );
        }
      }
    }

    if (!wsSent) {
      final recipient = _contactUid;
      final result = await TfApiClient.instance.sendMessage(
        uid,
        password,
        recipient: recipient,
        content: hash,
        contentType: 'file',
        clientMid: clientMid,
        fileHash: hash,
        quote: quoteMid,
        forwarded: forwardedMid,
        durationMs: durationMs,
      );
      if (result != null) {
        final mid = (result['mid'] as num?)?.toInt();
        _updateMessageStatus(clientMid, mid: mid, status: MessageStatus.sent);
      } else {
        _failMessage(clientMid, reason: 'send.rejected');
        _showSendFailedSnackBar();
      }
    } else {
      // REST 再试一次
      _pendingWsTimers[clientMid]?.cancel();
      _pendingWsTimers[clientMid] = Timer(
        const Duration(seconds: 15),
        () => _wsAckFallback(
          clientMid: clientMid,
          content: hash,
          contentType: 'file',
          fileHash: hash,
          quoteMid: quoteMid,
          forwardedMid: forwardedMid,
          durationMs: durationMs,
        ),
      );
    }
  }

  /// 发送失败提示
  void _showSendFailedSnackBar([String? reason]) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(
      _sendFailureText(l10n, reason ?? TfApiClient.instance.lastContentError),
    );
  }

  /// 发送服务端已存在的文件
  Future<void> _sendServerFile(
    Map<String, dynamic> file,
    MessageType type,
  ) async {
    final uid = AuthState.instance.uid;
    if (uid == null) return;
    final hash = file['hash'] as String? ?? '';
    if (hash.isEmpty) return;
    final fileName = file['file_name'] as String? ?? hash;
    final fileSize = (file['size'] as num?)?.toInt() ?? 0;
    final rawMime = file['mime_type'] as String?;
    final mimeType = (rawMime == null || rawMime == 'application/octet-stream')
        ? null
        : rawMime;
    final downloadUrl = file['download_url'] as String?;

    final replyTarget = _replyingTo;
    final quoteMid = replyTarget?.mid ?? -1;
    final clientMid = 'c${DateTime.now().microsecondsSinceEpoch}';
    final baseUrl = await TfApiClient.instance.getBaseUrl();
    // 服务端返回的 download_url 是相对路径
    final mediaPath = (downloadUrl != null && downloadUrl.startsWith('http'))
        ? downloadUrl
        : '$baseUrl/file/get_file/$hash';
    final messageText = switch (type) {
      MessageType.image => '[IMAGE]',
      MessageType.video => '[VIDEO]',
      MessageType.audio => '[AUDIO]',
      MessageType.file => '[FILE] $fileName',
      _ => fileName,
    };

    final userMessage = ChatMessage(
      id: clientMid,
      clientMid: clientMid,
      senderUid: uid,
      text: messageText,
      timestamp: DateTime.now(),
      isMe: true,
      type: type,
      media: MessageMedia(
        path: mediaPath,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        fileHash: hash,
      ),
      status: MessageStatus.pending,
      quoteMid: quoteMid >= 0 ? quoteMid : null,
      quotePreview: replyTarget == null
          ? null
          : _quotePreviewFor(replyTarget),
    );

    if (!mounted) return;
    _setReplyingTo(null);
    _appendLocalMessage(userMessage);
    _scrollToBottom();

    try {
      await _dispatchFileSend(
        clientMid: clientMid,
        hash: hash,
        quoteMid: quoteMid,
      );
    } catch (e) {
      talker.error('ChatDetail server file send failed', e);
      _failMessage(clientMid, reason: 'send.network');
      _showSendFailedSnackBar();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    _follower.scrollToBottom(animated: animated);
  }

  /// 跳转后目标消息三下闪烁落点提示
  void _flashMessage(int? mid) {
    if (mid == null) return;
    _flashTimer?.cancel();
    setState(() => _flashMid = mid);
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flashMid = null);
    });
  }

  int _beginJump() {
    final token = ++_jumpToken;
    _jumpGuard?.cancel();
    _jumpGuard = Timer(_jumpGuardDuration, () {
      if (!mounted) return;
      talker.warning('jump-to-message: watchdog cancelled the jump');
      _cancelJump(token);
    });
    if (mounted) _setJumpingToMessage(true);
    return token;
  }

  void _finishJump(int token) {
    if (token != _jumpToken) return;
    _jumpGuard?.cancel();
    _jumpGuard = null;
    _setJumpingToMessage(false);
  }
  void _cancelJump(int token) {
    if (token != _jumpToken) return;
    _jumpGuard?.cancel();
    _jumpGuard = null;
    _jumpToken++;
    if (mounted) _setJumpingToMessage(false);
  }

  /// 定位到列表下标
  void _jumpToIndex(int index, {required int token, int wait = 0, int refine = 0}) {
    if (!mounted || token != _jumpToken) return;
    if (index < 0 || index >= _messages.length) {
      _finishJump(token);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _jumpToken) return;
      if (index >= _messages.length) {
        _finishJump(token);
        return;
      }
      if (!_scrollController.hasClients || !_messageListController.isAttached) {
        // 还没挂载
        if (wait < _jumpWaitFrames) {
          _jumpToIndex(index, token: token, wait: wait + 1, refine: refine);
        } else {
          _finishJump(token);
        }
        return;
      }
      final placeholderCount = _uploadingStatuses.length;
      final reverseIndex =
          _messages.length + placeholderCount - 1 - index;

      final range = _messageListController.visibleRange;
      if (range != null) {
        final visibleCount = range.$2 - range.$1 + 1;
        final margin = (visibleCount * 1.5).ceil();
        final isNear =
            reverseIndex >= range.$1 - margin &&
            reverseIndex <= range.$2 + margin;
        if (isNear && refine == 0) {
          final duration = Duration(
            milliseconds: (140 + visibleCount * 4).clamp(140, 260),
          );
          try {
            _messageListController.animateToItem(
              index: reverseIndex,
              scrollController: _scrollController,
              alignment: 0.35,
              duration: (_) => duration,
              curve: (_) => TFMotion.decelerate,
            );
          } catch (error, stackTrace) {
            talker.error('animate to message failed', error, stackTrace);
            _finishJump(token);
            return;
          }
          _settleJumpAfter(token, duration, index);
          return;
        }
      }
      try {
        _messageListController.jumpToItem(
          index: reverseIndex,
          scrollController: _scrollController,
          alignment: 0.35,
        );
      } catch (error, stackTrace) {
        talker.error('jump to message failed', error, stackTrace);
        _finishJump(token);
        return;
      }
      if (refine < 2) {
        _jumpToIndex(index, token: token, wait: wait, refine: refine + 1);
      } else {
        _finishJump(token);
      }
    });
  }

  void _settleJumpAfter(int token, Duration duration, int index) {
    _jumpGuard?.cancel();
    _jumpGuard = Timer(duration + const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _finishJump(token);
      _jumpToIndex(index, token: token, refine: 2);
    });
  }

  void _landOnMessage(int index, {required int token}) {
    if (index >= 0 && index < _messages.length) {
      _flashMessage(_messages[index].mid);
    }
    _jumpToIndex(index, token: token);
  }

  Future<_LocateResult> _locateMessageInHistory(
    int Function(List<ChatMessage> messages) locate, {
    required int token,
  }) async {
    final roomId = _contactUid;
    final roomGeneration = _roomGeneration;
    final deadline = DateTime.now().add(_jumpLocateBudget);

    _LocateResult miss({
      bool exhausted = false,
      bool timedOut = false,
      bool failed = false,
      bool aborted = false,
    }) => (
      index: null,
      exhausted: exhausted,
      timedOut: timedOut,
      failed: failed,
      aborted: aborted,
    );
    _LocateResult hit(int index) => (
      index: index,
      exhausted: false,
      timedOut: false,
      failed: false,
      aborted: false,
    );

    for (var page = 0; page < _jumpMaxPages; page++) {
      if (!mounted || token != _jumpToken) return miss(aborted: true);
      if (DateTime.now().isAfter(deadline)) return miss(timedOut: true);
      if (_isLoadingMessages || _isLoadingOlder) {
        final settled = await _waitForOngoingMessageLoad();
        if (!mounted || token != _jumpToken) return miss(aborted: true);
        final indexNow = locate(_messages);
        if (indexNow >= 0) return hit(indexNow);
        if (!settled) return miss(timedOut: true);
        continue;
      }
      if (!_hasMoreMessages) return miss(exhausted: true);

      setState(() => _isLoadingOlder = true);
      bool hasMore;
      try {
        hasMore = await ref
            .read(roomMessagesProvider(roomId).notifier)
            .loadOlder();
      } catch (error, stackTrace) {
        talker.error('jump-to-message: load older failed', error, stackTrace);
        if (mounted) setState(() => _isLoadingOlder = false);
        return miss(failed: true);
      }
      if (!mounted ||
          roomGeneration != _roomGeneration ||
          roomId != _contactUid) {
        if (mounted) setState(() => _isLoadingOlder = false);
        return miss(aborted: true);
      }
      setState(() {
        _isLoadingOlder = false;
        _hasMoreMessages = hasMore;
      });

      final index = locate(_messages);
      if (index >= 0) return hit(index);
      if (!hasMore) return miss(exhausted: true);
    }
    return miss(timedOut: true);
  }

  void _handleLocateMiss(int token, _LocateResult result) {
    if (!mounted) return;
    _finishJump(token);
    if (result.aborted) return;
    if (result.failed) {
      _showJumpLoadFailed();
      return;
    }
    if (result.timedOut) {
      _showJumpMessageTooFar();
      return;
    }
    _showJumpMessageNotFound();
  }
  void _scrollToQuotedMessage(int mid) {
    unawaited(_jumpToMessageMid(mid));
  }

  Future<void> _jumpToMessageMid(int mid) async {
    if (!mounted) return;
    _follower.stopFollowing();
    final token = _beginJump();
    final indexNow = _messages.indexWhere((message) => message.mid == mid);
    if (indexNow >= 0) {
      _landOnMessage(indexNow, token: token);
      return;
    }
    final result = await _locateMessageInHistory(
      (messages) => messages.indexWhere((message) => message.mid == mid),
      token: token,
    );
    final index = result.index;
    if (index == null) {
      _handleLocateMiss(token, result);
      return;
    }
    _landOnMessage(index, token: token);
  }

  int _indexOfMessage(ChatMessage target) {
    final mid = target.mid;
    if (mid != null) {
      final byMid = _messages.indexWhere((m) => m.mid == mid);
      if (byMid >= 0) return byMid;
    }
    final byId = _messages.indexWhere((m) => m.id == target.id);
    if (byId >= 0) return byId;
    final clientMid = target.clientMid;
    if (clientMid != null) {
      final byClientMid = _messages.indexWhere((m) => m.clientMid == clientMid);
      if (byClientMid >= 0) return byClientMid;
    }
    return -1;
  }

  void _showJumpMessageNotFound() {
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(l10n.chatSearchMessagesNoResults);
  }

  void _showJumpMessageTooFar() {
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(l10n.chatJumpMessageTooFar);
  }

  void _showJumpLoadFailed() {
    final l10n = AppLocalizations.of(context)!;
    TouchFishSnackbarService.instance.show(l10n.chatMessagesLoadFailed);
  }

  Future<void> _jumpToMessage(ChatMessage target) async {
    if (!mounted) return;
    _follower.stopFollowing();
    final token = _beginJump();
    final indexNow = _indexOfMessage(target);
    if (indexNow >= 0) {
      _landOnMessage(indexNow, token: token);
      return;
    }

    final targetMid = target.mid;
    if (targetMid == null || target.isDeleted) {
      _finishJump(token);
      _showJumpMessageNotFound();
      return;
    }

    final result = await _locateMessageInHistory(
      (messages) => messages.indexWhere((message) => message.mid == targetMid),
      token: token,
    );
    final index = result.index;
    if (index == null) {
      _handleLocateMiss(token, result);
      return;
    }
    _landOnMessage(index, token: token);
  }

  /// 等待并发中的消息加载
  Future<bool> _waitForOngoingMessageLoad({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted && (_isLoadingMessages || _isLoadingOlder)) {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return !_isLoadingMessages && !_isLoadingOlder;
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    final avatarUrl = _currentRoom!.avatar;
    final Widget avatar;
    if (avatarUrl == null || _avatarLoadFailed) {
      avatar = CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(
          _currentRoom!.type == ChatType.group ? Icons.group : Icons.person,
          size: 20,
          color: colorScheme.onPrimaryContainer,
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        backgroundImage: resizedImageProvider(
          NetworkImage(avatarUrl),
          MediaQuery.of(context).devicePixelRatio,
          width: 36,
          height: 36,
        ),
        onBackgroundImageError: (_, error) {
          talker.warning(
            'Avatar load failed for ${_currentRoom!.id}: $avatarUrl',
          );
          if (mounted) setState(() => _avatarLoadFailed = true);
        },
      );
    }
    // 仅私聊展示对方在线点
    if (_currentRoom!.type == ChatType.group) return avatar;
    final peerUid = int.tryParse(_currentRoom!.id.replaceFirst('U', ''));
    return OnlineAvatarBadge(uid: peerUid, radius: 18, child: avatar);
  }

  Widget _buildPinnedMessagesBar() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final pins = _pinnedMessages;
    if (pins.isEmpty) return const SizedBox.shrink();

    final currentIndex = _pinCurrentPage.clamp(0, pins.length - 1);
    final currentPin = pins[currentIndex];

    // 内缩浮卡
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        key: _pinnedBarKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: colorScheme.surfaceContainerLow,
            child: InkWell(
            onTap: () {
              ChatMessage? cachedMsg =
                  _pinnedMessageContents[currentPin.messageId];
              cachedMsg ??= _messages.cast<ChatMessage?>().firstWhere(
                (m) => m?.mid == currentPin.messageId,
                orElse: () => null,
              );
              _scrollToQuotedMessage(cachedMsg?.mid ?? currentPin.messageId);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Telegram-style left accent bar
                  Container(
                    width: 3,
                    height: 38,
                    margin: const EdgeInsets.only(left: 12, right: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content area with animated pin switch
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: TFMotion.respecting(context, TFMotion.base),
                      child: _buildCurrentPinContent(
                        key: ValueKey(currentPin.messageId),
                        pin: currentPin,
                        pageLabel: pins.length > 1
                            ? ' · ${currentIndex + 1}/${pins.length}'
                            : null,
                        l10n: l10n,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
                  // View-all button (only when multiple pins)
                  if (pins.length > 1)
                    IconButton(
                      icon: const Icon(Symbols.list, size: 18),
                      onPressed: _showPinnedMessagesSheet,
                      tooltip: l10n.viewAllPinned,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildCurrentPinContent({
    required Key key,
    required PinnedMessage pin,
    required String? pageLabel,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
  }) {
    final textTheme = Theme.of(context).textTheme;

    ChatMessage? cachedMsg = _pinnedMessageContents[pin.messageId];
    if (cachedMsg == null) {
      cachedMsg = _messages.cast<ChatMessage?>().firstWhere(
        (m) => m?.mid == pin.messageId,
        orElse: () => null,
      );
      if (cachedMsg != null) _pinnedMessageContents[pin.messageId] = cachedMsg;
    }

    final senderName = cachedMsg?.senderName?.trim().isNotEmpty == true
        ? cachedMsg!.senderName!
        : cachedMsg?.isMe == true
        ? (AuthState.instance.currentUser?.username ?? '')
        : ChatDataService.instance
              .getUser('U${cachedMsg?.senderUid ?? ''}')
              ?.username;

    final content = cachedMsg == null
        ? ''
        : messagePlainText(cachedMsg, l10n);
    final hasAttachment = cachedMsg?.media != null;

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top line: label + page indicator
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.push_pin, size: 11, color: colorScheme.primary),
            const SizedBox(width: 3),
            Text(
              l10n.pinnedMessageLabel,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (pageLabel != null)
              Text(
                pageLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Bottom line: sender + preview
        if (cachedMsg == null)
          Text(
            '...',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          )
        else
          Row(
            children: [
              if (senderName != null && senderName.isNotEmpty)
                Text(
                  '$senderName: ',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Expanded(
                child: content.isNotEmpty
                    ? Text(
                        content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      )
                    : hasAttachment
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.attach_file,
                            size: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              cachedMsg.media?.fileName ?? 'Attachment',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
  }

  void _onEssenceChanged(int gid) {
    if (_contactUid == 'G$gid') unawaited(_fetchEssenceMessages());
  }

  void _openGroupProfile() {
    final room = _currentRoom;
    if (room?.type != ChatType.group || !_contactUid.startsWith('G')) return;
    final gid = _contactUid.substring(1);
    context.push(
      AppRoutes.groupProfile.replaceFirst(':gid', gid),
      extra: <String, dynamic>{'groupName': room!.name},
    );
  }

  Future<void> _openEssenceScreen() async {
    final room = _currentRoom;
    final gid = int.tryParse(_contactUid.substring(1));
    if (room?.type != ChatType.group || gid == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupEssenceScreen(gid: gid, groupName: room!.name),
      ),
    );
    if (mounted && _contactUid == 'G$gid') {
      unawaited(_fetchEssenceMessages());
    }
  }

  Widget _buildEssenceBar() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: cs.surfaceContainerHigh,
      child: InkWell(
        onTap: _openEssenceScreen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Symbols.auto_awesome, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                l10n.essenceLabel(_essenceMids.length),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinnedMessagesSheet() {
    final canUnpin = _canModerateGroup;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => PinnedMessagesSheet(
        roomId: _contactUid,
        pins: _pinnedMessages,
        canUnpin: canUnpin,
        onUnpin: canUnpin
            ? (pinId) async {
                final uid = AuthState.instance.uid;
                final password = AuthState.instance.password;
                final gid = int.tryParse(_contactUid.substring(1));
                if (uid == null || password == null || gid == null) return;
                final ok = await TfApiClient.instance.unpinMessage(
                  uid,
                  password,
                  gid,
                  pinId,
                );
                if (ok) {
                  unawaited(_fetchPinnedMessages());
                }
              }
            : null,
        onJumpToMessage: (mid) {
          _scrollToQuotedMessage(mid);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 消息列表的订阅不在页 watch
    // 否则房间里每来一条消息都会重建
    final chatRoomState = chatRoomStateProvider(_contactUid);
    final scrollController = ref.watch(
      chatRoomState.select((s) => s.scrollController),
    );
    final isSelectionMode = ref.watch(
      chatRoomState.select((s) => s.isSelectionMode),
    );
    final selectedMessageIds = ref.watch(
      chatRoomState.select((s) => s.selectedMessageIds),
    );
    final replyingTo = ref.watch(chatRoomState.select((s) => s.replyingTo));
    final forwardingTo = ref.watch(chatRoomState.select((s) => s.forwardingTo));
    final gallery = ref.watch(imageGalleryProvider(_contactUid));
    ref.listen(roomMessagesProvider(_contactUid), _onProviderMessagesChanged);

    if (_currentRoom == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.chatDetailLoading)),
        body: const LoadingIndicator(),
      );
    }

    // 捕获成局部量
    // 安全
    final room = _currentRoom!;

    final colorScheme = Theme.of(context).colorScheme;
    final isWide = WideScreenHelper.isExpanded(context);
    final essenceButton = IconButton(
      icon: const Icon(Icons.auto_awesome),
      onPressed: _openEssenceScreen,
    );
    final callButton = _currentRoom?.type == ChatType.direct
        ? IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: l10n.callStartVideo,
            onPressed: _startVideoCall,
          )
        : null;
    final settingButton = IconButton(
      icon: const Icon(Icons.more_vert),
      onPressed: () async {
        final result = await Navigator.push<ChatMessage>(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomSettingsScreen(chatRoom: _currentRoom!),
          ),
        );
        if (result != null && mounted) {
          unawaited(_jumpToMessage(result));
        }
        if (mounted && _currentRoom?.type == ChatType.group) {
          unawaited(_loadMentionUsers());
          unawaited(_fetchEssenceMessages());
        }
      },
    );
    List<IconButton> actiontmp = [];
    if (callButton != null) actiontmp.add(callButton);
    if (_currentRoom?.type == ChatType.group && _essenceEnabled) {
      actiontmp.add(essenceButton);
    }
    actiontmp.add(settingButton);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.selectionExit,
                onPressed: _exitSelection,
              )
            : isWide
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.chat);
                  }
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(AppRoutes.chat),
              ),
        automaticallyImplyLeading: false,
        backgroundColor: colorScheme.surfaceContainerHighest,
        surfaceTintColor: Colors.transparent,
        title: isSelectionMode
            ? Text(
                selectedMessageIds.isEmpty
                    ? l10n.selectionSelectMessages
                    : l10n.selectionCount(selectedMessageIds.length),
              )
            : Row(
                children: [
                  InkWell(
                    onTap: _currentRoom!.type == ChatType.group
                        ? _openGroupProfile
                        : null,
                    customBorder: const CircleBorder(),
                    child: _buildAvatar(colorScheme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentRoom!.name,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_currentRoom!.type == ChatType.group)
                          Text(
                            l10n.chatDetailGroupChat,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: isSelectionMode ? const [SizedBox.shrink()] : actiontmp,
      ),
      body: SafeArea(
        child: Column(
          children: [
            ChatDetailBanners(
              // 只重建指示器
              syncIndicator: ListenableBuilder(
                listenable: MessageSyncService.instance,
                builder: (context, _) =>
                    SyncIndicator(isSyncing: _isRoomSyncing, hint: _syncHint),
              ),
              progress: (_isLoadingMessages || _isLoadingOlder)
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Colors.transparent,
                    )
                  : null,
              pinnedBar:
                  _currentRoom!.type == ChatType.group &&
                      _pinnedMessages.isNotEmpty
                  ? _buildPinnedMessagesBar()
                  : null,
              essenceBar:
                  _currentRoom!.type == ChatType.group &&
                      _essenceMids.isNotEmpty &&
                      _essenceEnabled
                  ? _buildEssenceBar()
                  : null,
              notice:
                  _currentRoom!.type == ChatType.group &&
                      _groupEnterHint.isNotEmpty &&
                      _showGroupEnterHint
                  ? ChatDetailNotice(
                      text: _groupEnterHint,
                      onDismiss: () {
                        setState(() => _showGroupEnterHint = false);
                        unawaited(
                          DraftService.instance.acknowledge(
                            'group_enter_hint',
                            _contactUid.substring(1),
                            _groupEnterHint,
                          ),
                        );
                      },
                    )
                  : null,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _onScrollMetricsChanged,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onUserScroll,
                        // 已读回执不改变消息列表
                        child: ValueListenableBuilder<int>(
                          valueListenable:
                              ChatDataService.instance.readReceiptRevision,
                          builder: (context, _, _) => Consumer(
                            builder: (context, messageRef, _) {
                              final messages = messageRef.watch(
                                roomMessagesProvider(_contactUid),
                              );
                              return ValueListenableBuilder<Set<String>>(
                                valueListenable: _entranceKeys,
                                builder: (context, entranceKeys, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: _activityRevision,
                                    builder: (context, _, _) {
                                      // 对方上传中的占位消息
                                      final displayMessages =
                                          ChatMessage.dedupeByMid(
                                        _uploadingStatuses.isEmpty
                                            ? messages
                                            : [
                                                ...messages,
                                                ..._buildUploadPlaceholderMessages(),
                                              ],
                                      );
                                      return MessageListView(
                                    messages: displayMessages,
                                    entranceKeys: entranceKeys,
                                    scrollController: scrollController,
                                    listController: _messageListController,
                                    galleryItems: gallery.items,
                                    imageIndexById: gallery.indexById,
                                    essenceMids: _essenceMids,
                                    pinnedMessages: _pinnedMessages,
                                    essenceEnabled: _essenceEnabled,
                                    currentRoom: room,
                                    canModerateGroup: _canModerateGroup,
                                    onRefresh: _onRefresh,
                                    onReply: _startReply,
                                    onForward: _startForward,
                                    onRecall: _recallMessage,
                                    onDelete: _deleteLocalMessage,
                                    onRetry: _resendMessage,
                                    onQuoteTap: _scrollToQuotedMessage,
                                    onPinToggle: _togglePin,
                                    onEssenceToggle: _toggleEssence,
                                    canRecall: _canRecall,
                                    canDeleteLocally: _canDeleteLocally,
                                    noMessagesText: l10n.chatDetailNoMessages,
                                    colorScheme: colorScheme,
                                    isLoading: _isLoadingMessages,
                                    errorText: _messagesError,
                                    highlightedMid: _flashMid,
                                    isSelectionMode: isSelectionMode,
                                    selectedMessageKeys: selectedMessageIds,
                                    onEnterSelectionMode: _enterSelection,
                                    onToggleSelection: _toggleSelection,
                                    readReceiptEnabled: FeatureFlags.instance.readReceipt,
                                    peerReadSeq: room.type == ChatType.group
                                        ? null
                                        : ChatDataService.instance.peerReadSeq(_contactUid),
                                    groupReadCounts: room.type == ChatType.group
                                        ? ChatDataService.instance.groupReadCounts
                                        : const {},
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: AnimatedScale(
                      scale: _showBackToBottom ? 1 : 0.8,
                      duration: TFMotion.respecting(context, TFMotion.base),
                      child: AnimatedOpacity(
                        opacity: _showBackToBottom ? 1 : 0,
                        duration: TFMotion.respecting(context, TFMotion.base),
                        child: IgnorePointer(
                          ignoring: !_showBackToBottom,
                          child: FloatingActionButton.small(
                            heroTag: 'chat-back-to-bottom',
                            tooltip: l10n.chatBackToBottom,
                            onPressed: _scrollToBottom,
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: TFMotion.respecting(context, TFMotion.fast),
              switchInCurve: TFMotion.standard,
              switchOutCurve: TFMotion.standard,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: TFMotion.standard,
                    ),
                  ),
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  ),
                );
              },
              child: ValueListenableBuilder<int>(
                valueListenable: _activityRevision,
                builder: (context, _, _) {
                  final typingStatuses = _typingStatuses;
                  return typingStatuses.isNotEmpty
                      ? TypingIndicator(
                          key: ValueKey(
                            typingStatuses.map((s) => s.compositeKey).toList(),
                          ),
                          typingStatuses: typingStatuses,
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('typing-indicator-none'),
                        );
                },
              ),
            ),
            RoomSelectionMode(
              visible: isSelectionMode,
              selectedCount: selectedMessageIds.length,
              onClose: _exitSelection,
              onCopy: _copySelectedMessages,
              onRedirect: _mergeForwardSelected,
              onRedirectToCurrentChat: _redirectToCurrentChat,
            ),
            if (!isSelectionMode) ...[
              // WS 断开时明确提示
              const WsConnectionStrip(),
              FailedMessagesBar(
                count: _failedMessages.length,
                onRetryAll: _retryAllFailed,
              ),
              ChatInputBar(
                roomId: _contactUid,
                controller: _messageController,
                onSend: _sendMessage,
                onFilePicked: _sendMediaMessage,
                onServerFilePicked: _sendServerFile,
                onVoiceRecorded: _sendVoiceMessage,
                mentionUsers: _mentionUsers,
                actionMessage: replyingTo ?? forwardingTo,
                actionIsForward: forwardingTo != null,
                onClearAction: _clearReplyAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MergeForwardTarget {
  final String roomId;
  final String name;

  const _MergeForwardTarget({required this.roomId, required this.name});
}

typedef _LocateResult = ({
  int? index,
  bool exhausted,
  bool timedOut,
  bool failed,
  bool aborted,
});
