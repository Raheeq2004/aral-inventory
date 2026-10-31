Claude


















Main · DART
import 'package:aral_project/Admin/providers/transaction_data.dart';
import 'package:aral_project/Landing/landing_page.dart';
import 'package:aral_project/Theme/theme.dart';
import 'package:aral_project/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
 
  // 2. Initialize Firebase FIRST before running the app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
 
  runApp(
    ChangeNotifierProvider(
      create: (context) => TransactionData(),
      child: const MyApp(),
    ),
  );
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: AppTheme.lightTheme,
      // The app now opens on the Landing page.
      // "Sign in" there opens AdminRouting (for now, until the Login page exists).
      home: const LandingPage(),
    );
  }
}
 
Claude finished the response
