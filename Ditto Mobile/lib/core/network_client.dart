import 'dart:io';
import 'package:http/io_client.dart';
import '../state/browser_state.dart';

class NetworkClient {
  static IOClient getSecureOrProxyClient(BrowserState state) {
    HttpClient httpClient = HttpClient();
    
    // 1. SSL Pinning & Certificate Error Bypass
    if (state.isSslBypassEnabled) {
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }
    
    // 2. External Proxy Chaining
    if (state.isExternalProxyEnabled && state.externalProxyHost.isNotEmpty) {
      httpClient.findProxy = (uri) {
        return "PROXY ${state.externalProxyHost}:${state.externalProxyPort}";
      };
    }
    
    return IOClient(httpClient);
  }
}
