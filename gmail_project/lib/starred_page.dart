import 'package:flutter/material.dart';
import 'search.dart';
import 'menu_drawer.dart';

class StarredPage extends StatefulWidget {
  const StarredPage({super.key});

  @override
  State<StarredPage> createState() => _StarredPageState();
}

class _StarredPageState extends State<StarredPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> users = [
    // {"id": 1, "fullName": "John Doe", "jobTitle": "Software Engineer"},
    // {"id": 2, "fullName": "Jane Smith", "jobTitle": "Product Manager"},
    
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      //--------search, drawer-----------
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
                    backgroundImage: NetworkImage('https://randomuser.me/api/portraits/men/1.jpg'),
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      //---------------------------------------

      // -----neu khong co du lieu se hien thi hinh anh mac dinh-----
      body: users.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/empty_starred.png', width: 150, height: 150),
                  const SizedBox(height: 20),
                  const Text("Nothing in starred folder", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            )
            //--------------------

          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                var user = users[index];
                return ListTile(
                  onTap: () {},
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      'https://randomuser.me/api/portraits/men/${user['id']}.jpg',
                    ),
                    radius: 25,
                  ),
                  title: Text(user["fullName"].toString(), style: const TextStyle(color: Colors.white)),
                  subtitle: Text(user["jobTitle"].toString(), style: const TextStyle(color: Colors.white70)),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("7 Mar", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(height: 4),
                      const Icon(Icons.star, color: Colors.yellow), // tô vàng ngôi sao
                    ],
                  ),
                );
              },
            ),

      // floatting button
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("Floating button pressed");
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color.fromARGB(255, 89, 89, 89),
      ),
      backgroundColor: const Color(0xFF121212),
    );
  }
}
