import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sales_management_app/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../screens/home_page.dart';
import '../screens/login_page.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  RegistrationScreenState createState() => RegistrationScreenState();
}

class RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _phoneNoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _register(BuildContext context) async {
    String url = _urlController.text.trim();
    String phoneNo = _phoneNoController.text.trim();
    String password = _passwordController.text.trim();

    if (url.isEmpty || phoneNo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
        ),
      );
      return;
    }
    if (!_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid URL format'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    await _callRegistrationApi(url, phoneNo, password, context);
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _callRegistrationApi(
      String url, String phoneNo, String password, BuildContext context) async {
    final DateTime now = DateTime.now();
    String formattedDate = "${now.year.toString().padLeft(4, '0')}"
        "${now.month.toString().padLeft(2, '0')}"
        "${now.day.toString().padLeft(2, '0')}"
        "${now.hour.toString().padLeft(2, '0')}"
        "${now.minute.toString().padLeft(2, '0')}"
        "${now.second.toString().padLeft(2, '0')}";

    String apiUrl = '$url/registration.php';
    final Map<String, String> body = {
      "user_name": phoneNo,
      "unid": formattedDate,
      "password": password,
    };

    // Debug prints for request
    print('=== REGISTRATION API REQUEST ===');
    print('API URL: $apiUrl');
    print('Request Headers: {"Content-Type": "application/json"}');
    print('Request Body: ${json.encode(body)}');
    print('Formatted Date (unid): $formattedDate');
    print('================================');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      // Debug prints for response
      print('=== REGISTRATION API RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('==================================');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Debug print for parsed response data
        print('=== PARSED RESPONSE DATA ===');
        print('Parsed Data: $data');
        print('Result: ${data['result']}');
        print('Message: ${data['message']}');
        if (data.containsKey('slex')) {
          print('Slex: ${data['slex']}');
        }
        print('============================');

        if (data['result'] == "1") {
          String slex = data['slex'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isRegistered', true);
          await prefs.setString('url', url);
          await prefs.setString('username', phoneNo);
          await prefs.setString('password', password);
          await prefs.setString('slex', slex);
          await prefs.setString('unid', formattedDate);
          
          print('=== SHARED PREFERENCES SAVED ===');
          print('isRegistered: true');
          print('url: $url');
          print('username: $phoneNo');
          print('password: [HIDDEN]');
          print('slex: $slex');
          print('unid: $formattedDate');
          print('=================================');
          
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration Successful: ${data['message']}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else {
          print('=== REGISTRATION FAILED ===');
          print('Server returned result: ${data['result']}');
          print('Error message: ${data['message']}');
          print('===========================');
          
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${data['message']}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        print('=== HTTP ERROR ===');
        print('Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
        print('==================');
        
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (error) {
      print('=== EXCEPTION CAUGHT ===');
      print('Error Type: ${error.runtimeType}');
      print('Error Message: $error');
      print('========================');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  bool _isValidUrl(String url) {
    const urlPattern =
        r'^(https?:\/\/)?([\w-]+\.)+[\w-]{2,4}(/[\w\-./?%&=]*)?$';
    return RegExp(urlPattern).hasMatch(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Icon(
                      Icons.account_circle,
                      size: 80,
                      color: Colors.white,
                    ),
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _urlController,
                            labelText: 'Server URL',
                            hintText: 'Enter the URL',
                            icon: Icons.link,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _phoneNoController,
                            labelText: 'Username',
                            hintText: 'Enter Your Username',
                            icon: Icons.person,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(),
                          const SizedBox(height: 30),
                          _buildRegisterButton(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "Registering...",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
      ),
      enabled: enabled,
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(
          Icons.lock,
          color: Theme.of(context).primaryColor,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
      ),
      enabled: !_isLoading,
    );
  }

  Widget _buildRegisterButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _register(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'REGISTER',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}