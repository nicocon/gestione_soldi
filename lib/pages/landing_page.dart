import 'package:flutter/material.dart';

import '../widgets/landing_navbar.dart';
import 'auth_page.dart';
import 'download_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

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

  void _goToDownload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DownloadPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LandingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            LandingNavbar(
              activeHome: true,
              onHome: () {},
              onDownload: () => _goToDownload(context),
              onLogin: () => _goToAuth(context, showRegister: false),
              onRegister: () => _goToAuth(context, showRegister: true),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _HeroSection(
                      onStart: () => _goToAuth(context, showRegister: true),
                    ),
                    const _StatsSection(),
                    const _FeaturesSection(),
                    const _WhySection(),
                    const _HowItWorksSection(),
                    _FinalCtaSection(
                      onStart: () => _goToAuth(context, showRegister: true),
                    ),
                    const _FooterSection(),
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

class _LandingColors {
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

class _HeroSection extends StatelessWidget {
  final VoidCallback onStart;

  const _HeroSection({
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 860;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 20 : 32,
        isMobile ? 34 : 66,
        isMobile ? 20 : 32,
        isMobile ? 34 : 62,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _HeroText(
                      isMobile: true,
                      onStart: onStart,
                    ),
                    const SizedBox(height: 30),
                    const _MockPreviewCard(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _HeroText(
                        isMobile: false,
                        onStart: onStart,
                      ),
                    ),
                    const SizedBox(width: 54),
                    const Expanded(
                      flex: 10,
                      child: _MockPreviewCard(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onStart;

  const _HeroText({
    required this.isMobile,
    required this.onStart,
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
        const _Badge(
          text: 'Il tuo piano mensile, gestito con AI',
          icon: Icons.auto_awesome_rounded,
        ),
        SizedBox(height: isMobile ? 20 : 24),
        Text(
          'Gestisci soldi, obiettivi e scadenze senza stress.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isMobile ? 34 : 54,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: _LandingColors.dark,
            letterSpacing: isMobile ? -0.6 : -1.2,
          ),
        ),
        SizedBox(height: isMobile ? 18 : 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: Text(
            'PocketPlan ti aiuta a organizzare entrate, spese, conti, obiettivi e promemoria in un unico posto. E con l’AI puoi capire meglio quanto puoi spendere, risparmiare o mettere da parte ogni mese.',
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              height: 1.58,
              color: _LandingColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 26 : 32),
        if (isMobile)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: 'Inizia gratis',
                  icon: Icons.rocket_launch_rounded,
                  height: 54,
                  onPressed: onStart,
                ),
              ),
              const SizedBox(height: 13),
              const _TrustText(),
            ],
          )
        else
          Row(
            children: [
              _PrimaryButton(
                label: 'Inizia gratis',
                icon: Icons.rocket_launch_rounded,
                height: 54,
                horizontalPadding: 24,
                onPressed: onStart,
              ),
              const SizedBox(width: 16),
              const _TrustText(),
            ],
          ),
      ],
    );
  }
}

class _TrustText extends StatelessWidget {
  const _TrustText();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 18,
          color: _LandingColors.muted,
        ),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            'Nessun conto bancario da collegare.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _LandingColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MockPreviewCard extends StatelessWidget {
  const _MockPreviewCard();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 860;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        color: _LandingColors.surface,
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
      child: Column(
        children: [
          const _MockTopBar(),
          const SizedBox(height: 18),
          const _MockBalanceCard(),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _MiniMockCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Entrate',
                  value: '€ 2.050',
                  color: _LandingColors.success,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MiniMockCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'Spese',
                  value: '€ 810',
                  color: _LandingColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _MockCard(
            icon: Icons.flag_rounded,
            title: 'Obiettivo viaggio',
            value: '€ 420 / € 900',
            subtitle: 'Stai procedendo bene: 47% completato',
          ),
          const SizedBox(height: 14),
          const _MockCard(
            icon: Icons.notifications_active_rounded,
            title: 'Prossima scadenza',
            value: 'Bolletta luce - 12 Maggio',
            subtitle: 'Promemoria attivo via notifica/email',
          ),
          const SizedBox(height: 14),
          const _AiSuggestionBox(),
        ],
      ),
    );
  }
}

