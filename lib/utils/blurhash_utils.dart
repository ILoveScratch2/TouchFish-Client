/// flutter_blurhash 
/// 这是 贝斯83吧
const String _base83Alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    r'#$%*+,-.:;=?@[]^_{|}~';

/// 检测 blurhash ok，不然会 BOOM shakalaka
bool isValidBlurHash(String? hash) {
  if (hash == null || hash.length < 6) return false;
  for (final unit in hash.codeUnits) {
    if (!_base83Alphabet.contains(String.fromCharCode(unit))) return false;
  }
  return true;
}
