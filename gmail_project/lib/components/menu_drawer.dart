import 'package:flutter/material.dart';
import 'package:gmail_project/components/label.dart';
import 'package:gmail_project/pages/starred_page.dart';
import 'package:gmail_project/pages/inbox_page.dart';
import 'package:gmail_project/pages/sent_page.dart';
import 'package:gmail_project/pages/draft_page.dart';
import 'package:gmail_project/pages/trash_page.dart';
import 'package:gmail_project/pages/donotdisturb_page.dart';
import 'package:gmail_project/components/NewLabelDialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ignore: use_key_in_widget_constructors
class MenuDrawer extends StatefulWidget {
  @override
  State<MenuDrawer> createState() => _MenuDrawerState();
}

class _MenuDrawerState extends State<MenuDrawer> {
  bool isActive = true; // State variable to track active/inactive status

  List<String> userLabels = [];
  @override
  void initState() {
    super.initState();
    _loadUserLabels();
  }

  void _loadUserLabels() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final DatabaseReference labelsRef = FirebaseDatabase.instance.ref(
      'users/$uid/labels',
    );
    final snapshot = await labelsRef.get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        userLabels =
            data.values.map((labelData) {
              return (labelData as Map)['name'] as String;
            }).toList();
      });
    }
  }

  void _editLabel(String oldLabel) async {
    // Example: Show a dialog to input a new label name
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) {
        String? updatedLabel;
        return AlertDialog(
          title: const Text('Edit Label'),
          content: TextField(
            onChanged: (value) => updatedLabel = value,
            decoration: const InputDecoration(hintText: 'Enter new label name'),
            controller: TextEditingController(text: oldLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, updatedLabel),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newLabel != null && newLabel.isNotEmpty) {
      setState(() {
        final index = userLabels.indexOf(oldLabel);
        if (index != -1) {
          userLabels[index] = newLabel;
        }
      });
      // Optionally, persist the change (e.g., to a backend or local storage)
    }
  }

  Future<void> _deleteLabel(String label) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print(' Người dùng chưa đăng nhập');
      return;
    }

    try {
      // Tùy chọn 1: Xóa nhãn khỏi node users/$uid/labels (nếu nhãn là danh sách riêng)
      final labelRef = FirebaseDatabase.instance.ref('users/$uid/labels');
      await labelRef.remove();
      print('Đã xóa nhãn "$label" khỏi danh sách nhãn của người dùng');

      // Tùy chọn 2: Xóa nhãn khỏi tất cả email trong internal_messages
      final messagesRef = FirebaseDatabase.instance.ref('internal_messages');
      final snapshot = await messagesRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
        for (var entry in data.entries) {
          final messageId = entry.key.toString();
          final messageData = Map<String, dynamic>.from(entry.value as Map);
          final labels = messageData['labels'] as Map<dynamic, dynamic>?;

          if (labels != null &&
              labels.containsKey(label) &&
              labels[label] == true) {
            final labelToRemoveRef = messagesRef.child(
              '$messageId/labels/$label',
            );
            await labelToRemoveRef.remove();
            print(' Đã xóa nhãn "$label" khỏi email $messageId');
          }
        }
      }
    } catch (e) {
      print(' Lỗi khi xóa nhãn: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa nhãn: $e')));
      }
    }
  }

  void _showMessagesWithLabel(String labelName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Người dùng chưa đăng nhập')),
      );
      return;
    }

    final DatabaseReference labelsRef = FirebaseDatabase.instance.ref(
      'users/$uid/labels',
    );
    final snapshot = await labelsRef.get();

    String? labelId;
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      labelId =
          data.entries
              .firstWhere(
                (entry) =>
                    (entry.value as Map).containsKey('name') &&
                    (entry.value as Map)['name'] == labelName,
                orElse: () => MapEntry('', {}),
              )
              .key;
    }

    print('Label Name: $labelName, Label ID: $labelId');

    if (labelId != null && labelId.isNotEmpty) {
      print('Hiển thị email với labelId: $labelId');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => MessagesByLabelScreen(
                labelId: labelId!, // Truyền labelId
                labelName: labelName, // Truyền labelName (tên hiển thị)
              ),
        ),
      );
    } else {
      print('Không tìm thấy nhãn: $labelName');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy nhãn: $labelName')),
      );
    }
  }

  Future<bool> _assignLabelToMail(String mailId, String labelId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print('Người dùng chưa đăng nhập');
      return false;
    }

    try {
      // Gán nhãn trong users/$uid/morsoails
      final mailLabelRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(uid)
          .child('mails')
          .child(mailId)
          .child('labels')
          .child(labelId);
      await mailLabelRef.set(true);

      // Đồng thời gán nhãn trong internal_messages/labels
      final messageLabelRef = FirebaseDatabase.instance
          .ref()
          .child('internal_messages')
          .child(mailId)
          .child('labels')
          .child(labelId);
      await messageLabelRef.set(true);

      print('Đã gán mail $mailId vào label $labelId');
      return true;
    } catch (e) {
      print(' Gán thất bại: $e');
      return false;
    }
  }

  final List<Map<String, dynamic>> menuItems = [
    {"title": "All inboxes", "icon": Icons.all_inbox, "count": "99+"},
    {"divider": true},
    {
      "title": "Inbox",
      "icon": Icons.inbox_outlined,
      "count": 48,
      "highlight": true,
    },
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
    {"title": "Labels", "icon": Icons.label_outline},
    {"divider": true},
    {"title": "Setting", "icon": Icons.settings},
    {"title": "Send feedback", "icon": Icons.feedback},
    {"title": "Help", "icon": Icons.help},
  ];

  // Show dropdown menu for status selection
  void _showStatusMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
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
                  decoration: const BoxDecoration(color: Color(0xFF121212)),
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
                          const Text(
                            "Gmail",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Divider(color: Colors.grey[800], height: 12),

                      // Active/Inactive status menu button
                      Builder(
                        builder:
                            (context) => InkWell(
                              onTap: () => _showStatusMenu(context),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        isActive ? Colors.green : Colors.red,
                                    radius: 7,
                                  ),
                                  const SizedBox(width: 17),
                                  Text(
                                    isActive ? "Active" : "Inactive",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                title: const Text(
                  "Add a status",
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                dense: true,
                visualDensity: const VisualDensity(vertical: -3),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                onTap: () {
                  // Add status functionality
                },
              ),
              const SizedBox(height: 2),
              ...menuItems.map((item) {
                if (item.containsKey("divider")) {
                  return Divider(height: 4, color: Colors.grey[800]);
                }
                if (item["title"] == "Labels") {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -1),
                        leading: Icon(item["icon"], color: Colors.white70),
                        title: Text(
                          item["title"],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white70),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return NewLabelDialog();
                              },
                            );
                          },
                        ),
                      ),
                      //Hiển thị các nhãn người dùng
                      ...userLabels
                          .map(
                            (label) => ListTile(
                              onTap: () {
                                // Gọi hàm để lọc hoặc chuyển đến màn hình chứa các message có label này
                                _showMessagesWithLabel(label);
                              },
                              leading: const Icon(
                                Icons.label_outline,
                                color: Colors.white70,
                                size: 20,
                              ),
                              title: Text(
                                label,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    print('Sửa nhãn: $label');
                                    // Add logic to edit the label (e.g., show a dialog to input a new label name)
                                    _editLabel(label);
                                  } else if (value == 'delete') {
                                    print('Xóa nhãn: $label');
                                    // Remove the label from the list and update the state
                                    setState(() {
                                      userLabels.remove(label);
                                    });
                                    // Optionally, persist the change (e.g., to a backend or local storage)
                                    _deleteLabel(label);
                                  }
                                },
                                itemBuilder:
                                    (BuildContext context) =>
                                        <PopupMenuEntry<String>>[
                                          const PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  );
                }
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  leading: Icon(item["icon"], color: Colors.white70),
                  title: Text(
                    item["title"],
                    style: TextStyle(
                      fontSize: 16,
                      color:
                          item["highlight"] == true
                              ? Colors.redAccent
                              : Colors.white70,
                    ),
                  ),
                  trailing:
                      item["title"] == "Labels"
                          ? IconButton(
                            icon: const Icon(Icons.add, color: Colors.white70),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return NewLabelDialog(); // gọi widget dialog
                                },
                              );
                            },
                          )
                          : item.containsKey("count")
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
                        MaterialPageRoute(
                          builder: (context) => const StarredPage(),
                        ),
                      );
                    } else if (item["title"] == "Inbox") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyHomePage(),
                        ),
                      );
                    } else if (item["title"] == "Sent") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SentPage(),
                        ),
                      );
                    } else if (item["title"] == "Drafts") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DraftPage(),
                        ),
                      );
                    } else if (item["title"] == "Bin") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrashPage(),
                        ),
                      );
                    }
                  },
                  tileColor:
                      item["highlight"] == true
                          ? Colors.redAccent.withOpacity(0.2)
                          : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}

