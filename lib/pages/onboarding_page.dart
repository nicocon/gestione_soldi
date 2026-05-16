import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final AuthService _authService = AuthService();

  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isSaving = false;

  String? _mainGoal;
  String? _moneyFeeling;
  String? _adviceStyle;
  String? _aiFrequency;

  final List<String> _selectedInterests = [];

  final List<_OnboardingOption> _mainGoalOptions = const [
    _OnboardingOption(
      value: 'save_more',
      title: 'Risparmiare di più',
      subtitle: 'Voglio mettere da parte più soldi ogni mese.',
      icon: Icons.savings_rounded,
    ),
    _OnboardingOption(
      value: 'control_expenses',
      title: 'Controllare meglio le spese',
      subtitle: 'Voglio capire dove finiscono i miei soldi.',
      icon: Icons.receipt_long_rounded,
    ),
    _OnboardingOption(
      value: 'reach_goal',
      title: 'Raggiungere un obiettivo',
      subtitle: 'Voglio organizzarmi per qualcosa di importante.',
      icon: Icons.flag_rounded,
    ),
    _OnboardingOption(
      value: 'reduce_stress',
      title: 'Vivere più tranquillo',
      subtitle: 'Voglio avere meno ansia quando penso ai soldi.',
      icon: Icons.favorite_rounded,
    ),
  ];

  final List<_OnboardingOption> _interestOptions = const [
    _OnboardingOption(
      value: 'travel',
      title: 'Viaggiare',
      subtitle: 'Voglio mettere soldi da parte per viaggi e vacanze.',
      icon: Icons.flight_takeoff_rounded,
    ),
    _OnboardingOption(
      value: 'home',
      title: 'Casa',
      subtitle: 'Affitto, mutuo, arredamento o acquisto casa.',
      icon: Icons.home_rounded,
    ),
    _OnboardingOption(
      value: 'car',
      title: 'Auto o moto',
      subtitle: 'Voglio gestire meglio spese o acquisti importanti.',
      icon: Icons.directions_car_rounded,
    ),
    _OnboardingOption(
      value: 'emergency_fund',
      title: 'Fondo emergenza',
      subtitle: 'Voglio creare una sicurezza per gli imprevisti.',
      icon: Icons.health_and_safety_rounded,
    ),
    _OnboardingOption(
      value: 'shopping',
      title: 'Tempo libero',
      subtitle: 'Voglio godermi di più le mie passioni senza esagerare.',
      icon: Icons.shopping_bag_rounded,
    ),
    _OnboardingOption(
      value: 'investing',
      title: 'Investire in futuro',
      subtitle: 'Voglio prepararmi meglio per il domani.',
      icon: Icons.trending_up_rounded,
    ),
  ];

  final List<_OnboardingOption> _moneyFeelingOptions = const [
    _OnboardingOption(
      value: 'calm',
      title: 'Abbastanza tranquillo',
      subtitle: 'Mi sento abbastanza in controllo.',
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    _OnboardingOption(
      value: 'medium',
      title: 'Così così',
      subtitle: 'A volte controllo, a volte mi sfugge qualcosa.',
      icon: Icons.sentiment_neutral_rounded,
    ),
    _OnboardingOption(
      value: 'confused',
      title: 'Un po’ confuso',
      subtitle: 'Non sempre capisco dove vanno i soldi.',
      icon: Icons.psychology_rounded,
    ),
    _OnboardingOption(
      value: 'stressed',
      title: 'Spesso in difficoltà',
      subtitle: 'Vorrei sentirmi più sicuro a fine mese.',
      icon: Icons.sentiment_dissatisfied_rounded,
    ),
  ];

  final List<_OnboardingOption> _adviceStyleOptions = const [
    _OnboardingOption(
      value: 'practical',
      title: 'Pratico e diretto',
      subtitle: 'Dammi consigli chiari, senza troppi giri di parole.',
      icon: Icons.bolt_rounded,
    ),
    _OnboardingOption(
      value: 'motivational',
      title: 'Motivazionale',
      subtitle: 'Voglio sentirmi incoraggiato e seguito.',
      icon: Icons.emoji_events_rounded,
    ),
    _OnboardingOption(
      value: 'detailed',
      title: 'Dettagliato',
      subtitle: 'Voglio capire bene numeri, motivi e suggerimenti.',
      icon: Icons.analytics_rounded,
    ),
    _OnboardingOption(
      value: 'simple',
      title: 'Semplice e veloce',
      subtitle: 'Poche parole, ma utili.',
      icon: Icons.speed_rounded,
    ),
  ];

  final List<_OnboardingOption> _aiFrequencyOptions = const [
    _OnboardingOption(
      value: 'only_when_asked',
      title: 'Solo quando chiedo io',
      subtitle: 'Preferisco aprire l’AI quando mi serve.',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    _OnboardingOption(
      value: 'occasional',
      title: 'Ogni tanto',
      subtitle: 'Mi va bene ricevere qualche consiglio utile.',
      icon: Icons.notifications_active_rounded,
    ),
    _OnboardingOption(
      value: 'frequent',
      title: 'Seguimi spesso',
      subtitle: 'Voglio suggerimenti più frequenti e proattivi.',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  int get _totalSteps => 5;

  bool get _canGoNext {
    switch (_currentStep) {
      case 0:
        return _mainGoal != null;
      case 1:
        return _selectedInterests.isNotEmpty;
      case 2:
        return _moneyFeeling != null;
      case 3:
        return _adviceStyle != null;
      case 4:
        return _aiFrequency != null;
      default:
        return false;
    }
  }

  Future<void> _nextStep() async {
    if (!_canGoNext || _isSaving) return;

    if (_currentStep == _totalSteps - 1) {
      await _completeOnboarding();
      return;
    }

    setState(() {
      _currentStep++;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _previousStep() async {
    if (_currentStep == 0 || _isSaving) return;

    setState(() {
      _currentStep--;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_mainGoal == null ||
        _selectedInterests.isEmpty ||
        _moneyFeeling == null ||
        _adviceStyle == null ||
        _aiFrequency == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _authService.saveOnboardingProfile(
        mainGoal: _mainGoal!,
        interests: _selectedInterests,
        moneyFeeling: _moneyFeeling!,
        adviceStyle: _adviceStyle!,
        aiFrequency: _aiFrequency!,
      );

      // Non serve Navigator: main.dart ascolta Firestore.
      // Quando onboarding_completed diventa true, passa automaticamente alla AppShell.
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Non sono riuscito a salvare le risposte. Riprova. Errore: $e',
          ),
        ),
      );
    }
  }

  void _toggleInterest(String value) {
    setState(() {
      if (_selectedInterests.contains(value)) {
        _selectedInterests.remove(value);
      } else {
        _selectedInterests.add(value);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F8FC);
    const darkText = Color(0xFF172033);
    const mutedText = Color(0xFF64748B);
    const blue = Color(0xFF1677F2);

    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 980,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 18 : 32,
                vertical: isMobile ? 16 : 28,
              ),
              child: Column(
                children: [
                  _Header(
                    currentStep: _currentStep,
                    totalSteps: _totalSteps,
                  ),
                  SizedBox(height: isMobile ? 18 : 28),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _QuestionStep(
                          title: 'Qual è il tuo obiettivo principale?',
                          subtitle:
                              'Così PocketPlan capisce subito come aiutarti meglio.',
                          child: _OptionsGrid(
                            options: _mainGoalOptions,
                            selectedValue: _mainGoal,
                            onSelected: (value) {
                              setState(() {
                                _mainGoal = value;
                              });
                            },
                          ),
                        ),
                        _QuestionStep(
                          title: 'Cosa ti piacerebbe fare con i soldi risparmiati?',
                          subtitle:
                              'Puoi scegliere una o più cose. Useremo queste risposte per rendere i consigli più personali.',
                          child: _OptionsGrid(
                            options: _interestOptions,
                            selectedValues: _selectedInterests,
                            allowMultiple: true,
                            onSelected: _toggleInterest,
                          ),
                        ),
                        _QuestionStep(
                          title: 'Come ti senti oggi con i tuoi soldi?',
                          subtitle:
                              'Non serve essere perfetti: serve solo capire da dove partiamo.',
                          child: _OptionsGrid(
                            options: _moneyFeelingOptions,
                            selectedValue: _moneyFeeling,
                            onSelected: (value) {
                              setState(() {
                                _moneyFeeling = value;
                              });
                            },
                          ),
                        ),
                        _QuestionStep(
                          title: 'Che stile di consigli preferisci?',
                          subtitle:
                              'PocketPlan proverà a parlarti nel modo più utile per te.',
                          child: _OptionsGrid(
                            options: _adviceStyleOptions,
                            selectedValue: _adviceStyle,
                            onSelected: (value) {
                              setState(() {
                                _adviceStyle = value;
                              });
                            },
                          ),
                        ),
                        _QuestionStep(
                          title: 'Quanto vuoi essere seguito dall’AI?',
                          subtitle:
                              'Potrai sempre cambiare idea più avanti dalle impostazioni.',
                          child: _OptionsGrid(
                            options: _aiFrequencyOptions,
                            selectedValue: _aiFrequency,
                            onSelected: (value) {
                              setState(() {
                                _aiFrequency = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 22),
                  Row(
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _previousStep,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Indietro'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _canGoNext && !_isSaving ? _nextStep : null,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _currentStep == _totalSteps - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                        label: Text(
                          _currentStep == _totalSteps - 1
                              ? 'Inizia'
                              : 'Continua',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              blue.withValues(alpha: 0.35),
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == _totalSteps - 1
                        ? 'Potrai modificare queste risposte anche più avanti dalle impostazioni, così PocketPlan potrà conoscere meglio le tue abitudini e darti consigli AI sempre più precisi.'
                        : 'Le risposte servono solo a personalizzare i consigli di PocketPlan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: mutedText.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _Header({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF172033);
    const mutedText = Color(0xFF64748B);
    const blue = Color(0xFF1677F2);

    final progress = (currentStep + 1) / totalSteps;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFE5ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conosciamoci meglio',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Domanda ${currentStep + 1} di $totalSteps',
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE5ECF5),
                    valueColor: const AlwaysStoppedAnimation<Color>(blue),
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

class _QuestionStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _QuestionStep({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF172033);
    const mutedText = Color(0xFF64748B);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 30,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OptionsGrid extends StatelessWidget {
  final List<_OnboardingOption> options;
  final String? selectedValue;
  final List<String>? selectedValues;
  final bool allowMultiple;
  final ValueChanged<String> onSelected;

  const _OptionsGrid({
    required this.options,
    required this.onSelected,
    this.selectedValue,
    this.selectedValues,
    this.allowMultiple = false,
  });

  bool _isSelected(String value) {
    if (allowMultiple) {
      return selectedValues?.contains(value) ?? false;
    }

    return selectedValue == value;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = width < 620 ? 1 : 2;

        return GridView.builder(
          itemCount: options.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: width < 620 ? 3.25 : 3.2,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            final selected = _isSelected(option.value);

            return _OptionCard(
              option: option,
              selected: selected,
              onTap: () => onSelected(option.value),
            );
          },
        );
      },
    );
  }
}

class _OptionCard extends StatelessWidget {
  final _OnboardingOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const darkText = Color(0xFF172033);
    const mutedText = Color(0xFF64748B);
    const blue = Color(0xFF1677F2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? blue.withValues(alpha: 0.09) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? blue : const Color(0xFFE5ECF5),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(
                alpha: selected ? 0.09 : 0.045,
              ),
              blurRadius: selected ? 22 : 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? blue.withValues(alpha: 0.16)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                option.icon,
                color: selected ? blue : mutedText,
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? blue : darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? blue : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? blue : const Color(0xFFCBD5E1),
                  width: 1.4,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingOption {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}