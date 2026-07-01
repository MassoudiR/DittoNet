class TrafficLog {
  final String flowId;
  final String url;
  final String method;
  final int? statusCode;
  final String type; // 'Intercepted', 'Modified', 'Blocked'
  final DateTime timestamp;

  TrafficLog({
    required this.flowId,
    required this.url,
    required this.method,
    this.statusCode,
    required this.type,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'TrafficLog(flowId: $flowId, url: $url, method: $method, statusCode: $statusCode, type: $type, timestamp: $timestamp)';
  }
}
