import 'package:flutter/material.dart';

import 'auth_page.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _Navbar(
              onLogin: () => _goToAuth(context, showRegister: false),
              onRegister: () => _goToAuth(context, showRegister: true),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _HeroSection(
                      onStart: () => _goToAuth(context, showRegister: true),
                    ),
                    const _FeaturesSection(),
                    const _HowItWorksSection(),
                    const _FinalCtaSection(),
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

class _Navbar extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _Navbar({
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE8EDF3),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 320,
            height: 64,
            child: Image.asset(
              'assets/images/pocketplan_logo.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onLogin,
            child: const Text('Accedi'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onRegister,
            child: const Text('Registrati'),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final VoidCallback onStart;

  const _HeroSection({
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1180),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 72),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 560,
                  height: 170,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FC),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/images/pocketplan_logo_full.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Il tuo piano mensile, gestito con AI',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Gestisci entrate, spese e obiettivi senza stress.',
                  style: TextStyle(
                    fontSize: 52,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Tieni sotto controllo le scadenze, organizza il budget mensile e lascia che l’AI ti aiuti a capire quanto puoi spendere, risparmiare o mettere da parte per i tuoi obiettivi.',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: Color(0xFF5B6475),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.rocket_launch_rounded),
                        label: const Text('Inizia gratis'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Nessun conto bancario da collegare.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 56),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MockCard(
                    icon: Icons.payments_rounded,
                    title: 'Saldo previsto',
                    value: '€ 1.240,00',
                    subtitle: 'Dopo spese e risparmi pianificati',
                  ),
                  SizedBox(height: 16),
                  _MockCard(
                    icon: Icons.flag_rounded,
                    title: 'Obiettivo PS5',
                    value: '€ 320 / € 550',
                    subtitle: 'Mancano circa 3 mesi',
                  ),
                  SizedBox(height: 16),
                  _MockCard(
                    icon: Icons.notifications_active_rounded,
                    title: 'Prossima scadenza',
                    value: 'Bolletta luce - 12 Maggio',
                    subtitle: 'Promemoria attivo via notifica/email',
                  ),
                ],
              ),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7C8798),
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

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1180),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: const Column(
        children: [
          Text(
            'Tutto quello che ti serve per gestire il mese',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          SizedBox(height: 28),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _FeatureItem(
                icon: Icons.calendar_month_rounded,
                title: 'Scadenze e promemoria',
                text:
                    'Inserisci bollette, rate e pagamenti. L’app ti avvisa prima della scadenza.',
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
                    'L’AI ti suggerisce quanto mettere da parte e come ricalcolare il piano.',
              ),
            ],
          ),
        ],
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
    return SizedBox(
      width: 360,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFFE5ECF5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF1E88E5),
              size: 34,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                height: 1.5,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: const Column(
        children: [
          Text(
            'Come funziona',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          SizedBox(height: 28),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              _StepItem(
                number: '1',
                title: 'Inserisci entrate e spese',
                text:
                    'Aggiungi stipendio, spese fisse, spese extra e scadenze.',
              ),
              _StepItem(
                number: '2',
                title: 'Crea i tuoi obiettivi',
                text: 'Scegli cosa vuoi raggiungere, importo e data limite.',
              ),
              _StepItem(
                number: '3',
                title: 'Lascia calcolare all’AI',
                text:
                    'Ricevi un piano chiaro su quanto spendere e risparmiare.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String text;

  const _StepItem({
    required this.number,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFF1E88E5),
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 980),
        padding: const EdgeInsets.all(38),
        decoration: BoxDecoration(
          color: const Color(0xFF172033),
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Column(
          children: [
            Text(
              'Il modo più semplice per non perdere il controllo del mese.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 14),
            Text(
              'PocketPlan ti aiuta a ricordare, pianificare e risparmiare senza calcoli complicati.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD7DEE9),
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}