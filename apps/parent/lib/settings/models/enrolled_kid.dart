/// A child registered in the family by scanning the parent's enrollment QR.
class EnrolledKid {
  final String id;
  final String name;
  final DateTime enrolledAt;

  const EnrolledKid({
    required this.id,
    required this.name,
    required this.enrolledAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enrolledAt': enrolledAt.toIso8601String(),
  };

  factory EnrolledKid.fromJson(Map<String, dynamic> json) => EnrolledKid(
    id: json['id'] as String,
    name: json['name'] as String,
    enrolledAt: DateTime.parse(json['enrolledAt'] as String),
  );
}
