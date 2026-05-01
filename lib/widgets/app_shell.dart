import 'package:flutter/material.dart';

import '../pages/dashboard_page.dart';
import '../pages/expenses_page.dart';
import '../pages/incomes_page.dart';
import '../services/auth_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AuthService _authService = AuthService();

  int _selectedIndex = 0;

  late final List<_AppNavItem> _items = [
    const _AppNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      page: DashboardPage(),
    ),
    const _AppNavItem(
      label: 'Spese',
      icon: Icons.receipt_long_rounded,
      page: ExpensesPage(),
    ),
    const _AppNavItem(
      label: 'Entrate',
      icon: Icons.trending_up_rounded,
      page: IncomesPage(),
    ),
    const _AppNavItem(
      label: 'Obiettivi',
      icon: Icons.flag_rounded,
      page: _PlaceholderPage(
        title: 'Obiettivi',
        icon: Icons.flag_rounded,
        description:
            'Qui gestiremo gli obiettivi di risparmio e il progresso mensile.',
      ),
    ),
    const _AppNavItem(
      label: 'AI Planner',
      icon: Icons.auto_awesome_rounded,
      page: _PlaceholderPage(
        title: 'AI Planner',
        icon: Icons.auto_awesome_rounded,
        description:
            'Qui aggiungeremo l’assistente AI per ricalcolare budget e risparmi.',
      ),
    ),
    const _AppNavItem(
      label: 'Impostazioni',
      icon: Icons.settings_rounded,
      page: _PlaceholderPage(
        title: 'Impostazioni',
        icon: Icons.settings_rounded,
        description: 'Qui gestiremo profilo, notifiche, email e preferenze.',
      ),
    ),
  ];

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);
    final selectedItem = _items[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(
                selectedItem.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
              centerTitle: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  tooltip: 'Esci',
                  onPressed: _logout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF172033),
                  ),
                ),
              ],
            ),
      body: Row(
        children: [
          if (isDesktop)
            _DesktopSidebar(
              items: _items,
              selectedIndex: _selectedIndex,
              onSelect: _selectPage,
              onLogout: _logout,
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: selectedItem.page,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : _MobileBottomNav(
              items: _items,
              selectedIndex: _selectedIndex,
              onSelect: _selectPage,
            ),
    );
  }
}

class _AppNavItem {
  final String label;
  final IconData icon;
  final Widget page;

  const _AppNavItem({
    required this.label,
    required this.icon,
    required this.page,
  });
}

class _DesktopSidebar extends StatelessWidget {
  final List<_AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _DesktopSidebar({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Color(0xFFE5ECF5),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            children: [
              const _SidebarLogo(),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = index == selectedIndex;

                    return _SidebarItem(
                      label: item.label,
                      icon: item.icon,
                      selected: selected,
                      onTap: () => onSelect(index),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              _SidebarLogoutButton(
                onLogout: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 82,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: const Offset(-8, 0),
          child: Image.asset(
            'assets/images/pocketplan_logo.png',
            width: 230,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        selected ? const Color(0xFFE3F2FD) : Colors.transparent;

    final foregroundColor =
        selected ? const Color(0xFF1565C0) : const Color(0xFF475569);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: foregroundColor,
                size: 23,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E88E5),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLogoutButton extends StatelessWidget {
  final VoidCallback onLogout;

  const _SidebarLogoutButton({
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 12),
              Text(
                'Esci',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final List<_AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MobileBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final dashboard = items[0];
    final expenses = items[1];
    final incomes = items[2];
    final goals = items[3];
    final aiPlanner = items[4];

    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        8,
        14,
        bottomPadding > 0 ? bottomPadding : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE5ECF5),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SizedBox(
        height: 92,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _MobileNavItem(
                item: expenses,
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
            ),
            Expanded(
              child: _MobileNavItem(
                item: incomes,
                selected: selectedIndex == 2,
                onTap: () => onSelect(2),
              ),
            ),
            Expanded(
              child: _MobileDashboardButton(
                item: dashboard,
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
            ),
            Expanded(
              child: _MobileNavItem(
                item: goals,
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
              ),
            ),
            Expanded(
              child: _MobileNavItem(
                item: aiPlanner,
                selected: selectedIndex == 4,
                onTap: () => onSelect(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final _AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF1565C0) : const Color(0xFF94A3B8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE3F2FD) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: color,
                size: selected ? 25 : 23,
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileDashboardButton extends StatelessWidget {
  final _AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _MobileDashboardButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: selected ? 62 : 58,
                height: selected ? 62 : 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E88E5),
                      Color(0xFF1565C0),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                      blurRadius: selected ? 22 : 16,
                      offset: const Offset(0, 9),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white,
                    width: 4,
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: Colors.white,
                  size: selected ? 29 : 27,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFE5ECF5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF1E88E5),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pagina in preparazione',
                  style: TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}