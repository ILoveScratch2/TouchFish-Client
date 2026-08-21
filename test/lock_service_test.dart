import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/services/lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LockService.resetForTest();
  });

  test('is disabled and unlocked by default', () async {
    final service = LockService.instance;
    await service.init();
    expect(service.isEnabled, isFalse);
    expect(service.isLocked, isFalse);
    expect(service.isBiometricEnabled, isFalse);
  });

  test('starts locked on init once a master password is set', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');
    expect(service.isEnabled, isTrue);
    expect(service.isLocked, isFalse);

    // A fresh process (re-initialized singleton) starts locked.
    LockService.resetForTest();
    final restarted = LockService.instance;
    await restarted.init();
    expect(restarted.isEnabled, isTrue);
    expect(restarted.isLocked, isTrue);
  });

  test(
    'verifyPassword accepts the correct password and rejects wrong ones',
    () async {
      final service = LockService.instance;
      await service.init();
      await service.enableMasterPassword('secret-1234');
      expect(await service.verifyPassword('secret-1234'), isTrue);
      expect(await service.verifyPassword('wrong'), isFalse);
      expect(await service.verifyPassword(''), isFalse);
    },
  );

  test('password verification does not block the event loop', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');

    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks++,
    );
    final verified = await service.verifyPassword('secret-1234');
    timer.cancel();

    expect(verified, isTrue);
    expect(ticks, greaterThan(0));
  });

  test('lock and unlockWithPassword toggle the locked state', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');

    await service.lock();
    expect(service.isLocked, isTrue);

    expect(await service.unlockWithPassword('wrong'), isFalse);
    expect(service.isLocked, isTrue);

    expect(await service.unlockWithPassword('secret-1234'), isTrue);
    expect(service.isLocked, isFalse);
  });

  test('lock is a no-op when no master password is configured', () async {
    final service = LockService.instance;
    await service.init();
    await service.lock();
    expect(service.isLocked, isFalse);
  });

  test('changeMasterPassword re-wraps the password hash', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('old-password');
    expect(await service.verifyPassword('old-password'), isTrue);

    await service.changeMasterPassword('old-password', 'new-password');
    expect(await service.verifyPassword('new-password'), isTrue);
    expect(await service.verifyPassword('old-password'), isFalse);
  });

  test('changeMasterPassword rejects an incorrect current password', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('old-password');
    await expectLater(
      service.changeMasterPassword('wrong', 'new-password'),
      throwsA(isA<LockException>()),
    );
    expect(await service.verifyPassword('old-password'), isTrue);
  });

  test(
    'disableMasterPassword requires the current password and clears state',
    () async {
      final service = LockService.instance;
      await service.init();
      await service.enableMasterPassword('secret-1234');

      await expectLater(
        service.disableMasterPassword('wrong'),
        throwsA(isA<LockException>()),
      );
      expect(service.isEnabled, isTrue);

      await service.disableMasterPassword('secret-1234');
      expect(service.isEnabled, isFalse);
      expect(service.isLocked, isFalse);
      expect(service.isBiometricEnabled, isFalse);
    },
  );

  test('biometric enable requires a master password first', () async {
    final service = LockService.instance;
    await service.init();
    await expectLater(service.enableBiometric(), throwsA(isA<LockException>()));
  });

  test('biometric enable prompts once and persists on success', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');
    var prompted = false;
    service.biometricAvailabilityOverride = () async => true;
    service.biometricPrompt = (_) async {
      prompted = true;
      return true;
    };

    await service.enableBiometric();
    expect(prompted, isTrue);
    expect(service.isBiometricEnabled, isTrue);

    // Persisted across restart.
    LockService.resetForTest();
    final restarted = LockService.instance;
    await restarted.init();
    expect(restarted.isBiometricEnabled, isTrue);
  });

  test('biometric enable does not persist when authentication fails', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');
    service.biometricAvailabilityOverride = () async => true;
    service.biometricPrompt = (_) async => false;

    await expectLater(service.enableBiometric(), throwsA(isA<LockException>()));
    expect(service.isBiometricEnabled, isFalse);
  });

  test('biometric unlock unlocks the app', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');
    service.biometricAvailabilityOverride = () async => true;
    service.biometricPrompt = (_) async => true;
    await service.enableBiometric();

    await service.lock();
    expect(service.isLocked, isTrue);

    expect(await service.unlockWithBiometrics(), isTrue);
    expect(service.isLocked, isFalse);
  });

  test('biometric unlock throws when disabled', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');
    await service.lock();
    await expectLater(
      service.unlockWithBiometrics(),
      throwsA(isA<LockException>()),
    );
  });

  test('disabling the master password also clears biometrics', () async {
    final service = LockService.instance;
    await service.init();
    await service.enableMasterPassword('secret-1234');
    service.biometricAvailabilityOverride = () async => true;
    service.biometricPrompt = (_) async => true;
    await service.enableBiometric();

    await service.disableMasterPassword('secret-1234');
    expect(service.isEnabled, isFalse);
    expect(service.isBiometricEnabled, isFalse);

    // Fresh process has nothing persisted.
    LockService.resetForTest();
    final restarted = LockService.instance;
    await restarted.init();
    expect(restarted.isEnabled, isFalse);
    expect(restarted.isBiometricEnabled, isFalse);
  });
}
