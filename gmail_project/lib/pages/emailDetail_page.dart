import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EmailDetailPage extends StatefulWidget {
  final String subject;
  final String body;
  final String senderName; // Có thể để trống, sẽ load từ database
  final String senderTitle; // Có thể để trống, sẽ load từ database
  final String senderImageUrl;
  final String? sentAt;

  // Thêm senderId và receiverId nếu bạn cần
  final String? senderId;
  final String? receiverId;

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
  });

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
  bool showContent = true;
  bool isLoadingUserInfo = true;
  
  // Thông tin người dùng được load từ database
  String displaySenderName = '';
  String displaySenderTitle = '';
  String displayReceiverName = '';

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      // Load thông tin người gửi
      if (widget.senderId != null && widget.senderId!.isNotEmpty) {
        print('Loading sender info for ID: ${widget.senderId}');
        final senderSnapshot = await _db.child('users/${widget.senderId}').get();
        if (senderSnapshot.exists) {
          final senderData = senderSnapshot.value as Map<dynamic, dynamic>;
          displaySenderName = senderData['username'] ?? senderData['name'] ?? 'Unknown User';
          displaySenderTitle = senderData['email'] ?? senderData['title'] ?? '';
          print('Sender loaded: $displaySenderName');
        } else {
          print('Sender not found in database');
        }
      }

      // Load thông tin người nhận
      if (widget.receiverId != null && widget.receiverId!.isNotEmpty) {
        print('Loading receiver info for ID: ${widget.receiverId}');
        final receiverSnapshot = await _db.child('users/${widget.receiverId}').get();
        if (receiverSnapshot.exists) {
          final receiverData = receiverSnapshot.value as Map<dynamic, dynamic>;
          displayReceiverName = receiverData['username'] ?? receiverData['name'] ?? 'Unknown Receiver';
          print('Receiver loaded: $displayReceiverName');
        } else {
          print('Receiver not found in database');
          displayReceiverName = 'Unknown Receiver';
        }
      } else {
        print('No receiver ID provided');
        displayReceiverName = 'No Receiver';
      }

      // Fallback to widget values if database doesn't have info
      if (displaySenderName.isEmpty) {
        displaySenderName = widget.senderName.isNotEmpty ? widget.senderName : 'Unknown User';
      }
      if (displaySenderTitle.isEmpty) {
        displaySenderTitle = widget.senderTitle;
      }

    } catch (e) {
      print('Error loading user info: $e');
      // Fallback to widget values
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.mail_outline, color: Colors.white),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              }),
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
                        // Hàng đầu: Tên người gửi và thời gian gửi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Hiển thị loading hoặc tên người gửi
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
                            // Thời gian gửi ở bên phải
                            if (widget.sentAt != null)
                              Text(
                                _formatDate(widget.sentAt!),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Hiển thị thông tin người nhận - luôn hiển thị nếu không đang loading
                        if (!isLoadingUserInfo)
                          Text(
                            displayReceiverName.isNotEmpty 
                                ? 'To: $displayReceiverName' 
                                : 'To: Loading...',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        // Hiển thị email hoặc title của người gửi
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
                style:
                    const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
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