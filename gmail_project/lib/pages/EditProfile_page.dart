import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; 

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  File? _image;
  final picker = ImagePicker();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  // final firstNameController = TextEditingController(text: "Lillie");
  // final lastNameController = TextEditingController(text: "Brown");
  // final positionController = TextEditingController(text: "UI/UX Designer");
  // final emailController = TextEditingController(text: "lillie@example.com");

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
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
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
            Stack(
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
                      child: _image != null
                          ? Image.file(_image!, fit: BoxFit.cover, width: 95, height: 95)
                          : Image.asset('assets/images/avatar.png', fit: BoxFit.cover, width: 95, height: 95),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.edit, size: 18, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            // _buildLabel("First Name"),
            // _buildTextField(firstNameController, bold: true),
            // _buildLabel("Last Name"),
            // _buildTextField(lastNameController),
            // _buildLabel("Current Position"),
            // _buildTextField(
            //   positionController,
            //   suffixIcon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
            // ),
            // _buildLabel("Email"),
            // _buildTextField(emailController),
            _buildLabel("Username"),
            _buildTextField(usernameController, bold: true),

            _buildLabel("Phone"),
            _buildTextField(phoneController),

            _buildLabel("Password"),
            _buildTextField(passwordController, isPassword: true),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final user = _auth.currentUser;
                  if (user != null) {
                    final ref = _database.ref('users/${user.uid}');
                    await ref.update({
                      'username': usernameController.text,
                      'phone_number': phoneController.text,
                      'password': passwordController.text,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: const Color(0xFFF48FB1),
                  elevation: 5,
                ),
                child: const Text(
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
}
