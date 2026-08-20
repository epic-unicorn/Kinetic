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
    title: 'Belastingaangifte checken',
    skipIfTitleContains: ['belasting', 'aangifte'],
    explanation: 'Maart — tijd om de aangifte te checken.',
  ),
  CalendarPrompt(
    months: [8],
    title: 'Schoolspullen klaarzetten',
    skipIfTitleContains: ['schoolspul', 'schooltas', 'etui'],
    explanation: 'Augustus — schoolspullen klaarzetten voor het nieuwe jaar.',
  ),
  CalendarPrompt(
    months: [12],
    title: 'Kerst voorbereiden',
    skipIfTitleContains: ['kerst', 'cadeau'],
    explanation: 'December — kerst voorbereiden.',
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
    ],
    categories: {TaskCategory.school},
    partnerTitle: 'Schoolronde of opvang deze week?',
    explanation:
        'Op basis van je taken (zonder privédetails) lijkt school deze week '
        'een thema. Dit ziet je partner.',
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
    ],
    categories: {TaskCategory.household},
    partnerTitle: 'Kan jij deze week iets in huishouden oppakken?',
    explanation:
        'Je hebt meerdere huishoudtaken open. Het voorstel is bewust algemeen.',
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
    ],
    categories: {TaskCategory.health},
    partnerTitle: 'Iets oppakken rond zorg of gezondheid?',
    explanation:
        'Er speelt iets rond zorg. Je partner ziet alleen deze algemene vraag.',
  ),
  PartnerHintTemplate(
    familyId: 'sport',
    keywords: ['sport', 'training', 'sporttas', 'wedstrijd'],
    categories: {},
    partnerTitle: 'Sporttas of training deze week?',
    explanation:
        'Op basis van je taken lijkt sport een thema. Geen privédetails.',
  ),
  PartnerHintTemplate(
    familyId: 'admin',
    keywords: ['belasting', 'gemeente', 'formulier', 'verzekering', 'paspoort'],
    categories: {TaskCategory.admin, TaskCategory.finance},
    partnerTitle: 'Een administratief klusje deze week?',
    explanation:
        'Er staat administratie open. Het voorstel noemt geen concrete taak.',
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
  'household' => 'Kan jij deze week iets in huishouden oppakken?',
  'health' => 'Kan jij deze week iets in zorg of gezondheid oppakken?',
  'admin' => 'Kan jij deze week iets in administratie oppakken?',
  'school' => 'Kan jij deze week iets rond school oppakken?',
  'finance' => 'Kan jij deze week iets in financiën oppakken?',
  _ => 'Kan jij deze week iets oppakken?',
};

String categoryLabelNl(String category) => switch (category) {
  'household' => 'Huishouden',
  'health' => 'Gezondheid',
  'admin' => 'Administratie',
  'school' => 'School',
  'finance' => 'Financiën',
  _ => 'Overig',
};
