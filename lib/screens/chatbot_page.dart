import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat.dart';
import 'dart:convert';
import 'dart:async';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final String _apiUrl = "http://35.219.25.94/chat"; // Move to config
  
  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isLoading || _controller.text.trim().isEmpty) return;

    final text = _controller.text.trim();
    _controller.clear();
    
    // Add user message
    setState(() {
      _messages.insert(0, ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': text}), 
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final botResponse = data['reply'] ?? "No response received";
        
        setState(() {
          _messages.insert(0, ChatMessage(
            text: botResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });

        await _saveChatHistory(); 

      } else {
        throw "Request failed with status ${response.statusCode}";
      }
    } on TimeoutException {
      _showError("Response timeout. Please check your connection.");
    } catch (e) {
      _showError("Error: ${e.toString().replaceAll('Exception: ', '')}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _messages.insert(0, ChatMessage(
        text: message,
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('chat_history') ?? [];
    final loadedMessages = jsonList.map((e) => ChatMessage.fromJson(jsonDecode(e))).toList();
    setState(() {
      _messages.clear();
      _messages.addAll(loadedMessages);
    });
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await prefs.setStringList('chat_history', jsonList);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Asisten Obat',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        toolbarHeight: 70, 
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ChatBubble(
                    message: message,
                    fontSize: 18, 
                  );
                },
              ),
            ),
            if (_isLoading)
              const LinearProgressIndicator(minHeight: 4),
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + bottomPadding,
              ),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(fontSize: 18), 
                        decoration: InputDecoration(
                          hintText: 'Tanyakan tentang obat...',
                          hintStyle: TextStyle(fontSize: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16, // Lebih tinggi
                          ),
                        ),
                        //maxLines: 3,
                        //minLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 128, 128, 0.3), // RGB values for teal with opacity
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        )
                      ],
                    ),
                    child: FloatingActionButton(
                      elevation: 0,
                      backgroundColor: Colors.teal,
                      onPressed: _sendMessage,
                      child: Icon(Icons.send, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final double fontSize;

  const ChatBubble({
    super.key, 
    required this.message,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 16,
      ),
      child: Column(
        crossAxisAlignment: message.isUser 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: message.isUser 
                  ? Colors.teal[200] 
                  : Colors.grey[300],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(message.isUser ? 20 : 0),
                bottomRight: Radius.circular(message.isUser ? 0 : 20),
              ),
              border: Border.all(
                color: message.isUser 
                  ? Colors.teal 
                  : Colors.grey.shade500,
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(message.timestamp),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}