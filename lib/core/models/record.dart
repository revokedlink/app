/// Represents a record from the PocketBase `records` collection.
class Record {
  final String id;
  final String key;
  final String value;
  final String label;
  final String type; // 'text' | 'number'
  final String format; // 'hidden' | 'default'
  final String user;
  final String workspace;
  final String? created;
  final String? updated;

  Record({
    required this.id,
    required this.key,
    required this.value,
    required this.label,
    required this.type,
    required this.format,
    required this.user,
    required this.workspace,
    this.created,
    this.updated,
  });

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      format: json['format'] as String,
      user: json['user'] as String,
      workspace: json['workspace'] as String,
      created: json['created'] as String?,
      updated: json['updated'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'label': label,
        'type': type,
        'format': format,
        'user': user,
        'workspace': workspace,
      };

  bool get isHidden => format == 'hidden';
}
