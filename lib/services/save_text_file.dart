export 'save_text_file_stub.dart'
    if (dart.library.io) 'save_text_file_native.dart'
    if (dart.library.html) 'save_text_file_web.dart';
