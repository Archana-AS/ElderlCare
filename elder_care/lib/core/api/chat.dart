import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaChatService {
  final String _baseUrl = 'http://10.0.2.2:8000';

  Stream<String> streamChatResponse({
    required String prompt,
    String model = 'helpingai',
  }) async* {
    final uri = Uri.parse('$_baseUrl/chat');
    final client = http.Client();
    final body = jsonEncode({'prompt': prompt, 'model': model});

    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('API request failed with status: ${response.statusCode}');
      }

      await for (var chunk in response.stream) {
        final token = utf8.decode(chunk);
        yield token;
      }
    } catch (e) {
      throw Exception('Failed to stream response: $e');
    } finally {
      client.close();
    }
  }
}