import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class BrowserTab {
  final String id;
  String url;
  String title;
  InAppWebViewController? controller;
  PullToRefreshController? pullToRefreshController;
  final int? windowId;
  Uint8List? screenshot;
  final GlobalKey windowKey;

  BrowserTab({
    required this.id,
    this.url = '',
    this.title = 'New Tab',
    this.controller,
    this.pullToRefreshController,
    this.windowId,
    this.screenshot,
    GlobalKey? windowKey,
  }) : windowKey = windowKey ?? GlobalKey();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'windowId': windowId,
    };
  }

  factory BrowserTab.fromJson(Map<String, dynamic> json) {
    return BrowserTab(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'New Tab',
      windowId: json['windowId'] as int?,
      windowKey: GlobalKey(),
    );
  }
}
