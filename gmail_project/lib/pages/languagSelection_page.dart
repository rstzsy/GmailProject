import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

Future<String?> _loadUserLanguage() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final ref = FirebaseDatabase.instance.ref('users/${user.uid}/language');
  final snapshot = await ref.get();
  if (snapshot.exists) {
    final langCode = snapshot.value as String;
    // map từ langCode sang tên hiển thị
    switch (langCode) {
      case 'vi':
        return 'Vietnamese';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'en':
      default:
        return 'English';
    }
  }
  return null;
}


class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final List<Map<String, String>> _languages = [
    {
      'name': 'English',
      'sub': 'Default language',
      'flag': 'assets/images/flag_united.png'
    },
    {
      'name': 'Vietnamese',
      'sub': 'Ngôn ngữ tiếng Việt',
      'flag': 'assets/images/flag_vietnam.png'
    },
    {
      'name': 'Spanish',
      'sub': 'Idioma español',
      'flag': 'assets/images/flag_spanish.png'
    },
    {
      'name': 'French',
      'sub': 'Langue française',
      'flag': 'assets/images/flag_france.png'
    },
    {
      'name': 'Chinese',
      'sub': '中文',          
      'flag': 'assets/images/flag_chinese.jpg'
    },
    {
      'name': 'Japanese',
      'sub': '日本語',       
      'flag': 'assets/images/flag_japan.png'
    },
    {
      'name': 'Korean',
      'sub': '한국어',        
      'flag': 'assets/images/flag_korean.png'
    },

  ];

  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _initSelectedLanguage();
  }

  Future<void> _initSelectedLanguage() async {
    final lang = await _loadUserLanguage();
    if (lang != null) {
      setState(() {
        _selectedLanguage = lang;
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
          'Choose Language',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF48FB1)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = _selectedLanguage == lang['name'];

          return GestureDetector(
            onTap: () async {
              setState(() {
                _selectedLanguage = lang['name']!;
              });

              // Map tên ngôn ngữ thành code
              String langCode;
              switch (_selectedLanguage) {
                case 'Vietnamese':
                  langCode = 'vi';
                  break;
                case 'Spanish':
                  langCode = 'es';
                  break;
                case 'French':
                  langCode = 'fr';
                  break;
                case 'Chinese':
                  langCode = 'zh';
                  break;
                case 'Japanese':
                  langCode = 'ja';
                  break;
                case 'Korean':
                  langCode = 'ko';
                  break;
                default:
                  langCode = 'en';
              }
              // Lấy user hiện tại
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                // Lưu mã ngôn ngữ vào Firebase Realtime Database
                final ref = FirebaseDatabase.instance.ref('users/${user.uid}');
                await ref.update({'language': langCode});
              }

              // Quay lại màn trước với giá trị langCode
              Navigator.pop(context, langCode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2A233D) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color.fromARGB(255, 232, 174, 210), Color.fromARGB(255, 252, 160, 209)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        lang['flag']!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang['name']!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFFF48FB1) : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lang['sub']!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFFF48FB1)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
