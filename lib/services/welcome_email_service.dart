import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum WelcomeEmailStatus {
  sent,
  notConfigured,
  invalidConfiguration,
  serverUnavailable,
  serverRejected,
  failed,
  verified,
  invalidCode,
}

class WelcomeEmailService {
  const WelcomeEmailService();

  static const _baseEndpoint = String.fromEnvironment(
    'ACCOUNT_API_URL',
    defaultValue: '',
  );
  static const _allowEmulatorHttp = bool.fromEnvironment(
    'ALLOW_INSECURE_MAIL_API',
    defaultValue: false,
  );

  Future<WelcomeEmailStatus> sendWelcome({
    required String email,
    required String firstName,
  }) async {
    return _post('/verification-email', {
      'email': email.trim(),
      'firstName': firstName.trim(),
    }, success: WelcomeEmailStatus.sent);
  }

  Future<WelcomeEmailStatus> verifyCode({required String email, required String code}) =>
      _post('/verify-email', {'email': email.trim(), 'code': code.trim()}, success: WelcomeEmailStatus.verified);

  Future<WelcomeEmailStatus> _post(String path, Map<String, String> payload, {required WelcomeEmailStatus success}) async {
    if (_baseEndpoint.trim().isEmpty) return WelcomeEmailStatus.notConfigured;

    final base = Uri.tryParse(_baseEndpoint);
    final uri = base?.replace(path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path');
    final isSecure = uri?.scheme == 'https';
    final isLocalEmulatorDebug = kDebugMode &&
        _allowEmulatorHttp &&
        uri?.scheme == 'http' &&
        uri?.host == '10.0.2.2';
    if (uri == null || (!isSecure && !isLocalEmulatorDebug) || uri.host.isEmpty) {
      return WelcomeEmailStatus.invalidConfiguration;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri).timeout(
        const Duration(seconds: 12),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(
        jsonEncode(payload),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) return success;
      if (response.statusCode == 400 && path == '/verify-email') return WelcomeEmailStatus.invalidCode;
      return WelcomeEmailStatus.serverRejected;
    } on Object {
      return WelcomeEmailStatus.serverUnavailable;
    } finally {
      client.close(force: true);
    }
  }
}
