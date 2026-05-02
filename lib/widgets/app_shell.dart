import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/ai_planner_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/expenses_page.dart';
import '../pages/goals_page.dart';
import '../pages/incomes_page.dart';
import '../pages/settings_page.dart';
import '../services/auth_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AuthService _authService = AuthService();

  final GlobalKey<FormState> _ticketFormKey = GlobalKey<FormState>();
  final TextEditingController _ticketSubjectController =
      TextEditingController();
  final TextEditingController _ticketMessageController =
      TextEditingController();

  int _selectedIndex = 0;
  String _ticketPriority = 'Normale';

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
      page: GoalsPage(),
    ),
    const _AppNavItem(
      label: 'AI Planner',
      icon: Icons.auto_awesome_rounded,
      page: AIPlannerPage(),
    ),
    const _AppNavItem(
      label: 'Impostazioni',
      icon: Icons.settings_rounded,
      page: SettingsPage(),
    ),
  ];

  @override
  void dispose() {
    _ticketSubjectController.dispose();
    _ticketMessageController.dispose();
    super.dispose();
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openSettings() {
    setState(() {
      _selectedIndex = 5;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
  }

  Future<void> _showLogoutDialog() async {
    final colors = _ShellColors.of(context);

    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Uscire dall’account?',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Sei sicuro di voler uscire dal tuo account?',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(
                    color: colors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Annulla'),
              ),
            ),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('Esci'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await _logout();
  }

  InputDecoration _ticketInputDecoration({
    required String label,
    String? hint,
  }) {
    final colors = _ShellColors.of(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: colors.textMuted,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(
        color: colors.textMuted,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: colors.isDark ? colors.cardSofter : Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  Future<void> _showSupportTicketDialog() async {
    final colors = _ShellColors.of(context);

    _ticketSubjectController.clear();
    _ticketMessageController.clear();
    _ticketPriority = 'Normale';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(
                        alpha: colors.isDark ? 0.32 : 0.12,
                      ),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Form(
                  key: _ticketFormKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.support_agent_rounded,
                                color: colors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Apri ticket di supporto',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Descrivi il problema e ti aiuteremo il prima possibile.',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: Icon(
                                Icons.close_rounded,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _ticketSubjectController,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _ticketInputDecoration(
                            label: 'Oggetto',
                            hint: 'Es. Problema con una spesa',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci un oggetto';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _ticketPriority,
                          dropdownColor: colors.card,
                          iconEnabledColor: colors.textMuted,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _ticketInputDecoration(
                            label: 'Priorità',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Bassa',
                              child: Text('Bassa'),
                            ),
                            DropdownMenuItem(
                              value: 'Normale',
                              child: Text('Normale'),
                            ),
                            DropdownMenuItem(
                              value: 'Alta',
                              child: Text('Alta'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              _ticketPriority = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _ticketMessageController,
                          minLines: 5,
                          maxLines: 7,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                          decoration: _ticketInputDecoration(
                            label: 'Descrizione',
                            hint:
                                'Scrivi qui cosa non funziona o cosa ti serve...',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci una descrizione';
                            }

                            if (value.trim().length < 10) {
                              return 'Descrivi meglio il problema';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Per ora il ticket viene solo simulato. Quando vuoi, lo colleghiamo a Firebase, Appwrite o al tuo backend.',
                                  style: TextStyle(
                                    color: colors.primary,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.textPrimary,
                                    side: BorderSide(
                                      color: colors.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  child: const Text('Annulla'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (!_ticketFormKey.currentState!
                                        .validate()) {
                                      return;
                                    }

                                    final subject =
                                        _ticketSubjectController.text.trim();

                                    Navigator.pop(dialogContext);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: colors.primary,
                                        content: Text(
                                          'Ticket "$subject" aperto correttamente.',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 19,
                                  ),
                                  label: const Text('Invia ticket'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor: colors.primaryText,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _ShellColors.of(context);
    final isDesktop = _isDesktop(context);
    final showSupportButton = kIsWeb && isDesktop;
    final selectedItem = _items[_selectedIndex];
    final settingsSelected = _selectedIndex == 5;

    return Scaffold(
      backgroundColor: colors.scaffold,
      extendBody: true,
      appBar: isDesktop
          ? null
          : AppBar(
              titleSpacing: 14,
              title: SizedBox(
                height: 46,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    colors.logoAsset,
                    width: 145,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) {
                      return Text(
                        'PocketPlan',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      );
                    },
                  ),
                ),
              ),
              centerTitle: false,
              backgroundColor: colors.card,
              surfaceTintColor: colors.card,
              elevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: settingsSelected
                            ? colors.primarySoft
                            : colors.cardSofter,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _openSettings,
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.settings_rounded,
                              color: settingsSelected
                                  ? colors.primary
                                  : colors.textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: colors.danger,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _showLogoutDialog,
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      body: Stack(
        children: [
          Row(
            children: [
              if (isDesktop)
                _DesktopSidebar(
                  items: _items,
                  selectedIndex: _selectedIndex,
                  onSelect: _selectPage,
                  onLogout: _showLogoutDialog,
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
          if (showSupportButton)
            Positioned(
              right: 28,
              bottom: 28,
              child: _SupportFloatingButton(
                onTap: _showSupportTicketDialog,
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

class _ShellColors {
  final bool isDark;
  final Color scaffold;
  final Color card;
  final Color cardSoft;
  final Color cardSofter;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primarySoft;
  final Color primaryText;
  final Color danger;
  final Color shadow;
  final String logoAsset;

  const _ShellColors({
    required this.isDark,
    required this.scaffold,
    required this.card,
    required this.cardSoft,
    required this.cardSofter,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primarySoft,
    required this.primaryText,
    required this.danger,
    required this.shadow,
    required this.logoAsset,
  });

  factory _ShellColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _ShellColors(
        isDark: true,
        scaffold: Color(0xFF0F172A),
        card: Color(0xFF172033),
        cardSoft: Color(0xFF111827),
        cardSofter: Color(0xFF1E293B),
        border: Color(0xFF334155),
        textPrimary: Color(0xFFF8FAFC),
        textSecondary: Color(0xFFCBD5E1),
        textMuted: Color(0xFF94A3B8),
        primary: Color(0xFF60A5FA),
        primarySoft: Color(0xFF1E3A5F),
        primaryText: Color(0xFF0F172A),
        danger: Color(0xFFF87171),
        shadow: Colors.black,
        logoAsset: 'assets/images/pocketplan_logo_themes.png',
      );
    }

    return const _ShellColors(
      isDark: false,
      scaffold: Color(0xFFF5F8FC),
      card: Colors.white,
      cardSoft: Color(0xFFF8FAFC),
      cardSofter: Color(0xFFF1F5F9),
      border: Color(0xFFE5ECF5),
      textPrimary: Color(0xFF172033),
      textSecondary: Color(0xFF64748B),
      textMuted: Color(0xFF94A3B8),
      primary: Color(0xFF1677F2),
      primarySoft: Color(0xFFE3F2FD),
      primaryText: Colors.white,
      danger: Color(0xFFDC2626),
      shadow: Colors.black,
      logoAsset: 'assets/images/pocketplan_logo.png',
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

class _SupportFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SupportFloatingButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _ShellColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(
                  alpha: colors.isDark ? 0.28 : 0.32,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: colors.primaryText,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Supporto',
                style: TextStyle(
                  color: colors.primaryText,
                  fontSize: 15,
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
    final colors = _ShellColors.of(context);

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          right: BorderSide(
            color: colors.border,
          ),
        ),
        boxShadow: [
          if (colors.isDark)
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(8, 0),
            ),
        ],
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
    final colors = _ShellColors.of(context);

    return SizedBox(
      width: double.infinity,
      height: 82,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.translate(
          offset: const Offset(-8, 0),
          child: Image.asset(
            colors.logoAsset,
            width: 230,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, __, ___) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'PocketPlan',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
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
    final colors = _ShellColors.of(context);

    final backgroundColor = selected ? colors.primarySoft : Colors.transparent;
    final foregroundColor = selected ? colors.primary : colors.textSecondary;

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
                  decoration: BoxDecoration(
                    color: colors.primary,
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
    final colors = _ShellColors.of(context);

    return Material(
      color: colors.cardSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: colors.danger,
              ),
              const SizedBox(width: 12),
              Text(
                'Esci',
                style: TextStyle(
                  color: colors.danger,
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
    final colors = _ShellColors.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final dashboard = items[0];
    final expenses = items[1];
    final incomes = items[2];
    final goals = items[3];
    final aiPlanner = items[4];

    return SizedBox(
      height: 88 + bottomPadding,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 74 + bottomPadding,
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                bottomPadding > 0 ? bottomPadding : 10,
              ),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: colors.isDark ? 0.24 : 0.08,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
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
                  const SizedBox(width: 78),
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
          ),
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 13 : 14,
            child: _MobileDashboardButton(
              item: dashboard,
              selected: selectedIndex == 0,
              onTap: () => onSelect(0),
            ),
          ),
        ],
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
    final colors = _ShellColors.of(context);

    final color = selected ? colors.primary : colors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? colors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: color,
                size: selected ? 23 : 21,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.8,
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
    final colors = _ShellColors.of(context);

    final circleColor = selected ? colors.primary : colors.card;
    final iconColor = selected ? colors.primaryText : colors.primary;
    final textColor = selected ? colors.primary : colors.textMuted;

    return SizedBox(
      width: 84,
      height: 82,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: selected ? 62 : 60,
                height: selected ? 62 : 60,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.scaffold,
                    width: 5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? colors.primary.withValues(
                              alpha: colors.isDark ? 0.28 : 0.30,
                            )
                          : colors.shadow.withValues(
                              alpha: colors.isDark ? 0.20 : 0.09,
                            ),
                      blurRadius: selected ? 22 : 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  item.icon,
                  color: iconColor,
                  size: selected ? 29 : 27,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
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