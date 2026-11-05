import 'dart:convert';
import 'dart:io';

class ComplaintRemoteService {
  static const _baseUrl = String.fromEnvironment('ACCOUNT_API_URL', defaultValue: '');

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final uri = _uri('/complaints');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) throw HttpException('Lecture refusée (${response.statusCode}).');
      final decoded = jsonDecode(body);
      if (decoded is! List) throw const FormatException('Réponse de réclamations invalide.');
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> upload(Map<String, dynamic> complaint) async {
    final uri = _uri('/complaints');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(complaint));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw HttpException('Envoi refusé (${response.statusCode}) ${body.substring(0, body.length.clamp(0, 200))}');
      }
    } finally {
      client.close(force: true);
    }
  }

  Uri _uri(String path) {
    if (_baseUrl.trim().isEmpty) throw const SocketException('URL API non configurée.');
    final base = Uri.tryParse(_baseUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const FormatException('L’API de réclamations doit être configurée en HTTPS.');
    }
    return base.replace(path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path');
  }
}
