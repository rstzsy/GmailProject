import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/message_service.dart';

class EmailDetailPage extends StatefulWidget {
  final String subject;
  final String body;
  final String senderName;
  final String senderTitle;
  final String senderImageUrl;
  final String? sentAt;
  final String? senderId;
  final String? receiverId;
  final String? messageId;

  const EmailDetailPage({
    super.key,
    required this.subject,
    required this.body,
    required this.senderName,
    required this.senderTitle,
    required this.senderImageUrl,
    this.sentAt,
    this.senderId,
    this.receiverId,
    this.messageId,
  });

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
  bool showContent = true;
  bool isLoadingUserInfo = true;
  String displaySenderName = '';
  String displaySenderTitle = '';
  String displayReceiverName = '';

  bool isTrashDetail = false;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final MessageService _messageService = MessageService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _markMessageAsRead(); // Thêm function này

    // Kiểm tra route name để xác định có phải đang xem thư trong thùng rác không
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == '/trashDetail') {
        setState(() {
          isTrashDetail = true;
        });
      }
    });
  }

  // Thêm function để đánh dấu thư đã đọc
  Future<void> _markMessageAsRead() async {
    try {
      if (widget.messageId == null) {
        print('Message ID is null, cannot mark as read');
        return;
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        print('Current user is null, cannot mark as read');
        return;
      }

      print('Marking message as read - MessageID: ${widget.messageId}, UserID: $currentUserId');

      // Cập nhật is_read_recip trong internal_message_recipients
      await _db
          .child('internal_message_recipients')
          .child(widget.messageId!)
          .child(currentUserId)
          .update({'is_read_recip': true});

      // Kiểm tra xem user hiện tại có phải là sender không
      final isSender = currentUserId == widget.senderId;
      
      // Nếu là sender, cập nhật is_read trong internal_messages
      if (isSender) {
        await _db
            .child('internal_messages')
            .child(widget.messageId!)
            .update({'is_read': true});
      }

      // Cập nhật tất cả notifications liên quan đến message này thành đã đọc
      final notificationsSnapshot = await _db
          .child('notifications')
          .child(currentUserId)
          .orderByChild('message_id')
          .equalTo(widget.messageId!)
          .get();

      if (notificationsSnapshot.exists) {
        final notifications = notificationsSnapshot.value as Map<dynamic, dynamic>;
        for (var notificationKey in notifications.keys) {
          await _db
              .child('notifications')
              .child(currentUserId)
              .child(notificationKey)
              .update({'is_read': true});
        }
        print('Updated ${notifications.length} notifications as read');
      }

      print('Successfully marked message as read');
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      if (widget.senderId != null && widget.senderId!.isNotEmpty) {
        final senderSnapshot = await _db.child('users/${widget.senderId}').get();
        if (senderSnapshot.exists) {
          final senderData = senderSnapshot.value as Map<dynamic, dynamic>;
          displaySenderName = senderData['username'] ?? senderData['name'] ?? 'Unknown User';
          displaySenderTitle = senderData['email'] ?? senderData['title'] ?? '';
        }
      }

      if (widget.receiverId != null && widget.receiverId!.isNotEmpty) {
        final receiverSnapshot = await _db.child('users/${widget.receiverId}').get();
        if (receiverSnapshot.exists) {
          final receiverData = receiverSnapshot.value as Map<dynamic, dynamic>;
          displayReceiverName = receiverData['username'] ?? receiverData['name'] ?? 'Unknown Receiver';
        } else {
          displayReceiverName = 'Unknown Receiver';
        }
      } else {
        displayReceiverName = 'No Receiver';
      }

      if (displaySenderName.isEmpty) {
        displaySenderName = widget.senderName.isNotEmpty ? widget.senderName : 'Unknown User';
      }
      if (displaySenderTitle.isEmpty) {
        displaySenderTitle = widget.senderTitle;
      }
    } catch (e) {
      displaySenderName = widget.senderName.isNotEmpty ? widget.senderName : 'Unknown User';
      displaySenderTitle = widget.senderTitle;
      displayReceiverName = 'Error Loading Receiver';
    } finally {
      if (mounted) {
        setState(() {
          isLoadingUserInfo = false;
        });
      }
    }
  }

  void toggleContent() {
    setState(() {
      showContent = !showContent;
    });
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xác nhận xoá"),
        content: const Text("Bạn có chắc muốn chuyển thư này vào thùng rác không?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Đồng ý"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (widget.messageId != null) {
          // Lấy current user ID từ Firebase Auth
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          
          if (currentUserId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể xác định người dùng hiện tại')),
            );
            return;
          }

          // Kiểm tra user hiện tại là sender hay receiver
          final isSender = currentUserId == widget.senderId;
          
          print('Debug - Current User: $currentUserId');
          print('Debug - Sender ID: ${widget.senderId}');
          print('Debug - Receiver ID: ${widget.receiverId}');
          print('Debug - Is Sender: $isSender');
          print('Debug - Message ID: ${widget.messageId}');

          await _messageService.moveMessageToTrash(
            widget.messageId!,
            currentUserId,
            isSender: isSender,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thư đã được chuyển vào thùng rác')),
            );
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thiếu thông tin để xoá thư')),
          );
        }
      } catch (e) {
        print('Error deleting message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xoá thư: $e')),
        );
      }
    }
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
        actions: [
          if (!isTrashDetail)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _handleDelete,
            ),
      
          IconButton(
            icon: const Icon(Icons.mail_outline, color: Colors.white),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: toggleContent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(widget.senderImageUrl),
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: isLoadingUserInfo
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                      ),
                                    )
                                  : Text(
                                      displaySenderName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            if (widget.sentAt != null)
                              Text(
                                _formatDate(widget.sentAt!),
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (!isLoadingUserInfo)
                          Text(
                            displayReceiverName.isNotEmpty
                                ? 'To: $displayReceiverName'
                                : 'To: Loading...',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        if (!isLoadingUserInfo && displaySenderTitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              displaySenderTitle,
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (showContent)
              Text(
                widget.body,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFffcad4),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Đã nhấn Trả lời")),
              );
            },
            icon: const Icon(Icons.reply, color: Color(0xFFF4538A), size: 20),
            label: const Text(
              "Reply",
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFFF4538A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year}";
    } catch (e) {
      return "";
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}