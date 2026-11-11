import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/chat_ws_service.dart';
import '../../theme/tokens.dart';

/// WebSocket 连接状态
class WsConnectionStrip extends StatelessWidget {
  const WsConnectionStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChatWsService.instance,
      builder: (context, _) {
        final state = ChatWsService.instance.state;
        final reconnecting = state == ChatWsState.disconnected ||
            state == ChatWsState.connecting;
        if (!reconnecting) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: TFSpace.lg,
            vertical: TFSpace.sm,
          ),
          color: colorScheme.errorContainer,
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(width: TFSpace.sm),
              Expanded(
                child: Text(
                  l10n.chatConnectionReconnecting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
