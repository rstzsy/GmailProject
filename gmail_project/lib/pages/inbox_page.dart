import 'package:flutter/material.dart';
import '../components/listview.dart';
import '../components/menu_drawer.dart';
import '../components/search.dart';
import 'profile_page.dart';
import 'composeEmail_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<MyListViewState> listViewKey = GlobalKey<MyListViewState>();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  // Thêm biến để lưu trữ thông tin user
  String? avatarUrl;
  bool isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    fetchUserAvatar();
  }

  // Hàm lấy avatar từ Firebase
  Future<void> fetchUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final dbRef = FirebaseDatabase.instance.ref('users/$uid');
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          avatarUrl = data['avatar_url'];
          isLoadingAvatar = false;
        });
      } else {
        setState(() => isLoadingAvatar = false);
      }
    }
  }

  // Widget để build avatar với loading state
  Widget _buildAvatar() {
    if (isLoadingAvatar) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    // Nếu có avatar từ Firebase
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Colors.grey,
        onBackgroundImageError: (exception, stackTrace) {
          // Nếu lỗi load ảnh từ Firebase, fallback về ảnh mặc định
          setState(() {
            avatarUrl = null;
          });
        },
      );
    }

    // Fallback về ảnh mặc định
    return const CircleAvatar(
      backgroundImage: AssetImage('assets/images/avatar.png'),
      radius: 20,
      backgroundColor: Colors.grey,
    );
  }

  // filter time
  Future<void> _selectDateFilter() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      listViewKey.currentState?.applyDateFilter(selectedDate);
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
              border: Border.all(
                color: const Color.fromARGB(255, 59, 58, 58),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: Color.fromARGB(221, 232, 229, 229),
                    ),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                  Expanded(
                    child: Search(
                      onChanged: (value) {
                        listViewKey.currentState?.applySearchFilter(value);
                      },
                      onDateFilterTap: _selectDateFilter,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      ).then((value) {
                        // Cập nhật lại avatar khi quay lại từ ProfilePage
                        fetchUserAvatar();
                      });
                    },
                    child: _buildAvatar(), // Sử dụng widget avatar đã tạo
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: MyListView(
        key: listViewKey,
        currentUserId: currentUserId,
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
    );
  }
}