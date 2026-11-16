import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_routes.dart';
import '../utils/talker.dart';
import 'permission_center.dart';


Future<bool> maybeShowBatteryOptimizationPrompt(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return false;

  final center = PermissionCenter.instance;
  if (center.batteryPromptMuted) return false;
  if (center.batteryPromptShown) return false;

  final status = await center.statusOf(TfPermissionKind.batteryOptimization);
  if (status.isGranted || status == TfPermissionStatus.notApplicable) {
    return false;
  }
  if (!context.mounted) return false;

  center.markBatteryPromptShown();
  talker.info('Showing battery optimization explainer.');
  await context.push(AppRoutes.batteryPermission);
  return true;
}
