import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../components/dialog.dart';
import './phoneOTP_page.dart';


class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  File? _image;
  final picker = ImagePicker();
  bool _isUploading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  String? _currentAvatarUrl; // Lưu URL ảnh hiện tại
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _database.ref('users/${user.uid}').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          usernameController.text = data['username'] ?? '';
          phoneController.text = data['phone_number'] ?? '';
          passwordController.text = data['password'] ?? '';
          _currentAvatarUrl = data['avatar_url']; // Load avatar URL
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 80,
        maxWidth: 400,
        maxHeight: 400,
      );
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorDialog("Error selecting image: $e");
    }
  }

  Future<void> _takePicture() async {
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 400,
        maxHeight: 400,
      );
      
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorDialog("Error taking picture: $e");
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;

    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Tạo reference với tên file unique
      final fileName = 'avatar_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('avatars/$fileName');

      // Upload file
      final uploadTask = ref.putFile(_image!);
      final snapshot = await uploadTask;
      
      // Lấy download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      _showErrorDialog("Error uploading image: $e");
      return null;
    }
  }

  void _showImageSourceDialog() {
    showDialog(
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
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFF48FB1)),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _takePicture();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    CustomDialog.show(
      context,
      title: "Error",
      content: message,
      icon: Icons.error_outline,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    bool bold = false,
    bool isPassword = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: TextStyle(
        color: Colors.white,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFF48FB1), width: 1.5),
        ),
        hintStyle: const TextStyle(color: Colors.white38),
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
        if (_isUploading)
          const Positioned(
            child: CircularProgressIndicator(
              color: Color(0xFFF48FB1),
              strokeWidth: 2,
            ),
          ),
        GestureDetector(
          onTap: _isUploading ? null : _showImageSourceDialog,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(
              _isUploading ? Icons.hourglass_empty : Icons.edit,
              size: 18,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    if (_image != null) {
      return Image.file(_image!, fit: BoxFit.cover, width: 95, height: 95);
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      return Image.network(
        _currentAvatarUrl!,
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
    } else {
      return Image.asset(
        'assets/images/avatar.png',
        fit: BoxFit.cover,
        width: 95,
        height: 95,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorDialog("User not logged in");
        return;
      }

      String? avatarUrl = _currentAvatarUrl;

      // Upload ảnh mới nếu có
      if (_image != null) {
        avatarUrl = await _uploadImage();
        if (avatarUrl == null) {
          _showErrorDialog("Cannot upload image");
          return;
        }
      }

      // Cập nhật thông tin user
      final ref = _database.ref('users/${user.uid}');
      final updateData = {
        'username': usernameController.text.trim(),
        'phone_number': phoneController.text.trim(),
        'password': passwordController.text.trim(),
      };

      if (avatarUrl != null) {
        updateData['avatar_url'] = avatarUrl;
      }

      await ref.update(updateData);

      setState(() {
        _currentAvatarUrl = avatarUrl;
        _image = null; // Clear local image after successful upload
      });

      CustomDialog.show(
        context,
        title: "Success",
        content: "Profile updated successfully!",
        icon: Icons.check_circle_outline,
      );
    } catch (e) {
      _showErrorDialog("Error updating profile: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFF48FB1)),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildAvatarSection(),
            const SizedBox(height: 30),
            
            _buildLabel("Username"),
            _buildTextField(usernameController, bold: true),

            _buildLabel("Phone"),
            _buildTextField(phoneController),

            _buildLabel("Password"),
            _buildTextField(passwordController, isPassword: true),

            // forgot pass link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhoneInputScreen(), 
                    ),
                  );
                },
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(
                    color: Color(0xFFF48FB1),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: _isUploading 
                      ? Colors.grey 
                      : const Color(0xFFF48FB1),
                  elevation: 5,
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Saving...",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      )
                    : const Text(
                        "Save",
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}