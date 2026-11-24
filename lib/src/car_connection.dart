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

  BluetoothDevice? _device;
  BluetoothCharacteristic? _control;
  StreamSubscription<bool>? _connSub;
  Timer? _ticker;
  bool _writing = false;

  bool get isSupported => FlutterWebBluetooth.instance.isBluetoothApiSupported;

  Future<void> connect() async {
    error = null;
    status = ConnectionStatus.connecting;
    notifyListeners();
    try {
      final device = await FlutterWebBluetooth.instance.requestDevice(
        RequestOptionsBuilder.acceptAllDevices(
          optionalServices: [ShellProtocol.serviceUuid],
        ),
      );
      await device.connect();
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.toLowerCase() == ShellProtocol.serviceUuid,
        orElse: () => throw StateError(
            'Serviço do carrinho não encontrado. É um carrinho Shell?'),
      );
      _control = await service
          .getCharacteristic(ShellProtocol.controlCharacteristicUuid);
      _device = device;
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
      status = ConnectionStatus.disconnected;
    }
    notifyListeners();
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
      await c.writeValueWithoutResponse(ShellProtocol.buildCommand(state));
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
