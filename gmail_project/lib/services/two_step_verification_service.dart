import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class TwoStepVerificationService {
  static const int BACKUP_CODES_COUNT = 12;
  static const int BACKUP_CODE_LENGTH = 8;
  
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Tạo backup codes
  List<String> generateBackupCodes() {
    final List<String> codes = [];
    final Random random = Random.secure();
    
    for (int i = 0; i < BACKUP_CODES_COUNT; i++) {
      String code = '';
      for (int j = 0; j < BACKUP_CODE_LENGTH; j++) {
        code += random.nextInt(10).toString();
      }
      // Format: XXXX-XXXX
      String formattedCode = '${code.substring(0, 4)}-${code.substring(4, 8)}';
      codes.add(formattedCode);
    }
    
    return codes;
  }

  // Lưu backup codes vào Firebase (không hash)
  Future<void> saveBackupCodes(List<String> codes) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    List<Map<String, dynamic>> codesList = [];
    for (String code in codes) {
      codesList.add({
        'code': code, // Lưu trực tiếp không hash
        'used': false,
        'created_at': ServerValue.timestamp,
      });
    }

    await _database.child('users/${user.uid}/two_step_verification/backup_codes').set(codesList);
    await _database.child('users/${user.uid}/two_step_verification/enabled').set(true);
    await _database.child('users/${user.uid}/two_step_verification/created_at').set(ServerValue.timestamp);
  }

  // Kiểm tra và sử dụng backup code (so sánh trực tiếp)
  Future<bool> verifyBackupCode(String inputCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    print('🔍 DEBUG: Starting verification for input: "$inputCode"');
    
    final snapshot = await _database.child('users/${user.uid}/two_step_verification').get();
    
    if (!snapshot.exists) {
      print('❌ DEBUG: No two_step_verification data found');
      return false;
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    print('🔍 DEBUG: Full data structure: $data');
    
    if (!data.containsKey('backup_codes')) {
      print('❌ DEBUG: No backup_codes in data structure');
      return false;
    }

    final backupCodes = data['backup_codes'] as List;
    print('🔍 DEBUG: Found backup_codes structure: $backupCodes');

    // Normalize input code
    String cleanedInput = inputCode.trim();
    
    // Try both formats to ensure compatibility
    List<String> inputVariants = [
      cleanedInput,
      cleanedInput.replaceAll('-', ''),
    ];
    
    // If input doesn't have dash and is 8 digits, add dash
    if (!cleanedInput.contains('-') && cleanedInput.length == 8) {
      inputVariants.add('${cleanedInput.substring(0, 4)}-${cleanedInput.substring(4, 8)}');
    }
    
    print('🔍 DEBUG: Input variants to try: $inputVariants');

    // Tìm code khớp và chưa được sử dụng
    for (int i = 0; i < backupCodes.length; i++) {
      if (backupCodes[i] == null) continue;
      
      final codeData = Map<String, dynamic>.from(backupCodes[i]);
      print('🔍 DEBUG: Checking code at index $i: ${codeData['code']}, used: ${codeData['used']}');
      
      if (codeData['used'] == true) {
        print('🔍 DEBUG: Code at index $i already used, skipping');
        continue;
      }
      
      final storedCode = codeData['code'].toString();
      
      // So sánh trực tiếp với stored code
      for (String variant in inputVariants) {
        print('🔍 DEBUG: Comparing variant "$variant" with stored "$storedCode"');
        
        if (variant == storedCode) {
          print('✅ DEBUG: Found matching code at index $i with variant "$variant"');
          
          // Đánh dấu code đã được sử dụng
          await _database.child('users/${user.uid}/two_step_verification/backup_codes/$i/used').set(true);
          await _database.child('users/${user.uid}/two_step_verification/backup_codes/$i/used_at').set(ServerValue.timestamp);
          
          print('✅ DEBUG: Successfully marked code as used');
          return true;
        }
      }
    }

    print('❌ DEBUG: No matching unused code found');
    return false;
  }

  // Kiểm tra trạng thái two-step verification
  Future<bool> isTwoStepEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final snapshot = await _database.child('users/${user.uid}/two_step_verification/enabled').get();
    return snapshot.exists ? snapshot.value as bool : false;
  }

  // Tắt two-step verification
  Future<void> disableTwoStep() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _database.child('users/${user.uid}/two_step_verification').remove();
  }

  // Tạo file backup codes để download
  Future<File> createBackupCodesFile(List<String> codes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/backup_codes.txt');
    
    final buffer = StringBuffer();
    buffer.writeln('Gmail Project - Backup Codes');
    buffer.writeln('Generated: ${DateTime.now().toString()}');
    buffer.writeln('');
    buffer.writeln('IMPORTANT: Keep these codes safe and secure!');
    buffer.writeln('Each code can only be used once.');
    buffer.writeln('Use these codes when you cannot access your primary verification method.');
    buffer.writeln('');
    buffer.writeln('Backup Codes:');
    buffer.writeln('=============');
    
    for (int i = 0; i < codes.length; i++) {
      buffer.writeln('${(i + 1).toString().padLeft(2, '0')}. ${codes[i]}');
    }
    
    buffer.writeln('');
    buffer.writeln('After using a code, it will become invalid.');
    buffer.writeln('Generate new codes if you run out.');
    
    await file.writeAsString(buffer.toString());
    return file;
  }

  // Đếm số backup codes còn lại
  Future<int> getRemainingCodesCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final snapshot = await _database.child('users/${user.uid}/two_step_verification/backup_codes').get();
    
    if (!snapshot.exists) return 0;

    final backupCodes = snapshot.value as List;
    int remainingCount = 0;
    
    for (var codeData in backupCodes) {
      if (codeData != null) {
        final code = Map<String, dynamic>.from(codeData);
        if (code['used'] != true) {
          remainingCount++;
        }
      }
    }
    
    return remainingCount;
  }

  // Tạo lại backup codes mới
  Future<List<String>> regenerateBackupCodes() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Tạo codes mới
    final newCodes = generateBackupCodes();
    
    // Xóa codes cũ và lưu codes mới
    await _database.child('users/${user.uid}/two_step_verification/backup_codes').remove();
    await saveBackupCodes(newCodes);
    
    return newCodes;
  }

  // Debug method to check the actual structure
  Future<void> debugBackupCodesStructure() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _database.child('users/${user.uid}/two_step_verification').get();
    
    if (snapshot.exists) {
      print('🔍 DEBUG: Full two_step_verification structure: ${snapshot.value}');
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      if (data.containsKey('backup_codes')) {
        final codes = data['backup_codes'] as List;
        print('🔍 DEBUG: Backup codes count: ${codes.length}');
        for (int i = 0; i < codes.length && i < 3; i++) {
          print('🔍 DEBUG: Sample code $i: ${codes[i]}');
        }
      }
    }
  }

  // Method để lấy danh sách backup codes còn lại (cho debugging)
  Future<List<String>> getAvailableBackupCodes() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _database.child('users/${user.uid}/two_step_verification/backup_codes').get();
    
    if (!snapshot.exists) return [];

    final backupCodes = snapshot.value as List;
    List<String> availableCodes = [];
    
    for (var codeData in backupCodes) {
      if (codeData != null) {
        final code = Map<String, dynamic>.from(codeData);
        if (code['used'] != true) {
          availableCodes.add(code['code'].toString());
        }
      }
    }
    
    return availableCodes;
  }
}