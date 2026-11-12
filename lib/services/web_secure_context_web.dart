import 'package:web/web.dart' as web;

/// 浏览器是否把当前视为安全上下文
bool get isSecureWebContext => web.window.isSecureContext;
