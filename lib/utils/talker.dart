import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init();

void registerTalkerErrorHandlers() {
  FlutterError.onError = (details) {
    logFlutterErrorDetails(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    talker.error('Unhandled platform error', error, stackTrace);
    return true;
  };
}

void logFlutterErrorDetails(
  FlutterErrorDetails details, {
  String message = 'Unhandled Flutter framework error',
}) {
  final buffer = StringBuffer(message);
  if (details.library != null && details.library!.isNotEmpty) {
    buffer.write(' [${details.library}]');
  }

  final contextDescription = details.context?.toDescription();
  if (contextDescription != null && contextDescription.isNotEmpty) {
    buffer.write(' ($contextDescription)');
  }

  talker.error(
    buffer.toString(),
    details.exception,
    details.stack ?? StackTrace.current,
  );
}

void logUnhandledAsyncError(Object error, StackTrace stackTrace) {
  talker.error('Unhandled async error', error, stackTrace);
}

class TalkerRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    talker.debug(
      'Route push: ${route.settings.name} (from: ${previousRoute?.settings.name})',
    );
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    talker.debug(
      'Route pop: ${route.settings.name} (to: ${previousRoute?.settings.name})',
    );
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    talker.debug(
      'Route replace: ${oldRoute?.settings.name} -> ${newRoute?.settings.name}',
    );
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    talker.debug('Route remove: ${route.settings.name}');
  }
}
