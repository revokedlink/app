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
  final int views;

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
    this.views = 0,
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
      views: json['views'] as int? ?? 0,
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

  Link copyWith({
    String? id,
    String? slug,
    String? label,
    List<String>? sections,
    List<String>? records,
    String? user,
    String? workspace,
    String? status,
    String? created,
    String? updated,
    int? views,
  }) {
    return Link(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      label: label ?? this.label,
      sections: sections ?? this.sections,
      records: records ?? this.records,
      user: user ?? this.user,
      workspace: workspace ?? this.workspace,
      status: status ?? this.status,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      views: views ?? this.views,
    );
  }
}
