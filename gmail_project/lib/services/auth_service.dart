import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'two_step_verification_service.dart';
import 'package:dio/dio.dart';
import 'dart:convert';  
import 'package:crypto/crypto.dart'; 

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Dio _dio = Dio();

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

  // Kiểm tra xem user có bật Two-Step Verification không
  Future<bool> isTwoStepEnabled(String uid) async {
    try {
      final snapshot = await _dbRef.child('users/$uid/two_step_verification/enabled').get();
      return snapshot.exists ? snapshot.value as bool : false;
    } catch (e) {
      print('Error checking two-step status: $e');
      return false;
    }
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

  // Đăng nhập - UPDATED để hỗ trợ Two-Step Verification
  Future<Map<String, dynamic>> signIn({
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
        // Kiểm tra xem user có bật Two-Step Verification không
        final twoStepEnabled = await isTwoStepEnabled(userCredential.user!.uid);
        
        if (twoStepEnabled) {
          // Nếu có bật 2FA, đăng xuất tạm thời và yêu cầu backup code
          await _auth.signOut();
          
          return {
            'success': false,
            'requiresTwoStep': true,
            'userId': userCredential.user!.uid,
            'phone': normalizedPhone,
            'password': password,
            'message': 'Two-step verification required'
          };
        } else {
          // Đăng nhập thành công bình thường
          print(' User signed in successfully: ${userCredential.user!.uid}');
          return {
            'success': true,
            'requiresTwoStep': false,
            'message': 'Login successful'
          };
        }
      } else {
        return {
          'success': false,
          'requiresTwoStep': false,
          'message': "Không thể đăng nhập. Vui lòng thử lại."
        };
      }
    } on FirebaseAuthException catch (e) {
      print(' Sign in error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Không tìm thấy tài khoản với số điện thoại này.';
          break;
        case 'wrong-password':
          errorMessage = 'Mật khẩu không chính xác.';
          break;
        case 'too-many-requests':
          errorMessage = 'Quá nhiều lần thử. Vui lòng thử lại sau.';
          break;
        default:
          errorMessage = e.message ?? 'Lỗi đăng nhập không xác định.';
      }
      return {
        'success': false,
        'requiresTwoStep': false,
        'message': errorMessage
      };
    } catch (e) {
      print(' General sign in error: $e');
      return {
        'success': false,
        'requiresTwoStep': false,
        'message': 'Lỗi hệ thống: $e'
      };
    }
  }

  // Xác thực backup code từ Firebase Database và đăng nhập - FIXED VERSION
  Future<Map<String, dynamic>> verifyBackupCodeAndSignIn({
    required String userId,
    required String phone,
    required String password,
    required String backupCode,
  }) async {
    try {
      print('🔍 DEBUG: Starting backup code verification');
      print('🔍 DEBUG: UserId: $userId');
      print('🔍 DEBUG: Input backup code: "$backupCode"');
      print('🔍 DEBUG: Backup code length: ${backupCode.length}');

      // Đăng nhập trước để có quyền truy cập
      final normalizedPhone = normalizePhoneNumber(phone);
      final fakeEmail = "$normalizedPhone@example.com";

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      if (userCredential.user == null) {
        return {
          'success': false,
          'message': 'Không thể xác thực tài khoản.'
        };
      }

      print('✅ DEBUG: User authenticated successfully');

      // Truy cập dữ liệu two-step verification
      final userRef = _dbRef.child('users').child(userId).child('two_step_verification');
      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        print('❌ DEBUG: No two-step verification data found');
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Không tìm thấy dữ liệu xác thực hai bước.'
        };
      }

      print('✅ DEBUG: Two-step verification data found');
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      print('🔍 DEBUG: Full data structure: $data');

      // Chuẩn hóa input code
      String cleanedInputCode = backupCode.trim().toUpperCase();
      print('🔍 DEBUG: Cleaned input code: "$cleanedInputCode"');

      // Kiểm tra backup_codes array - FIXED VERSION
      if (data.containsKey('backup_codes')) {
        final backupCodes = data['backup_codes'];
        print('🔍 DEBUG: Found backup_codes structure: $backupCodes');
        
        // Kiểm tra nếu backup_codes là List (Array)
        if (backupCodes is List) {
          print('🔍 DEBUG: Backup codes is a List with ${backupCodes.length} items');
          
          for (int i = 0; i < backupCodes.length; i++) {
            final codeData = backupCodes[i];
            print('🔍 DEBUG: Checking code at index $i: $codeData');
            
            if (codeData is Map) {
              final codeInfo = Map<String, dynamic>.from(codeData);
              final isUsed = codeInfo['used'] == true;
              final storedCode = codeInfo['code']?.toString() ?? '';
              
              print('🔍 DEBUG: Code $i - stored: "$storedCode", used: $isUsed');
              
              if (!isUsed && storedCode.isNotEmpty) {
                String cleanedStoredCode = storedCode.trim().toUpperCase();
                
                // So sánh trực tiếp (plain text)
                if (cleanedInputCode == cleanedStoredCode) {
                  print('✅ DEBUG: Direct match found for code at index $i!');
                  
                  // Đánh dấu đã sử dụng
                  await _markBackupCodeAsUsedByIndex(userId, i);
                  
                  return {
                    'success': true,
                    'message': 'Đăng nhập thành công với mã backup.'
                  };
                }
                
                // Thử các format khác nhau (với/không có dấu gạch ngang)
                List<String> variations = _generateCodeVariations(cleanedInputCode);
                for (String variation in variations) {
                  if (variation == cleanedStoredCode) {
                    print('✅ DEBUG: Variation match found: "$variation" for code at index $i!');
                    
                    await _markBackupCodeAsUsedByIndex(userId, i);
                    
                    return {
                      'success': true,
                      'message': 'Đăng nhập thành công với mã backup.'
                    };
                  }
                }
              }
            }
          }
        } 
        // Nếu vẫn là Map (fallback cho trường hợp cũ)
        else if (backupCodes is Map) {
          final codesMap = Map<String, dynamic>.from(backupCodes);
          print('🔍 DEBUG: Backup codes is a Map with ${codesMap.length} keys');
          
          for (String key in codesMap.keys) {
            final codeData = codesMap[key];
            print('🔍 DEBUG: Checking code $key: $codeData');
            
            if (codeData is Map) {
              final codeInfo = Map<String, dynamic>.from(codeData);
              final isUsed = codeInfo['used'] == true;
              final storedCode = codeInfo['code']?.toString() ?? '';
              
              print('🔍 DEBUG: Code $key - stored: "$storedCode", used: $isUsed');
              
              if (!isUsed && storedCode.isNotEmpty) {
                String cleanedStoredCode = storedCode.trim().toUpperCase();
                
                // So sánh trực tiếp (plain text)
                if (cleanedInputCode == cleanedStoredCode) {
                  print('✅ DEBUG: Direct match found for code $key!');
                  
                  // Đánh dấu đã sử dụng
                  await _markBackupCodeAsUsed(userId, key);
                  
                  return {
                    'success': true,
                    'message': 'Đăng nhập thành công với mã backup.'
                  };
                }
                
                // Thử các format khác nhau (với/không có dấu gạch ngang)
                List<String> variations = _generateCodeVariations(cleanedInputCode);
                for (String variation in variations) {
                  if (variation == cleanedStoredCode) {
                    print('✅ DEBUG: Variation match found: "$variation" for code $key!');
                    
                    await _markBackupCodeAsUsed(userId, key);
                    
                    return {
                      'success': true,
                      'message': 'Đăng nhập thành công với mã backup.'
                    };
                  }
                }
              }
            }
          }
        }
      }

      print('❌ DEBUG: No matching backup code found');
      await _auth.signOut();
      return {
        'success': false,
        'message': 'Mã backup không chính xác.'
      };

    } catch (e, stackTrace) {
      print('❌ DEBUG: Error in verifyBackupCodeAndSignIn: $e');
      print('🔍 DEBUG: Stacktrace: $stackTrace');
      
      try {
        await _auth.signOut();
      } catch (signOutError) {
        print('⚠️ DEBUG: Sign out error: $signOutError');
      }

      return {
        'success': false,
        'message': 'Lỗi hệ thống khi xác minh mã backup.'
      };
    }
  }

  // Helper methods - loại bỏ hash-related methods
  List<String> _generateCodeVariations(String code) {
    List<String> variations = [];
    
    // Original
    variations.add(code);
    
    // Lowercase
    variations.add(code.toLowerCase());
    
    // With dash if not present
    if (!code.contains('-') && code.length == 8) {
      variations.add('${code.substring(0, 4)}-${code.substring(4)}');
      variations.add('${code.substring(0, 4)}-${code.substring(4)}'.toLowerCase());
    }
    
    // Without dash if present
    if (code.contains('-')) {
      variations.add(code.replaceAll('-', ''));
      variations.add(code.replaceAll('-', '').toLowerCase());
    }
    
    // With spaces
    if (!code.contains(' ') && code.length == 8) {
      variations.add('${code.substring(0, 4)} ${code.substring(4)}');
    }
    
    return variations;
  }

  // Đánh dấu backup code đã sử dụng theo Map key
  Future<void> _markBackupCodeAsUsed(String userId, String codeKey) async {
    try {
      final codeRef = _dbRef.child('users').child(userId)
          .child('two_step_verification').child('backup_codes').child(codeKey);
      
      await codeRef.update({
        'used': true,
        'used_at': ServerValue.timestamp,
      });
      
      print('✅ DEBUG: Marked code $codeKey as used');
    } catch (e) {
      print('⚠️ DEBUG: Failed to mark backup code as used: $e');
    }
  }

  // Đánh dấu backup code đã sử dụng theo Array index
  Future<void> _markBackupCodeAsUsedByIndex(String userId, int index) async {
    try {
      final codeRef = _dbRef.child('users').child(userId)
          .child('two_step_verification').child('backup_codes').child(index.toString());
      
      await codeRef.update({
        'used': true,
        'used_at': ServerValue.timestamp,
      });
      
      print('✅ DEBUG: Marked code at index $index as used');
    } catch (e) {
      print('⚠️ DEBUG: Failed to mark backup code as used: $e');
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