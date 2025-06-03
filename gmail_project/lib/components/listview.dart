import 'dart:async';

import 'package:flutter/material.dart';
import 'package:translator/translator.dart'; // Dùng package dịch
import '../pages/emailDetail_page.dart';
import '../services/message_service.dart';

import 'package:firebase_database/firebase_database.dart';

class MyListView extends StatefulWidget {
  final String currentUserId;
  const MyListView({super.key, required this.currentUserId});

  @override
  MyListViewState createState() => MyListViewState();
}

class MyListViewState extends State<MyListView> {
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> allMessages = [];
  bool isLoading = true;
  String userLanguage = 'en'; // default
  final translator = GoogleTranslator();

  late final DatabaseReference _languageRef;
  StreamSubscription<DatabaseEvent>? _languageSubscription;

  @override
  void initState() {
    super.initState();

    // Khởi tạo ref realtime đến node language của user
    _languageRef = FirebaseDatabase.instance.ref('users/${widget.currentUserId}/language');

    // Lắng nghe realtime khi language thay đổi
    _languageSubscription = _languageRef.onValue.listen((event) async {
      final newLang = event.snapshot.value?.toString() ?? 'en';
      if (newLang != userLanguage) {
        setState(() {
          userLanguage = newLang;
          isLoading = true;
        });
        await loadMessages();
      }
    });

    // Load lần đầu ngôn ngữ & messages
    _initUserLanguageAndLoadMessages();
  }

  @override
  void dispose() {
    _languageSubscription?.cancel();
    super.dispose();
  }

  // Hàm lấy ngôn ngữ user từ Firebase Realtime Database
  Future<String> getUserLanguage(String userId) async {
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/language');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        return snapshot.value.toString();
      }
    } catch (e) {
      print("Error getting user language: $e");
    }
    return 'en';
  }

  // Khởi tạo ngôn ngữ rồi load message
  Future<void> _initUserLanguageAndLoadMessages() async {
    userLanguage = await getUserLanguage(widget.currentUserId);
    await loadMessages();
  }

  // Dịch text với target language
  Future<String> translateText(String text, String targetLang) async {
    if (text.isEmpty) return text;
    if (targetLang == 'en') return text; // bỏ dịch nếu là tiếng Anh
    try {
      final translation = await translator.translate(text, to: targetLang);
      return translation.text;
    } catch (e) {
      print("Translate error: $e");
      return text;
    }
  }

  // Load message và dịch từng subject + body
  Future<void> loadMessages() async {
    final service = MessageService();
    final result = await service.loadInboxMessages(widget.currentUserId);

    List<Map<String, dynamic>> translatedMessages = [];

    for (var msg in result) {
      final translatedSubject = await translateText(msg['subject'] ?? '', userLanguage);
      final translatedBody = await translateText(msg['body'] ?? '', userLanguage);

      translatedMessages.add({
        ...msg,
        'subject_translated': translatedSubject,
        'body_translated': translatedBody,
      });
    }

    setState(() {
      allMessages = translatedMessages;
      messages = translatedMessages;
      isLoading = false;
    });
  }

  void applyDateFilter(DateTime date) {
    final String dateStr = date.toIso8601String().split('T')[0]; // yyyy-MM-dd
    setState(() {
      messages = allMessages.where((msg) {
        final sentAt = msg['sent_at'] ?? '';
        return sentAt.startsWith(dateStr);
      }).toList();
    });
  }

  void applySearchFilter(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      messages = allMessages.where((msg) {
        final subject = (msg['subject_translated'] ?? msg['subject'] ?? '').toLowerCase();
        final body = (msg['body_translated'] ?? msg['body'] ?? '').toLowerCase();
        return subject.contains(lowerQuery) || body.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _toggleStar(String messageId, bool newStatus) async {
    setState(() {
      final index = messages.indexWhere((msg) => msg['message_id'] == messageId);
      if (index != -1) {
        messages[index]['is_starred_recip'] = newStatus;
      }
    });

    await MessageService().updateStarStatus(
      messageId,
      newStatus,
      widget.currentUserId,
      isSender: false,
    );

    await loadMessages();
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day.toString().padLeft(2, '0')} ${_getMonthName(dateTime.month)}";
    } catch (e) {
      return '';
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messages.isEmpty) {
      return FutureBuilder<String>(
        future: translateText('No messages available.', userLanguage),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = snapshot.data ?? 'No messages available.';
          return Center(child: Text(text));
        },
      );
    }

    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final subject = message['subject_translated'] ?? message['subject'] ?? 'No subject';
        final body = message['body_translated'] ?? message['body'] ?? '';
        final sentAt = message['sent_at'] ?? '';
        final senderId = message['sender_id'] ?? '';
        final isStarred = message['is_starred_recip'] == true;

        return ListTile(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailDetailPage(
                  subject: subject,
                  body: body,
                  senderName: '',
                  senderTitle: '',
                  senderImageUrl:
                      'https://randomuser.me/api/portraits/men/${senderId.hashCode % 100}.jpg',
                  sentAt: sentAt,
                  senderId: senderId,
                  receiverId: widget.currentUserId,
                  messageId: message['message_id'] ?? '',
                ),
              ),
            );

            if (result == true) {
              await loadMessages();
            }
          },
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              'https://randomuser.me/api/portraits/men/${senderId.hashCode % 100}.jpg',
            ),
            radius: 25,
          ),
          title: Text(subject),
          subtitle: Text(
            body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(sentAt),
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _toggleStar(message['message_id'], !isStarred),
                child: Icon(
                  isStarred ? Icons.star : Icons.star_border,
                  color: isStarred ? Colors.yellow : Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
