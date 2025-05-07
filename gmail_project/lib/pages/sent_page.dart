import 'package:flutter/material.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import 'composeEmail_page.dart';

class SentPage extends StatefulWidget {
  const SentPage({super.key});

  @override
  State<SentPage> createState() => _SentPageState();
}

class _SentPageState extends State<SentPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> sentEmails = [
    // {
    //   "id": 5,
    //   "fullName": "David Johnson",
    //   "jobTitle": "Marketing Lead",
    //   "recipient": "to: alice@example.com",
    //   "date": "6 May",
    // },
    // {
    //   "id": 7,
    //   "fullName": "Emily Clark",
    //   "jobTitle": "UX Designer",
    //   "recipient": "to: bob@example.com",
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
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 3)),
              ],
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
                    backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/2.jpg'),
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: sentEmails.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/empty_sent.png', width: 150, height: 150),
                  const SizedBox(height: 20),
                  const Text("No sent emails", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: sentEmails.length,
              itemBuilder: (context, index) {
                var email = sentEmails[index];
                return ListTile(
                  onTap: () {},
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      'https://randomuser.me/api/portraits/men/${email['id']}.jpg',
                    ),
                    radius: 25,
                  ),
                  title: Text(
                    email["recipient"].split('@')[0], 
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email["jobTitle"], style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(email["date"], style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(height: 4),
                      const Icon(Icons.star_outline),
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
