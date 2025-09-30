import 'dart:async';
import 'dart:convert';
import 'package:elder_care/core/api/urlfinder.dart';
import 'package:http/http.dart' as http;

// NEW: A class to hold either a text token or structured reminder data
class ChatResponse {
  final String? text;
  final Map<String, dynamic>? reminderData;

  ChatResponse.text(this.text) : reminderData = null;
  ChatResponse.reminder(this.reminderData) : text = null;

  bool get isReminder => reminderData != null;
}

class OllamaChatService {
  // Use the correct base URL for the emulator
  late String _baseUrl = '';

  // Change return type to Stream<ChatResponse>
  Stream<ChatResponse> streamChatResponse({
    required String prompt,
  }) async* {
    if (_baseUrl==''){
      _baseUrl = await getPublicUrl();
    }
    final uri = Uri.parse('$_baseUrl/chat');
    final client = http.Client();
    final body = jsonEncode({'user_input': prompt});

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..body = body;

    // Send the request and get the streamed response
    final response = await client.send(request);

    if (response.statusCode != 200) {
      // Consume and decode any error body for better debugging
      final errorBody = await response.stream.bytesToString();
      client.close();
      throw Exception('API request failed with status: ${response.statusCode}. Body: $errorBody');
    }

    // 1. Check for JSON (Reminder) Response
    final contentType = response.headers['content-type']?.split(';').first.trim();
    if (contentType == 'application/json') {
      try {
        // Read the entire JSON body from the stream
        final jsonString = await response.stream.bytesToString();
        final jsonResponse = jsonDecode(jsonString) as Map<String, dynamic>;

        client.close();

        // Yield the structured reminder data
        yield ChatResponse.reminder(jsonResponse['data'] as Map<String, dynamic>);
      } catch (e) {
        client.close();
        throw Exception('Failed to decode JSON response: $e');
      }
    }
    // 2. Handle Text Streaming Response
    else if (contentType == 'text/plain') {
      try {
        await for (var chunk in response.stream) {
          final token = utf8.decode(chunk);
          // Yield text chunks
          yield ChatResponse.text(token);
        }
      } catch (e) {
        throw Exception('Failed to stream text response: $e');
      } finally {
        client.close();
      }
    } else {
      client.close();
      throw Exception('Unsupported Content-Type: $contentType');
    }
  }
}