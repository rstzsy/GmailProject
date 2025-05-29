import 'package:flutter/material.dart';
//import 'pages/inbox_page.dart'; 
import './pages/welcome_page.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Baloo2',
      ).copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Baloo2',
            ),
        primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(
              fontFamily: 'Baloo2',
            ),
      ),
      //home: const MyHomePage(), 
      home: WelcomeScreen(),
    );
  }
}
