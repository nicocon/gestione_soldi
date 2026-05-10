import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum PocketPlanThemeMode {
  system,
  light,
  dark,
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _supportEmail = 'soluzioni@pocketplan.it';

  static const String _emailJsServiceId = 'service_73zufzx';
  static const String _emailJsTemplateId = 'template_ifzi2bi';
  static const String _emailJsPublicKey = 'X56EUiEzL7jD0hVRl';

  bool _budgetAlertsEnabled = true;
  bool _goalAlertsEnabled = true;
  bool _ticketUpdatesEnabled = true;
  bool _aiTipsEnabled = true;

  bool _isLoadingProfile = true;

  String _userRole = 'user';
  bool get _isAdmin => _userRole == 'admin';

  String _profileName = '';
  String _profileSurname = '';
  String _profileCountry = '';
  String _profilePhone = '';
  DateTime? _profileBirthDate;

  PocketPlanThemeMode _selectedThemeMode = PocketPlanThemeMode.system;

  User? get _user => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  PocketPlanThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return PocketPlanThemeMode.light;
      case 'dark':
        return PocketPlanThemeMode.dark;
      case 'system':
      default:
        return PocketPlanThemeMode.system;
    }
  }

  String _themeModeToString(PocketPlanThemeMode value) {
    switch (value) {
      case PocketPlanThemeMode.light:
        return 'light';
      case PocketPlanThemeMode.dark:
        return 'dark';
      case PocketPlanThemeMode.system:
        return 'system';
    }
  }

  String get _themeModeLabel {
    switch (_selectedThemeMode) {
      case PocketPlanThemeMode.light:
        return 'Chiaro';
      case PocketPlanThemeMode.dark:
        return 'Scuro';
      case PocketPlanThemeMode.system:
        return 'Auto';
    }
  }

  String get _themeModeSubtitle {
    switch (_selectedThemeMode) {
      case PocketPlanThemeMode.light:
        return 'PocketPlan usa sempre il tema chiaro.';
      case PocketPlanThemeMode.dark:
        return 'PocketPlan usa sempre il tema scuro.';
      case PocketPlanThemeMode.system:
        return 'PocketPlan segue il tema del dispositivo.';
    }
  }

  String get _displayName {
    final fullName = '$_profileName $_profileSurname'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final name = _user?.displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = _user?.email ?? '';

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'Utente PocketPlan';
  }

  String get _email {
    final email = _user?.email?.trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return 'Email non disponibile';
  }

  String get _initials {
    final name = _displayName.trim();

    if (name.isEmpty) return 'P';

    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    return name[0].toUpperCase();
  }

  bool _isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 700;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Future<void> _loadUserProfile() async {
    final user = _user;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });

      return;
    }

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();

      final displayName = user.displayName?.trim() ?? '';
      final parts = displayName
          .split(' ')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      DateTime? birthDate;

      final rawBirthDate = data?['birth_date'];

      if (rawBirthDate is Timestamp) {
        birthDate = rawBirthDate.toDate();
      } else if (rawBirthDate is String && rawBirthDate.trim().isNotEmpty) {
        birthDate = DateTime.tryParse(rawBirthDate);
      }

      final savedThemeMode = data?['theme_mode']?.toString();
      final savedRole = (data?['role'] ?? 'user').toString().trim();

      if (!mounted) return;

      setState(() {
        _profileName = (data?['name'] ?? '').toString().trim();
        _profileSurname = (data?['surname'] ?? '').toString().trim();
        _profileCountry = (data?['country'] ?? '').toString().trim();
        _profilePhone = (data?['phone'] ?? '').toString().trim();
        _profileBirthDate = birthDate;
        _selectedThemeMode = _themeModeFromString(savedThemeMode);
        _userRole = savedRole.isEmpty ? 'user' : savedRole;

        if (_profileName.isEmpty && parts.isNotEmpty) {
          _profileName = parts.first;
        }

        if (_profileSurname.isEmpty && parts.length >= 2) {
          _profileSurname = parts.sublist(1).join(' ');
        }

        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _saveThemeMode(PocketPlanThemeMode themeMode) async {
    final user = _user;

    if (user == null) {
      await _showInfoDialog(
        title: 'Account non disponibile',
        description:
            'Non riesco a salvare il tema perché non trovo l’utente corrente.',
        icon: Icons.person_off_rounded,
      );
      return;
    }

    final oldThemeMode = _selectedThemeMode;

    setState(() {
      _selectedThemeMode = themeMode;
    });

    try {
      await _db.collection('users').doc(user.uid).set(
        {
          'theme_mode': _themeModeToString(themeMode),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      await _showInfoDialog(
        title: 'Tema aggiornato',
        description:
            'Preferenza salvata correttamente. Il tema verrà applicato in tutta l’app.',
        icon: Icons.check_circle_rounded,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _selectedThemeMode = oldThemeMode;
      });

      await _showInfoDialog(
        title: 'Errore',
        description: 'Non sono riuscito a salvare il tema. Riprova tra poco.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _showInfoDialog({
    required String title,
    required String description,
    IconData icon = Icons.info_rounded,
  }) async {
    final colors = _SettingsColors.of(context);

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              _DialogIcon(
                icon: icon,
                colors: colors,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            description,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.primaryText,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                child: const Text('Ho capito'),
              ),
            ),
          ],
        );
      },
    );
  }

    Future<void> _showPlanDialog() async {
    final colors = _SettingsColors.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1080,
              maxHeight: MediaQuery.sizeOf(context).height - 48,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: colors.isDark ? 0.35 : 0.14,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _DialogIcon(
                          icon: Icons.workspace_premium_rounded,
                          colors: colors,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Piani PocketPlan',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Scegli il piano più adatto alle tue esigenze.',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 780;

                        final plans = [
                          _PlanOptionCard(
                            icon: Icons.person_rounded,
                            title: 'Free',
                            badge: 'Piano attuale',
                            description:
                                'Gratuito per tutti, con tutte le funzionalità disponibili adesso.',
                            monthlyPrice: 'Gratis',
                            annualPrice: null,
                            annualSaving: null,
                            features: const [
                              'Dashboard personale',
                              'Entrate e spese',
                              'Obiettivi',
                              'Supporto ticket',
                            ],
                            highlighted: true,
                            buttonEnabled: false,
                            buttonText: 'Attivo',
                            onTap: null,
                          ),
                          _PlanOptionCard(
                            icon: Icons.family_restroom_rounded,
                            title: 'Famiglia',
                            badge: 'Prossimamente',
                            description:
                                'Pensato per gestire budget, spese e obiettivi condivisi in famiglia.',
                            monthlyPrice: '1,99€/mese',
                            annualPrice: '20€/anno',
                            annualSaving: 'Risparmi 3,88€',
                            features: const [
                              'Gestione famiglia',
                              'Membri collegati',
                              'Budget condivisi',
                              'Obiettivi familiari',
                              'Statistiche avanzate',
                            ],
                            highlighted: false,
                            buttonEnabled: false,
                            buttonText: 'Non disponibile',
                            onTap: null,
                          ),
                          _PlanOptionCard(
                            icon: Icons.business_center_rounded,
                            title: 'Azienda',
                            badge: 'Prossimamente',
                            description:
                                'Una versione avanzata per piccole attività, team e gestione business.',
                            monthlyPrice: '5,99€/mese',
                            annualPrice: '65€/anno',
                            annualSaving: 'Risparmi 6,88€',
                            features: const [
                              'Gestione aziendale',
                              'Più profili o reparti',
                              'Report finanziari',
                              'Analisi avanzate',
                              'Funzioni professionali',
                            ],
                            highlighted: false,
                            buttonEnabled: false,
                            buttonText: 'Non disponibile',
                            onTap: null,
                          ),
                        ];

                        if (isMobile) {
                          return Column(
                            children: plans
                                .map(
                                  (plan) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: plan,
                                  ),
                                )
                                .toList(),
                          );
                        }

                        return SizedBox(
                          height: 500,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: plans
                                .map(
                                  (plan) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: plan,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color:
                              colors.isDark ? colors.border : Colors.transparent,
                        ),
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
                              'I piani Famiglia e Azienda sono mostrati solo come anteprima. I pulsanti sono disattivati perché il pagamento verrà collegato più avanti.',
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
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
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
                        child: const Text('Chiudi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showThemeDialog() async {
    final colors = _SettingsColors.of(context);
    PocketPlanThemeMode tempThemeMode = _selectedThemeMode;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> confirmTheme() async {
              Navigator.pop(dialogContext);
              await _saveThemeMode(tempThemeMode);
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: colors.isDark ? 0.35 : 0.14,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _DialogIcon(
                            icon: Icons.palette_rounded,
                            colors: colors,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tema app',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Scegli come vuoi visualizzare PocketPlan.',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ThemeOptionTile(
                        icon: Icons.phone_android_rounded,
                        title: 'Automatico',
                        subtitle:
                            'Segue il tema chiaro o scuro del dispositivo.',
                        selected:
                            tempThemeMode == PocketPlanThemeMode.system,
                        onTap: () {
                          setDialogState(() {
                            tempThemeMode = PocketPlanThemeMode.system;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _ThemeOptionTile(
                        icon: Icons.light_mode_rounded,
                        title: 'Chiaro',
                        subtitle: 'Interfaccia chiara, pulita e luminosa.',
                        selected: tempThemeMode == PocketPlanThemeMode.light,
                        onTap: () {
                          setDialogState(() {
                            tempThemeMode = PocketPlanThemeMode.light;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _ThemeOptionTile(
                        icon: Icons.dark_mode_rounded,
                        title: 'Scuro',
                        subtitle: 'Interfaccia scura, più comoda la sera.',
                        selected: tempThemeMode == PocketPlanThemeMode.dark,
                        onTap: () {
                          setDialogState(() {
                            tempThemeMode = PocketPlanThemeMode.dark;
                          });
                        },
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
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
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                child: const Text('Annulla'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: confirmTheme,
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
                                child: const Text('Salva'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showProfileDialog() async {
    final user = _user;

    if (user == null) {
      await _showInfoDialog(
        title: 'Account non disponibile',
        description:
            'Non riesco a trovare l’utente corrente. Prova a uscire e rientrare nell’app.',
        icon: Icons.person_off_rounded,
      );
      return;
    }

    final colors = _SettingsColors.of(context);
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: _profileName);
    final surnameController = TextEditingController(text: _profileSurname);
    final countryController = TextEditingController(text: _profileCountry);
    final phoneController = TextEditingController(text: _profilePhone);
    final birthDateController = TextEditingController(
      text: _formatDate(_profileBirthDate),
    );

    DateTime? selectedBirthDate = _profileBirthDate;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickBirthDate() async {
              final now = DateTime.now();

              final picked = await showDatePicker(
                context: context,
                initialDate: selectedBirthDate ??
                    DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(1900),
                lastDate: DateTime(now.year, now.month, now.day),
                helpText: 'Seleziona data di nascita',
                cancelText: 'Annulla',
                confirmText: 'Conferma',
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: colors.isDark
                          ? const ColorScheme.dark(
                              primary: Color(0xFF60A5FA),
                              onPrimary: Color(0xFF0F172A),
                              surface: Color(0xFF172033),
                              onSurface: Color(0xFFF8FAFC),
                            )
                          : const ColorScheme.light(
                              primary: Color(0xFF1677F2),
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Color(0xFF172033),
                            ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked == null) return;

              setDialogState(() {
                selectedBirthDate = picked;
                birthDateController.text = _formatDate(picked);
              });
            }

            Future<void> saveProfile() async {
              if (!formKey.currentState!.validate()) return;

              final name = nameController.text.trim();
              final surname = surnameController.text.trim();
              final country = countryController.text.trim();
              final phone = phoneController.text.trim();
              final fullName = '$name $surname'.trim();

              setDialogState(() {
                isSaving = true;
              });

              try {
                await user.updateDisplayName(fullName);
                await user.reload();

                await _db.collection('users').doc(user.uid).set(
                  {
                    'name': name,
                    'surname': surname,
                    'country': country,
                    'phone': phone,
                    'birth_date': selectedBirthDate == null
                        ? null
                        : Timestamp.fromDate(selectedBirthDate!),
                    'email': user.email,
                    'display_name': fullName,
                    'role': _userRole,
                    'updated_at': FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true),
                );

                if (!mounted) return;

                setState(() {
                  _profileName = name;
                  _profileSurname = surname;
                  _profileCountry = country;
                  _profilePhone = phone;
                  _profileBirthDate = selectedBirthDate;
                });

                Navigator.pop(dialogContext);

                await _showInfoDialog(
                  title: 'Profilo aggiornato',
                  description:
                      'Le informazioni del profilo sono state salvate correttamente.',
                  icon: Icons.check_circle_rounded,
                );
              } catch (_) {
                if (!mounted) return;

                setDialogState(() {
                  isSaving = false;
                });

                await _showInfoDialog(
                  title: 'Errore',
                  description:
                      'Non sono riuscito ad aggiornare il profilo. Riprova tra poco.',
                  icon: Icons.error_outline_rounded,
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: colors.isDark ? 0.35 : 0.14,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _DialogIcon(
                                icon: Icons.badge_rounded,
                                colors: colors,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Profilo personale',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Modifica i dati del tuo account.',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isSaving
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded),
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _ProfileTextField(
                            controller: nameController,
                            label: 'Nome',
                            hint: 'Es. Nicola',
                            icon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Inserisci il nome';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _ProfileTextField(
                            controller: surnameController,
                            label: 'Cognome',
                            hint: 'Es. Consoli',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 12),
                          _ProfileTextField(
                            controller: birthDateController,
                            label: 'Data di nascita',
                            hint: 'Seleziona una data',
                            icon: Icons.cake_rounded,
                            readOnly: true,
                            onTap: pickBirthDate,
                            suffixIcon: Icons.calendar_month_rounded,
                          ),
                          const SizedBox(height: 12),
                          _ProfileTextField(
                            controller: countryController,
                            label: 'Paese',
                            hint: 'Es. Italia',
                            icon: Icons.public_rounded,
                          ),
                          const SizedBox(height: 12),
                          _ProfileTextField(
                            controller: phoneController,
                            label: 'Telefono',
                            hint: 'Es. +39 333 1234567',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.cardSoft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.email_rounded,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w700,
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
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: isSaving
                                        ? null
                                        : () => Navigator.pop(dialogContext),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.textPrimary,
                                      side: BorderSide(
                                        color: colors.border,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    child: const Text('Annulla'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: isSaving ? null : saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.primaryText,
                                      disabledBackgroundColor:
                                          colors.primary.withValues(alpha: 0.45),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    child: isSaving
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: colors.primaryText,
                                            ),
                                          )
                                        : const Text('Salva'),
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
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    surnameController.dispose();
    countryController.dispose();
    phoneController.dispose();
    birthDateController.dispose();
  }

    Future<void> _sendTicketEmailWithEmailJs({
    required String ticketCode,
    required String subject,
    required String message,
    required String priority,
    required String userName,
    required String userEmail,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': _emailJsServiceId,
        'template_id': _emailJsTemplateId,
        'user_id': _emailJsPublicKey,
        'template_params': {
          'to_email': _supportEmail,
          'ticket_code': ticketCode,
          'subject': subject,
          'message': message,
          'priority': priority,
          'user_name': userName,
          'user_email': userEmail,
        },
      }),
    );

    debugPrint('EmailJS status: ${response.statusCode}');
    debugPrint('EmailJS body: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore EmailJS: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<String> _createSupportTicket({
    required String subject,
    required String message,
    required String priority,
  }) async {
    final user = _user;

    if (user == null) {
      throw Exception('Utente non disponibile');
    }

    final ticketRef = _db.collection('support_tickets').doc();

    final userTicketRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('support_tickets')
        .doc(ticketRef.id);

    final ticketCode = 'PP-${DateTime.now().millisecondsSinceEpoch}';

    final userName = _displayName;
    final userEmail = user.email?.trim() ?? 'Email non disponibile';

    final ticketData = {
      'id': ticketRef.id,
      'ticket_code': ticketCode,
      'user_id': user.uid,
      'user_name': userName,
      'user_email': userEmail,
      'subject': subject,
      'message': message,
      'priority': priority,
      'status': 'open',
      'status_label': 'Aperto',
      'recipient_email': _supportEmail,
      'email_provider': 'emailjs',
      'email_sent': false,
      'last_message': message,
      'last_message_sender_role': 'user',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    final firstMessageData = {
      'sender_id': user.uid,
      'sender_role': 'user',
      'sender_name': userName,
      'sender_email': userEmail,
      'message': message,
      'created_at': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();

    batch.set(ticketRef, ticketData);
    batch.set(userTicketRef, ticketData);

    batch.set(
      ticketRef.collection('messages').doc(),
      firstMessageData,
    );

    batch.set(
      userTicketRef.collection('messages').doc(),
      firstMessageData,
    );

    await batch.commit();

    try {
      await _sendTicketEmailWithEmailJs(
        ticketCode: ticketCode,
        subject: subject,
        message: message,
        priority: priority,
        userName: userName,
        userEmail: userEmail,
      );

      await Future.wait([
        ticketRef.set(
          {
            'email_sent': true,
            'email_sent_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
        userTicketRef.set(
          {
            'email_sent': true,
            'email_sent_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
      ]);
    } catch (error) {
      await Future.wait([
        ticketRef.set(
          {
            'email_sent': false,
            'email_error': error.toString(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
        userTicketRef.set(
          {
            'email_sent': false,
            'email_error': error.toString(),
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        ),
      ]);

      rethrow;
    }

    return ticketCode;
  }

  Future<void> _sendTicketMessage({
    required String ticketId,
    required String ownerUserId,
    required String message,
    required bool asAdmin,
  }) async {
    final user = _user;

    if (user == null) {
      throw Exception('Utente non disponibile');
    }

    final cleanMessage = message.trim();

    if (cleanMessage.isEmpty) {
      return;
    }

    final senderRole = asAdmin ? 'admin' : 'user';
    final senderName = asAdmin ? 'Supporto PocketPlan' : _displayName;
    final senderEmail = user.email?.trim() ?? '';

    final ticketRef = _db.collection('support_tickets').doc(ticketId);

    final userTicketRef = _db
        .collection('users')
        .doc(ownerUserId)
        .collection('support_tickets')
        .doc(ticketId);

    final messageData = {
      'sender_id': user.uid,
      'sender_role': senderRole,
      'sender_name': senderName,
      'sender_email': senderEmail,
      'message': cleanMessage,
      'created_at': FieldValue.serverTimestamp(),
    };

    final updateData = {
      'last_message': cleanMessage,
      'last_message_sender_role': senderRole,
      'updated_at': FieldValue.serverTimestamp(),
      if (asAdmin) ...{
        'status': 'pending',
        'status_label': 'In attesa utente',
      } else ...{
        'status': 'open',
        'status_label': 'Aperto',
      },
    };

    final batch = _db.batch();

    batch.set(ticketRef.collection('messages').doc(), messageData);
    batch.set(userTicketRef.collection('messages').doc(), messageData);

    batch.set(ticketRef, updateData, SetOptions(merge: true));
    batch.set(userTicketRef, updateData, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> _showTicketChatDialog({
    required String ticketId,
    required String ownerUserId,
    required String ticketCode,
    required String subject,
    required bool adminMode,
  }) async {
    final colors = _SettingsColors.of(context);
    final replyController = TextEditingController();

    bool isSending = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSending,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendReply() async {
              final text = replyController.text.trim();

              if (text.isEmpty) return;

              setDialogState(() {
                isSending = true;
              });

              try {
                await _sendTicketMessage(
                  ticketId: ticketId,
                  ownerUserId: ownerUserId,
                  message: text,
                  asAdmin: adminMode,
                );

                replyController.clear();

                if (!mounted) return;

                setDialogState(() {
                  isSending = false;
                });
              } catch (_) {
                if (!mounted) return;

                setDialogState(() {
                  isSending = false;
                });

                await _showInfoDialog(
                  title: 'Errore',
                  description:
                      'Non sono riuscito a inviare la risposta. Riprova tra poco.',
                  icon: Icons.error_outline_rounded,
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  maxHeight: MediaQuery.sizeOf(context).height - 40,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: colors.isDark ? 0.35 : 0.14,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _DialogIcon(
                            icon: adminMode
                                ? Icons.admin_panel_settings_rounded
                                : Icons.support_agent_rounded,
                            colors: colors,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticketCode,
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subject,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isSending
                                ? null
                                : () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close_rounded),
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _db
                              .collection('support_tickets')
                              .doc(ticketId)
                              .collection('messages')
                              .orderBy('created_at', descending: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: colors.primary,
                                ),
                              );
                            }

                            final docs = snapshot.data?.docs ?? [];

                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'Nessun messaggio presente.',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final data = docs[index].data();

                                final senderRole =
                                    (data['sender_role'] ?? 'user').toString();
                                final senderName =
                                    (data['sender_name'] ?? '').toString();
                                final message =
                                    (data['message'] ?? '').toString();

                                final isAdminMessage = senderRole == 'admin';

                                DateTime? createdAt;
                                final rawCreatedAt = data['created_at'];

                                if (rawCreatedAt is Timestamp) {
                                  createdAt = rawCreatedAt.toDate();
                                }

                                return Align(
                                  alignment: isAdminMessage
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      maxWidth: 520,
                                    ),
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: isAdminMessage
                                          ? colors.primary
                                          : colors.cardSoft,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(
                                          isAdminMessage ? 18 : 6,
                                        ),
                                        bottomRight: Radius.circular(
                                          isAdminMessage ? 6 : 18,
                                        ),
                                      ),
                                      border: Border.all(
                                        color: isAdminMessage
                                            ? colors.primary
                                            : colors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isAdminMessage
                                              ? 'Supporto PocketPlan'
                                              : senderName.isEmpty
                                                  ? 'Utente'
                                                  : senderName,
                                          style: TextStyle(
                                            color: isAdminMessage
                                                ? colors.primaryText
                                                : colors.primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          message,
                                          style: TextStyle(
                                            color: isAdminMessage
                                                ? colors.primaryText
                                                : colors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (createdAt != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatDate(createdAt),
                                            style: TextStyle(
                                              color: isAdminMessage
                                                  ? colors.primaryText
                                                      .withValues(alpha: 0.78)
                                                  : colors.textMuted,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              minLines: 1,
                              maxLines: 4,
                              enabled: !isSending,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: adminMode
                                    ? 'Scrivi una risposta al ticket...'
                                    : 'Scrivi un nuovo messaggio...',
                                hintStyle: TextStyle(
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: colors.cardSoft,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: colors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: colors.primary,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isSending ? null : sendReply,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: colors.primaryText,
                                disabledBackgroundColor:
                                    colors.primary.withValues(alpha: 0.45),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: isSending
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.3,
                                        color: colors.primaryText,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    replyController.dispose();
  }

    Future<void> _showSupportTicketDialog() async {
    final colors = _SettingsColors.of(context);

    final formKey = GlobalKey<FormState>();
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    String priority = 'Normale';
    bool isSending = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSending,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendTicket() async {
              if (!formKey.currentState!.validate()) return;

              final subject = subjectController.text.trim();
              final message = messageController.text.trim();

              setDialogState(() {
                isSending = true;
              });

              try {
                final ticketCode = await _createSupportTicket(
                  subject: subject,
                  message: message,
                  priority: priority,
                );

                if (!mounted) return;

                if (Navigator.canPop(dialogContext)) {
                  Navigator.pop(dialogContext);
                }

                await Future.delayed(const Duration(milliseconds: 150));

                if (!mounted) return;

                await _showInfoDialog(
                  title: 'Ticket aperto',
                  description:
                      'Il ticket $ticketCode è stato creato correttamente. Riceveremo la richiesta su $_supportEmail.',
                  icon: Icons.support_agent_rounded,
                );
              } catch (error) {
                debugPrint('Errore creazione/invio ticket: $error');

                if (!mounted) return;

                setDialogState(() {
                  isSending = false;
                });

                await _showInfoDialog(
                  title: 'Errore invio ticket',
                  description:
                      'Il ticket potrebbe essere stato salvato, ma l’email non è partita. Errore: $error',
                  icon: Icons.error_outline_rounded,
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(
                          alpha: colors.isDark ? 0.35 : 0.14,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _DialogIcon(
                                icon: Icons.support_agent_rounded,
                                colors: colors,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Apri ticket di supporto',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Descrivi il problema o la richiesta.',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: isSending
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded),
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _SupportTextField(
                            controller: subjectController,
                            label: 'Oggetto',
                            hint: 'Es. Problema con una spesa',
                            icon: Icons.title_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Inserisci un oggetto';
                              }

                              if (value.trim().length < 4) {
                                return 'Inserisci un oggetto più chiaro';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: priority,
                            dropdownColor: colors.card,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Priorità',
                              prefixIcon: Icon(
                                Icons.priority_high_rounded,
                                color: colors.primary,
                              ),
                              labelStyle: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                              filled: true,
                              fillColor: colors.cardSoft,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: colors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide(
                                  color: colors.primary,
                                  width: 1.4,
                                ),
                              ),
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
                            onChanged: isSending
                                ? null
                                : (value) {
                                    if (value == null) return;

                                    setDialogState(() {
                                      priority = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 12),
                          _SupportTextField(
                            controller: messageController,
                            label: 'Descrizione',
                            hint: 'Scrivi cosa non funziona o cosa ti serve...',
                            icon: Icons.chat_bubble_outline_rounded,
                            minLines: 5,
                            maxLines: 7,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Inserisci una descrizione';
                              }

                              if (value.trim().length < 10) {
                                return 'Descrivi meglio la richiesta';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colors.primarySoft,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colors.isDark
                                    ? colors.border
                                    : Colors.transparent,
                              ),
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
                                    'Il ticket verrà salvato nel database e inviato a $_supportEmail. Priorità selezionata: $priority.',
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
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: isSending
                                        ? null
                                        : () => Navigator.pop(dialogContext),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.textPrimary,
                                      side: BorderSide(
                                        color: colors.border,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    child: const Text('Annulla'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: isSending ? null : sendTicket,
                                    icon: isSending
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: colors.primaryText,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      isSending ? 'Invio...' : 'Invia ticket',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.primaryText,
                                      disabledBackgroundColor:
                                          colors.primary.withValues(alpha: 0.45),
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
              ),
            );
          },
        );
      },
    );

    subjectController.dispose();
    messageController.dispose();
  }

  Future<void> _showMyTicketsDialog() async {
    final user = _user;

    if (user == null) {
      await _showInfoDialog(
        title: 'Account non disponibile',
        description:
            'Non riesco a trovare l’utente corrente. Prova a uscire e rientrare nell’app.',
        icon: Icons.person_off_rounded,
      );
      return;
    }

    final colors = _SettingsColors.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: MediaQuery.sizeOf(context).height - 48,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: colors.isDark ? 0.35 : 0.14,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DialogIcon(
                        icon: Icons.confirmation_number_rounded,
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I miei ticket',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Consulta e continua le richieste inviate al supporto.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db
                          .collection('users')
                          .doc(user.uid)
                          .collection('support_tickets')
                          .orderBy('updated_at', descending: true)
                          .limit(30)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colors.cardSoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.border,
                              ),
                            ),
                            child: Text(
                              'Non hai ancora aperto nessun ticket.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            final ticketCode =
                                (data['ticket_code'] ?? 'Ticket').toString();
                            final subject =
                                (data['subject'] ?? 'Senza oggetto').toString();
                            final priority =
                                (data['priority'] ?? 'Normale').toString();
                            final statusLabel =
                                (data['status_label'] ?? 'Aperto').toString();
                            final lastMessage =
                                (data['last_message'] ?? data['message'] ?? '')
                                    .toString();

                            DateTime? updatedAt;
                            final rawUpdatedAt = data['updated_at'];

                            if (rawUpdatedAt is Timestamp) {
                              updatedAt = rawUpdatedAt.toDate();
                            }

                            return Material(
                              color: colors.cardSoft,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  Navigator.pop(dialogContext);

                                  _showTicketChatDialog(
                                    ticketId: doc.id,
                                    ownerUserId: user.uid,
                                    ticketCode: ticketCode,
                                    subject: subject,
                                    adminMode: false,
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: colors.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.support_agent_rounded,
                                          color: colors.primary,
                                          size: 21,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ticketCode,
                                              style: TextStyle(
                                                color: colors.primary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              subject,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                            if (lastMessage.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Text(
                                                lastMessage,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _PlanBadge(text: statusLabel),
                                                _PlanBadge(text: priority),
                                                if (updatedAt != null)
                                                  _PlanBadge(
                                                    text: _formatDate(updatedAt),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: colors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
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
                      child: const Text('Chiudi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAdminTicketsDialog() async {
    if (!_isAdmin) {
      await _showInfoDialog(
        title: 'Accesso non autorizzato',
        description:
            'Questa sezione è disponibile solo per gli amministratori PocketPlan.',
        icon: Icons.lock_rounded,
      );
      return;
    }

    final colors = _SettingsColors.of(context);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 780,
              maxHeight: MediaQuery.sizeOf(context).height - 48,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(
                      alpha: colors.isDark ? 0.35 : 0.14,
                    ),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _DialogIcon(
                        icon: Icons.admin_panel_settings_rounded,
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Area Admin Ticket',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Visualizza e rispondi alle richieste degli utenti.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db
                          .collection('support_tickets')
                          .orderBy('updated_at', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: colors.cardSoft,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.border,
                              ),
                            ),
                            child: Text(
                              'Non ci sono ticket da gestire.',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            final ticketCode =
                                (data['ticket_code'] ?? 'Ticket').toString();
                            final subject =
                                (data['subject'] ?? 'Senza oggetto').toString();
                            final priority =
                                (data['priority'] ?? 'Normale').toString();
                            final statusLabel =
                                (data['status_label'] ?? 'Aperto').toString();
                            final userName =
                                (data['user_name'] ?? 'Utente').toString();
                            final userEmail =
                                (data['user_email'] ?? '').toString();
                            final ownerUserId =
                                (data['user_id'] ?? '').toString();
                            final lastMessage =
                                (data['last_message'] ?? data['message'] ?? '')
                                    .toString();

                            DateTime? updatedAt;
                            final rawUpdatedAt = data['updated_at'];

                            if (rawUpdatedAt is Timestamp) {
                              updatedAt = rawUpdatedAt.toDate();
                            }

                            return Material(
                              color: colors.cardSoft,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: ownerUserId.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(dialogContext);

                                        _showTicketChatDialog(
                                          ticketId: doc.id,
                                          ownerUserId: ownerUserId,
                                          ticketCode: ticketCode,
                                          subject: subject,
                                          adminMode: true,
                                        );
                                      },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: colors.border,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: colors.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Icon(
                                          Icons.support_agent_rounded,
                                          color: colors.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    ticketCode,
                                                    style: TextStyle(
                                                      color: colors.primary,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                _PlanBadge(text: statusLabel),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              subject,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              '$userName · $userEmail',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            if (lastMessage.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                lastMessage,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.25,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _PlanBadge(text: priority),
                                                if (updatedAt != null)
                                                  _PlanBadge(
                                                    text: _formatDate(updatedAt),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: colors.textMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
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
                      child: const Text('Chiudi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

    Future<void> _showDeleteDataDialog() async {
    final colors = _SettingsColors.of(context);

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Eliminare i dati?',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Questa funzione verrà collegata più avanti. Prima di eliminare dati reali aggiungeremo una conferma sicura, così l’utente non rischia di cancellare tutto per errore.',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
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
                child: const Text('Chiudi'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _user?.email;

    if (email == null || email.trim().isEmpty) {
      await _showInfoDialog(
        title: 'Email non disponibile',
        description:
            'Non riesco a trovare l’email dell’account corrente. Più avanti potremo aggiungere una pagina dedicata per gestire meglio il profilo.',
        icon: Icons.email_outlined,
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      await _showInfoDialog(
        title: 'Email inviata',
        description:
            'Ti abbiamo inviato un’email per reimpostare la password a $email.',
        icon: Icons.mark_email_read_rounded,
      );
    } catch (_) {
      if (!mounted) return;

      await _showInfoDialog(
        title: 'Errore',
        description:
            'Non sono riuscito a inviare l’email di recupero password. Riprova tra poco.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final isMobile = _isMobile(context);

    return Scaffold(
      backgroundColor: colors.scaffold,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 16 : 24,
          isMobile ? 16 : 24,
          isMobile ? 120 : 36,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsHeader(
                  displayName: _displayName,
                  email: _email,
                  initials: _initials,
                  isLoadingProfile: _isLoadingProfile,
                ),
                SizedBox(height: isMobile ? 18 : 22),
                _ResponsiveSettingsGrid(
                  children: [
                    _SettingsSection(
                      title: 'Account',
                      icon: Icons.person_rounded,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.badge_rounded,
                          title: 'Profilo personale',
                          subtitle: 'Modifica nome, cognome e dati personali.',
                          onTap: _showProfileDialog,
                        ),
                        _SettingsActionTile(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Piano attuale',
                          subtitle:
                              'Gratis',
                          trailing: const _PlanBadge(text: 'Free'),
                          onTap: _showPlanDialog,
                        ),
                      ],
                    ),
                    _SettingsSection(
                      title: 'Preferenze',
                      icon: Icons.tune_rounded,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.palette_rounded,
                          title: 'Tema app',
                          subtitle: _themeModeSubtitle,
                          trailing: _PlanBadge(text: _themeModeLabel),
                          onTap: _showThemeDialog,
                        ),
                        _SettingsActionTile(
                          icon: Icons.euro_rounded,
                          title: 'Valuta',
                          subtitle: 'Valuta predefinita per entrate e spese.',
                          trailing: const _PlanBadge(text: 'EUR'),
                          onTap: () => _showInfoDialog(
                            title: 'Valuta',
                            description:
                                'Per ora usiamo l’euro come valuta principale. Più avanti potremo rendere questa impostazione modificabile.',
                            icon: Icons.euro_rounded,
                          ),
                        ),
                      ],
                    ),
                    _SettingsSection(
                      title: 'Notifiche',
                      icon: Icons.notifications_rounded,
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Avvisi budget',
                          subtitle:
                              'Ricevi promemoria quando stai superando i limiti.',
                          value: _budgetAlertsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _budgetAlertsEnabled = value;
                            });
                          },
                        ),
                        _SettingsSwitchTile(
                          icon: Icons.flag_rounded,
                          title: 'Avvisi obiettivi',
                          subtitle:
                              'Promemoria per seguire meglio i tuoi traguardi.',
                          value: _goalAlertsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _goalAlertsEnabled = value;
                            });
                          },
                        ),
                        _SettingsSwitchTile(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Consigli AI',
                          subtitle:
                              'Suggerimenti intelligenti sulle tue abitudini.',
                          value: _aiTipsEnabled,
                          onChanged: (value) {
                            setState(() {
                              _aiTipsEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    _SettingsSection(
                      title: 'Supporto e ticket',
                      icon: Icons.support_agent_rounded,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.add_comment_rounded,
                          title: 'Apri ticket di supporto',
                          subtitle:
                              'Segnala un problema o invia una richiesta.',
                          onTap: _showSupportTicketDialog,
                        ),
                        _SettingsActionTile(
                          icon: Icons.confirmation_number_rounded,
                          title: 'I miei ticket',
                          subtitle:
                              'Consulta lo stato delle richieste inviate.',
                          onTap: _showMyTicketsDialog,
                        ),
                        _SettingsSwitchTile(
                          icon: Icons.mark_email_unread_rounded,
                          title: 'Aggiornamenti ticket',
                          subtitle:
                              'Ricevi notifiche quando un ticket viene aggiornato.',
                          value: _ticketUpdatesEnabled,
                          onChanged: (value) {
                            setState(() {
                              _ticketUpdatesEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isAdmin)
                      _SettingsSection(
                        title: 'Area Admin',
                        icon: Icons.admin_panel_settings_rounded,
                        children: [
                          _SettingsActionTile(
                            icon: Icons.support_agent_rounded,
                            title: 'Gestione ticket',
                            subtitle:
                                'Visualizza e rispondi ai ticket degli utenti.',
                            trailing: const _PlanBadge(text: 'Admin'),
                            onTap: _showAdminTicketsDialog,
                          ),
                        ],
                      ),
                    _SettingsSection(
                      title: 'Sicurezza',
                      icon: Icons.lock_rounded,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.password_rounded,
                          title: 'Cambia password',
                          subtitle:
                              'Ricevi un’email per reimpostare la password.',
                          onTap: _sendPasswordResetEmail,
                        ),
                        _SettingsActionTile(
                          icon: Icons.privacy_tip_rounded,
                          title: 'Privacy dati',
                          subtitle:
                              'Scopri come vengono usati i dati finanziari.',
                          onTap: () => _showInfoDialog(
                            title: 'Privacy dati',
                            description:
                                'PocketPlan deve trattare i dati finanziari con molta attenzione. Qui inseriremo una spiegazione chiara su privacy, sicurezza e utilizzo dei dati.',
                            icon: Icons.privacy_tip_rounded,
                          ),
                        ),
                      ],
                    ),
                    _SettingsSection(
                      title: 'Gestione dati',
                      icon: Icons.storage_rounded,
                      children: [
                        _SettingsActionTile(
                          icon: Icons.file_download_rounded,
                          title: 'Esporta dati',
                          subtitle:
                              'Scarica una copia delle tue entrate e spese.',
                          onTap: () => _showInfoDialog(
                            title: 'Esporta dati',
                            description:
                                'Qui potremo aggiungere un export CSV o PDF con movimenti, obiettivi e riepiloghi.',
                            icon: Icons.file_download_rounded,
                          ),
                        ),
                        _SettingsActionTile(
                          icon: Icons.delete_forever_rounded,
                          title: 'Elimina dati',
                          subtitle:
                              'Cancella i dati salvati nel tuo account.',
                          danger: true,
                          onTap: _showDeleteDataDialog,
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 18 : 22),
                const _AppInfoCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsColors {
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
  final Color headerBackground;
  final Color headerText;
  final Color headerMuted;
  final Color success;
  final Color danger;
  final Color dangerSoft;
  final Color shadow;

  const _SettingsColors({
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
    required this.headerBackground,
    required this.headerText,
    required this.headerMuted,
    required this.success,
    required this.danger,
    required this.dangerSoft,
    required this.shadow,
  });

  factory _SettingsColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _SettingsColors(
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
        headerBackground: Color(0xFF020617),
        headerText: Colors.white,
        headerMuted: Color(0xFFCBD5E1),
        success: Color(0xFF22C55E),
        danger: Color(0xFFF87171),
        dangerSoft: Color(0xFF450A0A),
        shadow: Colors.black,
      );
    }

    return const _SettingsColors(
      isDark: false,
      scaffold: Color(0xFFF5F8FC),
      card: Colors.white,
      cardSoft: Color(0xFFF7FAFE),
      cardSofter: Color(0xFFF3F6FB),
      border: Color(0xFFE5ECF5),
      textPrimary: Color(0xFF172033),
      textSecondary: Color(0xFF64748B),
      textMuted: Color(0xFF94A3B8),
      primary: Color(0xFF1677F2),
      primarySoft: Color(0xFFE3F2FD),
      primaryText: Colors.white,
      headerBackground: Color(0xFF172033),
      headerText: Colors.white,
      headerMuted: Color(0xFFD7DEE9),
      success: Color(0xFF16A34A),
      danger: Color(0xFFDC2626),
      dangerSoft: Color(0xFFFEE2E2),
      shadow: Colors.black,
    );
  }
}

class _DialogIcon extends StatelessWidget {
  final IconData icon;
  final _SettingsColors colors;
  final double size;

  const _DialogIcon({
    required this.icon,
    required this.colors,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(size <= 42 ? 14 : 16),
      ),
      child: Icon(
        icon,
        color: colors.primary,
      ),
    );
  }
}

BoxDecoration _settingsCardDecoration(BuildContext context) {
  final colors = _SettingsColors.of(context);

  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(26),
    border: Border.all(
      color: colors.border,
    ),
    boxShadow: [
      BoxShadow(
        color: colors.shadow.withValues(alpha: colors.isDark ? 0.18 : 0.035),
        blurRadius: colors.isDark ? 22 : 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _PlanOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String monthlyPrice;
  final String? annualPrice;
  final String? annualSaving;
  final String badge;
  final String description;
  final List<String> features;
  final bool highlighted;
  final bool buttonEnabled;
  final String buttonText;
  final VoidCallback? onTap;

  const _PlanOptionCard({
    required this.icon,
    required this.title,
    required this.monthlyPrice,
    required this.annualPrice,
    required this.annualSaving,
    required this.badge,
    required this.description,
    required this.features,
    required this.highlighted,
    required this.buttonEnabled,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktopPlanModal = width >= 780;

    final borderColor = highlighted ? colors.primary : colors.border;
    final backgroundColor = highlighted ? colors.primarySoft : colors.cardSoft;

    Widget priceSection() {
      if (annualPrice == null) {
        return _PlanPriceBox(
          label: 'Piano gratuito',
          price: monthlyPrice,
          highlighted: highlighted,
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PlanPriceBox(
              label: 'Mensile',
              price: monthlyPrice,
              highlighted: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlanPriceBox(
              label: 'Annuale',
              price: annualPrice!,
              saving: annualSaving,
              highlighted: false,
            ),
          ),
        ],
      );
    }

    Widget featuresSection() {
      return Column(
        children: features
            .map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: colors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisSize:
            isDesktopPlanModal ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: highlighted ? colors.primary : colors.card,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: highlighted ? colors.primary : colors.border,
                  ),
                ),
                child: Icon(
                  icon,
                  color: highlighted ? colors.primaryText : colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: highlighted ? colors.primary : colors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: highlighted ? colors.primary : colors.border,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: highlighted
                            ? colors.primaryText
                            : colors.textMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          priceSection(),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          if (isDesktopPlanModal)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: featuresSection(),
              ),
            )
          else
            featuresSection(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: buttonEnabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted ? colors.primary : colors.card,
                foregroundColor:
                    highlighted ? colors.primaryText : colors.textPrimary,
                disabledBackgroundColor: colors.cardSofter,
                disabledForegroundColor: colors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: highlighted ? colors.primary : colors.border,
                  ),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPriceBox extends StatelessWidget {
  final String label;
  final String price;
  final String? saving;
  final bool highlighted;

  const _PlanPriceBox({
    required this.label,
    required this.price,
    this.saving,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: highlighted ? colors.primary : colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? colors.primary : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlighted ? colors.primaryText : colors.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: TextStyle(
              color: highlighted ? colors.primaryText : colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          if (saving != null) ...[
            const SizedBox(height: 5),
            Text(
              saving!,
              style: TextStyle(
                color: colors.success,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Material(
      color: selected ? colors.primarySoft : colors.cardSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.card,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selected ? colors.primary : colors.border,
                  ),
                ),
                child: Icon(
                  icon,
                  color: selected ? colors.primaryText : colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colors.primary : colors.textMuted,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: colors.primaryText,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final IconData? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      keyboardType: keyboardType,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: colors.primary,
        ),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(
                suffixIcon,
                color: colors.textMuted,
              ),
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: colors.cardSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.danger,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.danger,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SupportTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;

  const _SupportTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            bottom: maxLines > 1 ? 72 : 0,
          ),
          child: Icon(
            icon,
            color: colors.primary,
          ),
        ),
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: colors.cardSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.danger,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.danger,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String displayName;
  final String email;
  final String initials;
  final bool isLoadingProfile;

  const _SettingsHeader({
    required this.displayName,
    required this.email,
    required this.initials,
    required this.isLoadingProfile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 22 : 28),
      decoration: BoxDecoration(
        color: colors.headerBackground,
        borderRadius: BorderRadius.circular(isMobile ? 26 : 30),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(
              alpha: colors.isDark ? 0.24 : 0.10,
            ),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccountAvatar(initials: initials, size: 68),
                const SizedBox(height: 18),
                _HeaderText(
                  displayName: displayName,
                  email: email,
                  isMobile: true,
                  isLoadingProfile: isLoadingProfile,
                ),
                const SizedBox(height: 18),
                const _HeaderStatusCard(),
              ],
            )
          : Row(
              children: [
                _AccountAvatar(initials: initials, size: 78),
                const SizedBox(width: 20),
                Expanded(
                  child: _HeaderText(
                    displayName: displayName,
                    email: email,
                    isMobile: false,
                    isLoadingProfile: isLoadingProfile,
                  ),
                ),
                const SizedBox(width: 20),
                const _HeaderStatusCard(),
              ],
            ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const _AccountAvatar({
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colors.headerText,
            fontSize: size >= 78 ? 26 : 23,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String displayName;
  final String email;
  final bool isMobile;
  final bool isLoadingProfile;

  const _HeaderText({
    required this.displayName,
    required this.email,
    required this.isMobile,
    required this.isLoadingProfile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Impostazioni',
          style: TextStyle(
            color: colors.headerText,
            fontSize: isMobile ? 27 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        if (isLoadingProfile)
          Container(
            width: isMobile ? 170 : 220,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
          )
        else
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.headerMuted,
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.headerMuted.withValues(alpha: 0.82),
            fontSize: isMobile ? 13 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HeaderStatusCard extends StatelessWidget {
  const _HeaderStatusCard();

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    return Container(
      width: isMobile ? double.infinity : 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stato account',
            style: TextStyle(
              color: colors.headerMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.verified_rounded,
                color: colors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Account attivo',
                  style: TextStyle(
                    color: colors.headerText,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Piano Free · Funzioni base attive',
            style: TextStyle(
              color: colors.headerMuted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveSettingsGrid extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveSettingsGrid({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isMobile = constraints.maxWidth < 850;

        if (isMobile) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map(
                (child) => SizedBox(
                  width: (constraints.maxWidth - 16) / 2,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    final visibleChildren = children
        .map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: child,
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _settingsCardDecoration(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...visibleChildren,
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    final iconColor = danger ? colors.danger : colors.primary;
    final iconBg = danger ? colors.dangerSoft : colors.primarySoft;
    final titleColor = danger ? colors.danger : colors.textPrimary;

    return Material(
      color: colors.cardSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TileText(
                  title: title,
                  subtitle: subtitle,
                  titleColor: titleColor,
                ),
              ),
              const SizedBox(width: 10),
              if (trailing != null) trailing!,
              if (trailing == null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: danger ? colors.danger : colors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: value ? colors.primarySoft : colors.cardSofter,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: value ? colors.primary : colors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TileText(
              title: title,
              subtitle: subtitle,
              titleColor: colors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            activeColor: colors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TileText extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color titleColor;

  const _TileText({
    required this.title,
    required this.subtitle,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String text;

  const _PlanBadge({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.isDark ? colors.border : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: _settingsCardDecoration(context),
      child: isMobile
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AppInfoTitle(),
                SizedBox(height: 14),
                _AppInfoBadges(),
              ],
            )
          : const Row(
              children: [
                Expanded(
                  child: _AppInfoTitle(),
                ),
                SizedBox(width: 18),
                _AppInfoBadges(),
              ],
            ),
    );
  }
}

class _AppInfoTitle extends StatelessWidget {
  const _AppInfoTitle();

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PocketPlan',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Gestisci i tuoi soldi con un’intelligenza che pensa ai tuoi obiettivi.',
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _AppInfoBadges extends StatelessWidget {
  const _AppInfoBadges();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoBadge(
          icon: Icons.verified_rounded,
          label: 'Versione 1.0.0',
        ),
        _InfoBadge(
          icon: Icons.security_rounded,
          label: 'Dati protetti',
        ),
        _InfoBadge(
          icon: Icons.support_agent_rounded,
          label: 'Supporto ticket',
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _SettingsColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colors.cardSofter,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colors.isDark ? colors.border : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}