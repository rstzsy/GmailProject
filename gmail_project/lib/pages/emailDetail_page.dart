import 'package:flutter/material.dart';
import 'package:gmail_project/pages/inbox_page.dart'; 


class EmailDetailPage extends StatefulWidget {
  final String fullName;
  final String jobTitle;
  final String imageUrl;

  const EmailDetailPage({
    super.key,
    required this.fullName,
    required this.jobTitle,
    required this.imageUrl,
  });

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage> {
  bool showContent = true;

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
                Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyHomePage()),
                      );
              }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'THÔNG BÁO Về việc triển khai cài đặt ứng dụng Công dân số TPHCM',
              style: TextStyle(
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
                    backgroundImage: NetworkImage(widget.imageUrl),
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.jobTitle,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (showContent)
              const Text(
                '''
Thân gửi sinh viên,

Nhằm triển khai hiệu quả Nghị quyết số 57-NQ/TW ngày 22/12/2024 của Bộ Chính trị về đột phá phát triển khoa học, công nghệ, đổi mới sáng tạo và chuyển đổi số quốc gia; đồng thời thực hiện theo chủ đề năm 2025 của Thành phố Hồ Chí Minh với trọng tâm là công tác chuyển đổi số,

Hưởng ứng phong trào “Hãy trở thành công dân số Thành phố Hồ Chí Minh”,

Phòng Công tác học sinh – sinh viên thông báo đến toàn thể sinh viên thực hiện việc cài đặt và sử dụng ứng dụng Công dân số TPHCM để tiếp cận các tiện ích số và chung tay xây dựng thành phố thông minh, hiện đại.

🗓 Thời gian thực hiện: Từ nay đến hết ngày 11/5/2025.
👥 Đối tượng: Toàn thể sinh viên đang theo học tại trường.
📲 Ứng dụng: Công dân số TPHCM (tải trên App Store/Google Play).

Việc cài đặt ứng dụng là hành động thiết thực nhằm nâng cao ý thức công dân số, đồng thời phục vụ tốt hơn cho học tập, sinh hoạt và tiếp cận các dịch vụ công một cách tiện lợi, nhanh chóng.
                ''',
                style: TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFffcad4),
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
            icon: const Icon(Icons.reply, color: Color(0xFFF4538A), size: 20,),
            label: const Text(
              "Reply",
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFFF4538A),
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
      ),
    );
  }
}