class _MockTopBar extends StatelessWidget {
  const _MockTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _LandingColors.primaryLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: _LandingColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard mensile',
                style: TextStyle(
                  color: _LandingColors.dark,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Maggio 2026',
                style: TextStyle(
                  color: _LandingColors.muted,
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
                color: _LandingColors.success,
                size: 16,
              ),
              SizedBox(width: 5),
              Text(
                'In ordine',
                style: TextStyle(
                  color: _LandingColors.success,
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

class _MockBalanceCard extends StatelessWidget {
  const _MockBalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _LandingColors.dark,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo previsto a fine mese',
            style: TextStyle(
              color: Color(0xFFD7DEE9),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '€ 1.240,00',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.68,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(
                _LandingColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Budget mensile utilizzato al 68%',
            style: TextStyle(
              color: Color(0xFFD7DEE9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMockCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniMockCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LandingColors.softCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _LandingColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 25,
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: _LandingColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: _LandingColors.dark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _MockCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 860;

    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
      decoration: BoxDecoration(
        color: _LandingColors.softCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _LandingColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 46 : 50,
            height: isMobile ? 46 : 50,
            decoration: BoxDecoration(
              color: _LandingColors.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: _LandingColors.primary,
              size: isMobile ? 23 : 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _LandingColors.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 19,
                    fontWeight: FontWeight.w900,
                    color: _LandingColors.dark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _LandingColors.muted,
                    fontSize: 13,
                    height: 1.35,
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

class _AiSuggestionBox extends StatelessWidget {
  const _AiSuggestionBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _LandingColors.primaryLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFCFE8FF),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: _LandingColors.primary,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI Planner: puoi mettere da parte circa € 230 questo mese senza superare il budget.',
              style: TextStyle(
                color: _LandingColors.primaryDark,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 8 : 12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 28,
              vertical: isMobile ? 18 : 22,
            ),
            decoration: BoxDecoration(
              color: _LandingColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _LandingColors.border,
              ),
            ),
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              alignment: WrapAlignment.spaceEvenly,
              children: const [
                _StatItem(
                  value: '1',
                  label: 'dashboard semplice',
                ),
                _StatItem(
                  value: '0',
                  label: 'conti bancari collegati',
                ),
                _StatItem(
                  value: 'AI',
                  label: 'pianificazione smart',
                ),
                _StatItem(
                  value: '100%',
                  label: 'controllo manuale',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return SizedBox(
      width: isMobile ? 140 : 230,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _LandingColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _LandingColors.text,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 42 : 58,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _SectionHeader(
                badge: 'Funzionalità',
                title: 'Tutto quello che ti serve per gestire il mese',
                subtitle:
                    'Organizza i tuoi soldi in modo chiaro, senza fogli Excel complicati e senza dover collegare il conto bancario.',
              ),
              SizedBox(height: isMobile ? 24 : 32),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: const [
                  _FeatureItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Conti manuali',
                    text:
                        'Crea uno o più conti e tieni traccia dei movimenti senza sincronizzazioni bancarie.',
                  ),
                  _FeatureItem(
                    icon: Icons.calendar_month_rounded,
                    title: 'Scadenze e promemoria',
                    text:
                        'Inserisci bollette, rate e pagamenti. L’app ti aiuta a non dimenticare nulla.',
                  ),
                  _FeatureItem(
                    icon: Icons.savings_rounded,
                    title: 'Obiettivi di risparmio',
                    text:
                        'Crea obiettivi come viaggio, PS5 o fondo emergenza e segui il progresso.',
                  ),
                  _FeatureItem(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Planner',
                    text:
                        'Fai domande sul tuo mese e ricevi suggerimenti semplici su budget e risparmio.',
                  ),
                  _FeatureItem(
                    icon: Icons.trending_up_rounded,
                    title: 'Entrate e spese',
                    text:
                        'Registra quello che entra e quello che esce, diviso per mese e categorie.',
                  ),
                  _FeatureItem(
                    icon: Icons.dark_mode_rounded,
                    title: 'Tema chiaro e scuro',
                    text:
                        'Usa l’app nel modo più comodo per te, sia da mobile che da desktop.',
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

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return SizedBox(
      width: isMobile ? double.infinity : 360,
      child: Container(
        constraints: BoxConstraints(
          minHeight: isMobile ? 0 : 235,
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          color: _LandingColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _LandingColors.border,
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _LandingColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: _LandingColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _LandingColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: isMobile ? TextAlign.center : TextAlign.left,
              style: const TextStyle(
                height: 1.52,
                color: _LandingColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  const _WhySection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 900;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 12 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 24 : 34),
            decoration: BoxDecoration(
              color: _LandingColors.dark,
              borderRadius: BorderRadius.circular(isMobile ? 30 : 36),
            ),
            child: isMobile
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WhyText(),
                      SizedBox(height: 24),
                      _WhyList(),
                    ],
                  )
                : const Row(
                    children: [
                      Expanded(
                        child: _WhyText(),
                      ),
                      SizedBox(width: 34),
                      Expanded(
                        child: _WhyList(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _WhyText extends StatelessWidget {
  const _WhyText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Badge(
          text: 'Pensata per la vita reale',
          icon: Icons.favorite_rounded,
          darkMode: true,
        ),
        SizedBox(height: 18),
        Text(
          'Non devi essere esperto di finanza per gestire meglio i tuoi soldi.',
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
          'PocketPlan nasce per chi vuole una gestione semplice, veloce e concreta: inserisci i dati, controlli il mese e ricevi suggerimenti utili senza complicarti la vita.',
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

class _WhyList extends StatelessWidget {
  const _WhyList();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _WhyRow(
          icon: Icons.check_circle_rounded,
          title: 'Semplice da usare',
          text: 'Interfaccia chiara, pulita e adatta anche da smartphone.',
        ),
        SizedBox(height: 14),
        _WhyRow(
          icon: Icons.lock_rounded,
          title: 'Controllo manuale',
          text: 'Non devi collegare conti bancari o servizi esterni.',
        ),
        SizedBox(height: 14),
        _WhyRow(
          icon: Icons.psychology_rounded,
          title: 'AI come supporto',
          text: 'Ti aiuta a leggere meglio entrate, spese e obiettivi.',
        ),
      ],
    );
  }
}

class _WhyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _WhyRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
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
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      color: _LandingColors.surface,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 48 : 66,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _SectionHeader(
                badge: 'Come funziona',
                title: 'Tre passaggi e hai già tutto sotto controllo',
                subtitle:
                    'Parti dalle informazioni principali e lascia che PocketPlan ti aiuti a leggere meglio il mese.',
              ),
              SizedBox(height: isMobile ? 28 : 34),
              Wrap(
                spacing: 18,
                runSpacing: 22,
                alignment: WrapAlignment.center,
                children: const [
                  _StepItem(
                    number: '1',
                    icon: Icons.edit_note_rounded,
                    title: 'Inserisci entrate e spese',
                    text:
                        'Aggiungi stipendio, spese fisse, spese extra, conti e scadenze.',
                  ),
                  _StepItem(
                    number: '2',
                    icon: Icons.flag_rounded,
                    title: 'Crea i tuoi obiettivi',
                    text:
                        'Scegli cosa vuoi raggiungere, importo, priorità e data limite.',
                  ),
                  _StepItem(
                    number: '3',
                    icon: Icons.auto_awesome_rounded,
                    title: 'Chiedi supporto all’AI',
                    text:
                        'Ricevi un piano semplice su quanto spendere, risparmiare o spostare.',
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

class _StepItem extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String text;

  const _StepItem({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return SizedBox(
      width: isMobile ? double.infinity : 360,
      child: Container(
        constraints: BoxConstraints(
          minHeight: isMobile ? 0 : 240,
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          color: _LandingColors.softCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _LandingColors.border,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: _LandingColors.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
                Positioned(
                  right: -8,
                  top: -8,
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: _LandingColors.dark,
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _LandingColors.dark,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _LandingColors.text,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalCtaSection extends StatelessWidget {
  final VoidCallback onStart;

  const _FinalCtaSection({
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 32,
        vertical: isMobile ? 44 : 60,
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 980),
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? 26 : 40),
          decoration: BoxDecoration(
            color: _LandingColors.primary,
            borderRadius: BorderRadius.circular(isMobile ? 30 : 36),
            boxShadow: [
              BoxShadow(
                color: _LandingColors.primary.withValues(alpha: 0.22),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Il modo più semplice per non perdere il controllo del mese.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 27 : 34,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PocketPlan ti aiuta a ricordare, pianificare e risparmiare senza calcoli complicati.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFEAF3FF),
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: isMobile ? double.infinity : null,
                child: ElevatedButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Crea il tuo piano gratis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _LandingColors.primary,
                    elevation: 0,
                    minimumSize: Size(isMobile ? double.infinity : 250, 54),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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

class _FooterSection extends StatelessWidget {
  const _FooterSection();

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
                color: _LandingColors.border,
              ),
              const SizedBox(height: 18),
              isMobile
                  ? const Column(
                      children: [
                        Text(
                          'PocketPlan',
                          style: TextStyle(
                            color: _LandingColors.dark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Gestione personale del budget mensile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _LandingColors.muted,
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
                            color: _LandingColors.dark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Gestione personale del budget mensile.',
                          style: TextStyle(
                            color: _LandingColors.muted,
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

class _SectionHeader extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Column(
      children: [
        _Badge(
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
              color: _LandingColors.dark,
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
              color: _LandingColors.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool darkMode;

  const _Badge({
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
            : _LandingColors.primaryLight,
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
            color: darkMode ? Colors.white : _LandingColors.primaryDark,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkMode ? Colors.white : _LandingColors.primaryDark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double height;
  final double horizontalPadding;
  final VoidCallback onPressed;

  const _PrimaryButton({
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
          backgroundColor: _LandingColors.primary,
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