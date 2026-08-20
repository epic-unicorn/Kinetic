import '../models/enums.dart';

/// Calendar prompts that fire in a given month without needing last-year
/// history. [skipIfTitleContains] suppresses the prompt when an open task
/// already covers the same theme.
class CalendarPrompt {
  final List<int> months;
  final String title;
  final List<String> skipIfTitleContains;
  final String explanation;

  const CalendarPrompt({
    required this.months,
    required this.title,
    required this.skipIfTitleContains,
    required this.explanation,
  });
}

/// Generic partner hint. Never includes the source task title or notes.
class PartnerHintTemplate {
  final String familyId;
  final List<String> keywords;
  final Set<TaskCategory> categories;
  final String partnerTitle;
  final String explanation;

  const PartnerHintTemplate({
    required this.familyId,
    required this.keywords,
    required this.categories,
    required this.partnerTitle,
    required this.explanation,
  });
}

const calendarPrompts = <CalendarPrompt>[
  CalendarPrompt(
    months: [3],
    title: 'Check tax return',
    skipIfTitleContains: ['belasting', 'aangifte', 'tax', 'return'],
    explanation: 'March — time to check the tax return.',
  ),
  CalendarPrompt(
    months: [8],
    title: 'Prepare school supplies',
    skipIfTitleContains: ['schoolspul', 'schooltas', 'etui', 'school supplies'],
    explanation: 'August — prepare school supplies for the new year.',
  ),
  CalendarPrompt(
    months: [12],
    title: 'Prepare for Christmas',
    skipIfTitleContains: ['kerst', 'cadeau', 'christmas', 'gift'],
    explanation: 'December — prepare for Christmas.',
  ),
];

const partnerHintTemplates = <PartnerHintTemplate>[
  PartnerHintTemplate(
    familyId: 'school',
    keywords: [
      'school',
      'huiswerk',
      'juf',
      'meester',
      'opvang',
      'gymspullen',
      'schooltas',
      'ouderavond',
      'homework',
    ],
    categories: {TaskCategory.school},
    partnerTitle: 'School run or childcare this week?',
    explanation:
        'Based on your tasks (without private details), school looks like a '
        'theme this week. Your partner sees this.',
  ),
  PartnerHintTemplate(
    familyId: 'household',
    keywords: [
      'boodschappen',
      'wasgoed',
      'stofzuigen',
      'afwas',
      'schoonmaak',
      'opruimen',
      'groceries',
      'laundry',
    ],
    categories: {TaskCategory.household},
    partnerTitle: 'Can you pick up something around the house this week?',
    explanation:
        'You have several household tasks open. The suggestion is intentionally generic.',
  ),
  PartnerHintTemplate(
    familyId: 'health',
    keywords: [
      'dokter',
      'huisarts',
      'tandarts',
      'medicijn',
      'apotheek',
      'fysio',
      'doctor',
      'dentist',
    ],
    categories: {TaskCategory.health},
    partnerTitle: 'Something around care or health to pick up?',
    explanation:
        'Something around care is going on. Your partner only sees this generic question.',
  ),
  PartnerHintTemplate(
    familyId: 'sport',
    keywords: ['sport', 'training', 'sporttas', 'wedstrijd'],
    categories: {},
    partnerTitle: 'Sports bag or training this week?',
    explanation:
        'Based on your tasks, sport looks like a theme. No private details.',
  ),
  PartnerHintTemplate(
    familyId: 'admin',
    keywords: [
      'belasting',
      'gemeente',
      'formulier',
      'verzekering',
      'paspoort',
      'tax',
      'insurance',
    ],
    categories: {TaskCategory.admin, TaskCategory.finance},
    partnerTitle: 'An admin chore this week?',
    explanation:
        'There is admin work open. The suggestion does not name a concrete task.',
  ),
];

const strongHabitKeywords = <String>[
  'boodschappen',
  'wasgoed',
  'wassen',
  'stofzuigen',
  'afwas',
  'groceries',
  'laundry',
  'afval',
];

String normalizeSuggestionText(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool containsAnyKeyword(String haystack, List<String> keywords) {
  final n = normalizeSuggestionText(haystack);
  return keywords.any((k) => n.contains(k));
}

bool isStrongHabitTitle(String title) =>
    containsAnyKeyword(title, strongHabitKeywords);

List<CalendarPrompt> calendarPromptsForMonth(int month) =>
    calendarPrompts.where((p) => p.months.contains(month)).toList();

/// First matching partner template based on keywords in title/notes.
/// Category-only matching is intentionally omitted — volume-by-category is
/// handled by the load-balance detector so a single private task does not
/// leak a theme unless a keyword hits.
PartnerHintTemplate? matchPartnerHint({required String title, String? notes}) {
  final corpus = '$title ${notes ?? ''}';
  for (final t in partnerHintTemplates) {
    if (containsAnyKeyword(corpus, t.keywords)) return t;
  }
  return null;
}

String loadBalanceTitle(String categoryName) => switch (categoryName) {
  'household' => 'Can you pick up something around the house this week?',
  'health' => 'Can you pick up something around care or health this week?',
  'admin' => 'Can you pick up something in admin this week?',
  'school' => 'Can you pick up something around school this week?',
  'finance' => 'Can you pick up something in finances this week?',
  _ => 'Can you pick something up this week?',
};

String categoryLabel(String category) => switch (category) {
  'household' => 'Household',
  'health' => 'Health',
  'admin' => 'Admin',
  'school' => 'School',
  'finance' => 'Finance',
  _ => 'Other',
};
