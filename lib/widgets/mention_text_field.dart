import 'package:flutter/material.dart';
import 'account/profile_picture.dart';

class MentionUser {
  final String id;
  final String username;
  final String? avatarUrl;

  const MentionUser({
    required this.id,
    required this.username,
    this.avatarUrl,
  });
}


class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<MentionUser> mentionUsers;

  const MentionTextField({
    super.key,
    required this.controller,
    this.mentionUsers = const [],
    this.focusNode,
    this.decoration,
    this.maxLines = 1,
    this.minLines,
    this.style,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  late final FocusNode _focusNode;
  bool _ownedFocusNode = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final ValueNotifier<List<MentionUser>> _suggestionsNotifier =
      ValueNotifier(const []);
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownedFocusNode = true;
    }
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(MentionTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownedFocusNode) _focusNode.dispose();
    _hideSuggestions();
    _suggestionsNotifier.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_disposed) _hideSuggestions();
      });
    }
  }

  void _onTextChanged() {
    if (_disposed) return;
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || !_focusNode.hasFocus) {
      _hideSuggestions();
      return;
    }

    final cursorPos = selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      _hideSuggestions();
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = _findMentionTrigger(textBeforeCursor);
    if (atIndex == -1) {
      _hideSuggestions();
      return;
    }

    final query = textBeforeCursor.substring(atIndex + 1);
    final filtered = _filterUsers(query);
    if (filtered.isEmpty) {
      _hideSuggestions();
      return;
    }

    _suggestionsNotifier.value = filtered;
    _showSuggestions();
  }
  int _findMentionTrigger(String text) {
    for (int i = text.length - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == ' ' || ch == '\n') return -1;
      if (ch == '@') {
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') return i;
        return -1;
      }
    }
    return -1;
  }

  List<MentionUser> _filterUsers(String query) {
    final lower = query.toLowerCase();
    final src = query.isEmpty
        ? widget.mentionUsers
        : widget.mentionUsers.where(
            (u) => u.username.toLowerCase().contains(lower),
          );
    return src.take(8).toList();
  }

  void _showSuggestions() {
    if (_disposed || _overlayEntry != null) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!_disposed) _suggestionsNotifier.value = const [];
  }

  void _selectUser(MentionUser user) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (!selection.isValid) return;

    final cursorPos = selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) return;

    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = _findMentionTrigger(textBeforeCursor);
    if (atIndex == -1) return;
    final mention = '@${user.username} ';
    final newText = text.replaceRange(atIndex, cursorPos, mention);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + mention.length),
    );
    _hideSuggestions();
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -4),
          child: _MentionSuggestionList(
            notifier: _suggestionsNotifier,
            onSelect: _selectUser,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        style: widget.style,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        decoration: widget.decoration,
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

class _MentionSuggestionList extends StatelessWidget {
  final ValueNotifier<List<MentionUser>> notifier;
  final ValueChanged<MentionUser> onSelect;

  const _MentionSuggestionList({
    required this.notifier,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<MentionUser>>(
      valueListenable: notifier,
      builder: (context, users, _) {
        if (users.isEmpty) return const SizedBox.shrink();
        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHigh,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 300),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _MentionUserTile(
                    user: user,
                    onTap: () => onSelect(user),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MentionUserTile extends StatelessWidget {
  final MentionUser user;
  final VoidCallback onTap;

  const _MentionUserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(colorScheme),
            const SizedBox(width: 10),
            Text(
              '@${user.username}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    return ProfilePictureWidget(
      avatarUrl: user.avatarUrl,
      radius: 14,
    );
  }
}
