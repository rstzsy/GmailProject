import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gmail_project/pages/editProfile_page.dart';
import 'package:gmail_project/pages/languagSelection_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:translator/translator.dart'; // Add translator package
import 'welcome_page.dart'; 
import 'editProfile_page.dart';
import 'languagSelection_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'twoStepVerification_page.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isNotificationOn = true;
  bool _isUpdatingNotification = false;
  File? _avatarImage;

  String username = '';
  String phone = '';
  String? avatarUrl;
  bool isLoading = true;
  bool isUploadingAvatar = false;
  
  // Translation related variables
  String userLanguage = 'en';
  final translator = GoogleTranslator();
  late final DatabaseReference _languageRef;
  StreamSubscription<DatabaseEvent>? _languageSubscription;
  
  // Translated text cache
  Map<String, String> translatedTexts = {};

  @override
  void initState() {
    super.initState();
    _initLanguageListener();
    fetchUserData();
  }

  @override
  void dispose() {
    _languageSubscription?.cancel();
    super.dispose();
  }

  // Initialize language listener
  Future<void> _initLanguageListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _languageRef = FirebaseDatabase.instance.ref('users/${user.uid}/language');
      
      // Listen for language changes
      _languageSubscription = _languageRef.onValue.listen((event) async {
        final newLang = event.snapshot.value?.toString() ?? 'en';
        if (newLang != userLanguage) {
          setState(() {
            userLanguage = newLang;
            translatedTexts.clear(); // Clear cache when language changes
          });
          await _translateAllTexts();
        }
      });
      
      // Get initial language
      final snapshot = await _languageRef.get();
      userLanguage = snapshot.value?.toString() ?? 'en';
      await _translateAllTexts();
    }
  }

  // Translate text function
  Future<String> translateText(String text, String targetLang) async {
    if (text.isEmpty) return text;
    if (targetLang == 'en') return text;
    
    // Check cache first
    final cacheKey = '${text}_$targetLang';
    if (translatedTexts.containsKey(cacheKey)) {
      return translatedTexts[cacheKey]!;
    }
    
    try {
      final translation = await translator.translate(text, to: targetLang);
      translatedTexts[cacheKey] = translation.text;
      return translation.text;
    } catch (e) {
      print("Translate error: $e");
      return text;
    }
  }

  // Translate all UI texts
  Future<void> _translateAllTexts() async {
    if (userLanguage == 'en') return;
    
    final textsToTranslate = [
      'Profile',
      'Phone',
      'Notifications',
      'Edit Profile',
      'Languages',
      'Logout',
      'UX/UI Designer',
      'Select Image Source',
      'Photo Library',
      'Take Photo',
      'Error',
      'Success',
      'OK',
      'Avatar updated successfully!',
      'Notifications enabled. You\'ll receive notifications for new messages.',
      'Notifications disabled. You won\'t receive any notifications.',
      'Failed to update notification setting. Please try again.',
    ];

    for (String text in textsToTranslate) {
      await translateText(text, userLanguage);
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  // Helper method to get translated text
  String getTranslatedText(String originalText) {
    if (userLanguage == 'en') return originalText;
    final cacheKey = '${originalText}_$userLanguage';
    return translatedTexts[cacheKey] ?? originalText;
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
          avatarUrl = data['avatar_url'];
          _isNotificationOn = data['notification_enabled'] ?? true;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateNotificationSetting(bool value) async {
    setState(() {
      _isUpdatingNotification = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      
      await dbRef.update({
        'notification_enabled': value,
        'notification_updated_at': ServerValue.timestamp,
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      final snapshot = await dbRef.child('notification_enabled').get();
      final actualValue = snapshot.value as bool? ?? true;
      
      if (actualValue != value) {
        throw Exception('Failed to update notification setting - verification failed');
      }
      
      print('Notification setting successfully updated to: $value');
      print('Verified value in database: $actualValue');
      
    } catch (e) {
      print('Error updating notification setting: $e');
      throw e;
    } finally {
      setState(() {
        _isUpdatingNotification = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
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
          title: Text(
            getTranslatedText('Select Image Source'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFF48FB1)),
                title: Text(
                  getTranslatedText('Photo Library'), 
                  style: const TextStyle(color: Colors.white)
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFF48FB1)),
                title: Text(
                  getTranslatedText('Take Photo'), 
                  style: const TextStyle(color: Colors.white)
                ),
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

      final fileName = 'avatar_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('avatars/$fileName');

      final uploadTask = ref.putFile(_avatarImage!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final dbRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      await dbRef.update({'avatar_url': downloadUrl});

      setState(() {
        avatarUrl = downloadUrl;
        _avatarImage = null;
        isUploadingAvatar = false;
      });

      _showSuccessDialog(getTranslatedText("Avatar updated successfully!"));
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
        title: Text(getTranslatedText('Error'), style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(getTranslatedText('OK'), style: const TextStyle(color: Color(0xFFF48FB1))),
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
        title: Text(getTranslatedText('Success'), style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(getTranslatedText('OK'), style: const TextStyle(color: Color(0xFFF48FB1))),
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
    if (_avatarImage != null) {
      return Image.file(_avatarImage!, fit: BoxFit.cover, width: 95, height: 95);
    }
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
        title: Text(
          getTranslatedText('Profile'), 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)
        ),
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
                    _buildAvatarSection(),
                    const SizedBox(height: 10),
                    Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFffcad4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(FontAwesomeIcons.handHoldingHeart, color: Color(0xFFE21033), size: 18),
                          const SizedBox(width: 5),
                          Text(
                            getTranslatedText("UX/UI Designer"), 
                            style: const TextStyle(fontSize: 14, color: Colors.black)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Column(
                      children: [
                        _buildInfoCard(Icons.phone, getTranslatedText("Phone"), phone),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildListTile(
                      Icons.notifications,
                      getTranslatedText("Notifications"),
                      const Color(0xFFFF80AB),
                      null,
                      _isUpdatingNotification 
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF80AB),
                            ),
                          )
                        : Switch(
                            value: _isNotificationOn,
                            activeColor: const Color(0xFFFF80AB),
                            onChanged: _isUpdatingNotification ? null : (value) async {
                              print('Switch toggled to: $value');
                              
                              final previousValue = _isNotificationOn;
                              setState(() {
                                _isNotificationOn = value;
                              });

                              try {
                                await _updateNotificationSetting(value);
                                
                                String message = value 
                                  ? getTranslatedText("Notifications enabled. You'll receive notifications for new messages.")
                                  : getTranslatedText("Notifications disabled. You won't receive any notifications.");
                                
                                _showSuccessDialog(message);
                                
                                print('Notification setting change completed successfully');
                                
                              } catch (e) {
                                print('Failed to update notification setting: $e');
                                
                                setState(() {
                                  _isNotificationOn = previousValue;
                                });
                                
                                _showErrorDialog(getTranslatedText('Failed to update notification setting. Please try again.'));
                              }
                            },
                          ),
                    ),

                    _buildListTile(
                      FontAwesomeIcons.userSecret,
                      getTranslatedText("Edit Profile"),
                      const Color(0xFF4CC9FE),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfilePage()),
                      ).then((value) {
                        fetchUserData();
                      })
                    ),
                    _buildListTile(
                      FontAwesomeIcons.language,
                      getTranslatedText("Languages"),
                      const Color(0xFFFFB300),
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LanguageSelectionPage())),
                    ),
                    _buildListTile(
                      FontAwesomeIcons.shield,
                      getTranslatedText("Two-Step Verification"),
                      const Color(0xFF4CAF50),
                      () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const TwoStepVerificationPage())
                      ),
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
                        label: Text(
                          getTranslatedText("Logout"), 
                          style: const TextStyle(color: Colors.black)
                        ),
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
        color: const Color.fromARGB(255, 255, 230, 238),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE21033).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFFE21033)),
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