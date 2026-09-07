import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/settings_service.dart';
import '../utils/talker.dart';
import 'rsa_key_trust_service.dart';

/// 多开时对「服务器 + 账号」的进程间互斥。
///
/// 开启“允许多开”后，多个 TouchFish 进程会共用同一份本地数据目录，这里负责
/// 保证同一台机器上同一 (服务器, 账号) 不会被两个实例同时登录。做法是在共享
/// 目录里维护一张“活实例占位表”，每条记录带实例 id、服务器 authority、uid 与
/// 心跳时间戳；写入用独立 lock 文件（OS 文件锁）串行化，冲突检测与抢占是同一个
/// 原子临界区。进程崩溃后心跳停止，记录在超时后被其它实例当作过期条目清理。
///
/// 未开启“允许多开”或非桌面平台时所有方法都直接放行，不产生任何副作用。
class MultiInstanceGuard {
  static final MultiInstanceGuard instance = MultiInstanceGuard._();

  MultiInstanceGuard._();

  /// 开启条件：桌面平台且设置里 allowMultipleInstances = true。
  bool get _enabled {
    if (kIsWeb) return false;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return false;
    }
    return SettingsService.instance.getValue<bool>(
      'allowMultipleInstances',
      false,
    );
  }

  static const _registryFileName = 'multi_instance_registry.json';
  static const _lockFileName = 'multi_instance_registry.lock';

  /// 心跳间隔；心跳停了 3 次以上（3×间隔）的记录视为过期。
  static const Duration _heartbeatEvery = Duration(seconds: 15);

  /// 注册表记录超过该毫秒数未刷新即视为过期（= 3 次心跳间隔）。
  static const int _staleAfterMs = 45000;

  /// 每个进程唯一的实例 id。pid + 启动时刻可避免快速重启时 pid 复用造成的串扰。
  final String _instanceId =
      '$pid-${DateTime.now().microsecondsSinceEpoch}';

  Timer? _heartbeatTimer;
  Map<String, dynamic>? _claim;

  /// 尝试抢占 (当前选中服务器, uid)。已被其它存活实例占住时返回 false。
  Future<bool> acquire({required int uid, required String username}) async {
    if (!_enabled) return true;
    try {
      final server = await RsaKeyTrustService.currentAuthority();
      final now = DateTime.now().millisecondsSinceEpoch;
      final acquired = await _withRegistryLock(() async {
        final entries = await _readRegistry();
        pruneRegistry(entries, now);
        if (hasConflict(entries, server, uid, _instanceId)) return false;
        // 清掉本进程可能残留的旧记录后重新登记。
        entries.removeWhere((e) => e[kInst] == _instanceId);
        final claim = <String, dynamic>{
          kInst: _instanceId,
          kServer: server,
          kUid: uid,
          kUser: username,
          kTs: now,
        };
        entries.add(claim);
        await _writeRegistry(entries);
        _claim = claim;
        return true;
      });
      if (acquired) {
        _startHeartbeat();
      } else {
        talker.info(
          'MultiInstanceGuard: (server=$server, uid=$uid) is already held by '
          'another instance; rejecting.',
        );
      }
      return acquired;
    } catch (error, stackTrace) {
      // 读不到/抢不到锁时放行（本地互斥是尽力而为，别把登录卡死）。
      talker.warning(
        'MultiInstanceGuard.acquire failed; allowing anyway.',
        error,
        stackTrace,
      );
      return true;
    }
  }

  /// 释放本实例的占位记录（登出时调用）。
  Future<void> release() async {
    _stopHeartbeat();
    final claim = _claim;
    _claim = null;
    if (!_enabled || claim == null) return;
    try {
      await _withRegistryLock(() async {
        final entries = await _readRegistry();
        entries.removeWhere((e) => e[kInst] == _instanceId);
        await _writeRegistry(entries);
      });
    } catch (error, stackTrace) {
      // 只影响过期时间，下次会被清理，不阻塞登出。
      talker.warning('MultiInstanceGuard.release failed.', error, stackTrace);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatEvery, (_) {
      unawaited(_refreshClaim());
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _refreshClaim() async {
    final claim = _claim;
    if (!_enabled || claim == null) return;
    try {
      await _withRegistryLock(() async {
        final entries = await _readRegistry();
        final now = DateTime.now().millisecondsSinceEpoch;
        pruneRegistry(entries, now);
        final index = entries.indexWhere(
          (e) =>
              e[kInst] == claim[kInst] &&
              e[kServer] == claim[kServer] &&
              e[kUid] == claim[kUid],
        );
        final refreshed = Map<String, dynamic>.from(claim)..[kTs] = now;
        if (index < 0) {
          entries.add(refreshed);
        } else {
          entries[index] = refreshed;
        }
        await _writeRegistry(entries);
      });
    } catch (error, stackTrace) {
      talker.warning(
        'MultiInstanceGuard heartbeat refresh failed.',
        error,
        stackTrace,
      );
    }
  }

  /// 串行化 registry 的读改写：锁一个独立文件，锁内再用 File API 读写 JSON。
  Future<T> _withRegistryLock<T>(Future<T> Function() action) async {
    final dir = await getApplicationSupportDirectory();
    final lockFile = File(
      '${dir.path}${Platform.pathSeparator}$_lockFileName',
    );
    RandomAccessFile? raf;
    try {
      raf = await lockFile.open(mode: FileMode.append);
      await raf.lock(FileLock.exclusive);
      return await action();
    } finally {
      try {
        await raf?.unlock();
      } catch (_) {}
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> _readRegistry() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}$_registryFileName',
    );
    if (!await file.exists()) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return <Map<String, dynamic>>[];
      final entries = <Map<String, dynamic>>[];
      for (final raw in decoded) {
        if (raw is Map) {
          entries.add(Map<String, dynamic>.from(raw));
        }
      }
      return entries;
    } catch (error, stackTrace) {
      // 文件损坏按空处理，避免影响登录。
      talker.warning(
        'MultiInstanceGuard registry unreadable; treating as empty.',
        error,
        stackTrace,
      );
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writeRegistry(List<Map<String, dynamic>> entries) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}$_registryFileName',
    );
    await file.writeAsString(jsonEncode(entries), flush: true);
  }

  // registry 单条记录的字段名。
  static const String kInst = 'inst';
  static const String kServer = 'server';
  static const String kUid = 'uid';
  static const String kUser = 'user';
  static const String kTs = 'ts';

  /// 清理超过 [staleAfterMs] 未刷新的过期条目（进程崩溃/强杀留下的残骸）。
  /// 纯函数、就地修改 [entries]，便于测试。
  static void pruneRegistry(
    List<Map<String, dynamic>> entries,
    int nowMs, {
    int staleAfterMs = _staleAfterMs,
  }) {
    final threshold = nowMs - staleAfterMs;
    entries.removeWhere((e) {
      final ts = e[kTs];
      return ts is num && ts.toInt() < threshold;
    });
  }

  /// 冲突判定核心：把候选 (server, uid) 与 [entries]（已按当前时刻清理过期后）
  /// 比较，除 [ownInst] 自己的记录外，是否存在同 server 同 uid 的存活占用。
  /// 纯函数，便于测试。
  static bool hasConflict(
    List<Map<String, dynamic>> entries,
    String candidateServer,
    int candidateUid,
    String ownInst,
  ) {
    return entries.any(
      (e) =>
          e[kInst] != ownInst &&
          e[kServer] == candidateServer &&
          e[kUid] == candidateUid,
    );
  }
}
