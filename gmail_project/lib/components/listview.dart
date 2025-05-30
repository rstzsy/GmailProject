import 'package:flutter/material.dart';
import '../pages/emailDetail_page.dart';
import '../services/message_service.dart';

class MyListView extends StatefulWidget {
  final String currentUserId;
  const MyListView({super.key, required this.currentUserId});

  @override
  _MyListViewState createState() => _MyListViewState();
}

class _MyListViewState extends State<MyListView> {
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  Future<void> loadMessages() async {
    final service = MessageService();
    final result = await service.loadInboxMessages(widget.currentUserId);
    setState(() {
      messages = result;
      isLoading = false;
    });
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
      return const Center(child: Text('Không có thư nào.'));
    }

    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final subject = message['subject'] ?? 'Không có tiêu đề';
        final body = message['body'] ?? '';
        final sentAt = message['sent_at'] ?? '';
        final senderId = message['sender_id'] ?? '';

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailDetailPage(
                  subject: subject,
                  body: body,
                  senderName: '', // bạn có thể load từ DB nếu muốn
                  senderTitle: '',
                  senderImageUrl: 'https://randomuser.me/api/portraits/men/${senderId.hashCode % 100}.jpg',
                  sentAt: sentAt,
                  senderId: senderId,
                  receiverId: widget.currentUserId,
                ),
              ),
            );
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
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Icon(Icons.star_border, color: Colors.grey[600]),
            ],
          ),
        );
      },
    );
  }
}
