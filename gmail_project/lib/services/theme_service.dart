import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDarkMode = true;
  
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  // Light Theme Colors
  static const Color lightBackground = Colors.white;
  static const Color lightPrimary = Colors.pink;
  static const Color lightButtonBackground = Color(0xFFffcad4);
  static const Color lightTextColor = Colors.pink;
  static const Color lightIconColor = Colors.pink;

  // Dark Theme Colors
  static const Color darkBackground = Colors.black;
  static const Color darkPrimary = Color(0xFFF4538A);
  static const Color darkButtonBackground = Color(0xFFffcad4);
  static const Color darkTextColor = Color(0xFFF4538A);
  static const Color darkIconColor = Color(0xFFF4538A);

  // Get current theme colors
  Color get backgroundColor => _isDarkMode ? darkBackground : lightBackground;
  Color get primaryColor => _isDarkMode ? darkPrimary : lightPrimary;
  Color get buttonBackgroundColor => _isDarkMode ? darkButtonBackground : lightButtonBackground;
  Color get textColor => _isDarkMode ? darkTextColor : lightTextColor;
  Color get iconColor => _isDarkMode ? darkIconColor : lightIconColor;

  // Theme Data
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Baloo2',
      primarySwatch: Colors.pink,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: lightTextColor),
      ),
    ).copyWith(
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'Baloo2',
      ),
      primaryTextTheme: ThemeData.light().primaryTextTheme.apply(
        fontFamily: 'Baloo2',
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Baloo2',
      primarySwatch: Colors.pink,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: darkTextColor),
      ),
    ).copyWith(
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Baloo2',
      ),
      primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
        fontFamily: 'Baloo2',
      ),
    );
  }

  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;
}