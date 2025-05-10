import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gmail_project/pages/editProfile_page.dart';
import 'package:gmail_project/pages/languagSelection_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'welcome_page.dart'; 
import 'editProfile_page.dart';
import 'languagSelection_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  bool _isNotificationOn = true;

  File? _avatarImage;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _avatarImage = File(pickedFile.path);
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
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF48FB1)), // Màu nút back
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [              
              const SizedBox(height: 20),
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
                        child: _avatarImage != null
                            ? Image.file(_avatarImage!, fit: BoxFit.cover, width: 95, height: 95)
                            : Image.asset('assets/images/avatar.png', fit: BoxFit.cover, width: 95, height: 95),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.edit, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Text(
                'Lillie Brown',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
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

              Column(
                children: [
                  _buildInfoCard(Icons.email, "Email", "lilliebrown@example.com"),
                  const SizedBox(height: 10),
                  _buildInfoCard(Icons.phone, "Phone", "+1 234 567 890"),
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
                  onChanged: (value) {
                    setState(() {
                      _isNotificationOn = value;
                    });
                  },
                ),
              ),

              _buildListTile(
                FontAwesomeIcons.userSecret,
                "Edit Profile",
                Color(0xFF4CC9FE),
                (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfilePage(),
                    ),
                  );
                },

              ),

              _buildListTile(
                FontAwesomeIcons.language,
                "Languages",
                Color(0xFFFFB300),
                (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LanguageSelectionPage(),
                    ),
                  );
                },

              ),
              const Spacer(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  //onPressed: () {},
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
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
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
