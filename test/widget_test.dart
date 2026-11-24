import 'package:controle_rc/src/shell_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta o comando padrão com velocidade e criptografa', () {
    final s = CarState()..forward = true;
    final plain = ShellProtocol.buildPlain(s);
    expect(plain.sublist(0, 10), [0, 0x43, 0x54, 0x4c, 1, 0, 0, 0, 0, 0x50]);
    s
      ..turbo = true
      ..left = true;
    expect(ShellProtocol.buildPlain(s).sublist(4, 10), [1, 0, 0, 1, 0, 0x64]);
    expect(ShellProtocol.buildCommand(s).length, 16);
  });

  test('configuração altera posições', () {
    final cfg = ProtocolConfig()
      ..idxLeft = 6
      ..idxRight = 7;
    final s = CarState()..left = true;
    expect(ShellProtocol.buildPlain(s, cfg)[6], 1);
  });

  test('parseHex', () {
    expect(ShellProtocol.parseHex('00 43 54 4c 01')!.sublist(0, 5),
        [0, 0x43, 0x54, 0x4c, 1]);
    expect(ShellProtocol.parseHex('zz'), isNull);
  });
}
