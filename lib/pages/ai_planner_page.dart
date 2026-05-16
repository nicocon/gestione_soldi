import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/finance_service.dart';
import '../services/notification_service.dart';

class AIPlannerPage extends StatefulWidget {
  const AIPlannerPage({super.key});

  @override
  State<AIPlannerPage> createState() => _AIPlannerPageState();
}

class _AIPlannerPageState extends State<AIPlannerPage> {
  final FinanceService _financeService = FinanceService();

  final TextEditingController _questionController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  late Future<Map<String, dynamic>?> _aiProfileFuture;
  Map<String, dynamic>? _cachedAiProfile;

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
  );

  late Future<Map<String, dynamic>> _plannerFuture;

  bool _isAsking = false;

  final Set<String> _chatInsightIds = {};
  final Set<String> _activeChatInsightIds = {};

  final List<_AIMessage> _messages = [
    const _AIMessage(
      text:
          'Ciao! Sono il tuo AI Planner. Posso aiutarti a capire quanto puoi spendere, quanto puoi risparmiare e come gestire meglio il mese.',
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _plannerFuture = _financeService.getAIPlannerSnapshot();
    _aiProfileFuture = _loadAiProfile();

    _loadAiProfileIntoChat();
  }

  Future<Map<String, dynamic>?> _loadAiProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = userDoc.data();

    if (data == null) {
      return null;
    }

    final aiProfile = data['ai_profile'];

    if (aiProfile is Map) {
      final profile = Map<String, dynamic>.from(aiProfile);
      _cachedAiProfile = profile;

      return profile;
    }

    return null;
  }

  Future<void> _loadAiProfileIntoChat() async {
    try {
      final profile = await _aiProfileFuture;

      if (!mounted || profile == null) return;

      final welcomeMessage = _personalizedWelcomeMessage(profile);

      setState(() {
        _messages
          ..clear()
          ..add(
            _AIMessage(
              text: welcomeMessage,
              isUser: false,
            ),
          );
      });

      _scrollChatToBottom();
    } catch (_) {
      // Se il profilo non viene caricato, lasciamo il messaggio standard.
    }
  }

  String _labelFromValue(String? value, Map<String, String> labels) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    return labels[value] ?? value;
  }

  String _mainGoalLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['main_goal']?.toString(),
      {
        'save_more': 'risparmiare di più',
        'control_expenses': 'controllare meglio le spese',
        'reach_goal': 'raggiungere un obiettivo importante',
        'reduce_stress': 'vivere con più tranquillità nella gestione dei soldi',
      },
    );
  }

  String _moneyFeelingLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['money_feeling']?.toString(),
      {
        'calm': 'abbastanza tranquillo',
        'medium': 'così così',
        'confused': 'un po’ confuso',
        'stressed': 'spesso in difficoltà',
      },
    );
  }

  String _adviceStyleLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['advice_style']?.toString(),
      {
        'practical': 'pratico e diretto',
        'motivational': 'motivazionale',
        'detailed': 'dettagliato',
        'simple': 'semplice e veloce',
      },
    );
  }

  String _aiFrequencyLabel(Map<String, dynamic>? profile) {
    return _labelFromValue(
      profile?['ai_frequency']?.toString(),
      {
        'only_when_asked': 'solo quando chiede lui',
        'occasional': 'ogni tanto',
        'frequent': 'spesso e in modo più proattivo',
      },
    );
  }

  List<String> _interestLabels(Map<String, dynamic>? profile) {
    final rawInterests = profile?['interests'];

    if (rawInterests is! List) {
      return [];
    }

    final labels = {
      'travel': 'viaggiare',
      'home': 'casa',
      'car': 'auto o moto',
      'emergency_fund': 'fondo emergenza',
      'shopping': 'tempo libero',
      'investing': 'investire nel futuro',
    };

    return rawInterests
        .map((item) => labels[item.toString()] ?? item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  String _personalizedWelcomeMessage(Map<String, dynamic>? profile) {
    final mainGoal = _mainGoalLabel(profile);
    final interests = _interestLabels(profile);
    final adviceStyle = _adviceStyleLabel(profile);

    if (mainGoal.isEmpty && interests.isEmpty) {
      return 'Ciao! Sono il tuo AI Planner. Posso aiutarti a capire quanto puoi spendere, quanto puoi risparmiare e come gestire meglio il mese.';
    }

    final buffer = StringBuffer();

    buffer.write(
      'Ciao! Ho già letto le risposte iniziali che mi hai dato, quindi posso aiutarti in modo più personale. ',
    );

    if (mainGoal.isNotEmpty) {
      buffer.write('So che il tuo obiettivo principale è $mainGoal. ');
    }

    if (interests.isNotEmpty) {
      buffer.write(
        'Terrò conto anche dei tuoi interessi: ${interests.join(', ')}. ',
      );
    }

    if (adviceStyle.isNotEmpty) {
      buffer.write('Userò uno stile $adviceStyle. ');
    }

    buffer.write(
      '\n\nPuoi chiedermi, ad esempio: “quanto posso risparmiare questo mese?” oppure “come posso avvicinarmi ai miei obiettivi?”.',
    );

    return buffer.toString();
  }

  String _buildAiProfileContext(Map<String, dynamic>? profile) {
    if (profile == null || profile.isEmpty) {
      return '';
    }

    final mainGoal = _mainGoalLabel(profile);
    final moneyFeeling = _moneyFeelingLabel(profile);
    final adviceStyle = _adviceStyleLabel(profile);
    final aiFrequency = _aiFrequencyLabel(profile);
    final interests = _interestLabels(profile);

    final lines = <String>[];

    if (mainGoal.isNotEmpty) {
      lines.add('Obiettivo principale dell’utente: $mainGoal.');
    }

    if (interests.isNotEmpty) {
      lines.add('Interessi/obiettivi personali: ${interests.join(', ')}.');
    }

    if (moneyFeeling.isNotEmpty) {
      lines.add('Come si sente con i soldi: $moneyFeeling.');
    }

    if (adviceStyle.isNotEmpty) {
      lines.add('Stile di consiglio preferito: $adviceStyle.');
    }

    if (aiFrequency.isNotEmpty) {
      lines.add('Frequenza desiderata dei consigli AI: $aiFrequency.');
    }

    if (lines.isEmpty) {
      return '';
    }

    return lines.join('\n');
  }

  String _buildPersonalizedQuestion({
    required String question,
    required Map<String, dynamic>? profile,
  }) {
    // Il profilo AI viene già letto e usato dentro FinanceService.
    // Qui lasciamo passare solo la domanda pulita dell’utente,
    // così il riconoscimento locale delle intenzioni resta preciso.
    return question;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPlanner() async {
    final profileFuture = _loadAiProfile();

    setState(() {
      _plannerFuture = _financeService.getAIPlannerSnapshot();
      _aiProfileFuture = profileFuture;
    });

    final profile = await profileFuture;

    if (profile != null) {
      _cachedAiProfile = profile;
    }
  }

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  int _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return 0;
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  String _formatMoney(dynamic value) {
    return _currencyFormatter.format(_amountFrom(value));
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return [];

    return value.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _aiInsightsStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('ai_insights')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots();
  }

  DateTime? _aiInsightDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    return null;
  }

  Future<void> _markAiInsightAsRead(String insightId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || insightId.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_insights')
          .doc(insightId)
          .set(
        {
          'is_read': true,
          'read_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non blocchiamo mai la chat per un errore di lettura messaggio.
    }
  }

  Future<void> _archiveAiInsight(String insightId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || insightId.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_insights')
          .doc(insightId)
          .set(
        {
          'is_read': true,
          'is_archived': true,
          'archived_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _activeChatInsightIds.remove(insightId);
    } catch (_) {
      // Non blocchiamo mai la chat per un errore di archiviazione.
    }
  }

  Future<void> _archiveActiveChatInsights() async {
    if (_activeChatInsightIds.isEmpty) return;

    final ids = List<String>.from(_activeChatInsightIds);

    for (final id in ids) {
      await _archiveAiInsight(id);
    }

    _activeChatInsightIds.clear();
  }

  void _startNewChat() {
    final welcomeMessage = _personalizedWelcomeMessage(_cachedAiProfile);

    setState(() {
      _messages
        ..clear()
        ..add(
          _AIMessage(
            text: welcomeMessage,
            isUser: false,
          ),
        );

      _chatInsightIds.clear();
      _activeChatInsightIds.clear();
      _questionController.clear();
      _isAsking = false;
    });

    _scrollChatToBottom();
  }

  void _startChatFromInsight({
    required String id,
    required String title,
    required String message,
  }) {
    final text = message.trim().isEmpty ? title : '$title\n\n$message';

    setState(() {
      _messages
        ..clear()
        ..add(
          const _AIMessage(
            text:
                'Ciao! Apriamo una conversazione su questo messaggio. Dimmi pure cosa vuoi capire meglio.',
            isUser: false,
          ),
        )
        ..add(
          _AIMessage(
            text: text,
            isUser: false,
          ),
        );

      _chatInsightIds
        ..clear()
        ..add(id);

      _activeChatInsightIds
        ..clear()
        ..add(id);

      _questionController.clear();
      _isAsking = false;
    });

    _markAiInsightAsRead(id);
    _scrollChatToBottom();
  }

  String _normalizeQuestion(String value) {
    var text = value.toLowerCase().trim();

    const replacements = {
      'à': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'ò': 'o',
      'ù': 'u',
    };

    replacements.forEach((from, to) {
      text = text.replaceAll(from, to);
    });

    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text;
  }

  bool _containsAny(String text, List<String> words) {
    return words.any(text.contains);
  }

  bool _isGreetingOrSmallTalk(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final greetings = [
      'ciao',
      'hey',
      'ehi',
      'salve',
      'buongiorno',
      'buona sera',
      'buonasera',
      'buon pomeriggio',
      'hello',
      'hi',
    ];

    if (greetings.contains(cleaned)) return true;

    if (cleaned.split(' ').length <= 4 && _containsAny(cleaned, greetings)) {
      return true;
    }

    final smallTalk = [
      'come stai',
      'tutto bene',
      'che fai',
      'chi sei',
      'cosa fai',
      'mi aiuti',
      'puoi aiutarmi',
      'aiutami',
    ];

    return _containsAny(cleaned, smallTalk);
  }

  bool _isClearlyInvalidText(String text) {
    final compact = text.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (compact.length < 2) return true;

    if (RegExp(r'^(.)\1{5,}$').hasMatch(compact)) {
      return true;
    }

    final onlyNumbers = RegExp(r'^[0-9]+$').hasMatch(compact);
    if (onlyNumbers && compact.length < 4) {
      return true;
    }

    return false;
  }

  int _stableNotificationId(String value) {
    const int fnvPrime = 16777619;
    int hash = 2166136261;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }

    return 900000 + (hash % 800000000);
  }

  bool _shouldNotifyForAiAnswer(String answer) {
    final text = _normalizeQuestion(answer);

    return _containsAny(text, [
      'non te lo consiglio',
      'non ti consiglio',
      'margine negativo',
      'spese superano le entrate',
      'uscite superano le entrate',
      'situazione critica',
      'attenzione',
      'bloccare le spese',
      'evitare spese extra',
      'budget disponibile e negativo',
      'margine stimato resta negativo',
      'andresti sotto',
      'sei vicino al margine di sicurezza',
    ]);
  }

  Future<void> _notifyImportantAiAnswer(String answer) async {
    if (!_shouldNotifyForAiAnswer(answer)) return;

    try {
      final today = DateTime.now();

      final dayKey =
          '${today.year}_${today.month.toString().padLeft(2, '0')}_${today.day.toString().padLeft(2, '0')}';

      final id = _stableNotificationId(
        'ai_chat_${dayKey}_${answer.hashCode}',
      );

      await NotificationService.instance.showAiInsightNotification(
        id: id,
        title: 'Consiglio importante da PocketPlan',
        body: answer,
      );
    } catch (_) {
      // Le notifiche AI non devono mai bloccare la chat.
    }
  }

  bool _hasFinancialIntent(String text) {
    final financialWords = [
      'soldi',
      'spesa',
      'spese',
      'spendo',
      'spendere',
      'speso',
      'uscita',
      'uscite',
      'entrata',
      'entrate',
      'stipendio',
      'budget',
      'risparmio',
      'risparmiare',
      'risparmiato',
      'euro',
      '€',
      'mese',
      'mensile',
      'giorno',
      'giornaliero',
      'settimana',
      'pagare',
      'pagato',
      'pagamento',
      'bolletta',
      'bollette',
      'affitto',
      'mutuo',
      'rata',
      'rate',
      'obiettivo',
      'obiettivi',
      'target',
      'saldo',
      'disponibile',
      'posso comprare',
      'posso spendere',
      'quanto posso',
      'categoria',
      'categorie',
      'fine mese',
      'margine',
      'sicurezza',
      'finanziaria',
      'finanziario',
      'conto',
      'acquisto',
      'acquisti',
      'stipendi',
      'guadagno',
      'guadagnato',
      'cosa posso fare',
      'cosa devo fare',
      'che posso fare',
      'come posso migliorare',
      'migliorare',
      'sistemare',
      'consiglio',
      'consigli',
      'aiutami',
      'aiutami a migliorare',
      'come risolvo',
      'come posso sistemare',
      'che mi consigli',
      'cosa mi consigli',
      'budget mensile',
      'budget mensili',
      'pianificata',
      'pianificate',
      'spese pianificate',
      'spesa pianificata',
    ];

    return _containsAny(text, financialWords);
  }

  String? _localAnswerForQuestion(String question) {
    final text = _normalizeQuestion(question);

    if (_isGreetingOrSmallTalk(text)) {
      return 'Ciao! 😊 Posso aiutarti con domande legate alla tua situazione finanziaria. Per esempio puoi chiedermi:\n\n'
          '• Posso spendere 100€ questo mese?\n'
          '• Quanto posso risparmiare?\n'
          '• Sto spendendo troppo?\n'
          '• Quali budget dovrei controllare?\n'
          '• Quanto posso usare al giorno senza rischiare?\n'
          '• Come posso raggiungere meglio i miei obiettivi?';
    }

    if (_isClearlyInvalidText(text)) {
      return 'Non ho capito bene la domanda. Prova a scrivermi qualcosa legato a spese, entrate, budget, risparmio o obiettivi.';
    }

    if (!_hasFinancialIntent(text)) {
      return 'Posso aiutarti solo con domande legate alla tua situazione finanziaria: spese, entrate, budget, risparmio, obiettivi e gestione del mese.\n\n'
          'Prova per esempio a chiedermi: “Posso spendere 50€ oggi?” oppure “Quanto posso risparmiare questo mese?”.';
    }

    return null;
  }

  Future<void> _askQuestion() async {
    final question = _questionController.text.trim();

    if (question.isEmpty || _isAsking) return;

    setState(() {
      _messages.add(
        _AIMessage(
          text: question,
          isUser: true,
        ),
      );
      _isAsking = true;
      _questionController.clear();
    });

    await _archiveActiveChatInsights();

    _scrollChatToBottom();

    final localAnswer = _localAnswerForQuestion(question);

    if (localAnswer != null) {
      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;

      setState(() {
        _messages.add(
          _AIMessage(
            text: localAnswer,
            isUser: false,
          ),
        );
        _isAsking = false;
      });

      _scrollChatToBottom();
      return;
    }

    try {
      final profile = _cachedAiProfile ?? await _aiProfileFuture;

      final personalizedQuestion = _buildPersonalizedQuestion(
        question: question,
        profile: profile,
      );

      final answer = await _financeService.askAIPlannerLocally(
        question: personalizedQuestion,
      );

      final refreshedProfile = await _loadAiProfile();

      if (refreshedProfile != null) {
        _cachedAiProfile = refreshedProfile;
      }

      if (!mounted) return;

      setState(() {
        _messages.add(
          _AIMessage(
            text: answer,
            isUser: false,
          ),
        );
      });

      await _notifyImportantAiAnswer(answer);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          const _AIMessage(
            text:
                'Non sono riuscito ad analizzare i dati in questo momento. Controlla che entrate, spese e obiettivi siano caricati correttamente.',
            isUser: false,
          ),
        );
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isAsking = false;
      });

      _scrollChatToBottom();
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) return;

      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _askQuickQuestion(String question) async {
    _questionController.text = question;
    await _askQuestion();
  }

  Color _moodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'ottima':
        return const Color(0xFF16A34A);
      case 'stabile':
        return const Color(0xFF1677F2);
      case 'da controllare':
        return const Color(0xFFF59E0B);
      case 'attenzione':
      case 'critica':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _moodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'ottima':
        return Icons.verified_rounded;
      case 'stabile':
        return Icons.check_circle_rounded;
      case 'da controllare':
        return Icons.warning_amber_rounded;
      case 'attenzione':
      case 'critica':
        return Icons.error_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _mainInsight(Map<String, dynamic> data) {
    final smartInsights = _buildSmartInsights(data);

    if (smartInsights.isNotEmpty) {
      final first = smartInsights.first;

      return '${first.title}: ${first.message}';
    }

    final mood = (data['financial_mood'] ?? 'Da configurare').toString();
    final availableBudget = _amountFrom(data['available_budget']);
    final safetyBuffer = _amountFrom(data['safety_buffer']);
    final unpaidExpenses = _amountFrom(data['unpaid_expenses']);
    final monthlyIncome = _amountFrom(data['monthly_income']);

    if (monthlyIncome <= 0) {
      return 'Inserisci almeno un’entrata per permettere all’AI Planner di costruire un piano realistico per il mese.';
    }

    if (availableBudget < 0) {
      return 'Questo mese le uscite previste superano le entrate. Ti consiglio di bloccare le spese extra e controllare quelle non ancora pagate.';
    }

    if (availableBudget <= safetyBuffer) {
      return 'La situazione è delicata: hai ancora budget disponibile, ma sei vicino al margine di sicurezza.';
    }

    if (unpaidExpenses > 0) {
      return 'Hai ancora alcune spese da pagare. Prima di aggiungere nuovi acquisti, controlla bene le prossime scadenze.';
    }

    if (mood.toLowerCase() == 'ottima') {
      return 'Questo mese sei messo bene: puoi valutare di risparmiare qualcosa o alimentare un obiettivo.';
    }

    return 'La situazione è abbastanza stabile. Puoi continuare così, mantenendo un margine di sicurezza per eventuali imprevisti.';
  }

  List<_AIInsight> _buildSmartInsights(Map<String, dynamic> data) {
    final insights = <_AIInsight>[];

    final monthlyIncome = _amountFrom(data['monthly_income']);
    final paidExpenses = _amountFrom(data['paid_expenses']);
    final unpaidExpenses = _amountFrom(data['unpaid_expenses']);
    final plannedExpenses = _amountFrom(data['planned_expenses']);
    final totalExpenses = _amountFrom(data['total_expenses']);
    final availableBudget = _amountFrom(data['available_budget']);
    final safetyBuffer = _amountFrom(data['safety_buffer']);
    final spendableBudget = _amountFrom(data['spendable_budget']);
    final dailyAvailable = _amountFrom(data['daily_available']);
    final previousTotalExpenses = _amountFrom(data['previous_total_expenses']);

    final topCategoryName = (data['top_category_name'] ?? '').toString();
    final topCategoryAmount = _amountFrom(data['top_category_amount']);

    final categories = _listOfMaps(data['categories']);
    final activeGoals = _listOfMaps(data['active_goals']);
    final unpaidExpensesList = _listOfMaps(data['unpaid_expenses_list']);
    final upcomingExpenses = _listOfMaps(data['upcoming_expenses']);

    if (monthlyIncome <= 0) {
      insights.add(
        const _AIInsight(
          title: 'Configura le entrate',
          message:
              'Inserisci almeno un’entrata mensile per permettere all’AI Planner di darti consigli realistici su spese, risparmio e obiettivi.',
          type: 'info',
          icon: Icons.trending_up_rounded,
          priority: 100,
        ),
      );

      return insights;
    }

    final expenseRatio = totalExpenses / monthlyIncome;
    final unpaidRatio = unpaidExpenses / monthlyIncome;
    final spendableRatio = spendableBudget / monthlyIncome;

    if (totalExpenses > monthlyIncome) {
      insights.add(
        _AIInsight(
          title: 'Spese sopra le entrate',
          message:
              'Questo mese le uscite totali superano le entrate. Ti consiglio di evitare nuovi acquisti non necessari e controllare prima le spese obbligatorie già previste.',
          type: 'danger',
          icon: Icons.error_rounded,
          priority: 100,
        ),
      );
    } else if (expenseRatio >= 0.85) {
      insights.add(
        _AIInsight(
          title: 'Budget quasi esaurito',
          message:
              'Hai già impegnato circa ${(expenseRatio * 100).toStringAsFixed(0)}% delle entrate mensili. Meglio evitare nuove spese non necessarie fino a fine mese.',
          type: 'warning',
          icon: Icons.warning_amber_rounded,
          priority: 90,
        ),
      );
    } else if (expenseRatio >= 0.70) {
      insights.add(
        _AIInsight(
          title: 'Spese da controllare',
          message:
              'Le uscite stanno salendo: hai usato circa ${(expenseRatio * 100).toStringAsFixed(0)}% delle entrate. Le spese già sostenute servono per capire il mese, mentre i budget pianificati sono quelli che puoi eventualmente rivedere.',
          type: 'warning',
          icon: Icons.speed_rounded,
          priority: 75,
        ),
      );
    } else {
      insights.add(
        _AIInsight(
          title: 'Situazione gestibile',
          message:
              'Le spese sono sotto controllo rispetto alle entrate. Puoi continuare così mantenendo sempre un piccolo margine per gli imprevisti.',
          type: 'success',
          icon: Icons.check_circle_rounded,
          priority: 45,
        ),
      );
    }

    if (availableBudget < 0) {
      insights.add(
        _AIInsight(
          title: 'Margine negativo',
          message:
              'Il budget disponibile è negativo. Prima di nuovi acquisti, controlla le spese non pagate e valuta se qualche budget mensile pianificato può essere rivisto.',
          type: 'danger',
          icon: Icons.account_balance_wallet_rounded,
          priority: 98,
        ),
      );
    } else if (availableBudget <= safetyBuffer && safetyBuffer > 0) {
      insights.add(
        _AIInsight(
          title: 'Vicino al margine di sicurezza',
          message:
              'Hai ancora budget disponibile, ma sei vicino al margine di sicurezza. Meglio usare prudenza con acquisti non necessari.',
          type: 'warning',
          icon: Icons.shield_rounded,
          priority: 82,
        ),
      );
    }

    if (unpaidExpenses > 0) {
      if (unpaidRatio >= 0.30) {
        insights.add(
          _AIInsight(
            title: 'Troppe spese ancora da pagare',
            message:
                'Hai ancora ${_formatMoney(unpaidExpenses)} da pagare. Prima di pensare a nuovi acquisti, ti conviene sistemare queste scadenze.',
            type: 'warning',
            icon: Icons.schedule_rounded,
            priority: 88,
          ),
        );
      } else {
        insights.add(
          _AIInsight(
            title: 'Occhio alle prossime scadenze',
            message:
                'Ci sono ancora ${_formatMoney(unpaidExpenses)} di spese non pagate. Considerale nel budget prima di decidere quanto spendere.',
            type: 'info',
            icon: Icons.event_available_rounded,
            priority: 58,
          ),
        );
      }
    }

    if (spendableBudget > 0 && activeGoals.isNotEmpty) {
      final suggestedSaving = spendableBudget * 0.35;
      final safeSuggestedSaving = suggestedSaving.clamp(10.0, spendableBudget);

      if (safeSuggestedSaving >= 10) {
        final firstGoal = activeGoals.first;
        final goalTitle = (firstGoal['title'] ?? 'il tuo obiettivo').toString();

        insights.add(
          _AIInsight(
            title: 'Puoi alimentare un obiettivo',
            message:
                'Hai un margine spendibile positivo. Potresti mettere da parte circa ${_formatMoney(safeSuggestedSaving)} per “$goalTitle” senza usare tutto il budget libero.',
            type: 'success',
            icon: Icons.savings_rounded,
            priority: 72,
          ),
        );
      }
    }

    if (activeGoals.isNotEmpty) {
      final sortedGoals = [...activeGoals];

      sortedGoals.sort((a, b) {
        final aRemaining = _amountFrom(a['remaining_amount']);
        final bRemaining = _amountFrom(b['remaining_amount']);

        return aRemaining.compareTo(bRemaining);
      });

      final nearestGoal = sortedGoals.first;
      final title = (nearestGoal['title'] ?? 'Obiettivo').toString();
      final remainingAmount = _amountFrom(nearestGoal['remaining_amount']);
      final progress = _amountFrom(nearestGoal['progress']);

      if (remainingAmount > 0 && remainingAmount <= spendableBudget) {
        insights.add(
          _AIInsight(
            title: 'Obiettivo raggiungibile',
            message:
                'L’obiettivo “$title” è molto vicino: ti mancano ${_formatMoney(remainingAmount)} e il tuo margine attuale potrebbe coprirlo.',
            type: 'success',
            icon: Icons.flag_rounded,
            priority: 86,
          ),
        );
      } else if (progress >= 70 && remainingAmount > 0) {
        insights.add(
          _AIInsight(
            title: 'Obiettivo quasi completato',
            message:
                'Sei già al ${progress.toStringAsFixed(0)}% dell’obiettivo “$title”. Ti mancano ${_formatMoney(remainingAmount)}: continua così.',
            type: 'success',
            icon: Icons.emoji_events_rounded,
            priority: 68,
          ),
        );
      } else if (remainingAmount > 0 && spendableBudget <= 0) {
        insights.add(
          _AIInsight(
            title: 'Rallenta prima di risparmiare',
            message:
                'Hai obiettivi attivi, ma questo mese il margine spendibile è basso. Prima proteggi le spese essenziali, poi torna a risparmiare.',
            type: 'warning',
            icon: Icons.flag_circle_rounded,
            priority: 70,
          ),
        );
      }
    }

    if (topCategoryName.isNotEmpty && topCategoryAmount > 0) {
      final categoryRatio =
          totalExpenses > 0 ? topCategoryAmount / totalExpenses : 0;

      if (categoryRatio >= 0.35) {
        insights.add(
          _AIInsight(
            title: 'Categoria da osservare',
            message:
                'La categoria “$topCategoryName” pesa molto sulle uscite del mese. Non significa per forza che vada ridotta: potrebbe contenere spese necessarie o imprevisti. Se dentro questa categoria hai anche budget mensili modificabili, puoi valutare di rivederli con prudenza.',
            type: 'warning',
            icon: Icons.pie_chart_rounded,
            priority: 78,
          ),
        );
      }
    }

    if (previousTotalExpenses > 0) {
      final difference = totalExpenses - previousTotalExpenses;

      if (difference > 0) {
        final diffRatio = difference / previousTotalExpenses;

        if (diffRatio >= 0.20) {
          insights.add(
            _AIInsight(
              title: 'Spese in aumento',
              message:
                   'Questo mese hai registrato ${_formatMoney(difference)} in più rispetto al mese scorso. Controlla le categorie più alte per capire cosa è cambiato e, se possibile, rivedi solo i budget mensili modificabili.',
              type: 'warning',
              icon: Icons.trending_up_rounded,
              priority: 76,
            ),
          );
        }
      } else if (difference < 0) {
        insights.add(
          _AIInsight(
            title: 'Stai spendendo meno',
            message:
                'Ottimo: questo mese stai spendendo ${_formatMoney(difference.abs())} in meno rispetto al mese scorso. Potresti trasformare parte di questo risparmio in obiettivi.',
            type: 'success',
            icon: Icons.trending_down_rounded,
            priority: 55,
          ),
        );
      }
    }

    if (dailyAvailable > 0 && dailyAvailable < 10) {
      insights.add(
        _AIInsight(
          title: 'Budget giornaliero basso',
          message:
              'Il tuo margine giornaliero è di circa ${_formatMoney(dailyAvailable)}. Per arrivare tranquillo a fine mese, evita spese extra frequenti.',
          type: 'warning',
          icon: Icons.today_rounded,
          priority: 73,
        ),
      );
    } else if (dailyAvailable >= 20) {
      insights.add(
        _AIInsight(
          title: 'Buon margine giornaliero',
          message:
              'Hai circa ${_formatMoney(dailyAvailable)} al giorno disponibili. Puoi gestire il mese con serenità, senza dimenticare gli obiettivi.',
          type: 'success',
          icon: Icons.today_rounded,
          priority: 42,
        ),
      );
    }

    if (upcomingExpenses.length >= 3 || unpaidExpensesList.length >= 3) {
      insights.add(
        _AIInsight(
          title: 'Molte spese da monitorare',
          message:
              'Hai diverse spese in arrivo o ancora da pagare. Ti consiglio di controllarle prima di decidere nuovi acquisti.',
          type: 'info',
          icon: Icons.notifications_active_rounded,
          priority: 64,
        ),
      );
    }

    if (paidExpenses <= 0 && plannedExpenses <= 0 && unpaidExpenses <= 0) {
      insights.add(
        const _AIInsight(
          title: 'Aggiungi le prime spese',
          message:
               'Quando inserisci spese e budget, l’AI Planner può capire meglio il mese e suggerirti quali budget mensili potresti rivedere.',
          type: 'info',
          icon: Icons.receipt_long_rounded,
          priority: 60,
        ),
      );
    }

    insights.sort((a, b) => b.priority.compareTo(a.priority));

    final unique = <String>{};
    final filtered = <_AIInsight>[];

    for (final insight in insights) {
      final key = '${insight.title}-${insight.message}';

      if (unique.contains(key)) continue;

      unique.add(key);
      filtered.add(insight);
    }

    return filtered.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffold,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _plannerFuture,
        builder: (context, snapshot) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: colors.primary,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _AIPlannerError(
                  onRetry: _refreshPlanner,
                );
              }

              final data = snapshot.data ?? {};

              final monthlyIncome = _amountFrom(data['monthly_income']);
              final paidExpenses = _amountFrom(data['paid_expenses']);
              final unpaidExpenses = _amountFrom(data['unpaid_expenses']);
              final plannedExpenses = _amountFrom(data['planned_expenses']);
              final totalExpenses = _amountFrom(data['total_expenses']);
              final availableBudget = _amountFrom(data['available_budget']);
              final safetyBuffer = _amountFrom(data['safety_buffer']);
              final spendableBudget = _amountFrom(data['spendable_budget']);
              final dailyAvailable = _amountFrom(data['daily_available']);
              final score = _intFrom(data['financial_health_score']);
              final mood = (data['financial_mood'] ?? 'Da configurare').toString();
              final topCategoryName = (data['top_category_name'] ?? '').toString();
              final topCategoryAmount = _amountFrom(data['top_category_amount']);

              final previousTotalExpenses = _amountFrom(
                data['previous_total_expenses'],
              );

              final suggestions = (data['suggestions'] is List)
                  ? List<String>.from(
                      (data['suggestions'] as List).map(
                        (item) => item.toString(),
                      ),
                    )
                  : <String>[];

              final smartInsights = _buildSmartInsights(data);
              final categories = _listOfMaps(data['categories']);
              final activeGoals = _listOfMaps(data['active_goals']);
              final unpaidExpensesList = _listOfMaps(data['unpaid_expenses_list']);
              final upcomingExpenses = _listOfMaps(data['upcoming_expenses']);

              final aiProfile = data['ai_profile'] is Map
                  ? Map<String, dynamic>.from(data['ai_profile'])
                  : (_cachedAiProfile ?? <String, dynamic>{});

              final aiLearningProfile = data['ai_learning_profile'] is Map
                  ? Map<String, dynamic>.from(data['ai_learning_profile'])
                  : <String, dynamic>{};

              final aiPersonalContext =
                  (data['ai_personal_context'] ?? '').toString();

              return RefreshIndicator(
                color: colors.primary,
                backgroundColor: colors.card,
                onRefresh: _refreshPlanner,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
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
                          _AIPlannerHeader(
                            mood: mood,
                            moodColor: _moodColor(mood),
                            moodIcon: _moodIcon(mood),
                            score: score,
                            insight: _mainInsight(data),
                            availableBudget: _currencyFormatter.format(
                              availableBudget,
                            ),
                            spendableBudget: _currencyFormatter.format(
                              spendableBudget,
                            ),
                            safetyBuffer: _currencyFormatter.format(
                              safetyBuffer,
                            ),
                            onRefresh: _refreshPlanner,
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _SummaryGrid(
                            isMobile: isMobile,
                            items: [
                              _SummaryItem(
                                label: 'Entrate mese',
                                value: _currencyFormatter.format(monthlyIncome),
                                icon: Icons.trending_up_rounded,
                                color: const Color(0xFF16A34A),
                              ),
                              _SummaryItem(
                                label: 'Spese totali',
                                value: _currencyFormatter.format(totalExpenses),
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFFDC2626),
                              ),
                              _SummaryItem(
                                label: 'Disponibile',
                                value: _currencyFormatter.format(
                                  availableBudget,
                                ),
                                icon: Icons.account_balance_wallet_rounded,
                                color: const Color(0xFF1677F2),
                              ),
                              _SummaryItem(
                                label: 'Al giorno',
                                value: _currencyFormatter.format(
                                  dailyAvailable,
                                ),
                                icon: Icons.today_rounded,
                                color: const Color(0xFF7C3AED),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _AIInboxCard(
                            stream: _aiInsightsStream(),
                            dateFrom: _aiInsightDate,
                            onInsightVisibleInChat: _startChatFromInsight,
                            onArchiveInsight: _archiveAiInsight,
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _AIPersonalProfileCard(
                            aiProfile: aiProfile,
                            aiLearningProfile: aiLearningProfile,
                            aiPersonalContext: aiPersonalContext,
                            mainGoalLabel: _mainGoalLabel(aiProfile),
                            moneyFeelingLabel: _moneyFeelingLabel(aiProfile),
                            adviceStyleLabel: _adviceStyleLabel(aiProfile),
                            aiFrequencyLabel: _aiFrequencyLabel(aiProfile),
                            interestLabels: _interestLabels(aiProfile),
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          if (isMobile)
                            Column(
                              children: [
                                _AIAdviceCard(
                                  suggestions: suggestions,
                                  smartInsights: smartInsights,
                                  topCategoryName: topCategoryName,
                                  topCategoryAmount: _currencyFormatter.format(
                                    topCategoryAmount,
                                  ),
                                  previousTotalExpenses: previousTotalExpenses,
                                  totalExpenses: totalExpenses,
                                  formatMoney: _currencyFormatter.format,
                                ),
                                const SizedBox(height: 16),
                                _AIChatCard(
                                  messages: _messages,
                                  controller: _questionController,
                                  scrollController: _chatScrollController,
                                  isAsking: _isAsking,
                                  onSend: _askQuestion,
                                  onQuickQuestion: _askQuickQuestion,
                                  onNewChat: _startNewChat,
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _AIAdviceCard(
                                    suggestions: suggestions,
                                    smartInsights: smartInsights,
                                    topCategoryName: topCategoryName,
                                    topCategoryAmount:
                                        _currencyFormatter.format(
                                      topCategoryAmount,
                                    ),
                                    previousTotalExpenses:
                                        previousTotalExpenses,
                                    totalExpenses: totalExpenses,
                                    formatMoney: _currencyFormatter.format,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 5,
                                  child: _AIChatCard(
                                    messages: _messages,
                                    controller: _questionController,
                                    scrollController: _chatScrollController,
                                    isAsking: _isAsking,
                                    onSend: _askQuestion,
                                    onQuickQuestion: _askQuickQuestion,
                                    onNewChat: _startNewChat,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _BudgetBreakdownCard(
                            paidExpenses: _currencyFormatter.format(
                              paidExpenses,
                            ),
                            unpaidExpenses: _currencyFormatter.format(
                              unpaidExpenses,
                            ),
                            plannedExpenses: _currencyFormatter.format(
                              plannedExpenses,
                            ),
                            totalExpenses: _currencyFormatter.format(
                              totalExpenses,
                            ),
                            availableBudget: _currencyFormatter.format(
                              availableBudget,
                            ),
                            safetyBuffer: _currencyFormatter.format(
                              safetyBuffer,
                            ),
                            spendableBudget: _currencyFormatter.format(
                              spendableBudget,
                            ),
                            availableRaw: availableBudget,
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          if (isMobile)
                            Column(
                              children: [
                                _CategoriesCard(
                                  categories: categories,
                                  formatMoney: _formatMoney,
                                ),
                                const SizedBox(height: 16),
                                _GoalsPlannerCard(
                                  goals: activeGoals,
                                  formatMoney: _formatMoney,
                                  dateFrom: _dateFrom,
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _CategoriesCard(
                                    categories: categories,
                                    formatMoney: _formatMoney,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _GoalsPlannerCard(
                                    goals: activeGoals,
                                    formatMoney: _formatMoney,
                                    dateFrom: _dateFrom,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: isMobile ? 16 : 22),
                          _UpcomingCard(
                            unpaidExpenses: unpaidExpensesList,
                            upcomingExpenses: upcomingExpenses,
                            formatMoney: _formatMoney,
                            dateFrom: _dateFrom,
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
      ),
    );
  }
}

class _AIPlannerColors {
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
  final Color headerBackground;
  final Color headerSoft;
  final Color headerBorder;
  final Color headerText;
  final Color headerMuted;
  final Color shadow;

  const _AIPlannerColors({
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
    required this.headerBackground,
    required this.headerSoft,
    required this.headerBorder,
    required this.headerText,
    required this.headerMuted,
    required this.shadow,
  });

  factory _AIPlannerColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return const _AIPlannerColors(
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
        headerBackground: Color(0xFF020617),
        headerSoft: Color(0xFF111827),
        headerBorder: Color(0xFF334155),
        headerText: Colors.white,
        headerMuted: Color(0xFFCBD5E1),
        shadow: Colors.black,
      );
    }

    return const _AIPlannerColors(
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
      headerBackground: Color(0xFF172033),
      headerSoft: Color(0x14FFFFFF),
      headerBorder: Color(0x1FFFFFFF),
      headerText: Colors.white,
      headerMuted: Color(0xFFD7DEE9),
      shadow: Colors.black,
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final colors = _AIPlannerColors.of(context);

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

class _AIMessage {
  final String text;
  final bool isUser;

  const _AIMessage({
    required this.text,
    required this.isUser,
  });
}

class _AIInsight {
  final String title;
  final String message;
  final String type;
  final IconData icon;
  final int priority;

  const _AIInsight({
    required this.title,
    required this.message,
    required this.type,
    required this.icon,
    required this.priority,
  });
}

class _AIPlannerHeader extends StatelessWidget {
  final String mood;
  final Color moodColor;
  final IconData moodIcon;
  final int score;
  final String insight;
  final String availableBudget;
  final String spendableBudget;
  final String safetyBuffer;
  final Future<void> Function() onRefresh;

  const _AIPlannerHeader({
    required this.mood,
    required this.moodColor,
    required this.moodIcon,
    required this.score,
    required this.insight,
    required this.availableBudget,
    required this.spendableBudget,
    required this.safetyBuffer,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 22 : 28),
      decoration: BoxDecoration(
        color: colors.headerBackground,
        borderRadius: BorderRadius.circular(isMobile ? 26 : 30),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: colors.isDark ? 0.24 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderText(
                  mood: mood,
                  moodColor: moodColor,
                  moodIcon: moodIcon,
                  insight: insight,
                  isMobile: true,
                ),
                const SizedBox(height: 18),
                _HeaderStats(
                  score: score,
                  availableBudget: availableBudget,
                  spendableBudget: spendableBudget,
                  safetyBuffer: safetyBuffer,
                  isMobile: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Aggiorna analisi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.isDark
                          ? colors.primary
                          : Colors.white,
                      foregroundColor: colors.isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF172033),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HeaderText(
                    mood: mood,
                    moodColor: moodColor,
                    moodIcon: moodIcon,
                    insight: insight,
                    isMobile: false,
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _HeaderStats(
                      score: score,
                      availableBudget: availableBudget,
                      spendableBudget: spendableBudget,
                      safetyBuffer: safetyBuffer,
                      isMobile: false,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Aggiorna analisi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.isDark
                              ? colors.primary
                              : Colors.white,
                          foregroundColor: colors.isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF172033),
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
                  ],
                ),
              ],
            ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String mood;
  final Color moodColor;
  final IconData moodIcon;
  final String insight;
  final bool isMobile;

  const _HeaderText({
    required this.mood,
    required this.moodColor,
    required this.moodIcon,
    required this.insight,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'AI Planner',
              style: TextStyle(
                color: colors.headerText,
                fontSize: isMobile ? 28 : 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: moodColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: moodColor.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    moodIcon,
                    color: moodColor,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mood,
                    style: TextStyle(
                      color: moodColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Il tuo assistente personale per capire cosa puoi spendere, quanto puoi risparmiare e come arrivare meglio a fine mese.',
          style: TextStyle(
            color: colors.headerMuted,
            fontSize: isMobile ? 15 : 16,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.headerSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.headerBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight,
                  style: TextStyle(
                    color: colors.headerText,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderStats extends StatelessWidget {
  final int score;
  final String availableBudget;
  final String spendableBudget;
  final String safetyBuffer;
  final bool isMobile;

  const _HeaderStats({
    required this.score,
    required this.availableBudget,
    required this.spendableBudget,
    required this.safetyBuffer,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HeaderMiniStat(
        label: 'Score AI',
        value: '$score/100',
      ),
      _HeaderMiniStat(
        label: 'Disponibile',
        value: availableBudget,
      ),
      _HeaderMiniStat(
        label: 'Spendibile',
        value: spendableBudget,
      ),
      _HeaderMiniStat(
        label: 'Sicurezza',
        value: safetyBuffer,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: stats[0]),
              const SizedBox(width: 10),
              Expanded(child: stats[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: stats[2]),
              const SizedBox(width: 10),
              Expanded(child: stats[3]),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.end,
      children: stats,
    );
  }
}

class _HeaderMiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: isMobile ? double.infinity : 150,
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: colors.headerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.headerBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.headerMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.headerText,
              fontSize: isMobile ? 18 : 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<_SummaryItem> items;
  final bool isMobile;

  const _SummaryGrid({
    required this.items,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: items[0]),
              const SizedBox(width: 12),
              Expanded(child: items[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: items[2]),
              const SizedBox(width: 12),
              Expanded(child: items[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: items
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item == items.last ? 0 : 14,
                ),
                child: item,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: colors.isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: isMobile ? 18 : 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AIPersonalProfileCard extends StatelessWidget {
  final Map<String, dynamic> aiProfile;
  final Map<String, dynamic> aiLearningProfile;
  final String aiPersonalContext;
  final String mainGoalLabel;
  final String moneyFeelingLabel;
  final String adviceStyleLabel;
  final String aiFrequencyLabel;
  final List<String> interestLabels;

  const _AIPersonalProfileCard({
    required this.aiProfile,
    required this.aiLearningProfile,
    required this.aiPersonalContext,
    required this.mainGoalLabel,
    required this.moneyFeelingLabel,
    required this.adviceStyleLabel,
    required this.aiFrequencyLabel,
    required this.interestLabels,
  });

  bool get _hasDeclaredProfile {
    return mainGoalLabel.isNotEmpty ||
        moneyFeelingLabel.isNotEmpty ||
        adviceStyleLabel.isNotEmpty ||
        aiFrequencyLabel.isNotEmpty ||
        interestLabels.isNotEmpty;
  }

  bool get _hasLearningProfile {
    return aiLearningProfile.isNotEmpty ||
        aiPersonalContext.trim().isNotEmpty;
  }

  String _learningText() {
    final items = <String>[];

    final preferredGoalFocus =
        (aiLearningProfile['preferred_goal_focus'] ?? '').toString().trim();

    final spendingPattern =
        (aiLearningProfile['spending_pattern'] ?? '').toString().trim();

    final budgetSensitivity =
        (aiLearningProfile['budget_sensitivity'] ?? '').toString().trim();

    final strongestGoalCategory =
        (aiLearningProfile['strongest_goal_category'] ?? '').toString().trim();

    if (preferredGoalFocus.isNotEmpty) {
      items.add('Focus osservato: $preferredGoalFocus');
    }

    if (spendingPattern.isNotEmpty) {
      items.add('Pattern spese: $spendingPattern');
    }

    if (budgetSensitivity.isNotEmpty) {
      items.add('Sensibilità budget: $budgetSensitivity');
    }

    if (strongestGoalCategory.isNotEmpty) {
      items.add('Categoria da monitorare: $strongestGoalCategory');
    }

    if (aiLearningProfile['often_asks_before_spending'] == true) {
      items.add('Ti piace verificare prima di spendere');
    }

    if (aiLearningProfile['often_asks_about_saving'] == true) {
      items.add('Chiedi spesso consigli sul risparmio');
    }

    if (aiLearningProfile['often_asks_about_goals'] == true) {
      items.add('Ti interessano molto gli obiettivi');
    }

    if (items.isEmpty) {
      return 'Più userai la chat AI, più PocketPlan capirà come aiutarti meglio.';
    }

    return items.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    if (!_hasDeclaredProfile && !_hasLearningProfile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(context),
        child: const _SectionTitle(
          title: 'PocketPlan sta imparando a conoscerti',
          subtitle:
              'Rispondi alle domande iniziali e usa la chat AI: così i consigli diventeranno sempre più personali.',
          icon: Icons.psychology_rounded,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'PocketPlan ti conosce così',
            subtitle:
                'Queste informazioni aiutano l’AI a darti consigli più personali e meno generici.',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (mainGoalLabel.isNotEmpty)
                _ProfileBadge(
                  icon: Icons.flag_rounded,
                  label: 'Obiettivo',
                  value: mainGoalLabel,
                  color: colors.primary,
                ),
              if (interestLabels.isNotEmpty)
                _ProfileBadge(
                  icon: Icons.favorite_rounded,
                  label: 'Interessi',
                  value: interestLabels.join(', '),
                  color: const Color(0xFF7C3AED),
                ),
              if (moneyFeelingLabel.isNotEmpty)
                _ProfileBadge(
                  icon: Icons.psychology_alt_rounded,
                  label: 'Rapporto soldi',
                  value: moneyFeelingLabel,
                  color: const Color(0xFFF59E0B),
                ),
              if (adviceStyleLabel.isNotEmpty)
                _ProfileBadge(
                  icon: Icons.tune_rounded,
                  label: 'Stile AI',
                  value: adviceStyleLabel,
                  color: const Color(0xFF16A34A),
                ),
              if (aiFrequencyLabel.isNotEmpty)
                _ProfileBadge(
                  icon: Icons.notifications_active_rounded,
                  label: 'Frequenza',
                  value: aiFrequencyLabel,
                  color: const Color(0xFF0F766E),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.cardSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school_rounded,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _learningText(),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
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

class _ProfileBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      constraints: BoxConstraints(
        minWidth: isMobile ? double.infinity : 220,
        maxWidth: isMobile ? double.infinity : 340,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: colors.isDark ? 0.24 : 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: colors.isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
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

class _AIAdviceCard extends StatelessWidget {
  final List<String> suggestions;
  final List<_AIInsight> smartInsights;
  final String topCategoryName;
  final String topCategoryAmount;
  final double previousTotalExpenses;
  final double totalExpenses;
  final String Function(double) formatMoney;

  const _AIAdviceCard({
    required this.suggestions,
    required this.smartInsights,
    required this.topCategoryName,
    required this.topCategoryAmount,
    required this.previousTotalExpenses,
    required this.totalExpenses,
    required this.formatMoney,
  });

  String _comparisonText() {
    if (previousTotalExpenses <= 0) {
      return 'Quando avrai dati del mese precedente, qui vedrai anche il confronto automatico.';
    }

    if (totalExpenses > previousTotalExpenses) {
      return 'Questo mese stai spendendo ${formatMoney(totalExpenses - previousTotalExpenses)} in più rispetto al mese scorso.';
    }

    if (totalExpenses < previousTotalExpenses) {
      return 'Questo mese stai spendendo ${formatMoney(previousTotalExpenses - totalExpenses)} in meno rispetto al mese scorso.';
    }

    return 'Questo mese stai spendendo più o meno come il mese scorso.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final visibleSuggestions = suggestions.isEmpty
        ? [
            'Aggiungi entrate, spese e obiettivi per ricevere consigli più precisi.',
          ]
        : suggestions;

    final visibleInsights = smartInsights;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Consigli AI',
            subtitle: 'Analisi automatica basata sui tuoi dati del mese.',
            icon: Icons.psychology_alt_rounded,
          ),
          const SizedBox(height: 18),
          if (visibleInsights.isNotEmpty) ...[
            ...visibleInsights.take(4).map(
                  (insight) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InsightRow(
                      insight: insight,
                    ),
                  ),
                ),
          ] else ...[
            ...visibleSuggestions.take(4).map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AdviceRow(
                      text: suggestion,
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.cardSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confronto rapido',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _comparisonText(),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (topCategoryName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InfoBadge(
                    text:
                        'Categoria più alta: $topCategoryName · $topCategoryAmount',
                    icon: Icons.pie_chart_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdviceRow extends StatelessWidget {
  final String text;

  const _AdviceRow({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final _AIInsight insight;

  const _InsightRow({
    required this.insight,
  });

  Color _colorForType(BuildContext context) {
    switch (insight.type) {
      case 'danger':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'success':
        return const Color(0xFF16A34A);
      case 'info':
      default:
        return _AIPlannerColors.of(context).primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final color = _colorForType(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: colors.isDark ? 0.24 : 0.14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: colors.isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              insight.icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight.message,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
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

class _AIChatCard extends StatelessWidget {
  final List<_AIMessage> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isAsking;
  final VoidCallback onSend;
  final Future<void> Function(String question) onQuickQuestion;
  final VoidCallback onNewChat;

  const _AIChatCard({
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.isAsking,
    required this.onSend,
    required this.onQuickQuestion,
    required this.onNewChat,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'Parla con PocketPlan',
                  subtitle:
                      'Fai domande in base alla tua situazione finanziaria.',
                  icon: Icons.chat_bubble_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: onNewChat,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_comment_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Nuova chat',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickQuestionChip(
                label: 'Posso spendere 100€?',
                onTap: () => onQuickQuestion('Posso spendere 100 euro?'),
              ),
              _QuickQuestionChip(
                label: 'Quanto posso risparmiare?',
                onTap: () =>
                    onQuickQuestion('Quanto posso risparmiare questo mese?'),
              ),
              _QuickQuestionChip(
                label: 'Quali budget controllo?',
                onTap: () =>
                    onQuickQuestion('Quali budget posso controllare questo mese?'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: isMobile ? 330 : 390,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.cardSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.border,
              ),
            ),
            child: ListView.builder(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: messages.length + (isAsking ? 1 : 0),
              itemBuilder: (context, index) {
                if (isAsking && index == messages.length) {
                  return const _TypingBubble();
                }

                final message = messages[index];

                return _ChatBubble(
                  message: message,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Chiedi qualcosa al tuo AI Planner...',
                    hintStyle: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: colors.cardSoft,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: colors.border,
                      ),
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
                        width: 1.5,
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
                  onPressed: isAsking ? null : onSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor:
                        colors.isDark ? const Color(0xFF0F172A) : Colors.white,
                    disabledBackgroundColor: colors.border,
                    disabledForegroundColor: colors.textMuted,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isAsking
                      ? SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickQuestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickQuestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Material(
      color: colors.primarySoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _AIMessage message;

  const _ChatBubble({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isUser ? colors.primary : colors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: colors.border,
                ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? colors.isDark
                    ? const Color(0xFF0F172A)
                    : Colors.white
                : colors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: colors.border,
          ),
        ),
        child: Text(
          'Sto analizzando i tuoi dati...',
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _BudgetBreakdownCard extends StatelessWidget {
  final String paidExpenses;
  final String unpaidExpenses;
  final String plannedExpenses;
  final String totalExpenses;
  final String availableBudget;
  final String safetyBuffer;
  final String spendableBudget;
  final double availableRaw;

  const _BudgetBreakdownCard({
    required this.paidExpenses,
    required this.unpaidExpenses,
    required this.plannedExpenses,
    required this.totalExpenses,
    required this.availableBudget,
    required this.safetyBuffer,
    required this.spendableBudget,
    required this.availableRaw,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = availableRaw >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Piano del mese',
            subtitle: 'Come sono distribuiti entrate, spese e margine.',
            icon: Icons.account_tree_rounded,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _BreakdownTile(
                label: 'Spese pagate',
                value: paidExpenses,
                color: const Color(0xFF64748B),
                icon: Icons.check_circle_rounded,
              ),
              _BreakdownTile(
                label: 'Da pagare',
                value: unpaidExpenses,
                color: const Color(0xFFF59E0B),
                icon: Icons.schedule_rounded,
              ),
              _BreakdownTile(
                label: 'Pianificate',
                value: plannedExpenses,
                color: const Color(0xFF7C3AED),
                icon: Icons.event_note_rounded,
              ),
              _BreakdownTile(
                label: 'Totale uscite',
                value: totalExpenses,
                color: const Color(0xFFDC2626),
                icon: Icons.receipt_long_rounded,
              ),
              _BreakdownTile(
                label: 'Disponibile',
                value: availableBudget,
                color: isPositive
                    ? const Color(0xFF1677F2)
                    : const Color(0xFFDC2626),
                icon: Icons.account_balance_wallet_rounded,
              ),
              _BreakdownTile(
                label: 'Margine sicurezza',
                value: safetyBuffer,
                color: const Color(0xFF0F766E),
                icon: Icons.shield_rounded,
              ),
              _BreakdownTile(
                label: 'Spendibile AI',
                value: spendableBudget,
                color: const Color(0xFF16A34A),
                icon: Icons.savings_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _BreakdownTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 800;

    return Container(
      width: isMobile ? double.infinity : 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: colors.isDark ? 0.22 : 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: colors.isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
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

class _CategoriesCard extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String Function(dynamic value) formatMoney;

  const _CategoriesCard({
    required this.categories,
    required this.formatMoney,
  });

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Categorie principali',
            subtitle: 'Analisi delle uscite del mese, senza giudicare le singole spese.',
            icon: Icons.pie_chart_rounded,
          ),
          const SizedBox(height: 18),
          if (visibleCategories.isEmpty)
            const _EmptyMiniState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Nessuna categoria',
              text:
                  'Quando aggiungi spese, qui vedrai le categorie principali.',
            )
          else
            Column(
              children: visibleCategories.map((category) {
                final name = (category['name'] ?? 'Altro').toString();
                final amount = _amountFrom(category['amount']);
                final percentage = _amountFrom(category['percentage']);

                return _CategoryRow(
                  name: name,
                  amount: formatMoney(amount),
                  percentage: percentage,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final String amount;
  final double percentage;

  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: progress,
              backgroundColor: colors.border,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${percentage.toStringAsFixed(0)}% delle uscite',
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsPlannerCard extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final String Function(dynamic value) formatMoney;
  final DateTime? Function(dynamic value) dateFrom;

  const _GoalsPlannerCard({
    required this.goals,
    required this.formatMoney,
    required this.dateFrom,
  });

  double _amountFrom(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final visibleGoals = goals.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Obiettivi da seguire',
            subtitle: 'Gli obiettivi attivi più importanti per l’AI Planner.',
            icon: Icons.flag_rounded,
          ),
          const SizedBox(height: 18),
          if (visibleGoals.isEmpty)
            const _EmptyMiniState(
              icon: Icons.flag_outlined,
              title: 'Nessun obiettivo attivo',
              text:
                  'Crea un obiettivo per ricevere consigli di risparmio più precisi.',
            )
          else
            Column(
              children: visibleGoals.map((goal) {
                final title = (goal['title'] ?? 'Obiettivo').toString();
                final currentAmount = _amountFrom(goal['current_amount']);
                final targetAmount = _amountFrom(goal['target_amount']);
                final remainingAmount = _amountFrom(goal['remaining_amount']);
                final progress = _amountFrom(goal['progress']);
                final daysRemaining = goal['days_remaining'];

                return _GoalPlannerRow(
                  title: title,
                  currentAmount: formatMoney(currentAmount),
                  targetAmount: formatMoney(targetAmount),
                  remainingAmount: formatMoney(remainingAmount),
                  progress: progress,
                  daysRemaining: daysRemaining is int ? daysRemaining : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _GoalPlannerRow extends StatelessWidget {
  final String title;
  final String currentAmount;
  final String targetAmount;
  final String remainingAmount;
  final double progress;
  final int? daysRemaining;

  const _GoalPlannerRow({
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.remainingAmount,
    required this.progress,
    required this.daysRemaining,
  });

  String _daysLabel() {
    if (daysRemaining == null) return 'Senza scadenza';
    if (daysRemaining! < 0) return 'Scaduto';
    if (daysRemaining == 0) return 'Scade oggi';
    if (daysRemaining == 1) return 'Scade domani';

    return '$daysRemaining gg rimasti';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final value = (progress / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_rounded,
                color: colors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ColoredBadge(
                text: _daysLabel(),
                color: colors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: value,
              backgroundColor: colors.border,
              color: const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoBadge(
                text: 'Risparmiato: $currentAmount',
                icon: Icons.savings_rounded,
              ),
              _InfoBadge(
                text: 'Target: $targetAmount',
                icon: Icons.flag_rounded,
              ),
              _InfoBadge(
                text: 'Mancano: $remainingAmount',
                icon: Icons.timelapse_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final List<Map<String, dynamic>> unpaidExpenses;
  final List<Map<String, dynamic>> upcomingExpenses;
  final String Function(dynamic value) formatMoney;
  final DateTime? Function(dynamic value) dateFrom;

  const _UpcomingCard({
    required this.unpaidExpenses,
    required this.upcomingExpenses,
    required this.formatMoney,
    required this.dateFrom,
  });

  @override
  Widget build(BuildContext context) {
    final items = unpaidExpenses.isNotEmpty ? unpaidExpenses : upcomingExpenses;
    final title =
        unpaidExpenses.isNotEmpty ? 'Spese ancora da pagare' : 'Prossime spese';
    final subtitle = unpaidExpenses.isNotEmpty
        ? 'Controlla queste voci prima di fare nuove spese.'
        : 'Le prossime uscite previste dal tuo piano.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: title,
            subtitle: subtitle,
            icon: Icons.event_available_rounded,
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            const _EmptyMiniState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Nessuna scadenza critica',
              text:
                  'Non risultano spese imminenti o non pagate per questo mese.',
            )
          else
            Column(
              children: items.take(6).map((item) {
                final title = (item['title'] ?? 'Spesa').toString();
                final category = (item['category'] ?? 'Altro').toString();
                final amount = formatMoney(item['amount']);
                final date = dateFrom(item['due_date'] ?? item['date']);

                return _UpcomingExpenseRow(
                  title: title,
                  category: category,
                  amount: amount,
                  date: date,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _UpcomingExpenseRow extends StatelessWidget {
  final String title;
  final String category;
  final String amount;
  final DateTime? date;

  const _UpcomingExpenseRow({
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final formattedDate = date == null
        ? 'Data non indicata'
        : DateFormat('dd/MM/yyyy', 'it_IT').format(date!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.isDark
                  ? const Color(0xFF451A03)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$category · $formattedDate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoBadge({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
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
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColoredBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _ColoredBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colors.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyMiniState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyMiniState({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.cardSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: colors.textMuted,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AIInboxCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final DateTime? Function(dynamic value) dateFrom;
  final void Function({
    required String id,
    required String title,
    required String message,
  }) onInsightVisibleInChat;
  final Future<void> Function(String insightId) onArchiveInsight;

  const _AIInboxCard({
    required this.stream,
    required this.dateFrom,
    required this.onInsightVisibleInChat,
    required this.onArchiveInsight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final data = doc.data();

            return data['is_archived'] != true;
          }).take(8).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Messaggi AI recenti',
                subtitle:
                    'Qui trovi gli avvisi automatici che PocketPlan genera quando nota qualcosa di importante.',
                icon: Icons.mark_chat_unread_rounded,
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colors.primary,
                    ),
                  ),
                )
              else if (docs.isEmpty)
                const _EmptyMiniState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Nessun messaggio AI',
                  text:
                     'Quando l’AI noterà budget quasi finiti, uscite importanti o possibilità di rivedere budget mensili, vedrai qui i suoi messaggi.',
                )
              else
                Column(
                  children: docs.map((doc) {
                    final data = doc.data();

                    return _AIInboxRow(
                      id: doc.id,
                      title: (data['title'] ?? 'Messaggio AI').toString(),
                      message: (data['message'] ?? '').toString(),
                      type: (data['type'] ?? 'info').toString(),
                      isRead: data['is_read'] == true,
                      date: dateFrom(data['created_at']),
                      onAskAi: () {
                        onInsightVisibleInChat(
                          id: doc.id,
                          title: (data['title'] ?? 'Messaggio AI').toString(),
                          message: (data['message'] ?? '').toString(),
                        );
                      },
                      onArchive: () => onArchiveInsight(doc.id),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AIInboxRow extends StatelessWidget {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? date;
  final VoidCallback onAskAi;
  final VoidCallback onArchive;

  const _AIInboxRow({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.date,
    required this.onAskAi,
    required this.onArchive,
  });

  Color _colorForType(BuildContext context) {
    switch (type) {
      case 'danger':
        return const Color(0xFFDC2626);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'success':
        return const Color(0xFF16A34A);
      case 'info':
      default:
        return _AIPlannerColors.of(context).primary;
    }
  }

  IconData _iconForType() {
    switch (type) {
      case 'danger':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'info':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  String _dateLabel() {
    if (date == null) return 'Ora';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date!.year, date!.month, date!.day);

    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Ieri';
    if (diff < 7) return '$diff giorni fa';

    return DateFormat('dd/MM/yyyy', 'it_IT').format(date!);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);
    final color = _colorForType(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead
            ? colors.cardSoft
            : color.withValues(alpha: colors.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRead
              ? colors.border
              : color.withValues(alpha: colors.isDark ? 0.28 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: colors.isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _iconForType(),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Nuovo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoBadge(
                      text: _dateLabel(),
                      icon: Icons.schedule_rounded,
                    ),
                    _InboxActionButton(
                      label: 'Parla con l’AI',
                      icon: Icons.chat_bubble_rounded,
                      color: color,
                      onTap: onAskAi,
                    ),
                    _InboxActionButton(
                      label: 'Ho capito',
                      icon: Icons.check_rounded,
                      color: const Color(0xFF16A34A),
                      onTap: onArchive,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InboxActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Material(
      color: color.withValues(alpha: colors.isDark ? 0.18 : 0.10),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
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

class _AIPlannerError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _AIPlannerError({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AIPlannerColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: _cardDecoration(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                'Analisi non disponibile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Non sono riuscito a leggere i dati finanziari. Riprova tra poco oppure controlla entrate, spese e obiettivi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Riprova'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor:
                        colors.isDark ? const Color(0xFF0F172A) : Colors.white,
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
            ],
          ),
        ),
      ),
    );
  }
}