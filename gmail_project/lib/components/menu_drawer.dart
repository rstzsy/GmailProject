import 'package:flutter/material.dart';
import 'package:gmail_project/pages/starred_page.dart'; 
import 'package:gmail_project/pages/inbox_page.dart'; 
import 'package:gmail_project/pages/sent_page.dart'; 
import 'package:gmail_project/pages/draft_page.dart'; 
import 'package:gmail_project/pages/trash_page.dart'; 
import 'package:gmail_project/pages/donotdisturb_page.dart';

// ignore: use_key_in_widget_constructors
class MenuDrawer extends StatefulWidget {
  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  bool isActive = true; // State variable to track active/inactive status
  
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

  // Show dropdown menu for status selection
  void _showStatusMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    String? result = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1F1F1F),
      items: [
        PopupMenuItem<String>(
          value: 'active',
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.green, radius: 7),
              const SizedBox(width: 15),
              const Text('Active', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'inactive',
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.red, radius: 7),
              const SizedBox(width: 15),
              const Text('Inactive', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );

    if (result == 'active') {
      setState(() {
        isActive = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Status changed to Active"),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (result == 'inactive') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DoNotDisturbPage()),
      ).then((value) {
        if (value != null) {
          setState(() {
            isActive = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Container(
        color: const Color(0xFF121212), 
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              SizedBox(
                height: 120, 
                child: DrawerHeader(
                  decoration: const BoxDecoration(
                    color: Color(0xFF121212),
                  ),
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.mail, color: Colors.red, size: 30),
                          const SizedBox(width: 10),
                          const Text("Gmail", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Divider(color: Colors.grey[800], height: 12),
                      
                      // Active/Inactive status menu button
                      Builder(
                        builder: (context) => InkWell(
                          onTap: () => _showStatusMenu(context),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isActive ? Colors.green : Colors.red,
                                radius: 7
                              ),
                              const SizedBox(width: 17),
                              Text(
                                isActive ? "Active" : "Inactive", 
                                style: const TextStyle(fontSize: 16, color: Colors.white)
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                title: const Text(
                  "Add a status", 
                  style: TextStyle(fontSize: 16, color: Colors.white70)
                ),
                dense: true,
                visualDensity: const VisualDensity(vertical: -3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                onTap: () {
                  // Add status functionality
                },
              ),
              const SizedBox(height: 2),
              ...menuItems.map((item) {
                if (item.containsKey("divider")) {
                  return Divider(height: 4, color: Colors.grey[800]);
                }

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
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
                          style: const TextStyle(color: Colors.white70),
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
                    else if (item["title"] == "Sent") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SentPage()),
                      );
                    }
                    else if (item["title"] == "Drafts") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DraftPage()),
                      );
                    }
                    else if (item["title"] == "Bin") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TrashPage()),
                      );
                    }
                  },
                  tileColor: item["highlight"] == true ? Colors.redAccent.withOpacity(0.2) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}