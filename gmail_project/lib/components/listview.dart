import 'package:flutter/material.dart';
import '../pages/emailDetail_page.dart';
import '../services/message_service.dart';

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

  @override
  void initState() {
    super.initState();
    loadMessages();
  }

  Future<void> loadMessages() async {
    final service = MessageService();
    final result = await service.loadInboxMessages(widget.currentUserId);
    setState(() {
      allMessages = result;
      messages = result;
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
        final subject = msg['subject']?.toLowerCase() ?? '';
        final body = msg['body']?.toLowerCase() ?? '';
        return subject.contains(lowerQuery) || body.contains(lowerQuery);
      }).toList();
    });
  }

  // Đã bổ sung receiverId và isSender=false (người nhận)
  Future<void> _toggleStar(String messageId, bool newStatus) async {
    // Cập nhật local state ngay để UI phản hồi nhanh
    setState(() {
      final index = messages.indexWhere((msg) => msg['message_id'] == messageId);
      if (index != -1) {
        messages[index]['is_starred_recip'] = newStatus;
      }
    });

    // Cập nhật lên Firebase
    await MessageService().updateStarStatus(
      messageId,
      newStatus,
      widget.currentUserId,
      isSender: false,
    );

    // Tải lại danh sách để đồng bộ dữ liệu thật
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
        
        // Lấy trạng thái sao riêng của người nhận trong internal_message_recipients
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
                )
              ),
            );

            if (result == true) {
              loadMessages(); 
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
                onTap: () =>
                    _toggleStar(message['message_id'], !isStarred),
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
