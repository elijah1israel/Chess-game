import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_model.dart';

class OpenRouterException implements Exception {
  final String message;
  OpenRouterException(this.message);
  @override
  String toString() => 'OpenRouterException: $message';
}

class OpenRouterService {
  static const _base = 'https://openrouter.ai/api/v1';

  final String apiKey;
  final http.Client _client;

  OpenRouterService(this.apiKey, {http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://github.com/elijah1israel/chess-game',
        'X-Title': 'AI Chess Arena',
      };

  Future<List<AiModel>> listModels() async {
    final res = await _client.get(
      Uri.parse('$_base/models'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw OpenRouterException(
        'Failed to list models (${res.statusCode}): ${res.body}',
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>? ?? const []);
    final models = list
        .whereType<Map<String, dynamic>>()
        .map(AiModel.fromJson)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return models;
  }

  /// Sends a chat completion. Returns the assistant text.
  Future<String> chat({
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.2,
    int maxTokens = 128,
  }) async {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });
    final res = await _client.post(
      Uri.parse('$_base/chat/completions'),
      headers: _headers,
      body: body,
    );
    if (res.statusCode != 200) {
      throw OpenRouterException(
        'Chat failed (${res.statusCode}): ${res.body}',
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw OpenRouterException('No choices returned.');
    }
    final msg = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
    return (msg['content'] as String?) ?? '';
  }

  void close() => _client.close();
}
