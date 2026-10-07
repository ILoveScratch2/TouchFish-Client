import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const int kMaxBrowserTabs = 8;

/// 这个很大程度得感谢 DeepSeek-V4-Flase-Vision-Exp
/// 不然谁知道这玩意
class BrowserTab {
  final int id;
  String? title;
  String url;
  int progress = 0;
  bool loading = false;
  bool failed = false;

  /// 主 frame 加载失败时的错误描述
  String? errorDescription;
  InAppWebViewController? controller;
  final FindInteractionController findController;

  /// 页面退至后台（浏览器页面销毁）后保持 WebView（不然 BOOM）
  InAppWebViewKeepAlive keepAlive;

  /// 渲染进程崩溃重建时自增
  int generation = 0;
  Color? themeColor;

  BrowserTab({
    required this.id,
    required this.url,
    required this.findController,
    required this.keepAlive,
  });
}

/// App 级浏览器会话：BrowserScreen 页面 pop 后会话与各标签页
/// （WebView 实例经 keepAlive）依然存活，再次打开时原样恢复。
class BrowserSession {
  BrowserSession._();

  static final BrowserSession instance = BrowserSession._();

  final List<BrowserTab> tabs = [];
  int currentIndex = 0;
  int _nextTabId = 0;

  int get count => tabs.length;

  bool get isEmpty => tabs.isEmpty;

  BrowserTab get activeTab => tabs[currentIndex];

  BrowserTab createTab(
    String url, {
    void Function(int active, int total, bool done)? onFindResult,
  }) {
    final id = _nextTabId++;
    final tab = BrowserTab(
      id: id,
      url: url,
      findController: FindInteractionController(
        onFindResultReceived: (controller, active, total, done) =>
            onFindResult?.call(active, total, done),
      ),
      keepAlive: InAppWebViewKeepAlive(),
    );
    tabs.add(tab);
    currentIndex = tabs.length - 1;
    return tab;
  }

  int? indexOfUrl(String url) {
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].url == url) return i;
    }
    return null;
  }

  Future<void> closeTab(int index) async {
    if (index < 0 || index >= tabs.length) return;
    final tab = tabs.removeAt(index);
    await InAppWebViewController.disposeKeepAlive(tab.keepAlive);
    if (tabs.isEmpty) {
      currentIndex = 0;
      return;
    }
    if (currentIndex >= tabs.length) currentIndex = tabs.length - 1;
    if (currentIndex > index) currentIndex--;
  }

  /// 渲染进程崩溃后重建 WebView：释放旧 keepAlive 并换新实例，
  /// generation 自增使页面以新 key 重新挂载。
  Future<void> recycleTab(BrowserTab tab) async {
    if (tab.controller != null) {
      await InAppWebViewController.disposeKeepAlive(tab.keepAlive);
      tab.keepAlive = InAppWebViewKeepAlive();
      tab.controller = null;
    }
    tab.generation++;
    tab.loading = false;
    tab.progress = 0;
    tab.failed = false;
    tab.errorDescription = null;
    tab.themeColor = null;
  }

  Future<void> clearAll() async {
    for (final tab in tabs) {
      await InAppWebViewController.disposeKeepAlive(tab.keepAlive);
    }
    tabs.clear();
    currentIndex = 0;
  }
}
