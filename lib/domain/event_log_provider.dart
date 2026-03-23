import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/app_event.dart';

/// Holds the in-session event log (max 200 entries, newest first).
class EventLogNotifier extends StateNotifier<List<AppEvent>> {
  static const int _maxEvents = 200;

  EventLogNotifier() : super([]);

  void add(AppEvent event) {
    final updated = [event, ...state];
    state = updated.length > _maxEvents
        ? updated.sublist(0, _maxEvents)
        : updated;
  }

  void clear() => state = [];
}

final eventLogProvider =
    StateNotifierProvider<EventLogNotifier, List<AppEvent>>(
  (ref) => EventLogNotifier(),
);
