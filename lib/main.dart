import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sales_management_app/screens/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart';
import 'dart:io';
import 'screens/debug_preferences_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// Function to print all SharedPreferences data
Future<void> printAllSharedPreferences() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  Set<String> keys = prefs.getKeys();

  if (keys.isEmpty) {
    print("🔍 No SharedPreferences data found.");
  } else {
    print("📦 SharedPreferences Contents:");
    for (String key in keys) {
      var value = prefs.get(key);
      print('🔑 $key: $value');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('url')) {
    await prefs.setString('url', 'https://www.coremicron.in/test/mobile-service');
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await printAllSharedPreferences();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // Start with splash screen
      routes: {
        AppConstants.login: (context) => const LoginPage(),
        AppConstants.homeRoute: (context) => const HomePage(),
        AppConstants.registerRoute: (context) => const RegistrationScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    // Show splash screen for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isRegistered = prefs.getBool('isRegistered') ?? false;
    
    print('🔍 Checking registration status: $isRegistered');
    
    if (!mounted) return;
    
    if (isRegistered) {
      // User is registered, navigate to home page
      print('✅ User is registered, navigating to HomePage');
      Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
    } else {
      // User is not registered, navigate to registration page
      print('❌ User is not registered, navigating to RegistrationScreen');
      Navigator.pushReplacementNamed(context, AppConstants.registerRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.point_of_sale,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}