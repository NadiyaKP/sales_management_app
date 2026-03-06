import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sales_management_app/screens/login_page.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart';
import 'screens/debug_preferences_screen.dart';

// ✅ Import ApiServices
import 'services/api_service.dart';

/// ---------------- Permission Models ----------------
class PermissionResponse {
  final List<PermissionDetail> permissionDetails;

  PermissionResponse({required this.permissionDetails});

  factory PermissionResponse.fromJson(Map<String, dynamic> json) {
    return PermissionResponse(
      permissionDetails: (json['permissiondet'] as List)
          .map((item) => PermissionDetail.fromJson(item))
          .toList(),
    );
  }
}

class PermissionDetail {
  final String invoiceView;
  final String creditNoteView;
  final String receiptAdd;
  final String receiptDueAmount;
  final String orderAdd;
  final String orderView;
  final String customerAdd;

  PermissionDetail({
    required this.invoiceView,
    required this.creditNoteView,
    required this.receiptAdd,
    required this.receiptDueAmount,
    required this.orderAdd,
    required this.orderView,
    required this.customerAdd,
  });

  factory PermissionDetail.fromJson(Map<String, dynamic> json) {
    return PermissionDetail(
      invoiceView: json['invoice_view'] ?? '',
      creditNoteView: json['creditnote_view'] ?? '',
      receiptAdd: json['receipt_add'] ?? '',
      receiptDueAmount: json['receipt_due_amount'] ?? '',
      orderAdd: json['order_add'] ?? '',
      orderView: json['order_view'] ?? '',
      customerAdd: json['customer_add'] ?? '',
    );
  }

  @override
  String toString() {
    return '''
Invoice View: $invoiceView
Credit Note View: $creditNoteView
Receipt Add: $receiptAdd
Receipt Due Amount: $receiptDueAmount
Order Add: $orderAdd
Order View: $orderView
Customer Add: $customerAdd
''';
  }
}

/// ---------------- App Configuration ----------------
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// API Base URL - Keeping it as a constant in the code
const String url = 'http://192.168.1.108:80/gst-3-3-production/mobile-service/sales-executive';

// Print all SharedPreferences data
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

// ✅ Fetch permissions from API and print them
Future<void> fetchAndPrintPermissions() async {
  ApiServices api = ApiServices();
  final permissionResponse = await api.fetchPermissionDetails();

  if (permissionResponse == null) {
    print("⚠️ No permissions received from API.");
    return;
  }

  print("✅ Permissions loaded from API:");
  for (var detail in permissionResponse.permissionDetails) {
    print(detail); // thanks to toString()
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  // Orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await printAllSharedPreferences();
  await fetchAndPrintPermissions(); // ✅ call real API

  runApp(const MyApp());
}

/// ---------------- Flutter App ----------------
class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        AppConstants.login: (context) => const LoginPage(),
        AppConstants.homeRoute: (context) => const HomePage(),
        AppConstants.registerRoute: (context) =>
            const RegistrationScreen(),
      },
    );
  }
}

/// ---------------- Splash Screen ----------------
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
    await Future.delayed(const Duration(seconds: 3));

    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isRegistered = prefs.getBool('isRegistered') ?? false;

    print('🔍 Checking registration status: $isRegistered');

    if (!mounted) return;

    if (isRegistered) {
      print('✅ User is registered, navigating to HomePage');
      Navigator.pushReplacementNamed(context, AppConstants.homeRoute);
    } else {
      print('❌ User is not registered, navigating to RegistrationScreen');
      Navigator.pushReplacementNamed(context, AppConstants.registerRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/cm_logo.png',
              width: 170,
              height: 170,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 15),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
