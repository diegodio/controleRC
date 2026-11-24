import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Protocolo BLE dos carrinhos da coleção Shell (Shell Racing Legends /
/// Bburago). Baseado em engenharia reversa feita pela comunidade.
class ShellProtocol {
  ShellProtocol._();

  /// Serviço GATT que contém a característica de controle.
  static const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';

  /// Característica onde os comandos (criptografados) são escritos.
  static const controlCharacteristicUuid =
      'd44bc439-abfd-45a2-b575-925416129600';

  /// Chave AES-128 (modo ECB) usada pelo app oficial.
  static final Uint8List _key = Uint8List.fromList([
    0x34, 0x52, 0x2a, 0x5b, 0x7a, 0x6e, 0x49, 0x2c, //
    0x08, 0x09, 0x0a, 0x9d, 0x8d, 0x2a, 0x23, 0xf8,
  ]);

  static final AESEngine _engine = AESEngine()..init(true, KeyParameter(_key));

  /// Monta o bloco de 16 bytes em texto puro:
  /// `00 'C' 'T' 'L' frente ré esquerda direita luz turbo 00 00 00 00 00 00`
  static Uint8List buildPlain(CarState s) => Uint8List.fromList([
        0x00, 0x43, 0x54, 0x4c, //
        s.forward ? 1 : 0,
        s.backward ? 1 : 0,
        s.left ? 1 : 0,
        s.right ? 1 : 0,
        s.lights ? 1 : 0,
        s.turbo ? 1 : 0,
        0, 0, 0, 0, 0, 0,
      ]);

  /// Comando pronto para ser enviado (AES-128-ECB do bloco acima).
  static Uint8List buildCommand(CarState s) {
    final plain = buildPlain(s);
    final out = Uint8List(16);
    _engine.processBlock(plain, 0, out, 0);
    return out;
  }
}

/// Estado atual dos controles.
class CarState {
  bool forward = false;
  bool backward = false;
  bool left = false;
  bool right = false;
  bool lights = false;
  bool turbo = false;

  void releaseAll() {
    forward = backward = left = right = false;
  }
}
