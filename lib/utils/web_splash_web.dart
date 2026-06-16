import 'dart:js' as js;

void removeWebSplash() {
  js.context.callMethod('removeSplashFromWeb', []);
}
