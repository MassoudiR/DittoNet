class BookmarkItem {
  String title;
  String url;
  String? faviconUrl;

  BookmarkItem({
    required this.title,
    required this.url,
    this.faviconUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'faviconUrl': faviconUrl,
    };
  }

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      title: json['title'],
      url: json['url'],
      faviconUrl: json['faviconUrl'],
    );
  }
}
