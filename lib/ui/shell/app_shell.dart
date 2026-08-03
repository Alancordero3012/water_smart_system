import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../domain/auth_provider.dart';
import '../../domain/event_log_provider.dart';
import '../../domain/models/app_event.dart';
import '../alerts/alert_wrapper.dart';
import '../alerts/event_log_panel.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'control_screen.dart';
import '../components/components_screen.dart';
import '../worldwide/worldwide_screen.dart';

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
    _NavDest(Icons.device_hub_rounded, Icons.device_hub_outlined, 'Sistema'),
    _NavDest(Icons.public_rounded, Icons.public_outlined, 'Worldwide'),
    _NavDest(Icons.settings, Icons.settings_outlined, 'Config'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(_navIndexProvider);
    final isExpanded    = ref.watch(_sidebarExpandedProvider);
    final isSimulation  = ref.watch(useSimulationProvider);
    final events        = ref.watch(eventLogProvider);
    final authState     = ref.watch(authProvider);
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
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'v1.0 · ITT',
                        style: TextStyle(
                            color: Colors.white.withAlpha(30), fontSize: 10),
                      ),
                    )
                  else
                    const SizedBox(height: 4),

                  // ── Logout button ─────────────────────────────────────────────
                  if (isExpanded && authState.user != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: Text(
                        authState.user!.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(50),
                          fontSize: 9,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LogoutButton(
                      expanded: isExpanded,
                      onLogout: () => _confirmLogout(context, ref),
                    ),
                  ),
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
                  ComponentsScreen(),
                  WorldwideScreen(),
                  SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Deseas cerrar sesión? Tendrás que ingresar tus credenciales nuevamente.',
          style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withAlpha(120))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onLogout;

  const _LogoutButton({required this.expanded, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cerrar sesión',
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 10 : 0,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.red.withAlpha(0),
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded,
                  color: Colors.red.withAlpha(150), size: 20),
              if (expanded) ...[
                const SizedBox(width: 10),
                Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: Colors.red.withAlpha(180),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
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
