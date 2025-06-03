import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Kiểm tra người dùng đã đăng nhập chưa
  bool _isUserAuthenticated() {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user found');
      return false;
    }
    print(' User authenticated: ${user.uid}');
    return true;
  }

  // Khởi tạo cài đặt thông báo mặc định cho user (nếu chưa có)
  Future<void> initializeUserNotifications(String uid) async {
    try {
      if (!_isUserAuthenticated() || _auth.currentUser?.uid != uid) {
        print(' User not authenticated or UID mismatch');
        return;
      }

      final notificationRef = _dbRef.child('notifications').child(uid);
      final snapshot = await notificationRef.get();

      if (!snapshot.exists) {
        await notificationRef.set({
          'enabled': true,
          'email_notifications': true,
          'push_notifications': true,
          'created_at': ServerValue.timestamp,
        });
        print(' Initialized notifications for user: $uid');
      } else {
        print(' Notifications already exist for user: $uid');
      }
    } on FirebaseException catch (e) {
      print(' Firebase Error initializing notifications: ${e.code} - ${e.message}');
    } catch (e) {
      print(' General Error initializing notifications: $e');
    }
  }

  // Lấy cài đặt thông báo của user
  Future<Map<String, dynamic>?> getUserNotifications(String uid) async {
    try {
      if (!_isUserAuthenticated() || _auth.currentUser?.uid != uid) {
        print(' User not authenticated or UID mismatch for getUserNotifications');
        return null;
      }

      final snapshot = await _dbRef.child('notifications').child(uid).get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        // Nếu chưa có dữ liệu thông báo, khởi tạo mặc định
        await initializeUserNotifications(uid);
        return {
          'enabled': true,
          'email_notifications': true,
          'push_notifications': true,
        };
      }
    } on FirebaseException catch (e) {
      print(' Firebase Error getting user notifications: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print(' General Error getting user notifications: $e');
      return null;
    }
  }

  // Cập nhật cài đặt thông báo của user
  Future<bool> updateNotificationSettings(String uid, Map<String, dynamic> settings) async {
    try {
      if (!_isUserAuthenticated() || _auth.currentUser?.uid != uid) {
        print(' User not authenticated or UID mismatch for updateNotificationSettings');
        return false;
      }

      await _dbRef.child('notifications').child(uid).update({
        ...settings,
        'updated_at': ServerValue.timestamp,
      });
      print(' Updated notification settings for user: $uid');
      return true;
    } on FirebaseException catch (e) {
      print(' Firebase Error updating notification settings: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print(' General Error updating notification settings: $e');
      return false;
    }
  }

  // Lấy cài đặt thông báo cho user hiện tại
  Future<Map<String, dynamic>?> getCurrentUserNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      print(' No authenticated user for getCurrentUserNotifications');
      return null;
    }
    return await getUserNotifications(user.uid);
  }

  // Cập nhật cài đặt thông báo cho user hiện tại
  Future<bool> updateCurrentUserNotificationSettings(Map<String, dynamic> settings) async {
    final user = _auth.currentUser;
    if (user == null) {
      print(' No authenticated user for updateCurrentUserNotificationSettings');
      return false;
    }
    return await updateNotificationSettings(user.uid, settings);
  }

  // Đăng ký tài khoản
  Future<String?> signUp({
    required String phone,
    required String username,
    required String password,
  }) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phone);
      final fakeEmail = "$normalizedPhone@example.com";

      final existingUser = await checkUserExistsInDatabase(normalizedPhone);
      if (existingUser) {
        return 'Số điện thoại này đã được đăng ký.';
      }

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        await _dbRef.child('users').child(user.uid).set({
          'phone_number': normalizedPhone,
          'username': username,
          'password': password,
          'created_at': ServerValue.timestamp,
          'notification_enabled': true,
        });

        // Khởi tạo cài đặt thông báo sau khi đăng ký thành công
        await initializeUserNotifications(user.uid);

        print(' User registered successfully: ${user.uid}');
        return null;
      } else {
        return "Không thể tạo tài khoản. Vui lòng thử lại.";
      }
    } on FirebaseAuthException catch (e) {
      print(' Sign up error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          return 'Số điện thoại này đã được đăng ký.';
        case 'weak-password':
          return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu mạnh hơn.';
        default:
          return e.message ?? 'Lỗi đăng ký không xác định.';
      }
    } catch (e) {
      print(' General sign up error: $e');
      return 'Lỗi hệ thống: $e';
    }
  }

  // Kiểm tra tồn tại user theo số điện thoại
  Future<bool> checkUserExistsInDatabase(String phoneNumber) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phoneNumber);
      final snapshot = await _dbRef.child('users')
          .orderByChild('phone_number')
          .equalTo(normalizedPhone)
          .get();

      return snapshot.exists;
    } on FirebaseException catch (e) {
      print(' Database access error: ${e.code} - ${e.message}');
      return false;
    }
  }

  // Đăng nhập
  Future<String?> signIn({
    required String phone,
    required String password,
  }) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phone);
      final fakeEmail = "$normalizedPhone@example.com";

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      if (userCredential.user != null) {
        print(' User signed in successfully: ${userCredential.user!.uid}');
        return null;
      } else {
        return "Không thể đăng nhập. Vui lòng thử lại.";
      }
    } on FirebaseAuthException catch (e) {
      print(' Sign in error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          return 'Không tìm thấy tài khoản với số điện thoại này.';
        case 'wrong-password':
          return 'Mật khẩu không chính xác.';
        case 'too-many-requests':
          return 'Quá nhiều lần thử. Vui lòng thử lại sau.';
        default:
          return e.message ?? 'Lỗi đăng nhập không xác định.';
      }
    } catch (e) {
      print(' General sign in error: $e');
      return 'Lỗi hệ thống: $e';
    }
  }

  // Đặt lại mật khẩu theo số điện thoại
  Future<String?> resetPassword({
    required String phoneNumber,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final normalizedPhone = normalizePhoneNumber(phoneNumber);
      final fakeEmail = '$normalizedPhone@example.com';

      // Tạo một FirebaseApp tạm
      final tempApp = await Firebase.initializeApp(
        name: 'tempApp',
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final tempDb = FirebaseDatabase.instanceFor(app: tempApp);

      // Đăng nhập với app phụ
      final userCredential = await tempAuth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: oldPassword,
      );

      // Đổi mật khẩu
      await userCredential.user?.updatePassword(newPassword);

      // Cập nhật trong Realtime Database
      await tempDb.ref('users/${userCredential.user!.uid}').update({
        'password': newPassword,
      });

      // Đăng xuất khỏi app phụ
      await tempAuth.signOut();
      await tempApp.delete(); // xóa app phụ

      return null; // thành công
    } catch (e) {
      print('Lỗi đặt lại mật khẩu: $e');
      return 'Lỗi: ${e.toString()}';
    }
  }






  // Đăng xuất
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print(' User signed out successfully');
    } catch (e) {
      print(' Sign out error: $e');
    }
  }

  // Lấy user hiện tại
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Kiểm tra user đã đăng nhập chưa
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  // Chuẩn hóa số điện thoại (chuyển +84 về 0)
  String normalizePhoneNumber(String phoneNumber) {
    if (phoneNumber.startsWith('+84')) {
      return '0' + phoneNumber.substring(3);
    }
    return phoneNumber;
  }
}
