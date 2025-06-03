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
  bool _isAppInitialized = false;
  bool _notificationEnabled = true; // Track notification status

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Method để hủy tất cả notifications
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print('All notifications cancelled');
  }

  void _listenToNotificationSettingChanges() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(currentUser.uid)
        .child('notification_enabled')
        .onValue
        .listen((event) async {
      final isEnabled = event.snapshot.value as bool? ?? true;
      
      setState(() {
        _notificationEnabled = isEnabled;
      });
      
      // Nếu user tắt notification, hủy tất cả notifications hiện tại
      if (!isEnabled) {
        await cancelAllNotifications();
        print('Notifications disabled - all current notifications cancelled');
      } else {
        print('Notifications enabled');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    fetchUserAvatar();
    _initializeNotifications();
    _requestNotificationPermission().then((_) {
      // Debug permissions sau khi request
      _debugNotificationPermissions();
    });

    _listenToNotificationSettingChanges();
  
    // Delay một chút trước khi bắt đầu lắng nghe để skip notifications cũ
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isAppInitialized = true;
      });
      _listenToNotifications();
    });
  }

  Future<void> _requestNotificationPermission() async {
    // Request permission cho iOS với chi tiết hơn
    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      // Yêu cầu tất cả các quyền cần thiết
      final bool? granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,  // Thêm critical permission
        provisional: false, // Tắt provisional để force user action
      );
      
      print('iOS notification permission granted: $granted');
      
      if (granted != true) {
        print('iOS notification permission denied');
        // Hiển thị dialog hướng dẫn user vào Settings để bật notification
        _showPermissionDialog();
      } else {
        print('iOS notification permission granted successfully');
      }
    }

    // Request permission cho Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      print('Android notification permission granted: $granted');
    }
  }

  void _showPermissionDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Notification Permission Required'),
      content: Text(
        'To receive notifications, please enable notifications for this app in Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Có thể sử dụng package như app_settings để mở Settings
            // AppSettings.openNotificationSettings();
          },
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
}


  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_mail');

    // Cấu hình chi tiết hơn cho iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    // Cấu hình chung cho cả Android và iOS
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('Notification tapped with payload: ${response.payload}');
      },
    );

    print('Notifications initialized: $initialized');

    // Tạo notification channel cho Android
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

  Future<void> _debugNotificationPermissions() async {
    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      print('=== iOS Notification Permissions Debug ===');

      final bool? granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
        provisional: true,
      );

      print('Permission request result: $granted');

      if (granted != true) {
        print('User denied notification permissions.');
        // Có thể hiện một dialog tùy chỉnh để yêu cầu người dùng cấp quyền trong Cài đặt
      } else {
        print('User granted notification permissions.');
      }

      print('==========================================');
    }
  }

  // Phương thức show notification với cấu hình chi tiết hơn
  Future<void> _showNotification(String title, String body) async {
    if (!_notificationEnabled) {
      print('Cannot show notification - notifications are disabled');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_id',
      'General Notifications',
      channelDescription: 'This channel is for general notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    // Cấu hình chi tiết hơn cho iOS
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      threadIdentifier: 'email_notifications',
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformDetails,
      );
      print('Notification shown successfully: $title - $body');
    } catch (e) {
      print('Error showing notification: $e');
    }
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
      
      // Kiểm tra trạng thái notification trước khi xử lý
      if (!_notificationEnabled) {
        print('Notifications are disabled - skipping notification');
        return;
      }
      
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
          // VÀ notification được bật
          if (!isMessageRead && _notificationEnabled) {
            final title = value['title'] ?? 'Notification';
            final body = value['body'] ?? 'You have a new message';
            
            // Sử dụng phương thức _showNotification mới
            await _showNotification(title, body);
            
            print('Notification processed: $title - $body');
          } else {
            print('Notification skipped - either message read or notifications disabled');
          }

          // Đánh dấu notification đã được xử lý (không phải đã hiển thị)
          await event.snapshot.ref.update({'is_read': true});
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

  // Test function để kiểm tra notification - sử dụng _showNotification mới
  Future<void> _testNotification() async {
    await _showNotification('Test Notification', 'This is a test notification');
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
                  // Test button - hiển thị trạng thái notification
                  IconButton(
                    icon: Icon(
                      _notificationEnabled ? Icons.notifications : Icons.notifications_off, 
                      color: _notificationEnabled ? Colors.white : Colors.grey
                    ),
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