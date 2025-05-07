import 'package:flutter/material.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import 'composeEmail_page.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> trashItems = [
    {
      "id": 1,
      "sender": "alice@example.com",
      "subject": "Old Report",
      "content": "This is an outdated report...",
      "date": "3 Apr"
    },
    {
      "id": 2,
      "sender": "",
      "subject": "",
      "content": "Meeting notes that are no longer needed.",
      "date": "28 Mar"
    },
  ];

  void _clearTrash() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmation", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to empty the trash? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        trashItems.clear();
      });
    }
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
                    backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/4.jpg'),
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10), 
          trashItems.isEmpty
              ? Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/empty_trash.png', width: 150, height: 150),
                        const SizedBox(height: 20),
                        const Text("Nothing in Trash", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: Colors.grey[850],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Items in the trash for more than 30 days are automatically deleted.",
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _clearTrash,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFffcad4),
                              ),
                              child: const Text("Empty Trash", style: TextStyle(color: Color(0xFFF4538A))),
                            )
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: trashItems.length,
                          itemBuilder: (context, index) {
                            var item = trashItems[index];
                            return ListTile(
                              leading: const Icon(Icons.delete_outline, color: Colors.white),
                              title: Text(
                                item["sender"].isEmpty ? "Không rõ người gửi" : item["sender"],
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["subject"].isEmpty ? "Không có chủ đề" : item["subject"],
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    item["content"],
                                    style: const TextStyle(color: Colors.white54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              trailing: Text(
                                item["date"],
                                style: TextStyle(color: Colors.grey[400], fontSize: 14),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ],
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
