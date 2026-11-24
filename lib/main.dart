import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/car_connection.dart';
import 'src/shell_protocol.dart';

const shellYellow = Color(0xFFFFD500);
const shellRed = Color(0xFFDD1D21);

/// Preenchido no build de publicação (ver .github/workflows/deploy.yml).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

void main() => runApp(const ControleRcApp());

class ControleRcApp extends StatelessWidget {
  const ControleRcApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Controle RC Shell',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: shellYellow,
            brightness: Brightness.dark,
            primary: shellYellow,
            secondary: shellRed,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
        ),
        home: const ControlPage(),
      );
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  final car = CarConnection();
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    car.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    car.dispose();
    focus.dispose();
    super.dispose();
  }

  // Teclado: WASD / setas, Shift = turbo, L = farol.
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final down = e is KeyDownEvent || e is KeyRepeatEvent;
    if (e is KeyRepeatEvent) return KeyEventResult.handled;
    final k = e.logicalKey;
    void Function(CarState)? change;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
      change = (s) => s.forward = down;
    } else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.keyS) {
      change = (s) => s.backward = down;
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.keyA) {
      change = (s) => s.left = down;
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.keyD) {
      change = (s) => s.right = down;
    } else if (k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight) {
      change = (s) => s.turbo = down;
    } else if (k == LogicalKeyboardKey.keyL && down) {
      change = (s) => s.lights = !s.lights;
    }
    if (change == null) return KeyEventResult.ignored;
    car.update(change);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final connected = car.status == ConnectionStatus.connected;
    return Focus(
      focusNode: focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: shellRed,
          foregroundColor: Colors.white,
          title: const Text('Controle RC Shell',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ConnectButton(car: car),
            ),
          ],
        ),
        body: SafeArea(
          child: !car.isSupported
              ? const _Message(
                  icon: Icons.bluetooth_disabled,
                  text: 'Web Bluetooth não está disponível neste navegador.\n\n'
                      'Use Google Chrome ou Microsoft Edge (Android, Windows, macOS).\n\n'
                      'No Linux: abra chrome://flags/#enable-experimental-web-platform-features,\n'
                      'ative "Experimental Web Platform features" e reinicie o Chrome.\n\n'
                      'iPhone/Safari não suportam.',
                )
              : Column(
                  children: [
                    _StatusBar(car: car),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: !connected,
                        child: Opacity(
                          opacity: connected ? 1 : 0.4,
                          child: _Controls(car: car),
                        ),
                      ),
                    ),
                    if (car.debugInfo.isNotEmpty)
                      ExpansionTile(
                        dense: true,
                        title: const Text('Detalhes do Bluetooth',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: SelectableText(car.debugInfo,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 11)),
                          ),
                          ValueListenableBuilder<String>(
                            valueListenable: car.stats,
                            builder: (_, v, __) => Text(v,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 11)),
                          ),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            children: [
                              const Text('Intervalo:',
                                  style: TextStyle(fontSize: 12)),
                              DropdownButton<int>(
                                value: car.intervalMs,
                                items: const [25, 50, 100, 150, 200]
                                    .map((ms) => DropdownMenuItem(
                                        value: ms, child: Text('$ms ms')))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) car.setInterval(v);
                                  focus.requestFocus();
                                },
                              ),
                              if (car.canToggleResponse)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('Com confirmação',
                                      style: TextStyle(fontSize: 12)),
                                  Switch(
                                    value: car.withResponse,
                                    onChanged: (v) {
                                      car.setWithResponse(v);
                                      focus.requestFocus();
                                    },
                                  ),
                                ]),
                            ],
                          ),
                        ],
                      ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Teclado: W A S D / setas • Shift = turbo • L = farol'
                        '   •   versão $appVersion',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.car});
  final CarConnection car;

  @override
  Widget build(BuildContext context) {
    switch (car.status) {
      case ConnectionStatus.connecting:
        return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white));
      case ConnectionStatus.connected:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.black26, foregroundColor: Colors.white),
          onPressed: car.disconnect,
          icon: const Icon(Icons.bluetooth_connected),
          label: const Text('Desconectar'),
        );
      case ConnectionStatus.disconnected:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: shellYellow, foregroundColor: Colors.black),
          onPressed: car.isSupported ? car.connect : null,
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Conectar'),
        );
    }
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.car});
  final CarConnection car;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (car.error != null) {
      text = 'Erro: ${car.error}';
      color = shellRed;
    } else if (car.status == ConnectionStatus.connected) {
      text = 'Conectado a ${car.deviceName}';
      color = Colors.green;
    } else if (car.status == ConnectionStatus.connecting) {
      text = 'Conectando...';
      color = shellYellow;
    } else {
      text = 'Ligue o carrinho e toque em "Conectar" '
          '(normalmente aparece como "SL-...")';
      color = Colors.white54;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.white10,
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: color)),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.car});
  final CarConnection car;

  @override
  Widget build(BuildContext context) {
    final s = car.state;
    final steering = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoldButton(
            icon: Icons.arrow_back_rounded,
            active: s.left,
            onChanged: (v) => car.update((s) => s.left = v)),
        const SizedBox(width: 16),
        _HoldButton(
            icon: Icons.arrow_forward_rounded,
            active: s.right,
            onChanged: (v) => car.update((s) => s.right = v)),
      ],
    );
    final throttle = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoldButton(
            icon: Icons.arrow_upward_rounded,
            active: s.forward,
            onChanged: (v) => car.update((s) => s.forward = v)),
        const SizedBox(height: 16),
        _HoldButton(
            icon: Icons.arrow_downward_rounded,
            active: s.backward,
            onChanged: (v) => car.update((s) => s.backward = v)),
      ],
    );
    final extras = Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _HoldButton(
            icon: Icons.bolt,
            label: 'Turbo',
            small: true,
            active: s.turbo,
            onChanged: (v) => car.update((s) => s.turbo = v)),
        _ToggleButton(
            icon: Icons.highlight,
            label: 'Farol',
            active: s.lights,
            onTap: () => car.update((s) => s.lights = !s.lights)),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      // Layout "gamepad": direção à esquerda, acelerador à direita.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            extras,
            FittedBox(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [steering, SizedBox(width: c.maxWidth > 600 ? 120 : 32), throttle],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Botão que fica ativo enquanto é pressionado (suporta multitoque).
class _HoldButton extends StatelessWidget {
  const _HoldButton({
    required this.icon,
    required this.active,
    required this.onChanged,
    this.label,
    this.small = false,
  });

  final IconData icon;
  final String? label;
  final bool active;
  final bool small;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = small ? 80.0 : 110.0;
    return Listener(
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: _Pad(size: size, icon: icon, label: label, active: active),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: _Pad(size: 80, icon: icon, label: label, active: active),
      );
}

class _Pad extends StatelessWidget {
  const _Pad(
      {required this.size,
      required this.icon,
      required this.active,
      this.label});
  final double size;
  final IconData icon;
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active ? shellYellow : const Color(0xFF2A2A2A),
          shape: BoxShape.circle,
          border: Border.all(color: shellRed, width: 3),
          boxShadow: active
              ? [BoxShadow(color: shellYellow.withValues(alpha: 0.5), blurRadius: 20)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: size * 0.45,
                color: active ? Colors.black : Colors.white),
            if (label != null)
              Text(label!,
                  style: TextStyle(
                      fontSize: 12,
                      color: active ? Colors.black : Colors.white70)),
          ],
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 64, color: shellRed),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      );
}
