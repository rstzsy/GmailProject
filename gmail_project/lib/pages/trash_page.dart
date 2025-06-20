import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/menu_drawer.dart';
import '../components/search.dart';
import '../services/message_service.dart';
import 'emailDetail_page.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MessageService _messageService = MessageService();

  List<Map<String, dynamic>> trashEmails = [];
  bool isLoading = true;

  // Biến cho tìm kiếm và lọc ngày
  String _searchQuery = '';
  DateTime? _filterDate;

  @override
  void initState() {
    super.initState();
    _loadTrashedEmails();
  }

  Future<void> _loadTrashedEmails() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final trashedMessages = await _messageService.loadAllTrashedMessages(userId);

      setState(() {
        trashEmails = trashedMessages;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading trashed emails: $e');
      setState(() {
        isLoading = false;
      });
    }
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

  Future<void> _restoreMessage(Map<String, dynamic> email) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final messageId = email['message_id'];
    final isSentByMe = email['sender_id'] == currentUserId;

    try {
      await _messageService.restoreMessageFromTrash(
        messageId,
        currentUserId,
        isSender: isSentByMe,
      );

      _loadTrashedEmails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message restored successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring message: $e')),
      );
    }
  }

  Future<void> _permanentlyDeleteMessage(Map<String, dynamic> email) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final messageId = email['message_id'];
    final isSentByMe = email['sender_id'] == currentUserId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text('This message will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _messageService.permanentlyDeleteMessage(
          messageId,
          currentUserId,
          isSender: isSentByMe,
        );

        _loadTrashedEmails();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message permanently deleted')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
        );
      }
    }
  }

  // Hàm chọn ngày lọc
  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[850],
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  // Danh sách email đã lọc theo tìm kiếm và ngày
  List<Map<String, dynamic>> get _filteredEmails {
    return trashEmails.where((email) {
      final subject = (email['subject'] ?? '').toString().toLowerCase();
      final body = (email['body'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();

      final matchesSearch = subject.contains(searchLower) || body.contains(searchLower);

      bool matchesDate = true;
      if (_filterDate != null && email['sent_at'] != null) {
        try {
          final emailDate = DateTime.parse(email['sent_at']);
          matchesDate = emailDate.year == _filterDate!.year &&
              emailDate.month == _filterDate!.month &&
              emailDate.day == _filterDate!.day;
        } catch (_) {
          matchesDate = true;
        }
      }

      return matchesSearch && matchesDate;
    }).toList();
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

                  // Widget Search có icon lịch sẵn, dùng onDateFilterTap để mở date picker
                  Expanded(
                    child: Search(
                      onChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                      onDateFilterTap: () async {
                        // Mở date picker
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _filterDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  surface: Colors.grey[900]!,
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.grey[850],
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setState(() {
                            _filterDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                  
                  // Nút clear filter ngày nếu đang có filter
                  if (_filterDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _filterDate = null;
                        });
                      },
                      tooltip: 'Clear date filter',
                    ),

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
          : _filteredEmails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/empty_trash.png', width: 150, height: 150),
                      const SizedBox(height: 20),
                      const Text("Nothing in Trash", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.grey[400]),
                          const SizedBox(width: 8),
                          Text(
                            '${_filteredEmails.length} messages in trash',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredEmails.length,
                        itemBuilder: (context, index) {
                          final email = _filteredEmails[index];
                          final isSentByMe = email['sender_id'] == currentUserId;
                          final subject = email['subject']?.isNotEmpty == true ? email['subject'] : 'No Subject';

                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    settings: const RouteSettings(name: '/trashDetail'),
                                    builder: (context) => EmailDetailPage(
                                      subject: email['subject'] ?? 'No Subject',
                                      body: email['body'] ?? '',
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
                              },
                              leading: Icon(
                                isSentByMe ? Icons.send : Icons.inbox,
                                color: Colors.grey[400],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      subject,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (isSentByMe)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'Sent',
                                        style: TextStyle(color: Colors.blue, fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email["body"] ?? '',
                                    style: const TextStyle(color: Colors.white54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDate(email["sent_at"]),
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'restore') {
                                        _restoreMessage(email);
                                      } else if (value == 'delete') {
                                        _permanentlyDeleteMessage(email);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(Icons.restore, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text('Restore'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_forever, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Forever'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
