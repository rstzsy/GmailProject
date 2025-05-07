import 'package:flutter/material.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import 'composeEmail_page.dart';

class DraftPage extends StatefulWidget {
  const DraftPage({super.key});

  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> drafts = [
    // {
    //   "id": 1,
    //   "recipient": "",
    //   "subject": "Weekly Report",
    //   "content": "Here is the draft for this week's report...",
    //   "date": "6 May",
    // },
    // {
    //   "id": 2,
    //   "recipient": "bob@example.com",
    //   "subject": "",
    //   "content": "Don't forget our meeting tomorrow at 10 AM.",
    //   "date": "5 May",
    // },
  ];

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
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 3))],
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
                    backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/3.jpg'),
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: drafts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/empty_draft.png', width: 150, height: 150),
                  const SizedBox(height: 20),
                  const Text("Nothing in Draft folder", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: drafts.length,
              itemBuilder: (context, index) {
                var draft = drafts[index];
                return ListTile(
                  onTap: () {
                    // xu li khi nhan vao email
                  },
                  leading: const Icon(Icons.drafts, color: Colors.white),
                  title: Text(
                    "Drafts",
                    style: const TextStyle(color: Colors.red),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft["recipient"].isEmpty ? "Không có người nhận" : draft["recipient"].split('@')[0], 
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        draft["subject"].isEmpty ? "Không có chủ đề" : draft["subject"],
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        draft["content"],
                        style: const TextStyle(color: Colors.white54),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        draft["date"],
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
      backgroundColor: const Color(0xFF121212),
    );
  }
}
