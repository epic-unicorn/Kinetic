import '../models/enums.dart';

/// Keyword-based auto-categorization for personal tasks.
///
/// Runs entirely on-device, offline, deterministically.
/// The [CategoryClassifier] interface allows a TFLite model to be
/// substituted in a future phase without changing any call sites.
abstract class CategoryClassifier {
  TaskCategory classify(String title, {String? notes});
}

class KeywordCategoryClassifier implements CategoryClassifier {
  static const _rules = <TaskCategory, List<String>>{
    TaskCategory.household: [
      'clean',
      'cleaning',
      'wash',
      'laundry',
      'dishes',
      'vacuum',
      'mop',
      'groceries',
      'grocery',
      'supermarket',
      'shop',
      'shopping',
      'cook',
      'cooking',
      'dinner',
      'lunch',
      'breakfast',
      'meal',
      'repair',
      'fix',
      'garden',
      'lawn',
      'mow',
      'rubbish',
      'trash',
      'bin',
      'recycle',
      'ikea',
      'furniture',
      'paint',
      'plumber',
      'electrician',
    ],
    TaskCategory.health: [
      'doctor',
      'dentist',
      'hospital',
      'appointment',
      'prescription',
      'medicine',
      'medication',
      'pharmacy',
      'physio',
      'therapy',
      'exercise',
      'gym',
      'run',
      'running',
      'yoga',
      'checkup',
      'vaccine',
      'blood',
      'test',
      'optician',
      'glasses',
    ],
    TaskCategory.admin: [
      'email',
      'call',
      'phone',
      'letter',
      'form',
      'document',
      'sign',
      'contract',
      'insurance',
      'renew',
      'register',
      'application',
      'passport',
      'visa',
      'driving',
      'licence',
      'license',
      'id',
      'council',
      'government',
      'tax',
      'return',
      'accountant',
    ],
    TaskCategory.school: [
      'school',
      'homework',
      'teacher',
      'parent evening',
      'meeting',
      'permission',
      'trip',
      'uniform',
      'book',
      'books',
      'tutor',
      'pickup',
      'drop off',
      'nursery',
      'daycare',
      'sport',
      'kit',
    ],
    TaskCategory.finance: [
      'bank',
      'payment',
      'pay',
      'invoice',
      'bill',
      'transfer',
      'mortgage',
      'rent',
      'insurance',
      'savings',
      'invest',
      'pension',
      'finance',
      'budget',
      'expense',
      'receipt',
      'refund',
      'subscription',
    ],
  };

  @override
  TaskCategory classify(String title, {String? notes}) {
    final corpus = '${title.toLowerCase()} ${notes?.toLowerCase() ?? ''}';

    for (final entry in _rules.entries) {
      for (final keyword in entry.value) {
        if (corpus.contains(keyword)) return entry.key;
      }
    }
    return TaskCategory.other;
  }
}

/// Singleton for easy access throughout the app.
final categoryClassifier = KeywordCategoryClassifier();
