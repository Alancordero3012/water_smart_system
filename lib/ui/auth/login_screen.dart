import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/auth_provider.dart';
import '../../domain/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _formKey  = GlobalKey<FormState>();

  bool _obscurePass = true;
  bool _isLoading   = false;
  bool _hasError    = false;

  late final AnimationController _shakeCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() { _hasError = false; _isLoading = true; });

    final ok = await ref.read(authProvider.notifier)
        .login(_emailCtrl.text, _passCtrl.text);

    if (!mounted) return;

    if (ok) {
      // Simulación SIEMPRE apagada al iniciar sesión
      ref.read(useSimulationProvider.notifier).state = false;
    } else {
      final errMsg = ref.read(authProvider).error;
      setState(() {
        _isLoading = false;
        _hasError  = true;
        _errorMsg  = errMsg ?? 'Credenciales inválidas';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  String _errorMsg = 'Credenciales inválidas';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090E1A),
      body: Stack(
        children: [
          // ── Animated background blobs ─────────────────────────────────────
          _BackgroundBlobs(pulseAnim: _pulseAnim),

          // ── Center card ───────────────────────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ShakeWidget(
                  controller: _shakeCtrl,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white.withAlpha(8),
                        border: Border.all(
                          color: _hasError
                              ? Colors.redAccent.withAlpha(80)
                              : const Color(0xFF00E5FF).withAlpha(30),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _hasError
                                ? Colors.redAccent.withAlpha(20)
                                : const Color(0xFF00E5FF).withAlpha(15),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            _Logo(hasError: _hasError),
                            const SizedBox(height: 12),
                            const Text(
                              'SIGA',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PANEL DE CONTROL',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2.5,
                                color: Colors.white.withAlpha(60),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // ── Email ───────────────────────────────────────────
                            _GlowField(
                              controller: _emailCtrl,
                              label: 'Email',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              hasError: _hasError,
                              onSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 16),

                            // ── Contraseña ────────────────────────────────
                            _GlowField(
                              controller: _passCtrl,
                              label: 'Contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePass,
                              hasError: _hasError,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: Colors.white38,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePass = !_obscurePass),
                              ),
                              onSubmitted: (_) => _submit(),
                            ),

                            // Error message
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              child: _hasError
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.redAccent, size: 14),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _errorMsg,
                                              style: TextStyle(
                                                color: Colors.redAccent
                                                    .withAlpha(200),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 28),

                            // ── Botón Login ───────────────────────────────
                            _LoginButton(
                              isLoading: _isLoading,
                              onTap: _submit,
                            ),

                            const SizedBox(height: 24),
                            Text(
                              'Sistema de Gestión de Agua Inteligente',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withAlpha(30),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo animado ─────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final bool hasError;
  const _Logo({required this.hasError});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasError
            ? Colors.redAccent.withAlpha(15)
            : const Color(0xFF00E5FF).withAlpha(15),
        border: Border.all(
          color: hasError
              ? Colors.redAccent.withAlpha(80)
              : const Color(0xFF00E5FF).withAlpha(60),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: hasError
                ? Colors.redAccent.withAlpha(40)
                : const Color(0xFF00E5FF).withAlpha(30),
            blurRadius: 20,
          ),
        ],
      ),
      child: Icon(
        hasError ? Icons.lock_person_rounded : Icons.water_drop_rounded,
        color: hasError ? Colors.redAccent : const Color(0xFF00E5FF),
        size: 32,
      ),
    );
  }
}

// ── Glow text field ───────────────────────────────────────────────────────────

class _GlowField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final bool hasError;
  final Widget? suffix;
  final void Function(String)? onSubmitted;
  final TextInputType? keyboardType;

  const _GlowField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.hasError = false,
    this.suffix,
    this.onSubmitted,
    this.keyboardType,
  });

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.hasError
        ? Colors.redAccent
        : const Color(0xFF00E5FF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [BoxShadow(color: activeColor.withAlpha(40), blurRadius: 12)]
            : [],
      ),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure,
          keyboardType: widget.keyboardType,
          onFieldSubmitted: widget.onSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _focused ? activeColor : Colors.white38,
              fontSize: 13,
            ),
            prefixIcon: Icon(widget.icon,
                color: _focused ? activeColor : Colors.white24, size: 18),
            suffixIcon: widget.suffix,
            filled: true,
            fillColor: Colors.white.withAlpha(6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(20)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: widget.hasError
                      ? Colors.redAccent.withAlpha(60)
                      : Colors.white.withAlpha(20)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: activeColor.withAlpha(150), width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Login Button ─────────────────────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LoginButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF00B4D8), Color(0xFF00E5FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withAlpha(isLoading ? 20 : 70),
              blurRadius: isLoading ? 4 : 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login_rounded, color: Colors.black87, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'INGRESAR',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Shake animation ───────────────────────────────────────────────────────────

class _ShakeWidget extends StatelessWidget {
  final AnimationController controller;
  final Widget child;
  const _ShakeWidget({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final sin = math.sin(controller.value * math.pi * 6);
        return Transform.translate(
          offset: Offset(sin * 8.0, 0),
          child: child,
        );
      },
    );
  }
}

// ── Background blobs ──────────────────────────────────────────────────────────

class _BackgroundBlobs extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _BackgroundBlobs({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) => Stack(
        children: [
          // Top-left blob
          Positioned(
            top: -size.height * 0.15,
            left: -size.width * 0.2,
            child: _blob(
              size.width * 0.7 * pulseAnim.value,
              const Color(0xFF00B4D8),
            ),
          ),
          // Bottom-right blob
          Positioned(
            bottom: -size.height * 0.2,
            right: -size.width * 0.15,
            child: _blob(
              size.width * 0.65 * pulseAnim.value,
              const Color(0xFF0077B6),
            ),
          ),
          // Center subtle blob
          Positioned(
            top: size.height * 0.4,
            left: size.width * 0.3,
            child: _blob(size.width * 0.4, const Color(0xFF023E8A), alpha: 30),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, {int alpha = 20}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withAlpha(alpha), Colors.transparent],
          ),
        ),
      );
}
