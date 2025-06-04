import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/message_service.dart';
import 'replyEmail_page.dart'; 
import 'forwardEmail_page.dart';

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
  bool isLoadingAttachments = true;
  String displaySenderName = '';
  String displaySenderTitle = '';
  String displayReceiverName = '';
  List<Map<String, String>> attachments = [];

  bool isTrashDetail = false;

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final MessageService _messageService = MessageService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadAttachments();
    _markMessageAsRead();

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

  // Load attachments từ Firebase
  Future<void> _loadAttachments() async {
    try {
      if (widget.messageId == null) {
        setState(() {
          isLoadingAttachments = false;
        });
        return;
      }

      final messageSnapshot = await _db
          .child('internal_messages')
          .child(widget.messageId!)
          .get();

      if (messageSnapshot.exists) {
        final messageData = messageSnapshot.value as Map<dynamic, dynamic>;
        if (messageData.containsKey('attachments')) {
          final attachmentsData = messageData['attachments'];
          if (attachmentsData is List) {
            attachments = attachmentsData
                .map((item) => Map<String, String>.from(item as Map))
                .toList();
          }
        }
      }
    } catch (e) {
      print('Error loading attachments: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAttachments = false;
        });
      }
    }
  }

  // Function để đánh dấu thư đã đọc
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

  // Function để download/mở attachment
  Future<void> _openAttachment(String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open $fileName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening $fileName: $e')),
        );
      }
    }
  }

  // Function để format file size
  String _formatFileSize(String sizeStr) {
    try {
      final size = int.parse(sizeStr);
      if (size < 1024) {
        return '${size}B';
      } else if (size < 1024 * 1024) {
        return '${(size / 1024).toStringAsFixed(1)}KB';
      } else {
        return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
      }
    } catch (e) {
      return sizeStr;
    }
  }

  // Function để lấy icon cho file type
  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Widget để hiển thị attachments
  Widget _buildAttachmentsSection() {
    if (isLoadingAttachments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFffcad4),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.attach_file, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              'Attachments (${attachments.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...attachments.map((attachment) => _buildAttachmentItem(attachment)),
      ],
    );
  }

  Widget _buildAttachmentItem(Map<String, String> attachment) {
    final fileName = attachment['name'] ?? 'Unknown File';
    final fileSize = attachment['size'] ?? '0';
    final fileType = attachment['type'] ?? '';
    final fileUrl = attachment['url'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: InkWell(
        onTap: () => _openAttachment(fileUrl, fileName),
        child: Row(
          children: [
            Icon(
              _getFileIcon(fileType),
              color: const Color(0xFFffcad4),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(fileSize),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.download,
              color: Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
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

  // Function để navigate tới trang Reply
  void _navigateToReply() async {
    if (widget.messageId == null || widget.senderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể reply: thiếu thông tin tin nhắn')),
      );
      return;
    }

    // Kiểm tra xem có thể reply không (không reply cho chính mình)
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == widget.senderId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể reply cho tin nhắn của chính bạn')),
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReplyEmailPage(
            originalMessageId: widget.messageId!,
            originalSubject: widget.subject,
            originalBody: widget.body,
            originalSenderName: displaySenderName.isNotEmpty ? displaySenderName : widget.senderName,
            originalSenderId: widget.senderId!,
            originalSentAt: widget.sentAt,
          ),
        ),
      );

      // Nếu reply thành công, có thể refresh data hoặc hiển thị thông báo
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply đã được gửi thành công!')),
        );
      }
    } catch (e) {
      print('Error navigating to reply page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi mở trang reply: $e')),
      );
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
        title: attachments.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file, color: Color(0xFFffcad4), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${attachments.length}',
                    style: const TextStyle(
                      color: Color(0xFFffcad4),
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : null,
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
            // Hiển thị attachments
            _buildAttachmentsSection(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Reply Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFffcad4),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _navigateToReply,
                  icon: const Icon(Icons.reply, color: Color(0xFFF4538A), size: 20),
                  label: const Text(
                    "Reply",
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFFF4538A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Forward Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E8),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _navigateToForward,
                  icon: const Icon(Icons.forward, color: Color(0xFF4CAF50), size: 20),
                  label: const Text(
                    "Forward",
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
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

  Future<void> _navigateToForward() async {
    if (widget.messageId == null || widget.senderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể forward: thiếu thông tin tin nhắn')),
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForwardEmailPage(
            originalMessageId: widget.messageId!,
            originalSubject: widget.subject,
            originalBody: widget.body,
            originalSenderName: displaySenderName.isNotEmpty ? displaySenderName : widget.senderName,
            originalSenderId: widget.senderId!,
            originalSentAt: widget.sentAt,
          ),
        ),
      );

      // Nếu forward thành công, hiển thị thông báo
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forward đã được gửi thành công!')),
        );
      }
    } catch (e) {
      print('Error navigating to forward page: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi mở trang forward: $e')),
      );
    }
  }
}