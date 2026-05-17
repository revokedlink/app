/// Represents a section from the PocketBase `sections` collection.
class Section {
  final String id;
  final String key;
  final String name;
  final List<String> records;
  final String user;
  final String workspace;
  final String? created;
  final String? updated;

  Section({
    required this.id,
    required this.key,
    required this.name,
    required this.records,
    required this.user,
    required this.workspace,
    this.created,
    this.updated,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      records: (json['records'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      user: json['user'] as String,
      workspace: json['workspace'] as String,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'records': records,
        'user': user,
        'workspace': workspace,
      };
}
