import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum MemberRole { parent, child }

/// A trusted member of the family mesh.
///
/// Each member corresponds to a physical device. Identity is established by
/// their Ed25519 public key — there are no usernames or passwords.
class FamilyMember extends Equatable {
  final String id;
  final String publicKeyBase64;
  final String name;
  final MemberRole role;
  final DateTime createdAt;

  const FamilyMember({
    required this.id,
    required this.publicKeyBase64,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  /// Creates a new member with a generated UUID.
  factory FamilyMember.create({
    required String publicKeyBase64,
    required String name,
    required MemberRole role,
  }) =>
      FamilyMember(
        id: const Uuid().v4(),
        publicKeyBase64: publicKeyBase64,
        name: name,
        role: role,
        createdAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'publicKeyBase64': publicKeyBase64,
        'name': name,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'] as String,
        publicKeyBase64: json['publicKeyBase64'] as String,
        name: json['name'] as String,
        role: MemberRole.values.byName(json['role'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, publicKeyBase64, name, role, createdAt];
}
