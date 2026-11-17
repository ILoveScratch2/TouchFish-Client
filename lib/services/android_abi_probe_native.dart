import 'dart:ffi' show Abi;

/// 当前进程的 Android ABI 名
String currentProcessAndroidAbi() {
  final abi = Abi.current();
  if (abi == Abi.androidArm64) return 'arm64-v8a';
  if (abi == Abi.androidArm || abi == Abi.androidIA32) {
    // androidIA32（x86 32 位）没有对应产物
    return 'armeabi-v7a';
  }
  if (abi == Abi.androidX64) return 'x86_64';
  return 'arm64-v8a';
}
