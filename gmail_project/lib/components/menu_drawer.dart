import 'package:flutter/material.dart';
import 'package:gmail_project/pages/starred_page.dart'; 
import 'package:gmail_project/pages/inbox_page.dart'; 


// ignore: use_key_in_widget_constructors
class MenuDrawer extends StatelessWidget {
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
    return Drawer(
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
                      // Replaced Image.asset with an Icon to avoid asset dependency
                      Icon(Icons.mail, color: Colors.red, size: 30),
                      SizedBox(width: 10),
                      Text("Gmail", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(color: Colors.grey[800]),
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.green, radius: 7),
                      SizedBox(width: 17),
                      Text("Active", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ],
                  ),
                  SizedBox(height: 5),
                  GestureDetector(
                    onTap: () {},
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
                onTap: () {
                  Navigator.pop(context); // close drawer

                  // chuyen trang
                  if (item["title"] == "Starred") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StarredPage()),
                    );
                  }
                  else if (item["title"] == "Inbox") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyHomePage()),
                    );
                  }
                },
                tileColor: item["highlight"] == true ? Colors.redAccent.withOpacity(0.2) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}