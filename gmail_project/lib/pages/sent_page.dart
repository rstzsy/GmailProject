import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:translator/translator.dart'; // Dùng package dịch
import 'package:firebase_database/firebase_database.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import '../components/user_avatar.dart'; 
import 'composeEmail_page.dart';
import 'emailDetail_page.dart';
import 'profile_page.dart';
import '../services/message_service.dart';

class SentPage extends StatefulWidget {
  const SentPage({super.key});

  @override
  State<SentPage> createState() => _SentPageState();
}

class _SentPageState extends State<SentPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _avatarKey = GlobalKey();
  final MessageService _messageService = MessageService();

  List<Map<String, dynamic>> allSentEmails = [];
  List<Map<String, dynamic>> filteredEmails = [];
  bool isLoading = true;
  String searchQuery = '';
  DateTime? selectedDate;

  // Thêm biến dịch ngôn ngữ
  String userLanguage = 'en'; // default
  final translator = GoogleTranslator();
  
  late final DatabaseReference _languageRef;
  StreamSubscription<DatabaseEvent>? _languageSubscription;

  @override
  void initState() {
    super.initState();
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      // Khởi tạo ref realtime đến node language của user
      _languageRef = FirebaseDatabase.instance.ref('users/$currentUserId/language');

      // Lắng nghe realtime khi language thay đổi
      _languageSubscription = _languageRef.onValue.listen((event) async {
        final newLang = event.snapshot.value?.toString() ?? 'en';
        if (newLang != userLanguage) {
          setState(() {
            userLanguage = newLang;
            isLoading = true;
          });
          await _loadSentEmails();
        }
      });
    }

    // Load lần đầu ngôn ngữ & emails
    _initUserLanguageAndLoadEmails();
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

  // Khởi tạo ngôn ngữ rồi load emails
  Future<void> _initUserLanguageAndLoadEmails() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      userLanguage = await getUserLanguage(currentUserId);
    }
    await _loadSentEmails();
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

  Future<void> _loadSentEmails() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final loadedEmails = await _messageService.loadSentMessages(currentUserId);
    
    // Dịch từng subject + body của email sent
    List<Map<String, dynamic>> translatedEmails = [];

    for (var email in loadedEmails) {
      final translatedSubject = await translateText(email['subject'] ?? '', userLanguage);
      final translatedBody = await translateText(email['body'] ?? '', userLanguage);

      translatedEmails.add({
        ...email,
        'subject_translated': translatedSubject,
        'body_translated': translatedBody,
      });
    }

    setState(() {
      allSentEmails = translatedEmails;
      _applyFilters();
      isLoading = false;
    });
  }

  void _applyFilters() {
    final query = searchQuery.toLowerCase();
    setState(() {
      filteredEmails = allSentEmails.where((email) {
        // Sử dụng text đã dịch để tìm kiếm
        final subject = (email['subject_translated'] ?? email['subject'] ?? '').toString().toLowerCase();
        final body = (email['body_translated'] ?? email['body'] ?? '').toString().toLowerCase();
        final sentAt = email['sent_at'];
        bool matchesSearch = subject.contains(query) || body.contains(query);
        bool matchesDate = true;
        if (selectedDate != null && sentAt != null) {
          final date = DateTime.tryParse(sentAt);
          matchesDate = date != null &&
              date.year == selectedDate!.year &&
              date.month == selectedDate!.month &&
              date.day == selectedDate!.day;
        }
        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  Future<void> _toggleStar(String messageId, bool newValue, String senderId) async {
    await _messageService.updateStarStatus(messageId, newValue, senderId, isSender: true);
    _loadSentEmails();
  }

  void _onSearchChanged(String value) {
    searchQuery = value;
    _applyFilters();
  }

  void _onDateFilterTap() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      selectedDate = pickedDate;
      _applyFilters();
    }
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day} ${_getMonthName(dateTime.month)}";
    } catch (e) {
      return '';
    }
  }

  String _getMonthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: MenuDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 55, 54, 54),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color.fromARGB(255, 59, 58, 58), width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 3))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: Search(
                      onChanged: _onSearchChanged,
                      onDateFilterTap: _onDateFilterTap,
                    ),
                  ),
                  // Nút Clear filter ngày nếu đang có filter
                  if (selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      tooltip: 'Clear date filter',
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
                          _applyFilters();
                        });
                      },
                    ),
                  const SizedBox(width: 10),
                  UserAvatar(
                    key: _avatarKey,
                    radius: 20,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      ).then((value) {
                        // Cập nhật lại avatar khi quay lại từ ProfilePage
                        (_avatarKey.currentState as dynamic)?.refreshAvatar();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFF121212),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredEmails.isEmpty
              ? Center(
                  child: 
                  // Dịch text "No sent emails"
                  FutureBuilder<String>(
                    future: translateText('No sent emails', userLanguage),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final text = snapshot.data ?? 'No sent emails';
                      return Text(text, style: const TextStyle(color: Colors.white));
                    },
                  ),
                )
              : ListView.builder(
                  itemCount: filteredEmails.length,
                  itemBuilder: (context, index) {
                    final email = filteredEmails[index];
                    final isStarred = email['is_starred'] == true;

                    // Sử dụng text đã dịch để hiển thị
                    final subject = email['subject_translated'] ?? email['subject'] ?? 'No Subject';
                    final body = email['body_translated'] ?? email['body'] ?? '';

                    return ListTile(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailDetailPage(
                              subject: subject, // Truyền subject đã dịch
                              body: body, // Truyền body đã dịch
                              senderName: '',
                              senderTitle: '',
                              senderImageUrl: 'https://randomuser.me/api/portraits/men/${email['sender_id'].hashCode % 100}.jpg',
                              sentAt: email['sent_at'],
                              senderId: email['sender_id'] ?? '',
                              receiverId: email['receiver_id'] ?? '',
                              messageId: email['message_id'] ?? '',
                            ),
                          ),
                        );

                        if (result == true) {
                          _loadSentEmails();
                        }
                      },
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          'https://randomuser.me/api/portraits/men/${email['sender_id'].hashCode % 100}.jpg',
                        ),
                        radius: 25,
                      ),
                      title: Text(subject, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        body.isEmpty ? '(No Body)' : body,
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_formatDate(email["sent_at"]), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _toggleStar(
                              email['message_id'],
                              !isStarred,
                              email['sender_id'],
                            ),
                            child: Icon(
                              isStarred ? Icons.star : Icons.star_border,
                              color: isStarred ? Colors.yellow : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailPage()),
          );
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color.fromARGB(255, 89, 89, 89),
      ),
    );
  }
}