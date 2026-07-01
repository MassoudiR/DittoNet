/// Granular Per-Origin (Domain-Specific) Permission Model
class SitePermission {
  final String host;
  final bool allowCameraMic;
  final bool allowLocation;
  final bool allowJavascript;

  const SitePermission({
    required this.host,
    this.allowCameraMic = true,
    this.allowLocation = true,
    this.allowJavascript = true,
  });

  SitePermission copyWith({
    String? host,
    bool? allowCameraMic,
    bool? allowLocation,
    bool? allowJavascript,
  }) {
    return SitePermission(
      host: host ?? this.host,
      allowCameraMic: allowCameraMic ?? this.allowCameraMic,
      allowLocation: allowLocation ?? this.allowLocation,
      allowJavascript: allowJavascript ?? this.allowJavascript,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'allowCameraMic': allowCameraMic,
      'allowLocation': allowLocation,
      'allowJavascript': allowJavascript,
    };
  }

  factory SitePermission.fromJson(Map<String, dynamic> json) {
    return SitePermission(
      host: json['host'] as String? ?? '',
      allowCameraMic: json['allowCameraMic'] as bool? ?? true,
      allowLocation: json['allowLocation'] as bool? ?? true,
      allowJavascript: json['allowJavascript'] as bool? ?? true,
    );
  }
}
