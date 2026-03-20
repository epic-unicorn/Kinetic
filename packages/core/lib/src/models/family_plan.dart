import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'family_member.dart';

/// The root CRDT document — one per family, replicated across every peer.
///
/// All mutable operations return a **new** [FamilyPlan] with an incremented
/// [crdtVersion]. The sync layer (Phase 2) will merge diverged versions using
/// last-write-wins on scalar fields and union-merge on the members list.
class FamilyPlan extends Equatable {
  final String id;

  /// 32-byte AES-256 mesh key, base64-encoded.
  /// Shared at pairing time and used to encrypt all CouchDB documents.
  final String meshKeyBase64;

  final String name;
  final List<FamilyMember> members;
  final DateTime createdAt;

  /// Monotonic counter incremented on every local mutation.
  final int crdtVersion;

  const FamilyPlan({
    required this.id,
    required this.meshKeyBase64,
    required this.name,
    required this.members,
    required this.createdAt,
    this.crdtVersion = 0,
  });

  /// Creates a new [FamilyPlan] with [creator] as the first member.
  factory FamilyPlan.create({
    required String meshKeyBase64,
    required FamilyMember creator,
    String name = 'Our Family',
  }) =>
      FamilyPlan(
        id: const Uuid().v4(),
        meshKeyBase64: meshKeyBase64,
        name: name,
        members: [creator],
        createdAt: DateTime.now().toUtc(),
      );

  List<FamilyMember> get parents =>
      members.where((m) => m.role == MemberRole.parent).toList();

  List<FamilyMember> get children =>
      members.where((m) => m.role == MemberRole.child).toList();

  /// Adds [member] if not already present; increments [crdtVersion].
  FamilyPlan addMember(FamilyMember member) {
    if (members.any((m) => m.id == member.id)) return this;
    return _copyWith(members: [...members, member]);
  }

  FamilyPlan updateName(String newName) => _copyWith(name: newName);

  FamilyPlan _copyWith({String? name, List<FamilyMember>? members}) =>
      FamilyPlan(
        id: id,
        meshKeyBase64: meshKeyBase64,
        name: name ?? this.name,
        members: members ?? this.members,
        createdAt: createdAt,
        crdtVersion: crdtVersion + 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'meshKeyBase64': meshKeyBase64,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'crdtVersion': crdtVersion,
      };

  factory FamilyPlan.fromJson(Map<String, dynamic> json) => FamilyPlan(
        id: json['id'] as String,
        meshKeyBase64: json['meshKeyBase64'] as String,
        name: json['name'] as String,
        members: (json['members'] as List)
            .map((m) => FamilyMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        crdtVersion: (json['crdtVersion'] as int?) ?? 0,
      );

  @override
  List<Object?> get props =>
      [id, meshKeyBase64, name, members, createdAt, crdtVersion];
}
