/// A note in the iCal wire format (VJOURNAL component).
class ICalNote {
  final String uid;

  /// SUMMARY — the note title.
  final String summary;

  /// DESCRIPTION — the note body (may contain Markdown).
  final String? description;

  /// If true, this note is stored in the shared WebDAV folder with the
  /// family key.  False = personal note, personal key.
  final bool isShared;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional reminder timestamp → maps to VALARM + TRIGGER.
  final DateTime? remindAt;

  const ICalNote({
    required this.uid,
    required this.summary,
    this.description,
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
    this.remindAt,
  });

  ICalNote copyWith({
    String? uid,
    String? summary,
    String? description,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? remindAt,
  }) {
    return ICalNote(
      uid: uid ?? this.uid,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remindAt: remindAt ?? this.remindAt,
    );
  }

  @override
  String toString() =>
      'ICalNote(uid: $uid, summary: $summary, isShared: $isShared)';
}
