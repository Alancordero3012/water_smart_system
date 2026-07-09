import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/bomba_notifier.dart';

/// Gran botón pulsador industrial para la Bomba.
///
/// Diseño "Gritty Realism":
///   • Cuerpo metálico circluar con gradiente de aluminio anodizado.
///   • Anillo LED azul que sólo se ilumina tras recibir el eco MQTT del hardware.
///   • Spinner de confirmación mientras el comando viaja por el broker.
///   • Engranajes decorativos que giran cuando la bomba está activa.
class BombaButton extends ConsumerStatefulWidget {
  const BombaButton({super.key});

  @override
  ConsumerState<BombaButton> createState() => _BombaButtonState();
}

class _BombaButtonState extends ConsumerState<BombaButton>
    with TickerProviderStateMixin {
  // Animación del pulso del anillo LED
  late final AnimationController _ledPulse;
  late final Animation<double> _ledAnim;

  // Animación de presión del botón (scale down on press)
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressAnim;

  // Rotación del ícono de engranajes (activo = girando)
  late final AnimationController _gearCtrl;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    _ledPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _ledAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ledPulse, curve: Curves.easeInOut),
    );

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );

    _gearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ledPulse.dispose();
    _pressCtrl.dispose();
    _gearCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _pressCtrl.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bomba = ref.watch(bombaProvider);
    final on      = bomba.confirmedOn;
    final pending = bomba.isPending;

    // Paleta por estado
    const ledBlue      = Color(0xFF00B4FF);
    const ledGlow      = Color(0xFF00D4FF);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── LED ring + button body ──────────────────────────────────────
        GestureDetector(
          onTapDown: pending ? null : _onTapDown,
          onTapUp: pending ? null : (d) {
            _onTapUp(d);
            ref.read(bombaProvider.notifier).toggle();
          },
          onTapCancel: _onTapCancel,
          child: ScaleTransition(
            scale: _pressAnim,
            child: AnimatedBuilder(
              animation: Listenable.merge([_ledAnim, _gearCtrl]),
              builder: (context, _) {
                final ledOpacity = on ? _ledAnim.value : 0.18;
                final ledWidth   = on ? 6.0 : 3.0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // ── Outer LED ring glow (only when ON) ──────────
                    if (on)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _ledAnim.value * 0.55,
                        child: Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: ledGlow.withValues(alpha: 0.55),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── LED ring border ──────────────────────────────
                    Container(
                      width: 142,
                      height: 142,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: on
                              ? ledBlue.withValues(alpha: ledOpacity)
                              : Colors.white.withValues(alpha: 0.08),
                          width: ledWidth,
                        ),
                        color: Colors.transparent,
                      ),
                    ),

                    // ── Main metallic button body ────────────────────
                    _MetallicBody(
                      size: 128,
                      isPressed: _isPressed,
                      isOn: on,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Gear icon (rotates when on)
                          Opacity(
                            opacity: 0.15,
                            child: Transform.rotate(
                              angle: on
                                  ? _gearCtrl.value * 2 * math.pi
                                  : 0,
                              child: const Icon(
                                Icons.settings,
                                size: 88,
                                color: Colors.white,
                              ),
                            ),
                          ),

                          // Center icon + state
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (pending)
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ledBlue.withValues(alpha: 0.9),
                                    ),
                                  ),
                                )
                              else
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    on
                                        ? Icons.power_settings_new
                                        : Icons.power_settings_new,
                                    key: ValueKey(on),
                                    size: 30,
                                    color: on
                                        ? ledBlue
                                        : Colors.white.withValues(alpha: 0.35),
                                    shadows: on
                                        ? [
                                            Shadow(
                                              color: ledGlow,
                                              blurRadius: 14,
                                            )
                                          ]
                                        : null,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: pending
                                      ? Colors.orange.withValues(alpha: 0.85)
                                      : on
                                          ? ledBlue
                                          : Colors.white.withValues(alpha: 0.25),
                                  fontFamily: 'monospace',
                                  shadows: on && !pending
                                      ? [
                                          Shadow(
                                            color: ledGlow,
                                            blurRadius: 8,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  pending ? 'CONFIRM...' : on ? 'ACTIVA' : 'PARADA',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Screws (decorative corners) ──────────────────
                    ..._buildScrews(),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Label ───────────────────────────────────────────────────────
        _BombaLabel(isOn: bomba.confirmedOn, isPending: bomba.isPending),
      ],
    );
  }

  /// Cuatro tornillos decorativos en las esquinas del botón
  List<Widget> _buildScrews() {
    const offsets = [
      Offset(-55, -55),
      Offset(55, -55),
      Offset(-55, 55),
      Offset(55, 55),
    ];
    return offsets.map((o) {
      return Transform.translate(
        offset: o,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1E2C),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: Container(
              width: 3,
              height: 0.8,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ── Metallic body ─────────────────────────────────────────────────────────────

class _MetallicBody extends StatelessWidget {
  final double size;
  final bool isPressed;
  final bool isOn;
  final Widget child;

  const _MetallicBody({
    required this.size,
    required this.isPressed,
    required this.isOn,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: isPressed
              ? [
                  const Color(0xFF22222E),
                  const Color(0xFF111118),
                ]
              : [
                  const Color(0xFF3C3C50),
                  const Color(0xFF18181F),
                ],
        ),
        boxShadow: [
          // Inner depression when pressed
          if (isPressed) ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
          ] else ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 18,
              spreadRadius: 4,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.04),
              blurRadius: 4,
              spreadRadius: -2,
              offset: const Offset(-3, -3),
            ),
          ],
          // Glow when on
          if (isOn && !isPressed)
            BoxShadow(
              color: const Color(0xFF00B4FF).withValues(alpha: 0.20),
              blurRadius: 22,
              spreadRadius: 2,
            ),
        ],
        border: Border.all(
          color: isPressed
              ? Colors.black.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

// ── Label bajo el botón ───────────────────────────────────────────────────────

class _BombaLabel extends StatelessWidget {
  final bool isOn;
  final bool isPending;

  const _BombaLabel({required this.isOn, required this.isPending});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ENCENDER BOMBA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isPending
                ? Colors.orange.withValues(alpha: 0.12)
                : isOn
                    ? const Color(0xFF00B4FF).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPending
                  ? Colors.orange.withValues(alpha: 0.4)
                  : isOn
                      ? const Color(0xFF00B4FF).withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPending
                      ? Colors.orange
                      : isOn
                          ? const Color(0xFF00D4FF)
                          : Colors.white.withValues(alpha: 0.2),
                  boxShadow: isOn && !isPending
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withValues(alpha: 0.7),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isPending
                    ? 'ESPERANDO ECO MQTT...'
                    : isOn
                        ? 'BOMBA ENCENDIDA'
                        : 'BOMBA APAGADA',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontFamily: 'monospace',
                  color: isPending
                      ? Colors.orange.withValues(alpha: 0.85)
                      : isOn
                          ? const Color(0xFF00D4FF)
                          : Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
