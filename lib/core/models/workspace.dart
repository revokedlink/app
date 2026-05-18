/// Represents a workspace from the PocketBase `workspaces` collection.
class Workspace {
  final String id;
  final String name;
  final String slug;
  final String type; // 'personal' | 'business'
  final String? created;
  final String? updated;

  Workspace({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    this.created,
    this.updated,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      type: json['type'] as String,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'slug': slug, 'type': type};

  bool get isPersonal => type == 'personal';
  bool get isBusiness => type == 'business';
}
