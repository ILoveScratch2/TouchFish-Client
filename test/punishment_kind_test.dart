import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/models/support_ticket.dart';
void main() {
  test('parse ALL PUNISHMENT KINDS to punish zrt', () {
    expect(PunishmentKind.fromWire('warn'), PunishmentKind.warn);
    expect(PunishmentKind.fromWire('mute'), PunishmentKind.mute);
    expect(PunishmentKind.fromWire('ban'), PunishmentKind.ban);
    expect(PunishmentKind.fromWire('ban_full'), PunishmentKind.banFull);
  });

  test('wire same', () {
    expect(PunishmentKind.warn.wire, 'warn');
    expect(PunishmentKind.mute.wire, 'mute');
    expect(PunishmentKind.ban.wire, 'ban');
    expect(PunishmentKind.banFull.wire, 'ban_full');
  });

  test('unknown values still default to warn (old server)', () {
    expect(PunishmentKind.fromWire('something_new'), PunishmentKind.warn);
    expect(PunishmentKind.fromWire(null), PunishmentKind.warn);
  });
}
