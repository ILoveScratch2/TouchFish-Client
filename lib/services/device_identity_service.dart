export 'device_identity_service_stub.dart'
    if (dart.library.io) 'device_identity_service_native.dart'
    if (dart.library.html) 'device_identity_service_web.dart';
