import 'package:flutter/material.dart';

class ComposeEmailPage extends StatelessWidget {
  const ComposeEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController fromController = TextEditingController(text: 'user@example.com');
    final TextEditingController toController = TextEditingController();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController bodyController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Compose Email',
        ),
        backgroundColor: Colors.black, 
        titleTextStyle: TextStyle(
          color: Color(0xFFffcad4),
          fontWeight: FontWeight.bold,
          fontSize: 24, 
        ),
      ),
      backgroundColor: Colors.black, 
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [

            TextField(
              controller: fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                labelStyle: TextStyle(color: Colors.white), 
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white), 
                ),
              ),
              style: const TextStyle(color: Colors.white), 
            ),

            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: 'To',
                labelStyle: TextStyle(color: Colors.white),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: Colors.white),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),

            Expanded(
              child: TextField(
                controller: bodyController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  labelStyle: TextStyle(color: Colors.white),
                  border: InputBorder.none, 
                ),
                style: const TextStyle(color: Colors.white), 
                maxLines: null,
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.attach_file, color: Color(0xFFF4538A)),
                    label: const Text(
                      'Add Files',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18, 
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chức năng đính kèm chưa được triển khai.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFFF4538A), 
                      backgroundColor: Color(0xFFffcad4),
                    ),
                  ),
                ),

                const SizedBox(width: 16),
               
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print('Từ: ${fromController.text}');
                      print('Gửi đến: ${toController.text}');
                      print('Chủ đề: ${subjectController.text}');
                      print('Nội dung: ${bodyController.text}');
                    },
                    icon: const Icon(Icons.send, color: Color(0xFFF4538A)),
                    label: const Text(
                      'Send',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18, 
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Color(0xFFF4538A), 
                      backgroundColor: Color(0xFFffcad4),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
