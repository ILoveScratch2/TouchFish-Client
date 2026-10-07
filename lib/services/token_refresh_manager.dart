import 'dart:async';
import 'dart:math';

import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';

/// Token 自动刷新
class TokenRefreshManager {
  TokenRefreshManager._();
  static final instance = TokenRefreshManager._();

  Timer? _preRefreshTimer;
  Completer<bool>? _refreshInProgress;
  int _consecutiveFailures = 0;
  DateTime? _lastRefreshAttempt;

  /// 预刷新阈值：提前 5 分钟
  static const _preRefreshThreshold = Duration(minutes: 5);

  /// 最小重试间隔：30秒
  static const _minRetryInterval = Duration(seconds: 30);

  /// 最大重试间隔：10分钟
  static const _maxRetryInterval = Duration(minutes: 10);

  /// 最大连续失败次数：10次
  static const _maxConsecutiveFailures = 10;

  /// 启动自动刷新（登录后调用）
  void startAutoRefresh(int? tokenExpiresAt) {
    _preRefreshTimer?.cancel();
    _consecutiveFailures = 0;
    _lastRefreshAttempt = null;

    if (tokenExpiresAt == null) {
      talker.info('TokenRefreshManager: no expires_at, auto-refresh disabled');
      return;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(tokenExpiresAt * 1000);
    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);

    if (timeUntilExpiry < Duration.zero) {
      talker.warning('TokenRefreshManager: token already expired');
      return;
    }

    final refreshAt = timeUntilExpiry - _preRefreshThreshold;
    if (refreshAt < Duration.zero) {
      // Token 将在 5 分钟内过期，立即刷新
      talker.info('TokenRefreshManager: token expires soon, refreshing immediately');
      unawaited(_scheduleRefresh(Duration.zero));
    } else {
      talker.info(
        'TokenRefreshManager: scheduled refresh in ${refreshAt.inMinutes} minutes',
      );
      unawaited(_scheduleRefresh(refreshAt));
    }
  }

  /// 停止自动刷新（登出时调用）
  void stop() {
    _preRefreshTimer?.cancel();
    _preRefreshTimer = null;
    _refreshInProgress = null;
    _consecutiveFailures = 0;
    _lastRefreshAttempt = null;
  }

  /// 调度刷新任务
  Future<void> _scheduleRefresh(Duration delay) async {
    _preRefreshTimer?.cancel();
    _preRefreshTimer = Timer(delay, () {
      unawaited(_performRefresh());
    });
  }

  /// 执行刷新（带互斥锁）
  Future<bool> _performRefresh() async {
    // 刷新互斥：如果已有刷新在进行中，等待其完成
    final inProgress = _refreshInProgress;
    if (inProgress != null) {
      talker.info('TokenRefreshManager: refresh already in progress, waiting');
      return await inProgress.future;
    }

    // 频率限制：避免短时间内重复刷新
    if (_lastRefreshAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRefreshAttempt!);
      if (timeSinceLastAttempt < const Duration(seconds: 10)) {
        talker.warning(
          'TokenRefreshManager: rate limited, last attempt ${timeSinceLastAttempt.inSeconds}s ago',
        );
        return false;
      }
    }

    final completer = Completer<bool>();
    _refreshInProgress = completer;
    _lastRefreshAttempt = DateTime.now();

    try {
      final authState = AuthState.instance;
      final refreshToken = authState.refreshToken;

      if (refreshToken == null || refreshToken.isEmpty) {
        talker.warning('TokenRefreshManager: no refresh token available');
        completer.complete(false);
        return false;
      }

      talker.info('TokenRefreshManager: refreshing token (attempt ${_consecutiveFailures + 1})');
      final result = await TfApiClient.instance.refreshToken(refreshToken);

      if (result == null || result.token == null) {
        _consecutiveFailures++;
        talker.warning(
          'TokenRefreshManager: refresh failed (${_consecutiveFailures}/$_maxConsecutiveFailures)',
        );

        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          talker.error('TokenRefreshManager: max failures reached, triggering session expiry');
          completer.complete(false);
          unawaited(authState.logout());
          return false;
        }

        // 指数退避重试
        final retryDelay = _calculateBackoffDelay(_consecutiveFailures);
        talker.info('TokenRefreshManager: retrying in ${retryDelay.inSeconds}s');
        unawaited(_scheduleRefresh(retryDelay));
        completer.complete(false);
        return false;
      }

      // 刷新成功：重置失败计数，更新 AuthState
      _consecutiveFailures = 0;
      talker.info('TokenRefreshManager: refresh succeeded, scheduling next refresh');

      // 通知 AuthState 更新 token（避免直接修改私有字段）
      await authState.relogin();

      // 调度下一次刷新
      startAutoRefresh(result.expiresAt);

      completer.complete(true);
      return true;
    } catch (e, stackTrace) {
      _consecutiveFailures++;
      talker.error(
        'TokenRefreshManager: refresh error (${_consecutiveFailures}/$_maxConsecutiveFailures)',
        e,
        stackTrace,
      );

      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        talker.error('TokenRefreshManager: max failures reached, triggering session expiry');
        completer.complete(false);
        unawaited(AuthState.instance.logout());
        return false;
      }

      final retryDelay = _calculateBackoffDelay(_consecutiveFailures);
      talker.info('TokenRefreshManager: retrying in ${retryDelay.inSeconds}s');
      unawaited(_scheduleRefresh(retryDelay));
      completer.complete(false);
      return false;
    } finally {
      _refreshInProgress = null;
    }
  }

  /// 计算指数退避延迟
  Duration _calculateBackoffDelay(int failures) {
    // 基础延迟：30秒 * (2 ^ failures)，加随机抖动 ±20%
    final baseSeconds = _minRetryInterval.inSeconds * pow(2, failures - 1);
    final jitter = baseSeconds * (0.8 + Random().nextDouble() * 0.4);
    final delaySeconds = jitter.clamp(
      _minRetryInterval.inSeconds.toDouble(),
      _maxRetryInterval.inSeconds.toDouble(),
    );
    return Duration(seconds: delaySeconds.toInt());
  }

  /// 手动触发刷新（供外部调用，例如用户手动"刷新"操作）
  Future<bool> manualRefresh() async {
    talker.info('TokenRefreshManager: manual refresh triggered');
    _consecutiveFailures = 0; // 重置失败计数
    return await _performRefresh();
  }
}
