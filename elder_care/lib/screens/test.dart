import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/chat.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final OllamaChatService _chatService = OllamaChatService();
  final TextEditingController _controller = TextEditingController();
  String _currentResponse = '';
  bool _isLoading = false;

  void _sendMessage() {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _currentResponse = '';
    });

    try {
      _chatService.streamChatResponse(prompt: prompt).listen(
            (token) {
          setState(() {
            _currentResponse += token;
          });
        },
        onError: (error) {
          setState(() {
            _currentResponse = 'Error: $error';
            _isLoading = false;
          });
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
          _controller.clear();
        },
      );
    } catch (e) {
      setState(() {
        _currentResponse = 'Fatal Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Companion Chat'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      child: Text(
                        _currentResponse.isEmpty && !_isLoading
                            ? 'Enter a message to start streaming...'
                            : _currentResponse,
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16.0),

            const SizedBox(height: 8.0),

            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask your companion...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  tooltip: 'Send Message',
                  elevation: 2,
                  child: _isLoading
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}