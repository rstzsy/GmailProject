import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserAvatar extends StatefulWidget {
  final double radius;
  final VoidCallback? onTap;
  final bool showLoadingIndicator;

  const UserAvatar({
    super.key,
    this.radius = 20,
    this.onTap,
    this.showLoadingIndicator = true,
  });

  @override
  State<UserAvatar> createState() => UserAvatarState();
}

class UserAvatarState extends State<UserAvatar> {
  String? avatarUrl;
  bool isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    fetchUserAvatar();
  }

  // Hàm lấy avatar từ Firebase
  Future<void> fetchUserAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final dbRef = FirebaseDatabase.instance.ref('users/$uid');
      
      try {
        final snapshot = await dbRef.get();
        if (snapshot.exists) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          if (mounted) {
            setState(() {
              avatarUrl = data['avatar_url'];
              isLoadingAvatar = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => isLoadingAvatar = false);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoadingAvatar = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => isLoadingAvatar = false);
      }
    }
  }

  // Method để refresh avatar từ bên ngoài
  void refreshAvatar() {
    setState(() {
      isLoadingAvatar = true;
      avatarUrl = null;
    });
    fetchUserAvatar();
  }

  Widget _buildAvatarContent() {
    if (isLoadingAvatar && widget.showLoadingIndicator) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    // Nếu có avatar từ Firebase
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Colors.grey,
        onBackgroundImageError: (exception, stackTrace) {
          // Nếu lỗi load ảnh từ Firebase, fallback về ảnh mặc định
          if (mounted) {
            setState(() {
              avatarUrl = null;
            });
          }
        },
      );
    }

    // Fallback về ảnh mặc định
    return CircleAvatar(
      backgroundImage: const AssetImage('assets/images/avatar.png'),
      radius: widget.radius,
      backgroundColor: Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = _buildAvatarContent();

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}