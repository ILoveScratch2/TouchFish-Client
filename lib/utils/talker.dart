import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init();

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
