import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Protocolo BLE dos carrinhos da coleção Shell (Shell Racing Legends /
/// Bburago). Baseado em engenharia reversa feita pela comunidade.
class ShellProtocol {
  ShellProtocol._();

  /// Serviço GATT que contém a característica de controle.
  static const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';

  /// Característica onde os comandos (criptografados) são escritos.
  /// Se não existir no carrinho, a primeira característica gravável do
  /// serviço é usada.
  static const controlCharacteristicUuid =
      'd44bc439-abfd-45a2-b575-925416129600';

  /// Serviços que o navegador pode acessar (Web Bluetooth só expõe os
  /// serviços listados aqui).
  static const optionalServices = [
    serviceUuid,
    'd44bc439-abfd-45a2-b575-925416129600',
    '0000ffe0-0000-1000-8000-00805f9b34fb',
    '0000fee0-0000-1000-8000-00805f9b34fb',
    '0000180f-0000-1000-8000-00805f9b34fb', // bateria
  ];

  /// Chave AES-128 (modo ECB) usada pelo app oficial.
  static final Uint8List _key = Uint8List.fromList([
    0x34, 0x52, 0x2a, 0x5b, 0x7a, 0x6e, 0x49, 0x2c, //
    0x08, 0x09, 0x0a, 0x9d, 0x8d, 0x2a, 0x23, 0xf8,
  ]);

  static final AESEngine _engine = AESEngine()..init(true, KeyParameter(_key));

  /// Monta o bloco de 16 bytes em texto puro conforme [cfg]. Padrão:
  /// `00 'C' 'T' 'L' frente ré direita esquerda farol velocidade 00...`
  static Uint8List buildPlain(CarState s, [ProtocolConfig? cfg]) {
    final c = cfg ?? ProtocolConfig();
    final b = Uint8List(16);
    b[0] = c.header;
    b[1] = 0x43;
    b[2] = 0x54;
    b[3] = 0x4c;
    void set(int i, int v) {
      if (i >= 4 && i < 16) b[i] = v;
    }

    set(c.idxForward, s.forward ? 1 : 0);
    set(c.idxBackward, s.backward ? 1 : 0);
    set(c.idxLeft, s.left ? 1 : 0);
    set(c.idxRight, s.right ? 1 : 0);
    set(c.idxLights, (s.lights != c.lightsInverted) ? 1 : 0);
    set(c.idxSpeed, s.turbo ? c.speedTurbo : c.speedNormal);
    return b;
  }

  /// Criptografa um bloco de 16 bytes (AES-128-ECB).
  static Uint8List encrypt(Uint8List plain) {
    final out = Uint8List(16);
    _engine.processBlock(plain, 0, out, 0);
    return out;
  }

  /// Comando pronto para ser enviado.
  static Uint8List buildCommand(CarState s, [ProtocolConfig? cfg]) =>
      encrypt(buildPlain(s, cfg));

  static String toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  /// Converte "00 43 54 ..." em 16 bytes (completa com zeros). Null se inválido.
  static Uint8List? parseHex(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (clean.isEmpty || clean.length.isOdd || clean.length > 32) return null;
    final b = Uint8List(16);
    for (var i = 0; i < clean.length; i += 2) {
      b[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return b;
  }
}

/// Posição de cada função no comando (ajustável na tela, salvo no navegador).
class ProtocolConfig {
  int header = 0x00;
  int idxForward = 4;
  int idxBackward = 5;
  // Teste real (SL-F80): o byte 6 vira para a direita.
  int idxRight = 6;
  int idxLeft = 7;
  int idxLights = 8;
  bool lightsInverted = false;
  int idxSpeed = 9;
  int speedNormal = 0x50;
  int speedTurbo = 0x64;

  Map<String, int> toJson() => {
        'header': header,
        'idxForward': idxForward,
        'idxBackward': idxBackward,
        'idxRight': idxRight,
        'idxLeft': idxLeft,
        'idxLights': idxLights,
        'lightsInverted': lightsInverted ? 1 : 0,
        'idxSpeed': idxSpeed,
        'speedNormal': speedNormal,
        'speedTurbo': speedTurbo,
      };

  void fromJson(Map<String, dynamic> j) {
    int g(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    header = g('header', header);
    idxForward = g('idxForward', idxForward);
    idxBackward = g('idxBackward', idxBackward);
    idxRight = g('idxRight', idxRight);
    idxLeft = g('idxLeft', idxLeft);
    idxLights = g('idxLights', idxLights);
    lightsInverted = g('lightsInverted', lightsInverted ? 1 : 0) == 1;
    idxSpeed = g('idxSpeed', idxSpeed);
    speedNormal = g('speedNormal', speedNormal);
    speedTurbo = g('speedTurbo', speedTurbo);
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
