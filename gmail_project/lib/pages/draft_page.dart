import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../components/search.dart';
import '../components/menu_drawer.dart';
import 'composeEmail_page.dart';
import '../components/user_avatar.dart'; 
import 'profile_page.dart';
import '../services/message_service.dart';

class DraftPage extends StatefulWidget {
  const DraftPage({super.key});

  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _avatarKey = GlobalKey();
  final MessageService _messageService = MessageService();

  List<Map<String, dynamic>> allDrafts = [];
  List<Map<String, dynamic>> filteredDrafts = [];
  bool isLoading = true;
  String searchQuery = '';
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => isLoading = true);
    
    try {
      final loadedDrafts = await _messageService.loadDrafts(currentUserId);
      setState(() {
        allDrafts = loadedDrafts;
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading drafts: $e')),
      );
    }
  }

  void _applyFilters() {
    final query = searchQuery.toLowerCase();
    setState(() {
      filteredDrafts = allDrafts.where((draft) {
        final subject = (draft['subject'] ?? '').toString().toLowerCase();
        final body = (draft['body'] ?? '').toString().toLowerCase();
        final recipientName = (draft['recipient_name'] ?? '').toString().toLowerCase();
        final recipientPhone = (draft['recipient_phone'] ?? '').toString().toLowerCase();
        final updatedAt = draft['updated_at'] ?? draft['created_at'];
        
        bool matchesSearch = subject.contains(query) || 
                           body.contains(query) ||
                           recipientName.contains(query) ||
                           recipientPhone.contains(query);
        
        bool matchesDate = true;
        if (selectedDate != null && updatedAt != null) {
          final date = DateTime.tryParse(updatedAt);
          matchesDate = date != null &&
              date.year == selectedDate!.year &&
              date.month == selectedDate!.month &&
              date.day == selectedDate!.day;
        }
        
        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  void _onSearchChanged(String value) {
    searchQuery = value;
    _applyFilters();
  }

  void _onDateFilterTap() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      selectedDate = pickedDate;
      _applyFilters();
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Delete Draft', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this draft?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _messageService.deleteDraft(draftId);
        _loadDrafts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting draft: $e')),
        );
      }
    }
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day} ${_getMonthName(dateTime.month)}";
    } catch (e) {
      return '';
    }
  }

  String _getMonthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }

  String _getRecipientDisplay(Map<String, dynamic> draft) {
    final recipientPhone = draft['recipient_phone']?.toString() ?? '';
    final recipientName = draft['recipient_name']?.toString() ?? '';
    
    if (recipientName.isNotEmpty && recipientName != 'Unknown User') {
      return recipientName;
    } else if (recipientPhone.isNotEmpty) {
      return recipientPhone;
    } else {
      return 'No recipient';
    }
  }

  String _getRecipientImageUrl(Map<String, dynamic> draft) {
    // Tạo avatar dựa trên recipient info
    final recipientId = draft['recipient_phone']?.toString() ?? draft['recipient_name']?.toString() ?? 'default';
    return 'https://randomuser.me/api/portraits/women/${recipientId.hashCode.abs() % 100}.jpg';
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
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: Search(
                      onChanged: _onSearchChanged,
                      onDateFilterTap: _onDateFilterTap,
                    ),
                  ),
                  // Clear date filter button
                  if (selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      tooltip: 'Clear date filter',
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
                          _applyFilters();
                        });
                      },
                    ),
                  const SizedBox(width: 10),
                  UserAvatar(
                    key: _avatarKey,
                    radius: 20,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      ).then((value) {
                        // Refresh avatar when returning from ProfilePage
                        (_avatarKey.currentState as dynamic)?.refreshAvatar();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFF121212),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredDrafts.isEmpty
              ? const Center(
                  child: Text("No drafts found", style: TextStyle(color: Colors.white)),
                )
              : RefreshIndicator(
                  onRefresh: _loadDrafts,
                  child: ListView.builder(
                    itemCount: filteredDrafts.length,
                    itemBuilder: (context, index) {
                      var draft = filteredDrafts[index];
                      final recipientDisplay = _getRecipientDisplay(draft);
                      final subject = draft["subject"]?.toString() ?? "No Subject";
                      final body = draft["body"]?.toString() ?? "";
                      final timestamp = draft["updated_at"] ?? draft["created_at"];
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ComposeEmailPage(
                                  draftId: draft['draft_id'],
                                  initialTo: draft['recipient_phone']?.toString() ?? '',
                                  initialSubject: subject,
                                  initialBody: body,
                                ),
                              ),
                            );
                            
                            if (result == true) {
                              _loadDrafts();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  backgroundImage: NetworkImage(_getRecipientImageUrl(draft)),
                                  radius: 25,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Title row with draft icon
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.drafts,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              recipientDisplay,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      
                                      // Subject (if exists)
                                      if (subject.isNotEmpty && subject != "No Subject") ...[
                                        Text(
                                          subject,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      
                                      // Body content
                                      Text(
                                        body.isNotEmpty ? body : "(No content)",
                                        style: TextStyle(
                                          color: body.isNotEmpty ? Colors.white60 : Colors.white38,
                                          fontSize: 13,
                                          fontStyle: body.isEmpty ? FontStyle.italic : FontStyle.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Trailing
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatDate(timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      color: const Color(0xFF2C2C2C),
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _deleteDraft(draft['draft_id']);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, color: Colors.red, size: 18),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ComposeEmailPage()),
          );
          
          if (result == true) {
            _loadDrafts();
          }
        },
        child: const Icon(Icons.add),
        backgroundColor: const Color.fromARGB(255, 89, 89, 89),
      ),
    );
  }
}