import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


typedef OtpSentCallback = void Function(String verificationId);
typedef AuthErrorCallback = void Function(String error);

class OtpAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void sendOtp({
    required String phoneNumber,
    required OtpSentCallback onCodeSent,
    required AuthErrorCallback onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval (Android only)
        try {
          await _auth.signInWithCredential(credential);
          final user = FirebaseAuth.instance.currentUser;
          print("Đăng nhập bằng OTP thành công. UID: ${user?.uid}, phone: ${user?.phoneNumber}");

        } catch (e) {
          onFailed(e.toString());
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        onFailed(e.message ?? 'Lỗi xác thực');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String smsCode,
    required VoidCallback onSuccess,
    required AuthErrorCallback onFailed,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      await _auth.signInWithCredential(credential);
      onSuccess();
    } catch (e) {
      onFailed(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

