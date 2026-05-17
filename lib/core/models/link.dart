/// Represents a public link from the PocketBase `links` collection.
class Link {
  final String id;
  final String slug;
  final String label;
  final List<String> sections;
  final List<String> records;
  final String user;
  final String workspace;
  final String status; // active, paused, revoked
  final String? created;
  final String? updated;

  Link({
    required this.id,
    required this.slug,
    required this.label,
    required this.sections,
    required this.records,
    required this.user,
    required this.workspace,
    required this.status,
    this.created,
    this.updated,
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      id: json['id'] as String,
      slug: json['slug'] as String,
      label: json['label'] as String,
      sections: (json['sections'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      records: (json['records'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      user: json['user'] as String,
      workspace: json['workspace'] as String,
      status: json['status'] as String? ?? 'active',
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'label': label,
        'sections': sections,
        'records': records,
        'user': user,
        'workspace': workspace,
        'status': status,
      };
}
