import 'package:flutter/material.dart';

import '../widgets/landing_navbar.dart';
import 'auth_page.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  void _goToAuth(BuildContext context, {required bool showRegister}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthPage(
          startWithRegister: showRegister,
        ),
      ),
    );
  }

  void _goToHome(BuildContext context) {
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 820;

    return Scaffold(
      backgroundColor: _DownloadColors.background,
      body: SafeArea(
        child: Column(
          children: [
            LandingNavbar(
              activeDownload: true,
              onHome: () => _goToHome(context),
              onDownload: () {},
              onLogin: () => _goToAuth(context, showRegister: false),
              onRegister: () => _goToAuth(context, showRegister: true),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 20 : 32,
                        isMobile ? 42 : 70,
                        isMobile ? 20 : 32,
                        isMobile ? 30 : 56,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: isMobile
                              ? const Column(
                                  children: [
                                    _DownloadHeroText(isMobile: true),
                                    SizedBox(height: 28),
                                    _SyncPreviewCard(),
                                  ],
                                )
                              : const Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 11,
                                      child: _DownloadHeroText(
                                        isMobile: false,
                                      ),
                                    ),
                                    SizedBox(width: 54),
                                    Expanded(
                                      flex: 10,
                                      child: _SyncPreviewCard(),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const _DownloadPlatformsSection(),
                    const _DownloadQrSection(),
                    const _DownloadFinalNote(),
                    const _DownloadFooterSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadColors {
  static const Color background = Color(0xFFF5F8FC);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF1677F2);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color dark = Color(0xFF172033);
  static const Color text = Color(0xFF5B6475);
  static const Color muted = Color(0xFF7C8798);
  static const Color border = Color(0xFFE5ECF5);
  static const Color softCard = Color(0xFFF7FAFE);
  static const Color success = Color(0xFF13B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}

class _DownloadHeroText extends StatelessWidget {
  final bool isMobile;

  const _DownloadHeroText({
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? 265 : 500,
          height: isMobile ? 82 : 128,
          child: Image.asset(
            'assets/images/pocketplan_logo_full.png',
            fit: BoxFit.contain,
            alignment: isMobile ? Alignment.center : Alignment.centerLeft,
          ),
        ),
        SizedBox(height: isMobile ? 12 : 18),
        const _DownloadBadge(
          text: 'Un account, tutti i tuoi dispositivi',
          icon: Icons.sync_rounded,
        ),
        SizedBox(height: isMobile ? 20 : 24),
        Text(
          'PocketPlan ti segue ovunque.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isMobile ? 34 : 54,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: _DownloadColors.dark,
            letterSpacing: isMobile ? -0.6 : -1.2,
          ),
        ),
        SizedBox(height: isMobile ? 18 : 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Text(
            'Inserisci una spesa dal computer, controlli il budget dal telefono, aggiorni un obiettivo dal tablet o dalla versione desktop: tutto quello che fai nel gestionale resta sincronizzato e disponibile su ogni dispositivo.',
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              height: 1.58,
              color: _DownloadColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 22 : 28),
        const _DeviceSyncRow(),
      ],
    );
  }
}

class _DeviceSyncRow extends StatelessWidget {
  const _DeviceSyncRow();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
      children: const [
        _DevicePill(
          icon: Icons.desktop_mac_rounded,
          label: 'Desktop',
        ),
        _DevicePill(
          icon: Icons.phone_iphone_rounded,
          label: 'Mobile',
        ),
        _DevicePill(
          icon: Icons.tablet_mac_rounded,
          label: 'Tablet',
        ),
        _DevicePill(
          icon: Icons.language_rounded,
          label: 'Web',
        ),
      ],
    );
  }
}

class _DevicePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DevicePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: _DownloadColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _DownloadColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: _DownloadColors.primary,
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _DownloadColors.dark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncPreviewCard extends StatelessWidget {
  const _SyncPreviewCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 860;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: _DownloadColors.surface,
        borderRadius: BorderRadius.circular(isMobile ? 28 : 34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: const Column(
        children: [
          _SyncTopBar(),
          SizedBox(height: 18),
          _SyncMainCard(),
          SizedBox(height: 14),
          _SyncDeviceLine(
            icon: Icons.desktop_mac_rounded,
            title: 'Mac o Windows',
            text: 'Gestisci il mese con più spazio e comodità.',
          ),
          SizedBox(height: 12),
          _SyncDeviceLine(
            icon: Icons.phone_iphone_rounded,
            title: 'iPhone o Android',
            text: 'Controlla spese, entrate e obiettivi anche fuori casa.',
          ),
          SizedBox(height: 12),
          _SyncDeviceLine(
            icon: Icons.cloud_done_rounded,
            title: 'Dati sincronizzati',
            text: 'Le modifiche restano disponibili su tutti i dispositivi.',
          ),
        ],
      ),
    );
  }
}

class _SyncTopBar extends StatelessWidget {
  const _SyncTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _DownloadColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.devices_rounded,
            color: _DownloadColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PocketPlan Sync',
                style: TextStyle(
                  color: _DownloadColors.dark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Sempre aggiornato',
                style: TextStyle(
                  color: _DownloadColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFEAFBF3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: _DownloadColors.success,
                size: 16,
              ),
              SizedBox(width: 5),
              Text(
                'Cloud',
                style: TextStyle(
                  color: _DownloadColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncMainCard extends StatelessWidget {
  const _SyncMainCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _DownloadColors.dark,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ultimo aggiornamento',
            style: TextStyle(
              color: Color(0xFFD7DEE9),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Spesa aggiornata da iPhone',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'La dashboard desktop mostra già il nuovo saldo mensile.',
            style: TextStyle(
              color: Color(0xFFD7DEE9),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncDeviceLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _SyncDeviceLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _DownloadColors.softCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _DownloadColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _DownloadColors.primary,
            size: 27,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _DownloadColors.dark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _DownloadColors.text,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadPlatformsSection extends StatelessWidget {
  const _DownloadPlatformsSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 34 : 50,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _DownloadSectionHeader(
                badge: 'Piattaforme',
                title: 'Una versione per ogni dispositivo',
                subtitle:
                    'PocketPlan sarà disponibile progressivamente su desktop, mobile e web. Per ora prepariamo la pagina, poi collegheremo i download reali quando pubblicheremo le app.',
              ),
              SizedBox(height: isMobile ? 24 : 32),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: const [
                  _DownloadPlatformCard(
                    icon: Icons.desktop_mac_rounded,
                    title: 'macOS',
                    subtitle: 'App desktop per Mac',
                    fileType: 'File .dmg',
                    status: 'In arrivo',
                  ),
                  _DownloadPlatformCard(
                    icon: Icons.window_rounded,
                    title: 'Windows',
                    subtitle: 'Programma desktop per PC',
                    fileType: 'File .exe',
                    status: 'In arrivo',
                  ),
                  _DownloadPlatformCard(
                    icon: Icons.phone_iphone_rounded,
                    title: 'iOS',
                    subtitle: 'App per iPhone',
                    fileType: 'App Store',
                    status: 'In arrivo',
                  ),
                  _DownloadPlatformCard(
                    icon: Icons.android_rounded,
                    title: 'Android',
                    subtitle: 'App per smartphone Android',
                    fileType: 'Google Play',
                    status: 'In arrivo',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadPlatformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String fileType;
  final String status;

  const _DownloadPlatformCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.fileType,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return SizedBox(
      width: isMobile ? double.infinity : 270,
      child: Container(
        constraints: BoxConstraints(
          minHeight: isMobile ? 0 : 260,
        ),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _DownloadColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _DownloadColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _DownloadColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: _DownloadColors.primary,
                size: 31,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: const TextStyle(
                color: _DownloadColors.dark,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: const TextStyle(
                color: _DownloadColors.text,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _DownloadColors.softCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _DownloadColors.border,
                ),
              ),
              child: Text(
                fileType,
                style: const TextStyle(
                  color: _DownloadColors.dark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _DownloadColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  color: _DownloadColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadQrSection extends StatelessWidget {
  const _DownloadQrSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 860;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 12 : 26,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 24 : 34),
            decoration: BoxDecoration(
              color: _DownloadColors.dark,
              borderRadius: BorderRadius.circular(isMobile ? 30 : 36),
            ),
            child: isMobile
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _QrSectionText(),
                      SizedBox(height: 24),
                      _QrPlaceholderGrid(),
                    ],
                  )
                : const Row(
                    children: [
                      Expanded(
                        child: _QrSectionText(),
                      ),
                      SizedBox(width: 34),
                      Expanded(
                        child: _QrPlaceholderGrid(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _QrSectionText extends StatelessWidget {
  const _QrSectionText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DownloadBadge(
          text: 'QR code pronti per il futuro',
          icon: Icons.qr_code_rounded,
          darkMode: true,
        ),
        SizedBox(height: 18),
        Text(
          'Quando PocketPlan sarà pubblicata sugli store, qui troverai i QR code ufficiali.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 31,
            height: 1.12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Per ora lasciamo gli spazi già pronti. Appena avremo i link App Store e Google Play, sostituiremo i placeholder con i QR code reali.',
          style: TextStyle(
            color: Color(0xFFD7DEE9),
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _QrPlaceholderGrid extends StatelessWidget {
  const _QrPlaceholderGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _QrPlaceholderCard(
          icon: Icons.phone_iphone_rounded,
          title: 'QR code App Store',
          text: 'Disponibile dopo la pubblicazione iOS.',
        ),
        SizedBox(height: 14),
        _QrPlaceholderCard(
          icon: Icons.android_rounded,
          title: 'QR code Google Play',
          text: 'Disponibile dopo la pubblicazione Android.',
        ),
      ],
    );
  }
}

class _QrPlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _QrPlaceholderCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 520;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 72 : 88,
            height: isMobile ? 72 : 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              color: Colors.white.withValues(alpha: 0.72),
              size: isMobile ? 40 : 52,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFD7DEE9),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadFinalNote extends StatelessWidget {
  const _DownloadFinalNote();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 42 : 58,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 980),
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 24 : 34),
          decoration: BoxDecoration(
            color: _DownloadColors.surface,
            borderRadius: BorderRadius.circular(isMobile ? 30 : 36),
            border: Border.all(
              color: _DownloadColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_rounded,
                color: _DownloadColors.primary,
                size: isMobile ? 38 : 44,
              ),
              const SizedBox(height: 14),
              Text(
                'Le versioni desktop e mobile saranno rilasciate progressivamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _DownloadColors.dark,
                  fontSize: isMobile ? 24 : 30,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Questa pagina è già pronta per accogliere i download ufficiali di PocketPlan. Quando avremo i file .dmg, .exe e i link agli store, li collegheremo direttamente qui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _DownloadColors.text,
                  fontSize: 16,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadFooterSection extends StatelessWidget {
  const _DownloadFooterSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 20 : 32,
        0,
        isMobile ? 20 : 32,
        28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const Divider(
                color: _DownloadColors.border,
              ),
              const SizedBox(height: 18),
              isMobile
                  ? const Column(
                      children: [
                        Text(
                          'PocketPlan',
                          style: TextStyle(
                            color: _DownloadColors.dark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Gestione personale del budget mensile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _DownloadColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      children: [
                        Text(
                          'PocketPlan',
                          style: TextStyle(
                            color: _DownloadColors.dark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Gestione personale del budget mensile.',
                          style: TextStyle(
                            color: _DownloadColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadSectionHeader extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;

  const _DownloadSectionHeader({
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Column(
      children: [
        _DownloadBadge(
          text: badge,
          icon: Icons.circle_rounded,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 28 : 36,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: _DownloadColors.dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 15.5 : 17,
              height: 1.52,
              color: _DownloadColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool darkMode;

  const _DownloadBadge({
    required this.text,
    required this.icon,
    this.darkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: darkMode
            ? Colors.white.withValues(alpha: 0.10)
            : _DownloadColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
        border: darkMode
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: darkMode ? Colors.white : _DownloadColors.primaryDark,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkMode ? Colors.white : _DownloadColors.primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}