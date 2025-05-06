import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: MyListView(),
    );
  }
}

class MyListView extends StatefulWidget {
  @override
  _MyListViewState createState() => _MyListViewState();
}

class _MyListViewState extends State<MyListView> {
  int _selectedIndex = 0; 

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Map<String, dynamic>> users = [
    {"id": 1, "fullName": "John Doe", "jobTitle": "Software Engineer"},
    {"id": 2, "fullName": "Jane Smith", "jobTitle": "Product Manager"},
    {"id": 3, "fullName": "Michael Johnson", "jobTitle": "UX Designer"},
    {"id": 4, "fullName": "Sarah Lee", "jobTitle": "Data Scientist"},
    {"id": 5, "fullName": "David Brown", "jobTitle": "DevOps Engineer"},
    {"id": 6, "fullName": "Emily Davis", "jobTitle": "Quality Assurance Analyst"},
    {"id": 7, "fullName": "William Garcia", "jobTitle": "Front-end Developer"},
    {"id": 8, "fullName": "Ashley Rodriguez", "jobTitle": "Business Analyst"},
    {"id": 9, "fullName": "Matthew Wilson", "jobTitle": "Full-stack Developer"},
    {"id": 10, "fullName": "Olivia Taylor", "jobTitle": "Project Manager"},
    {
      "id": 11,
      "fullName": "James Anderson",
      "jobTitle": "Database Administrator"
    },
    {"id": 12, "fullName": "Isabella Thomas", "jobTitle": "Data Analyst"},
    {"id": 13, "fullName": "Alexander Jackson", "jobTitle": "Mobile Developer"},
    {"id": 14, "fullName": "Ava Miller", "jobTitle": "Quality Engineer"},
    {"id": 15, "fullName": "Ethan Davis", "jobTitle": "Systems Administrator"}
  ];

  final List<Map<String, dynamic>> menuItems = [
    {"title": "All inboxes", "icon": Icons.all_inbox, "count": "99+"},
    {"divider": true},
    {"title": "Inbox", "icon": Icons.inbox_outlined, "count": 48, "highlight": true},
    {"divider": true},
    {"title": "Starred", "icon": Icons.star_border},
    {"title": "Snoozed", "icon": Icons.access_time},
    {"title": "Important", "icon": Icons.label_important_outline, "count": 43},
    {"title": "Sent", "icon": Icons.send_outlined},
    {"title": "Scheduled", "icon": Icons.schedule_outlined},
    {"title": "Outbox", "icon": Icons.outbox_outlined},
    {"title": "Drafts", "icon": Icons.drafts_outlined, "count": 2},
    {"title": "All emails", "icon": Icons.mail_outline},
    {"title": "Spam", "icon": Icons.report_gmailerrorred_outlined},
    {"title": "Bin", "icon": Icons.delete_outline},
    {"divider": true},
    {"title": "Create new", "icon": Icons.add},
    {"divider": true},
    {"title": "Setting", "icon": Icons.settings},
    {"title": "Send feedback", "icon": Icons.feedback},
    {"title": "Help", "icon": Icons.help},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          color: Color(0xFF121212), 
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF121212),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset("assets/gmail.png", width: 30, height: 30), 
                        SizedBox(width: 10),
                        Text("Gmail", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(),

                    Row(
                      children: [
                        CircleAvatar(backgroundColor: Colors.green, radius: 7),
                        SizedBox(width: 17),
                        Text("Active", style: TextStyle(fontSize: 16, color: Colors.white)),
                      ],
                    ),
                    SizedBox(height: 5),
                    GestureDetector(
                      onTap: () {
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: Colors.white70, size: 18), 
                            SizedBox(width: 12),
                            Text(
                              "Add a status",
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    
                  ],
                ),
              ),
              

              ...menuItems.map((item) {
                if (item.containsKey("divider")) {
                  return Divider(color: Colors.grey[800]);
                }
                return ListTile(
                  leading: Icon(item["icon"], color: Colors.white70),
                  title: Text(
                    item["title"],
                    style: TextStyle(
                      fontSize: 16,
                      color: item["highlight"] == true ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                  trailing: item.containsKey("count")
                      ? Text(
                          item["count"].toString(),
                          style: TextStyle(color: Colors.white70),
                        )
                      : null,
                  onTap: () {},
                  tileColor: item["highlight"] == true ? Colors.redAccent.withOpacity(0.2) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }),
            ],
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(65),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 55, 54, 54),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color.fromARGB(255, 59, 58, 58), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: const Color.fromARGB(221, 232, 229, 229)),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 45,
                      child: Row(
                        children: [
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search in mail",
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey[600]),
                              ),
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  CircleAvatar(
                    backgroundImage: NetworkImage(
                        'https://randomuser.me/api/portraits/men/1.jpg'),
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              "Inbox",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400], 
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                  title: Text(user["fullName"].toString()),
                  subtitle: Text(user["jobTitle"].toString()),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "7 Mar",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Icon(Icons.star_border, color: Colors.grey[600]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 48, 46, 46),
        selectedItemColor: const Color.fromARGB(255, 247, 154, 142),
        unselectedItemColor: const Color.fromARGB(255, 119, 115, 115),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: false,  
        showUnselectedLabels: false,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: '',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
        },
        label: Text(
          'Compose',
          style: TextStyle(
            color: const Color.fromARGB(255, 235, 139, 139),
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: Icon(Icons.edit, color: const Color.fromARGB(255, 235, 139, 139)),
        backgroundColor: Color.fromARGB(255, 63, 62, 62), 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25), 
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, 
    );
    
  }
}
