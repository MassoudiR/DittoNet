class HookScript {
  String id;
  String name;
  String targetPattern;
  String code;
  bool isActive;
  bool isDeletable;

  HookScript({
    required this.id,
    required this.name,
    required this.targetPattern,
    required this.code,
    this.isActive = true,
    this.isDeletable = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetPattern': targetPattern,
    'code': code,
    'isActive': isActive,
    'isDeletable': isDeletable,
  };

  factory HookScript.fromJson(Map<String, dynamic> json) {
    return HookScript(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Script',
      targetPattern: json['targetPattern'] as String? ?? '.*',
      code: json['code'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      isDeletable: json['isDeletable'] as bool? ?? true,
    );
  }
}
