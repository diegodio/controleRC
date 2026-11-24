import 'package:controle_rc/src/shell_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta o comando CTL e criptografa em 16 bytes', () {
    final s = CarState()
      ..forward = true
      ..turbo = true;
    final plain = ShellProtocol.buildPlain(s);
    expect(plain.sublist(0, 10), [0, 0x43, 0x54, 0x4c, 1, 0, 0, 0, 0, 1]);
    final cmd = ShellProtocol.buildCommand(s);
    expect(cmd.length, 16);
    expect(cmd, isNot(equals(plain)));
  });
}
