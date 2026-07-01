class HistoryItem {
  String title;
  String url;
  DateTime timestamp;

  HistoryItem({
    required this.title,
    required this.url,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      title: json['title'],
      url: json['url'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
