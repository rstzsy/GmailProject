import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import '../components/user_avatar.dart'; 
import '../services/message_service.dart';
import 'composeEmail_page.dart';
import 'emailDetail_page.dart';
import 'profile_page.dart';

class StarredPage extends StatefulWidget {
  const StarredPage({super.key});

  @override
  State<StarredPage> createState() => _StarredPageState();
}

class _StarredPageState extends State<StarredPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _avatarKey = GlobalKey();
  final MessageService _messageService = MessageService();

  List<Map<String, dynamic>> allStarredEmails = [];
  List<Map<String, dynamic>> filteredEmails = [];
  bool isLoading = true;
  String searchQuery = '';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    _loadStarredEmails();
  }

  Future<void> _loadStarredEmails() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final sentEmails = await _messageService.loadSentMessages(userId);
    final inboxEmails = await _messageService.loadInboxMessages(userId);

    final allEmails = [...sentEmails, ...inboxEmails];

    final starred = allEmails.where((e) =>
      e['is_starred'] == true || e['is_starred_recip'] == true
    ).toList();

    setState(() {
      allStarredEmails = starred;
      _applyFilters();
      isLoading = false;
    });
  }

  void _applyFilters() {
    final query = searchQuery.toLowerCase();
    setState(() {
      filteredEmails = allStarredEmails.where((email) {
        final subject = (email['subject'] ?? '').toString().toLowerCase();
        final body = (email['body'] ?? '').toString().toLowerCase();
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

  Future<void> _toggleStar(
      String messageId, bool newStatus, String userId, bool isSender) async {
    await _messageService.updateStarStatus(
      messageId,
      newStatus,
      userId,
      isSender: isSender,
    );
    await _loadStarredEmails();
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day}/${dateTime.month}";
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

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

                  // Nút clear filter ngày nếu có selectedDate
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredEmails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/empty_starred.png', width: 150, height: 150),
                      const SizedBox(height: 20),
                      const Text("Nothing in starred folder", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredEmails.length,
                  itemBuilder: (context, index) {
                    final email = filteredEmails[index];
                    final isSentByMe = email['sender_id'] == currentUserId;
                    final isStarred = isSentByMe
                        ? (email['is_starred'] ?? false)
                        : (email['is_starred_recip'] ?? false);

                    return ListTile(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailDetailPage(
                              subject: email['subject'] ?? '',
                              body: email['body'] ?? '',
                              senderName: '',
                              senderTitle: '',
                              senderImageUrl: 'https://randomuser.me/api/portraits/men/${email['sender_id'].hashCode % 100}.jpg',
                              sentAt: email['sent_at'],
                              senderId: email['sender_id'],
                              receiverId: email['receiver_id'],
                              messageId: email['message_id'] ?? '',
                            ),
                          ),
                        );

                        if (result == true) {
                          _loadStarredEmails();
                        }
                      },
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/${email['sender_id'].hashCode % 100}.jpg'),
                        radius: 25,
                      ),
                      title: Text(email["subject"] ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        email["body"] ?? '',
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
                            onTap: () {
                              final userId = isSentByMe ? email['sender_id'] : email['receiver_id'];
                              _toggleStar(email['message_id'], !isStarred, userId, isSentByMe);
                            },
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ComposeEmailPage()));
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color.fromARGB(255, 89, 89, 89),
      ),
      backgroundColor: const Color(0xFF121212),
    );
  }
}