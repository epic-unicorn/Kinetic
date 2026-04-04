import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';

/// A note — plaintext or markdown, optionally shared via family key/WebDAV.
class PersonalNote {
  final String id;
  final String title;
  final String body;
  final bool isShared;
  final DateTime? remindAt;
  final String? category;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalNote({
    required this.id,
    required this.title,
    required this.body,
    required this.isShared,
    this.remindAt,
    this.category,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  static PersonalNote create({
    required String title,
    String body = '',
    bool isShared = false,
    DateTime? remindAt,
    String? category,
    int sortOrder = 0,
  }) {
    final now = DateTime.now().toUtc();
    return PersonalNote(
      id: const Uuid().v4(),
      title: title,
      body: body,
      isShared: isShared,
      remindAt: remindAt,
      category: category,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  static PersonalNote fromRow(PersonalNoteRow row) {
    return PersonalNote(
      id: row.id,
      title: row.title,
      body: row.body,
      isShared: row.isShared,
      remindAt: row.remindAt,
      category: row.category,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  PersonalNote copyWith({
    String? title,
    String? body,
    bool? isShared,
    DateTime? remindAt,
    bool clearRemindAt = false,
    String? category,
    bool clearCategory = false,
    int? sortOrder,
  }) {
    return PersonalNote(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      isShared: isShared ?? this.isShared,
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      category: clearCategory ? null : (category ?? this.category),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  String toString() =>
      'PersonalNote(id: $id, title: $title, isShared: $isShared)';
}
