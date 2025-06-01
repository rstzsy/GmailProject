import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gmail_project/pages/editProfile_page.dart';
import 'package:gmail_project/pages/languagSelection_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'welcome_page.dart'; 
import 'editProfile_page.dart';
import 'languagSelection_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isNotificationOn = true;
  File? _avatarImage;

  String username = '';
  String phone = '';
  String? avatarUrl; // Thêm biến để lưu URL avatar
  bool isLoading = true;
  bool isUploadingAvatar = false; // Thêm biến để track việc upload avatar

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final dbRef = FirebaseDatabase.instance.ref('users/$uid');
      final snapshot = await dbRef.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          username = data['username'] ?? 'No name';
          phone = data['phone_number'] ?? 'No phone';
          avatarUrl = data['avatar_url']; // Lấy URL avatar từ database
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      // Hiển thị dialog để chọn nguồn ảnh
      final source = await _showImageSourceDialog();
      if (source == null) return;

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 400,
        maxHeight: 400,
      );
      
      if (pickedFile != null) {
        setState(() {
          _avatarImage = File(pickedFile.path);
          isUploadingAvatar = true;
        });

        // Upload ảnh lên Firebase Storage
        await _uploadAvatarToFirebase();
      }
    } catch (e) {
      _showErrorDialog("Error selecting image: $e");
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Select Image Source',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFF48FB1)),
                title: const Text('Photo Library', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFF48FB1)),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadAvatarToFirebase() async {
    if (_avatarImage == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Tạo reference với tên file unique
      final fileName = 'avatar_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('avatars/$fileName');

      // Upload file
      final uploadTask = ref.putFile(_avatarImage!);
      final snapshot = await uploadTask;
      
      // Lấy download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Cập nhật URL vào database
      final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      await dbRef.update({'avatar_url': downloadUrl});

      setState(() {
        avatarUrl = downloadUrl;
        _avatarImage = null; // Clear local image sau khi upload thành công
        isUploadingAvatar = false;
      });

      _showSuccessDialog("Avatar updated successfully!");
    } catch (e) {
      setState(() {
        isUploadingAvatar = false;
      });
      _showErrorDialog("Error uploading avatar: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFF48FB1))),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Success', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFF48FB1))),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFD5C4F1), Color(0xFFF48FB1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.black,
            child: ClipOval(
              child: _buildAvatarImage(),
            ),
          ),
        ),
        if (isUploadingAvatar)
          const Positioned(
            child: CircularProgressIndicator(
              color: Color(0xFFF48FB1),
              strokeWidth: 2,
            ),
          ),
        Positioned(
          bottom: 0,
          right: 4,
          child: GestureDetector(
            onTap: isUploadingAvatar ? null : _pickImage,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(
                isUploadingAvatar ? Icons.hourglass_empty : Icons.edit,
                size: 18,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    // Ưu tiên hiển thị ảnh local nếu đang chọn ảnh mới
    if (_avatarImage != null) {
      return Image.file(_avatarImage!, fit: BoxFit.cover, width: 95, height: 95);
    }
    // Hiển thị ảnh từ Firebase nếu có
    else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        width: 95,
        height: 95,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFF48FB1),
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/avatar.png',
            fit: BoxFit.cover,
            width: 95,
            height: 95,
          );
        },
      );
    }
    // Hiển thị ảnh mặc định
    else {
      return Image.asset(
        'assets/images/avatar.png',
        fit: BoxFit.cover,
        width: 95,
        height: 95,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        iconTheme: const IconThemeData(color: Color(0xFFF48FB1)),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildAvatarSection(), // Sử dụng function mới
                    const SizedBox(height: 10),
                    // display username
                    Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFffcad4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(FontAwesomeIcons.handHoldingHeart, color: Color(0xFFE21033), size: 18),
                          SizedBox(width: 5),
                          Text("UX/UI Designer", style: TextStyle(fontSize: 14, color: Colors.black)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // display phone
                    Column(
                      children: [
                        _buildInfoCard(Icons.phone, "Phone", phone),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildListTile(
                      Icons.notifications,
                      "Notifications",
                      Color(0xFFFF80AB),
                      null,
                      Switch(
                        value: _isNotificationOn,
                        activeColor: Color(0xFFFF80AB),
                        onChanged: (value) => setState(() => _isNotificationOn = value),
                      ),
                    ),
                    _buildListTile(
                      FontAwesomeIcons.userSecret,
                      "Edit Profile",
                      Color(0xFF4CC9FE),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfilePage()),
                      ).then((value) {
                        // Gọi lại fetchUserData khi quay lại từ EditProfilePage
                        fetchUserData();
                      })
                    ),
                    _buildListTile(
                      FontAwesomeIcons.language,
                      "Languages",
                      Color(0xFFFFB300),
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageSelectionPage())),
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => WelcomeScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(FontAwesomeIcons.arrowRightFromBracket, color: Color(0xFFE21033)),
                        label: const Text("Logout", style: TextStyle(color: Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 255, 230, 238),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 255, 230, 238),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFE21033).withOpacity(0.1),
            child: Icon(icon, color: Color(0xFFE21033)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, Color color, [VoidCallback? onTap, Widget? trailing]) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
      onTap: onTap,
    );
  }
}