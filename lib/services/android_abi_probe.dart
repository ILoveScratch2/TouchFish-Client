/// 当前进程 ABI 探测
library;

export 'android_abi_probe_stub.dart'
    if (dart.library.io) 'android_abi_probe_native.dart';
