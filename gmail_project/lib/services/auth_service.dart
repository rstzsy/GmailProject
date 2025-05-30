import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Đăng ký user với phone, username, password
  Future<String?> signUp({
    required String phone,
    required String username,
    required String password,
  }) async {
    try {
      // Firebase Auth không hỗ trợ đăng ký trực tiếp với phone + password.
      // Thông thường phải dùng xác thực SMS. Ở đây dùng fakeEmail tương tự.
      String fakeEmail = "$phone@example.com";

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: fakeEmail, password: password);

      User? user = userCredential.user;

      if (user != null) {
        // Lưu dữ liệu vào Realtime Database dưới node 'users/{uid}'
        await _dbRef.child('users').child(user.uid).set({
          'phone_number': phone,
          'username': username,
          'password': password,
          'created_at': ServerValue.timestamp,
          // Thêm các trường khác nếu cần
        });
      }
      return null; // thành công
    } on FirebaseAuthException catch (e) {
      return e.message; // trả về lỗi của Firebase Auth
    } catch (e) {
      return e.toString();
    }
  }

  // dang nhap
  Future<String?> signIn({
  required String phone,
  required String password,
  }) async {
    try {
      String fakeEmail = "$phone@example.com";

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      // Đăng nhập thành công
      User? user = userCredential.user;
      if (user != null) {
        return null;
      } else {
        return "User not found";
      }
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}
