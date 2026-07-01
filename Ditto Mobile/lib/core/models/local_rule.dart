import 'dart:convert';

class LocalRule {
  final String id;
  final String name;
  final String targetPattern; // Regex pattern string
  final String phase; // "Request", "Response", "Both"
  final String actionType; // "BLOCK", "REDIRECT", "MATCH_REPLACE", "HEADER_INJECT", "BODY_REPLACE"
  final String? matchString;
  final String? replaceString;
  final bool isActive;
  final bool isRegex;
  final String method; // "ALL", "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"

  const LocalRule({
    required this.id,
    required this.name,
    required this.targetPattern,
    required this.phase,
    required this.actionType,
    this.matchString,
    this.replaceString,
    this.isActive = true,
    this.isRegex = false,
    this.method = 'ALL',
  });

  LocalRule copyWith({
    String? id,
    String? name,
    String? targetPattern,
    String? phase,
    String? actionType,
    String? matchString,
    String? replaceString,
    bool? isActive,
    bool? isRegex,
    String? method,
  }) {
    return LocalRule(
      id: id ?? this.id,
      name: name ?? this.name,
      targetPattern: targetPattern ?? this.targetPattern,
      phase: phase ?? this.phase,
      actionType: actionType ?? this.actionType,
      matchString: matchString ?? this.matchString,
      replaceString: replaceString ?? this.replaceString,
      isActive: isActive ?? this.isActive,
      isRegex: isRegex ?? this.isRegex,
      method: method ?? this.method,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetPattern': targetPattern,
      'phase': phase,
      'actionType': actionType,
      'matchString': matchString,
      'replaceString': replaceString,
      'isActive': isActive,
      'isRegex': isRegex,
      'method': method,
    };
  }

  factory LocalRule.fromJson(Map<String, dynamic> json) {
    return LocalRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      targetPattern: json['targetPattern'] as String? ?? '.*',
      phase: json['phase'] as String? ?? 'Both',
      actionType: json['actionType'] as String? ?? 'BLOCK',
      matchString: json['matchString'] as String?,
      replaceString: json['replaceString'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isRegex: json['isRegex'] as bool? ?? false,
      method: json['method'] as String? ?? 'ALL',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LocalRule.fromJsonString(String jsonString) => LocalRule.fromJson(jsonDecode(jsonString));
}

