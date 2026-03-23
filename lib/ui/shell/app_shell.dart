import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/event_log_provider.dart';
import '../../domain/models/app_event.dart';
import '../alerts/alert_wrapper.dart';
import '../alerts/event_log_panel.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'control_screen.dart';

// Tracks selected destination index
final _navIndexProvider = StateProvider<int>((ref) => 0);
// Tracks expanded/collapsed state of sidebar
final _sidebarExpandedProvider = StateProvider<bool>((ref) => false);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _destinations = [
    _NavDest(Icons.sensors, Icons.sensors_outlined, 'Dashboard'),
    _NavDest(Icons.tune, Icons.tune_outlined, 'Control'),
    _NavDest(Icons.show_chart, Icons.show_chart_outlined, 'Historial'),
    _NavDest(Icons.settings, Icons.settings_outlined, 'Config'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(_navIndexProvider);
    final isExpanded = ref.watch(_sidebarExpandedProvider);
    final isSimulation = ref.watch(useSimulationProvider);
    final events = ref.watch(eventLogProvider);
    final criticalCount = events
        .where((e) => e.severity == EventSeverity.critical)
        .length;

    return AlertWrapper(
      child: Scaffold(
        endDrawer: const EventLogPanel(),
        // Scaffold background matches sidebar so there's no flash on open
        backgroundColor: const Color(0xFF0D0D1A),
        body: Row(
          children: [
            // ── Sidebar ──────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: isExpanded ? 160 : 64,
              color: const Color(0xFF0F0F1B),
              child: Column(
                children: [
                  // App logo + hamburger
                  SizedBox(
                    height: MediaQuery.of(context).padding.top + 56,
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: isExpanded
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.center,
                        children: [
                          if (isExpanded) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.water_drop,
                                color: Color(0xFF00E5FF), size: 20),
                            const SizedBox(width: 4),
                            const Text(
                              'WSS',
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                          ],
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.menu_open : Icons.menu,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () => ref
                                .read(_sidebarExpandedProvider.notifier)
                                .state = !isExpanded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // DEMO badge
                  if (isSimulation)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.orange.withAlpha(60), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize:
                              isExpanded ? MainAxisSize.max : MainAxisSize.min,
                          children: [
                            const Icon(Icons.science,
                                size: 10, color: Colors.orange),
                            if (isExpanded) ...[
                              const SizedBox(width: 4),
                              const Text(
                                'DEMO',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),

                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      itemCount: _destinations.length,
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, i) {
                        final dest = _destinations[i];
                        final selected = selectedIndex == i;
                        return _NavItem(
                          icon: selected ? dest.selectedIcon : dest.icon,
                          label: dest.label,
                          selected: selected,
                          expanded: isExpanded,
                          onTap: () =>
                              ref.read(_navIndexProvider.notifier).state = i,
                        );
                      },
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 8),

                  // ── Bell button (opens EventLogPanel EndDrawer) ──
                  Builder(builder: (ctx) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              events.isEmpty
                                  ? Icons.notifications_none
                                  : Icons.notifications,
                              color: events.isEmpty
                                  ? Colors.white24
                                  : criticalCount > 0
                                      ? const Color(0xFFFF1744)
                                      : const Color(0xFFFF9100),
                              size: 22,
                            ),
                            tooltip: 'Log de eventos',
                            onPressed: () =>
                                Scaffold.of(ctx).openEndDrawer(),
                          ),
                          // Unread count badge
                          if (events.isNotEmpty)
                            Positioned(
                              top: 4,
                              right: isExpanded ? 30 : 6,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(
                                    minWidth: 15, minHeight: 15),
                                decoration: BoxDecoration(
                                  color: criticalCount > 0
                                      ? const Color(0xFFFF1744)
                                      : const Color(0xFFFF9100),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  events.length > 99
                                      ? '99+'
                                      : '${events.length}',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'v1.0 · ITT',
                        style: TextStyle(
                            color: Colors.white.withAlpha(30), fontSize: 10),
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),

            // Vertical divider
            Container(width: 1, color: Colors.white.withAlpha(8)),

            // ── Main Content (IndexedStack preserves state) ──────────
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: const [
                  DashboardBody(),
                  ControlScreen(),
                  HistoryScreen(),
                  SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDest {
  final IconData selectedIcon;
  final IconData icon;
  final String label;
  const _NavDest(this.selectedIcon, this.icon, this.label);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00E5FF);
    final bg = selected ? accent.withAlpha(18) : Colors.transparent;
    final iconColor = selected ? accent : Colors.white38;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 10 : 0,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: accent.withAlpha(40), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            if (expanded) ...[
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
