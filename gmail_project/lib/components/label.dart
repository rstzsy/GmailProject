import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class MessagesByLabelScreen extends StatefulWidget {
  final String labelId; // Clearer naming: labelId instead of label
  final String labelName; // Added for displaying label name in UI

  const MessagesByLabelScreen({
    super.key,
    required this.labelId,
    required this.labelName,
  });

  @override
  _MessagesByLabelScreenState createState() => _MessagesByLabelScreenState();
}

class _MessagesByLabelScreenState extends State<MessagesByLabelScreen> {
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  String? errorMessage;
  String? searchFilter;
  bool _notificationEnabled = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    fetchUserAvatar();
    _loadMessages();
  }

  void fetchUserAvatar() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _avatarUrl = user.photoURL;
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          errorMessage = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      final DatabaseReference messagesRef = FirebaseDatabase.instance.ref(
        'users/$uid/mails',
      );
      final snapshot = await messagesRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
        List<Map<String, dynamic>> tempMessages = [];

        for (var entry in data.entries) {
          final messageId = entry.key.toString();
          final messageData = Map<String, dynamic>.from(entry.value as Map);
          messageData['id'] = messageId;

          final labels = messageData['labels'] as Map<dynamic, dynamic>?;
          final hasLabel = labels != null && labels[widget.labelId] == true;

          if (hasLabel) {
            final internalSnapshot =
                await FirebaseDatabase.instance
                    .ref('internal_messages/$messageId')
                    .get();
            if (internalSnapshot.exists) {
              final messageContent = Map<String, dynamic>.from(
                internalSnapshot.value as Map,
              );
              messageContent['id'] = messageId;
              tempMessages.add(messageContent);
            }
          }
        }

        setState(() {
          messages = tempMessages;
        });
      } else {
        setState(() {
          messages = [];
        });
      }
    } catch (e) {
      setState(() {
        messages = [];
        errorMessage = 'Error loading emails: $e';
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading emails: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredMessages {
    if (searchFilter == null || searchFilter!.isEmpty) return messages;
    return messages.where((message) {
      final subject = message['subject']?.toString().toLowerCase() ?? '';
      final body = message['body']?.toString().toLowerCase() ?? '';
      final senderId = message['sender_id']?.toString().toLowerCase() ?? '';
      final query = searchFilter!.toLowerCase();
      return subject.contains(query) ||
          body.contains(query) ||
          senderId.contains(query);
    }).toList();
  }

  void _selectDateFilter() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          messages = messages.where((message) {
            if (message['sent_at'] == null) return false;
            final sentDate =
                DateTime.tryParse(message['sent_at']) ?? DateTime(2000);
            return sentDate.year == selectedDate.year &&
                sentDate.month == selectedDate.month &&
                sentDate.day == selectedDate.day;
          }).toList();
        });
      }
    });
  }

  void _testNotification() {
    setState(() {
      _notificationEnabled = !_notificationEnabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_notificationEnabled ? 'Notifications enabled' : 'Notifications disabled'),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 15,
      backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
      backgroundColor: Colors.grey,
      child: _avatarUrl == null
          ? Text(
              FirebaseAuth.instance.currentUser?.displayName
                      ?.substring(0, 1)
                      .toUpperCase() ??
                  'A',
              style: const TextStyle(color: Colors.white),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(child: Text("Menu")),
            ListTile(title: Text("Other options")),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          'Emails with label: ${widget.labelName}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMessages),
        ],
      ),
      body: Container(
        color: const Color(0xFF121212),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              )
            : errorMessage != null
                ? Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : filteredMessages.isEmpty
                    ? const Center(
                        child: Text(
                          'No emails found with this label',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) {
                          final message = filteredMessages[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF6B46C1),
                              child: Text(
                                message['subject']?.substring(0, 1) ?? '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              message['subject'] ?? 'No subject',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              message['body'] ?? 'No content',
                              style: const TextStyle(color: Colors.white54),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'search',
            onPressed: _selectDateFilter,
            tooltip: 'Filter by date',
            backgroundColor: Colors.pink,
            child: const Icon(Icons.date_range),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'notify',
            onPressed: _testNotification,
            tooltip: 'Toggle notifications',
            backgroundColor: _notificationEnabled ? Colors.green : Colors.grey,
            child: const Icon(Icons.notifications),
          ),
        ],
      ),
    );
  }
}
