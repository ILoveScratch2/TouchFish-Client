import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';

part 'chat_room_state_provider.g.dart';

/// Status of Liberty
@riverpod
class ChatRoomState extends _$ChatRoomState {
  @override
  ChatRoomUiState build(String roomId) {
    final scrollController = ScrollController();
    
    // 清理资源
    ref.onDispose(() {
      scrollController.dispose();
    });
    
    return ChatRoomUiState(
      roomId: roomId,
      scrollController: scrollController,
    );
  }

  // 回复相关
  void setReplyingTo(ChatMessage? message) {
    state = state.copyWith(replyingTo: () => message);
  }

  // 转发相关
  void setForwardingTo(ChatMessage? message) {
    state = state.copyWith(forwardingTo: () => message);
  }

  // 选择模式
  void enterSelectionMode(String messageId) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {messageId},
    );
  }

  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedMessageIds: {},
    );
  }

  void toggleMessageSelection(String messageId) {
    final selected = Set<String>.from(state.selectedMessageIds);
    if (selected.contains(messageId)) {
      selected.remove(messageId);
    } else {
      selected.add(messageId);
    }
    state = state.copyWith(selectedMessageIds: selected);
  }

  // 置顶消息栏
  void setPinnedPage(int page) {
    state = state.copyWith(pinnedCurrentPage: page);
  }

  // 跳转到消息标记
  void setJumpingToMessage(bool isJumping) {
    state = state.copyWith(isJumpingToMessage: isJumping);
  }
}

class ChatRoomUiState {
  final String roomId;
  final ScrollController scrollController;
  final ChatMessage? replyingTo;
  final ChatMessage? forwardingTo;
  final bool isSelectionMode;
  final Set<String> selectedMessageIds;
  final int pinnedCurrentPage;
  final bool isJumpingToMessage;

  ChatRoomUiState({
    required this.roomId,
    required this.scrollController,
    this.replyingTo,
    this.forwardingTo,
    this.isSelectionMode = false,
    this.selectedMessageIds = const {},
    this.pinnedCurrentPage = 0,
    this.isJumpingToMessage = false,
  });

  ChatRoomUiState copyWith({
    ChatMessage? Function()? replyingTo,
    ChatMessage? Function()? forwardingTo,
    bool? isSelectionMode,
    Set<String>? selectedMessageIds,
    int? pinnedCurrentPage,
    bool? isJumpingToMessage,
  }) {
    return ChatRoomUiState(
      roomId: roomId,
      scrollController: scrollController,
      replyingTo: replyingTo != null ? replyingTo() : this.replyingTo,
      forwardingTo: forwardingTo != null ? forwardingTo() : this.forwardingTo,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      pinnedCurrentPage: pinnedCurrentPage ?? this.pinnedCurrentPage,
      isJumpingToMessage: isJumpingToMessage ?? this.isJumpingToMessage,
    );
  }
}
