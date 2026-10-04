import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'session_service.dart';

enum PreflightErrorType {
  none, noNetwork, dnsFailure, tlsFailure, timeout, invalidUrl, localhostReleaseUrl, missingConfiguration, authenticationFailure,
  http400, http401, http403, http404, http408, http409, http429, http500, http502, http503, http504,
  htmlResponse, invalidJson, invalidAiSchema, emptyAiResponse, modelFailure, providerFailure, rateLimited, unknownServerError
}

class AiPreflightResult {
  final bool isReady;
  final PreflightErrorType errorType;
  final String diagnosticMessage;
  final int statusCode;
  final String contentType;

  AiPreflightResult({required this.isReady, this.errorType = PreflightErrorType.none, this.diagnosticMessage = '', this.statusCode = 0, this.contentType = ''});
}

class AiNetworkPreflight {
  static final AiNetworkPreflight instance = AiNetworkPreflight._internal();
  AiNetworkPreflight._internal();

  bool isReady = false;
  PreflightErrorType currentError = PreflightErrorType.none;
  String currentDiagnostic = '';

  Future<AiPreflightResult> runPreflight() async {
    isReady = false;
    final baseUrl = SessionService.instance.proxyGatewayUrl;
    final apiKey = SessionService.getSecureApiKey();
    
    if (baseUrl.isEmpty) return _fail(PreflightErrorType.missingConfiguration, "Base URL is empty");
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasScheme) return _fail(PreflightErrorType.invalidUrl, "Invalid URL format");
    if (kReleaseMode && uri.scheme != 'https') return _fail(PreflightErrorType.invalidUrl, "HTTPS is required in release mode");
    if (kReleaseMode && (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host.startsWith('192.168.') || uri.host.startsWith('10.0.2.'))) {
      return _fail(PreflightErrorType.localhostReleaseUrl, "Localhost used in release mode");
    }
    if (apiKey.isEmpty) return _fail(PreflightErrorType.missingConfiguration, "API Key is missing");

    try {
      final portStr = uri.hasPort ? ':${uri.port}' : '';
      final healthUri = Uri.parse('${uri.scheme}://${uri.host}$portStr/v1/models');
      final response = await http.get(healthUri, headers: {'Authorization': 'Bearer $apiKey'}).timeout(const Duration(seconds: 60));
      final rawBody = response.body.trim().toLowerCase();
      if (rawBody.startsWith('<!doctype') || rawBody.startsWith('<html')) {
        return _fail(PreflightErrorType.htmlResponse, "HTML_RESPONSE_FROM_API", status: response.statusCode, contentType: response.headers['content-type'] ?? 'unknown');
      }
      if (response.statusCode == 401) return _fail(PreflightErrorType.http401, "Auth Error");
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('lookup')) return _fail(PreflightErrorType.dnsFailure, "DNS Failure");
      if (msg.contains('timeout')) return _fail(PreflightErrorType.timeout, "Timeout");
      if (msg.contains('handshake') || msg.contains('cert')) return _fail(PreflightErrorType.tlsFailure, "TLS Failure");
      return _fail(PreflightErrorType.noNetwork, "Network Exception");
    }

    try {
      final targetUri = uri;
      final response = await http.post(
        targetUri,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
        body: jsonEncode({'model': 'auto', 'messages': [{'role': 'user', 'content': 'Reply with exactly: AI_READY'}], 'max_tokens': 10}),
      ).timeout(const Duration(seconds: 15));
      
      final contentType = response.headers['content-type'] ?? '';
      if (response.body.trim().toLowerCase().startsWith('<!doctype') || response.body.trim().toLowerCase().startsWith('<html')) {
        return _fail(PreflightErrorType.htmlResponse, "HTML_RESPONSE_FROM_API", status: response.statusCode, contentType: contentType);
      }
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('choices') && (data['choices'] as List).isNotEmpty) {
            final content = data['choices'][0]['message']['content'];
            if (content != null && content.toString().trim().isNotEmpty) {
              isReady = true;
              currentError = PreflightErrorType.none;
              currentDiagnostic = "AI_READY";
              return AiPreflightResult(isReady: true, statusCode: 200, contentType: contentType);
            } else {
              return _fail(PreflightErrorType.emptyAiResponse, "Empty content");
            }
          } else {
            return _fail(PreflightErrorType.invalidAiSchema, "Missing choices/message/content");
          }
        } catch (_) {
          return _fail(PreflightErrorType.invalidJson, "Invalid JSON");
        }
      } else {
         if (response.statusCode == 400) return _fail(PreflightErrorType.http400, "Bad Request");
         if (response.statusCode == 404) return _fail(PreflightErrorType.http404, "Not Found");
         if (response.statusCode == 429) return _fail(PreflightErrorType.http429, "Too Many Requests");
         return _fail(PreflightErrorType.unknownServerError, "Status ${response.statusCode}");
      }
    } catch (e) {
      return _fail(PreflightErrorType.noNetwork, "Inference Exception");
    }
  }

  AiPreflightResult _fail(PreflightErrorType type, String diag, {int status = 0, String contentType = ''}) {
    isReady = false;
    currentError = type;
    currentDiagnostic = diag;
    debugPrint("AI_PREFLIGHT FAIL: $type | $diag");
    return AiPreflightResult(isReady: false, errorType: type, diagnosticMessage: diag, statusCode: status, contentType: contentType);
  }
}
