import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.arrow_back, color: Colors.brown),
                ],
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFF4538A),
                    child: ClipOval(
                      child: _avatarImage != null
                          ? Image.file(_avatarImage!, fit: BoxFit.cover, width: 90, height: 90)
                          : Image.asset('assets/images/avatar.png', fit: BoxFit.cover, width: 90, height: 90),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.edit, size: 16, color: Colors.black),
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
              _buildListTile(Icons.notifications, "Notifications", Color(0xFFFF80AB)),
              _buildListTile(FontAwesomeIcons.userSecret, "Edit Profile", Color(0xFFC1B0E8)),
              _buildListTile(Icons.file_download, "My downloads", Color(0xFF42A5F5)),
              _buildListTile(Icons.payment, "Payment settings", Color(0xFFFFB300)),
              const Spacer(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  onPressed: () {},
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


  Widget _buildListTile(IconData icon, String title, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
      onTap: () {},
    );
  }
}
