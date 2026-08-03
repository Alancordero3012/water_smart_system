import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/app_event.dart';
import '../../domain/event_log_provider.dart';

/// EndDrawer panel showing the in-session event timeline.
class EventLogPanel extends ConsumerStatefulWidget {
  const EventLogPanel({super.key});

  @override
  ConsumerState<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends ConsumerState<EventLogPanel> {
  bool _sendingTest = false;

  Future<void> _sendTestEmail(BuildContext context) async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    try {
      final uri = Uri.parse('https://watersmart-backend.onrender.com/api/test-email');
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({}))
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(data['ok'] == true ? Icons.check_circle : Icons.error,
                color: data['ok'] == true ? Colors.greenAccent : Colors.redAccent,
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(data['ok'] == true
                  ? '✅ Email de prueba enviado a ${data['message'] ?? ''}'
                  : '❌ Error: ${data['error'] ?? 'desconocido'}'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        duration: const Duration(seconds: 4),
      ));
    } on Exception catch (e) {
      if (!context.mounted) return;
      final isTimeout = e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(
              isTimeout ? Icons.hourglass_empty_rounded : Icons.wifi_off_rounded,
              color: Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isTimeout
                    ? '⏱ El backend tardó demasiado (puede estar despertando). Espera 30s e intenta de nuevo.'
                    : '❌ Sin conexión al backend: ${e.toString().substring(0, 60)}',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventLogProvider);

    return Drawer(
      width: 300,
      backgroundColor: const Color(0xFF0F0F1B),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_outlined,
                      color: Color(0xFF00E5FF), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'LOG DE EVENTOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  // Botón test email
                  Tooltip(
                    message: 'Enviar email de prueba',
                    child: _sendingTest
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Color(0xFF00E5FF)))
                        : IconButton(
                            icon: const Icon(Icons.mail_outline_rounded,
                                size: 18, color: Color(0xFF00E5FF)),
                            onPressed: () => _sendTestEmail(context),
                          ),
                  ),
                  if (events.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined,
                          size: 18, color: Colors.white38),
                      tooltip: 'Limpiar log',
                      onPressed: () =>
                          ref.read(eventLogProvider.notifier).clear(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Colors.white38),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          Container(height: 1, color: Colors.white.withAlpha(10)),

          // ── Event count badge ───────────────────────────────────────
          if (events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text(
                    '${events.length} evento${events.length == 1 ? '' : 's'} registrado${events.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withAlpha(60),
                    ),
                  ),
                ],
              ),
            ),

          // ── Timeline list ───────────────────────────────────────────
          Expanded(
            child: events.isEmpty
                ? _EmptyLog()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
                    itemCount: events.length,
                    itemBuilder: (ctx, i) => _EventTile(event: events[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────

class _EmptyLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 40, color: Colors.white.withAlpha(25)),
          const SizedBox(height: 10),
          Text(
            'Sin eventos',
            style: TextStyle(
                color: Colors.white.withAlpha(40), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'El sistema opera normalmente.',
            style: TextStyle(
                color: Colors.white.withAlpha(25), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Event row with timeline connector ─────────────────────────────

class _EventTile extends StatelessWidget {
  final AppEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final config = _severityConfig(event.severity);
    final timeStr =
        '${event.timestamp.hour.toString().padLeft(2, '0')}:'
        '${event.timestamp.minute.toString().padLeft(2, '0')}:'
        '${event.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline gutter —————————————————————————————————————
          SizedBox(
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: config.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: config.color.withAlpha(80), blurRadius: 6)
                    ],
                  ),
                ),
                // Connector down to next item
                Container(
                  width: 1,
                  height: 40,
                  color: config.color.withAlpha(20),
                ),
              ],
            ),
          ),

          // ── Content card ——————————————————————————————————————
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              decoration: BoxDecoration(
                color: config.color.withAlpha(8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: config.color.withAlpha(25), width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Severity badge + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: config.color.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          config.label,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: config.color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white.withAlpha(45),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    event.message,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withAlpha(180),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  _SeverityConfig _severityConfig(EventSeverity s) => switch (s) {
        EventSeverity.critical => _SeverityConfig(
            color: const Color(0xFFFF1744), label: 'CRÍTICO'),
        EventSeverity.warning => _SeverityConfig(
            color: const Color(0xFFFF9100), label: 'ALERTA'),
        EventSeverity.info => _SeverityConfig(
            color: const Color(0xFF00E5FF), label: 'INFO'),
      };
}

class _SeverityConfig {
  final Color color;
  final String label;
  const _SeverityConfig({required this.color, required this.label});
}
