import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

import 'shell_protocol.dart';

enum ConnectionStatus { disconnected, connecting, connected }

/// Cuida da conexão Web Bluetooth e do envio contínuo de comandos.
class CarConnection extends ChangeNotifier {
  final CarState state = CarState();

  ConnectionStatus status = ConnectionStatus.disconnected;
  String? deviceName;
  String? error;

  /// Descrição dos serviços/características encontrados (diagnóstico).
  String debugInfo = '';

  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  StreamSubscription<bool>? _connSub;
  Timer? _ticker;
  bool _writing = false;
  bool _withResponse = false;

  bool get isSupported => FlutterWebBluetooth.instance.isBluetoothApiSupported;

  Future<void> connect() async {
    error = null;
    status = ConnectionStatus.connecting;
    notifyListeners();
    try {
      final device = await FlutterWebBluetooth.instance.requestDevice(
        RequestOptionsBuilder.acceptAllDevices(
          optionalServices: ShellProtocol.optionalServices,
        ),
      );
      await device.connect();
      _device = device;
      _control = await _findControl(device);
      deviceName = device.name ?? device.id;

      _connSub = device.connected.listen((connected) {
        if (!connected) _handleDisconnected();
      });

      status = ConnectionStatus.connected;
      // O carrinho espera comandos contínuos; se pararem, ele para.
      _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) => _send());
    } catch (e) {
      // Usuário fechou a janela de seleção: não é erro.
      final cancelled = e.toString().toLowerCase().contains('cancel');
      error = cancelled ? null : e.toString();
      _device?.disconnect();
      _device = null;
      status = ConnectionStatus.disconnected;
    }
    notifyListeners();
  }

  /// Procura a característica de controle: primeiro pelo UUID conhecido,
  /// depois a primeira gravável (de preferência no serviço fff0).
  Future<BluetoothCharacteristic> _findControl(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final info = StringBuffer();
    final writable = <BluetoothCharacteristic>[];
    BluetoothCharacteristic? known;
    // Serviço fff0 primeiro.
    services.sort((a, b) =>
        (a.uuid.toLowerCase() == ShellProtocol.serviceUuid ? 0 : 1) -
        (b.uuid.toLowerCase() == ShellProtocol.serviceUuid ? 0 : 1));
    for (final service in services) {
      info.writeln('Serviço ${service.uuid}');
      List<BluetoothCharacteristic> chars;
      try {
        chars = await service.getCharacteristics();
      } catch (e) {
        info.writeln('  (erro ao listar: $e)');
        continue;
      }
      for (final c in chars) {
        final p = c.properties;
        final flags = [
          if (p.read) 'read',
          if (p.write) 'write',
          if (p.writeWithoutResponse) 'writeNoResp',
          if (p.notify) 'notify',
        ].join(', ');
        info.writeln('  ${c.uuid} [$flags]');
        if (c.uuid.toLowerCase() == ShellProtocol.controlCharacteristicUuid) {
          known = c;
        }
        if (p.write || p.writeWithoutResponse) writable.add(c);
      }
    }
    final chosen = known ?? (writable.isNotEmpty ? writable.first : null);
    if (chosen == null) {
      debugInfo = info.toString();
      throw StateError(
          'Nenhuma característica gravável encontrada. É um carrinho Shell?');
    }
    _withResponse = !chosen.properties.writeWithoutResponse;
    info.writeln('Usando: ${chosen.uuid}'
        '${_withResponse ? ' (write com resposta)' : ''}');
    debugInfo = info.toString();
    return chosen;
  }

  void disconnect() {
    state.releaseAll();
    _device?.disconnect();
    _handleDisconnected();
  }

  void _handleDisconnected() {
    _ticker?.cancel();
    _ticker = null;
    _connSub?.cancel();
    _connSub = null;
    _control = null;
    _device = null;
    status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> _send() async {
    final c = _control;
    if (c == null || _writing) return;
    _writing = true;
    try {
      final cmd = ShellProtocol.buildCommand(state);
      if (_withResponse) {
        await c.writeValueWithResponse(cmd);
      } else {
        await c.writeValueWithoutResponse(cmd);
      }
    } catch (_) {
      // Ignora falhas pontuais; desconexão é tratada pelo stream.
    } finally {
      _writing = false;
    }
  }

  /// Atualiza o estado e envia imediatamente.
  void update(void Function(CarState s) change) {
    change(state);
    notifyListeners();
    _send();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
