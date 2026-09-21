/// 剪贴板读写er
library;

import 'package:flutter/services.dart';

/// 写入剪贴板，返回是否真正成功。
Future<bool> copyTextToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}

/// 读取剪贴板纯文本；读取失败（含非安全上下文）时返回 `null`。
Future<String?> readTextFromClipboard() async {
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  } catch (_) {
    return null;
  }
}
