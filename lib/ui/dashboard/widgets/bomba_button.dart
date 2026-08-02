import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/bomba_notifier.dart';

/// Control de Bomba Principal — Diseño premium horizontal tipo panel industrial.
///
/// Layout:
///   [Icono+Estado] ── [Nombre + Descripción + MQTT badge] ── [Toggle]
class BombaButton extends ConsumerStatefulWidget {
  final bool canControl;
  const BombaButton({super.key, this.canControl = true});

  @override
  ConsumerState<BombaButton> createState() => _BombaButtonState();
}

class _BombaButtonState extends ConsumerState<BombaButton>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;
  late final AnimationController _gearCtrl;
  late final AnimationController _pressCtrl;
  late final Animation<double>   _pressAnim;

  static const _blue    = Color(0xFF00B4FF);

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _gearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _gearCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _pressCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _pressCtrl.reverse();
  }

  void _onTapCancel() {
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bomba   = ref.watch(bombaProvider);
    final on      = bomba.confirmedOn;
    final pending = bomba.isPending;

    return GestureDetector(
      onTapDown: (pending || !widget.canControl) ? null : _onTapDown,
      onTapUp: (pending || !widget.canControl) ? null : (d) {
        _onTapUp(d);
        ref.read(bombaProvider.notifier).toggle();
      },
      onTapCancel: (pending || !widget.canControl) ? null : _onTapCancel,
      child: Opacity(
        opacity: widget.canControl ? 1.0 : 0.5,
        child: ScaleTransition(
          scale: _pressAnim,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnim, _gearCtrl]),
            builder: (_, __) => _buildCard(on: on, pending: pending),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required bool on, required bool pending}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: on && !pending
              ? [const Color(0xFF0A1A2E), const Color(0xFF0D1520)]
              : [const Color(0xFF141420), const Color(0xFF0E0E18)],
        ),
        border: Border.all(
          color: on && !pending
              ? _blue.withValues(alpha: _pulseAnim.value * 0.35)
              : Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          if (on && !pending)
            BoxShadow(
              color: _blue.withValues(alpha: _pulseAnim.value * 0.15),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // ── Icono circular con LED ─────────────────────────────────────
            _PowerIcon(
              on: on,
              pending: pending,
              pulseValue: _pulseAnim.value,
              gearValue: _gearCtrl.value,
            ),

            const SizedBox(width: 14),

            // ── Info central ──────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre
                  const Text(
                    'Bomba Principal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Estado animado
                  _StatusLine(on: on, pending: pending),
                  const SizedBox(height: 6),
                  // Badge MQTT
                  _MqttBadge(on: on),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Toggle switch custom ──────────────────────────────────────
            _PowerToggle(on: on, pending: pending, pulseValue: _pulseAnim.value),
          ],
        ),
      ),
    );
  }
}

// ── Power icon ────────────────────────────────────────────────────────────────

class _PowerIcon extends StatelessWidget {
  final bool on;
  final bool pending;
  final double pulseValue;
  final double gearValue;

  const _PowerIcon({
    required this.on,
    required this.pending,
    required this.pulseValue,
    required this.gearValue,
  });

  static const _blue    = Color(0xFF00B4FF);
  static const _blueGlow = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: on && !pending
              ? [const Color(0xFF0C2040), const Color(0xFF060C14)]
              : [const Color(0xFF1E1E2E), const Color(0xFF111118)],
        ),
        border: Border.all(
          color: on && !pending
              ? _blue.withValues(alpha: pulseValue * 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: on && !pending ? 1.5 : 1,
        ),
        boxShadow: [
          if (on && !pending)
            BoxShadow(
              color: _blueGlow.withValues(alpha: pulseValue * 0.3),
              blurRadius: 14,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Engranaje de fondo
          if (on && !pending)
            Transform.rotate(
              angle: gearValue * 2 * math.pi,
              child: Icon(
                Icons.settings,
                size: 38,
                color: _blue.withValues(alpha: 0.08),
              ),
            ),
          // Icono central
          if (pending)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.orange.withValues(alpha: 0.9),
                ),
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.power_settings_new_rounded,
                key: ValueKey(on),
                size: 22,
                color: on ? _blue : Colors.white.withValues(alpha: 0.3),
                shadows: on
                    ? [Shadow(color: _blueGlow, blurRadius: 10)]
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status line ───────────────────────────────────────────────────────────────

class _StatusLine extends StatelessWidget {
  final bool on;
  final bool pending;
  const _StatusLine({required this.on, required this.pending});

  static const _blue = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    final color = pending
        ? Colors.orange
        : on
            ? _blue
            : Colors.white.withValues(alpha: 0.3);

    final label = pending
        ? 'Sincronizando...'
        : on
            ? 'En operación'
            : 'Detenida';

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: (on || pending)
                ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 5)]
                : null,
          ),
        ),
        const SizedBox(width: 5),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
            letterSpacing: 0.2,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

// ── MQTT badge ────────────────────────────────────────────────────────────────

class _MqttBadge extends StatelessWidget {
  final bool on;
  const _MqttBadge({required this.on});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'MQTT · agua_iot/actuadores/bomba',
        style: TextStyle(
          fontSize: 8,
          fontFamily: 'monospace',
          color: Colors.white.withValues(alpha: 0.25),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Power toggle ──────────────────────────────────────────────────────────────

class _PowerToggle extends StatelessWidget {
  final bool on;
  final bool pending;
  final double pulseValue;
  const _PowerToggle({required this.on, required this.pending, required this.pulseValue});

  static const _blue = Color(0xFF00B4FF);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 48,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: pending
            ? Colors.orange.withValues(alpha: 0.15)
            : on
                ? _blue.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: pending
              ? Colors.orange.withValues(alpha: 0.5)
              : on
                  ? _blue.withValues(alpha: pulseValue * 0.8)
                  : Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: on && !pending
            ? [BoxShadow(color: _blue.withValues(alpha: pulseValue * 0.2), blurRadius: 8)]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Track line
          Container(
            height: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Thumb
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pending
                    ? Colors.orange
                    : on
                        ? _blue
                        : Colors.white.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: (pending
                            ? Colors.orange
                            : on
                                ? _blue
                                : Colors.transparent)
                        .withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: pending
                  ? Center(
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.2,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
