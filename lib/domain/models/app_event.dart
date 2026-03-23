
/// Severity levels for system events.
enum EventSeverity { info, warning, critical }

/// An immutable event emitted by the monitoring system.
class AppEvent {
  final String id;
  final String message;
  final DateTime timestamp;
  final EventSeverity severity;

  AppEvent({
    required this.message,
    required this.severity,
  })  : id = '${DateTime.now().microsecondsSinceEpoch}',
        timestamp = DateTime.now();
}
