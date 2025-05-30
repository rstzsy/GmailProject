import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import 'composeEmail_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'emailDetail_page.dart';
import '../services/message_service.dart';

class SentPage extends StatefulWidget {
  const SentPage({super.key});

  @override
  State<SentPage> createState() => _SentPageState();
}

class _SentPageState extends State<SentPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> sentEmails = [];
  bool isLoading = true;

  final MessageService _messageService = MessageService();

  @override
  void initState() {
    super.initState();
    _loadSentEmails();
  }

  Future<void> _loadSentEmails() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final loadedEmails = await _messageService.loadSentMessages(currentUserId);

    setState(() {
      sentEmails = loadedEmails;
      isLoading = false;
    });
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
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
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
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color.fromARGB(221, 232, 229, 229)),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Expanded(child: Search()),
                  const SizedBox(width: 10),
                  const CircleAvatar(
                    backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/2.jpg'),
                    radius: 20,
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
          : sentEmails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/empty_sent.png', width: 150, height: 150),
                      const SizedBox(height: 20),
                      const Text("No sent emails", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: sentEmails.length,
                  itemBuilder: (context, index) {
                    final email = sentEmails[index];
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EmailDetailPage(
                              subject: email['subject'] ?? 'No Subject',
                              body: email['body'] ?? '',
                              senderName: '', // Sẽ được load từ database
                              senderTitle: '', // Sẽ được load từ database
                              senderImageUrl:
                                  'https://randomuser.me/api/portraits/men/${email['sender_id'].hashCode % 100}.jpg',
                              sentAt: email['sent_at'],
                              senderId: email['sender_id'] ?? '',
                              receiverId: email['receiver_id'] ?? '',
                            ),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          'https://randomuser.me/api/portraits/men/${email['sender_id'].hashCode % 100}.jpg',
                        ),
                        radius: 25,
                      ),
                      title: Text(
                        email["subject"] ?? 'No Subject',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        email["body"] ?? '(No Body)',
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(email["sent_at"]),
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Icon(Icons.star_outline, color: Colors.grey),
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
