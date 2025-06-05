import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chatbot_service.dart';
import '../components/dialog.dart';

class ChatBotPage extends StatefulWidget {
  const ChatBotPage({super.key});

  @override
  State<ChatBotPage> createState() => _ChatBotPageState();
}

class _ChatBotPageState extends State<ChatBotPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ChatBotService _chatBotService = ChatBotService();
  
  bool _isTyping = false;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _loadChatHistory();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _typingAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        text: "Hii! I am AI Assistant. I can help you:\n\n"
              "• Answer the question about work\n"
              "• Supporting about composing email\n"
              "• Search information\n"
              "• Answer questions\n\n"
              "What support do you need today?",
        isUser: false,
        timestamp: DateTime.now(),
        messageType: MessageType.welcome,
      ));
    });
  }

  Future<void> _loadChatHistory() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final DatabaseReference chatRef = FirebaseDatabase.instance
          .ref()
          .child('chatbot_conversations')
          .child(currentUserId);

      final snapshot = await chatRef
          .orderByChild('timestamp')
          .limitToLast(50)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<ChatMessage> loadedMessages = [];

        data.entries.forEach((entry) {
          final messageData = entry.value as Map<dynamic, dynamic>;
          loadedMessages.add(ChatMessage.fromMap(messageData));
        });

        loadedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        setState(() {
          _messages.addAll(loadedMessages);
        });
      }
    } catch (e) {
      print('Error loading chat history: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();
    _typingAnimationController.repeat();

    try {
      // Save user message
      await _saveChatMessage(userMessage);

      // Get bot response
      final botResponse = await _chatBotService.sendMessage(text);
      
      final botMessage = ChatMessage(
        text: botResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(botMessage);
        _isTyping = false;
      });

      _typingAnimationController.stop();
      await _saveChatMessage(botMessage);

    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Xin lỗi, tôi đang gặp sự cố kỹ thuật. Vui lòng thử lại sau.",
          isUser: false,
          timestamp: DateTime.now(),
          messageType: MessageType.error,
        ));
        _isTyping = false;
      });
      _typingAnimationController.stop();
    }

    _scrollToBottom();
  }

  Future<void> _saveChatMessage(ChatMessage message) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final DatabaseReference chatRef = FirebaseDatabase.instance
          .ref()
          .child('chatbot_conversations')
          .child(currentUserId);

      await chatRef.push().set(message.toMap());
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  // clear chat
  Future<void> _clearChat() async {
    try {
      // Xóa tin nhắn trong Firebase
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId != null) {
        final DatabaseReference chatRef = FirebaseDatabase.instance
            .ref()
            .child('chatbot_conversations')
            .child(currentUserId);
        await chatRef.remove();
      }

      // Clear lịch sử trong ChatBotService
      _chatBotService.clearHistory();

      // Clear messages trong UI và thêm lại welcome message
      setState(() {
        _messages.clear();
      });
      
      _addWelcomeMessage();

      // Hiển thị thông báo thành công
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('Đã xóa lịch sử chat thành công'),
        //     backgroundColor: Colors.green,
        //     duration: Duration(seconds: 2),
        //   ),
        // );
        CustomDialog.show(
          context,
          title: "Success",
          content: 'Đã xóa lịch sử chat thành công',
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      print('Error clearing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi khi xóa lịch sử chat'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Thêm function để hiển thị confirmation dialog
  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            'Xóa lịch sử chat',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Bạn có chắc chắn muốn xóa toàn bộ lịch sử chat không? Hành động này không thể hoàn tác.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Hủy',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearChat();
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // Thêm function để hiển thị menu options
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title: const Text(
                  'Clear Chat',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Xóa toàn bộ lịch sử trò chuyện',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showClearChatDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFffcad4),
                ),
                title: const Text(
                  'About',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Thông tin về AI Assistant',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  // Có thể thêm logic hiển thị thông tin về app
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color.fromARGB(255, 247, 210, 217),
                child: Icon(
                  Icons.smart_toy_outlined,
                  color: Color.fromARGB(255, 247, 72, 130),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(0),
                    const SizedBox(width: 4),
                    _buildDot(1),
                    const SizedBox(width: 4),
                    _buildDot(2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        final delay = index * 0.2;
        final animationValue = (_typingAnimation.value + delay) % 1.0;
        final opacity = (animationValue < 0.5) ? animationValue * 2 : (1 - animationValue) * 2;
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color(0xFFffcad4).withOpacity(opacity.clamp(0.3, 1.0)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final isWelcome = message.messageType == MessageType.welcome;
    final isError = message.messageType == MessageType.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isError ? Colors.red.shade100 : const Color(0xFFffcad4),
              child: Icon(
                isError ? Icons.error_outline : Icons.smart_toy,
                color: isError ? Colors.red : const Color(0xFFF4538A),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                    ? const Color(0xFFffcad4)
                    : (isWelcome ? const Color(0xFF1E3A8A) : const Color(0xFF2C2C2C)),
                borderRadius: BorderRadius.circular(20),
                border: isWelcome ? Border.all(color: const Color(0xFFffcad4), width: 1) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser 
                          ? const Color(0xFFF4538A)
                          : (isWelcome ? const Color(0xFFffcad4) : Colors.white),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isUser 
                          ? const Color.fromARGB(255, 250, 68, 129).withOpacity(0.7)
                          : Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildQuickActions() {
    final quickActions = [
      {'icon': Icons.email, 'text': 'Compose email', 'action': 'compose_email'},
      {'icon': Icons.search, 'text': 'Search', 'action': 'search'},
      {'icon': Icons.help_outline, 'text': 'Help', 'action': 'help'},
      {'icon': Icons.schedule, 'text': 'Schedule', 'action': 'schedule'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thao tác nhanh:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickActions.map((action) {
              return InkWell(
                onTap: () => _handleQuickAction(action['action'] as String),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        color: const Color(0xFFffcad4),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        action['text'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _handleQuickAction(String action) {
    String message = '';
    switch (action) {
      case 'compose_email':
        message = 'Help me compose a professional email';
        break;
      case 'search':
        message = 'I want to find some informations';
        break;
      case 'help':
        message = 'I want to need a support';
        break;
      case 'schedule':
        message = 'Please help me schedule a meeting';
        break;
    }
    
    _messageController.text = message;
    _sendMessage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFffcad4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.smart_toy,
                color: Color(0xFFF4538A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showOptionsMenu, // Sử dụng function mới
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          if (_messages.length <= 1) _buildQuickActions(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Colors.white24, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Enter messages...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFffcad4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send,
                        color: Color(0xFFF4538A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MessageType {
  normal,
  welcome,
  error,
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType messageType;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.messageType = MessageType.normal,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'messageType': messageType.index,
    };
  }

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      isUser: map['isUser'] ?? false,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      messageType: MessageType.values[map['messageType'] ?? 0],
    );
  }
}