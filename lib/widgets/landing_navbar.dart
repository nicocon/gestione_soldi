import 'package:flutter/material.dart';

class LandingNavbar extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onDownload;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final bool activeHome;
  final bool activeDownload;

  const LandingNavbar({
    super.key,
    required this.onHome,
    required this.onDownload,
    required this.onLogin,
    required this.onRegister,
    this.activeHome = false,
    this.activeDownload = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;

    return Container(
      height: isMobile ? 68 : 76,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
      ),
      decoration: const BoxDecoration(
        color: _NavbarColors.surface,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE8EDF3),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              InkWell(
                onTap: onHome,
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: isMobile ? 155 : 260,
                  height: isMobile ? 48 : 58,
                  child: Image.asset(
                    'assets/images/pocketplan_logo.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
              const Spacer(),

              if (!isMobile) ...[
                _NavbarTextButton(
                  label: 'Home',
                  icon: Icons.home_rounded,
                  active: activeHome,
                  onPressed: onHome,
                ),
                const SizedBox(width: 8),
                _NavbarTextButton(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  active: activeDownload,
                  onPressed: onDownload,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onLogin,
                  style: TextButton.styleFrom(
                    foregroundColor: _NavbarColors.dark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    'Accedi',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                IconButton(
                  onPressed: onHome,
                  tooltip: 'Home',
                  icon: Icon(
                    Icons.home_rounded,
                    color: activeHome
                        ? _NavbarColors.primary
                        : _NavbarColors.dark,
                  ),
                ),
                IconButton(
                  onPressed: onDownload,
                  tooltip: 'Download',
                  icon: Icon(
                    Icons.download_rounded,
                    color: activeDownload
                        ? _NavbarColors.primary
                        : _NavbarColors.dark,
                  ),
                ),
                const SizedBox(width: 4),
              ],

              _NavbarPrimaryButton(
                label: isMobile ? 'Accedi' : 'Registrati gratis',
                icon: isMobile ? null : Icons.arrow_forward_rounded,
                height: isMobile ? 40 : 44,
                horizontalPadding: isMobile ? 18 : 22,
                onPressed: isMobile ? onLogin : onRegister,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavbarColors {
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF1677F2);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color dark = Color(0xFF172033);
}

class _NavbarTextButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  const _NavbarTextButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 18,
      ),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: active ? _NavbarColors.primary : _NavbarColors.dark,
        backgroundColor:
            active ? _NavbarColors.primaryLight : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NavbarPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double height;
  final double horizontalPadding;
  final VoidCallback onPressed;

  const _NavbarPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 48,
    this.horizontalPadding = 22,
  });

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _NavbarColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: child,
      ),
    );
  }
}