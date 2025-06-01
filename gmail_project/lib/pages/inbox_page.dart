import 'package:flutter/material.dart';
import '../components/listview.dart';
import '../components/menu_drawer.dart';
import '../components/search.dart';
import 'profile_page.dart';
import 'composeEmail_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<MyListViewState> listViewKey = GlobalKey<MyListViewState>();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String? avatarUrl;
  bool isLoadingAvatar = true;
  bool _isAppInitialized = false; // Thêm flag để kiểm soát notification

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    fetchUserAvatar();
    _initializeNotifications();
    _requestNotificationPermission();
    
    // Delay một chút trước khi bắt đầu lắng nghe để skip notifications cũ
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isAppInitialized = true;
      });
      _listenToNotifications();
    });
  }

  Future<void> _requestNotificationPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // For Android 13+ (API level 33+), request notification permission
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      print('Notification permission granted: $granted');
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_mail');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: null,
    );

    final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('Notification tapped with payload: ${response.payload}');
      },
    );

    print('Notifications initialized: $initialized');

    // Tạo notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'channel_id',
      'General Notifications',
      description: 'This channel is for general notifications.',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('Notification channel created');
  }

  void _listenToNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseDatabase.instance
        .ref()
        .child('notifications')
        .child(currentUser.uid)
        .onChildAdded
        .listen((event) async {
      
      if (!_isAppInitialized) return;
      
      final value = event.snapshot.value;
      if (value != null && value is Map<dynamic, dynamic>) {
        final isNotificationRead = value['is_read'] ?? false;
        final messageId = value['message_id'];
        
        if (!isNotificationRead && messageId != null) {
          // Kiểm tra thêm trạng thái is_read_recip của message
          final messageRecipSnapshot = await FirebaseDatabase.instance
              .ref()
              .child('internal_message_recipients')
              .child(messageId)
              .child(currentUser.uid)
              .get();
              
          final isMessageRead = messageRecipSnapshot.child('is_read_recip').value as bool? ?? false;
          
          // Chỉ hiển thị notification nếu cả notification và message đều chưa được đọc
          if (!isMessageRead) {
            final title = value['title'] ?? 'Notification';
            final body = value['body'] ?? 'You have a new message';
            
            // Hiển thị notification...
            const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
              'channel_id',
              'General Notifications',
              importance: Importance.max,
              priority: Priority.high,
            );

            const NotificationDetails platformDetails = NotificationDetails(
              android: androidDetails,
            );

            await flutterLocalNotificationsPlugin.show(
              DateTime.now().millisecondsSinceEpoch.remainder(100000),
              title,
              body,
              platformDetails,
            );

            // Đánh dấu notification đã được hiển thị
            await event.snapshot.ref.update({'is_read': true});
          }
        }
      }
    });
  }

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

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Colors.grey,
        onBackgroundImageError: (exception, stackTrace) {
          setState(() {
            avatarUrl = null;
          });
        },
      );
    }

    return const CircleAvatar(
      backgroundImage: AssetImage('assets/images/avatar.png'),
      radius: 20,
      backgroundColor: Colors.grey,
    );
  }

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

  // Test function để kiểm tra notification
  Future<void> _testNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_id',
      'General Notifications',
      channelDescription: 'This channel is for general notifications.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification',
      'This is a test notification',
      platformDetails,
    );
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
                  // Test button - bạn có thể xóa sau khi test xong
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: _testNotification,
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
                        fetchUserAvatar();
                      });
                    },
                    child: _buildAvatar(),
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