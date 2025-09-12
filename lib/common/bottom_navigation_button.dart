import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../screens/report_page.dart';
import '../screens/punchin/punchin_details.dart';
import '../screens/login_page.dart';
import '../screens/home_page.dart'; // Add this import - replace with your actual home page import

class BottomNavigationButton extends StatelessWidget {
  final int selectedIndex;
  
  const BottomNavigationButton({
    Key? key,
    required this.selectedIndex,
  }) : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
    // Get current route name to avoid unnecessary navigation
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    if (index == 0) {
      // Handle Home navigation
      // Only navigate if we're not already on the home page
      if (currentRoute != '/home' && currentRoute != '/') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomePage(), 
            settings: const RouteSettings(name: '/home'),
          ),
          (route) => false, 
        );
      }
    } else if (index == 1) {
      // Handle Reports navigation
      if (currentRoute != '/report') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ReportPage(),
            settings: const RouteSettings(name: '/report'),
          ),
        );
      }
    } else if (index == 2) {
      // Handle Punch-in navigation
      if (currentRoute != '/punchin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PunchInDetailsPage(),
            settings: const RouteSettings(name: '/punchin'),
          ),
        );
      }
    } else if (index == 3) {
      _showLogoutOptions(context);
    }
  }

  void _showLogoutOptions(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          'Change Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppTheme.primaryColor.withOpacity(0.7),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _handleChangePassword(context);
                        },
                      ),
                    ),
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.grey.shade300,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade50,
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.logout,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.red.shade700,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.red.shade300,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _handleLogout(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleChangePassword(BuildContext context) {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current Password Field
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrentPassword,
                    enabled: !isLoading,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Enter your current password',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureCurrentPassword = !obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // New Password Field
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNewPassword,
                    enabled: !isLoading,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Enter your new password',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.lock,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureNewPassword = !obscureNewPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Confirm Password Field
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    enabled: !isLoading,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: const TextStyle(fontSize: 12),
                      hintText: 'Confirm your new password',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_reset,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey.shade600,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword = !obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Updating password...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () {
                  currentPasswordController.dispose();
                  newPasswordController.dispose();
                  confirmPasswordController.dispose();
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  await _changePassword(
                    context,
                    currentPasswordController.text.trim(),
                    newPasswordController.text.trim(),
                    confirmPasswordController.text.trim(),
                    setState,
                    () {
                      setState(() {
                        isLoading = true;
                      });
                    },
                    () {
                      setState(() {
                        isLoading = false;
                      });
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Change Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changePassword(
    BuildContext context,
    String currentPassword,
    String newPassword,
    String confirmPassword,
    StateSetter setState,
    VoidCallback setLoading,
    VoidCallback clearLoading,
  ) async {
    // Validation
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(
        context,
        'All fields are required',
        Colors.redAccent,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar(
        context,
        'New password and confirm password do not match',
        Colors.redAccent,
      );
      return;
    }

    if (newPassword.length < 4) {
      _showSnackBar(
        context,
        'New password must be at least 4 characters long',
        Colors.redAccent,
      );
      return;
    }

    if (currentPassword == newPassword) {
      _showSnackBar(
        context,
        'New password must be different from current password',
        Colors.redAccent,
      );
      return;
    }

    setLoading();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null || 
          url.isEmpty || unid.isEmpty || slex.isEmpty) {
        clearLoading();
        if (!context.mounted) return;
        _showSnackBar(
          context,
          'Session expired. Please login again.',
          Colors.redAccent,
        );
        return;
      }

      String apiUrl = '$url/action/change-password.php';
      final Map<String, String> body = {
        "unid": unid,
        "slex": slex,
        "old_password": currentPassword,
        "new_password": newPassword,
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      clearLoading();

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] == "1") {
          // Update stored password in SharedPreferences
          await prefs.setString('password', newPassword);
          
          Navigator.pop(context);
          _showSnackBar(
            context,
            data['message'] ?? 'Password changed successfully',
            AppTheme.primaryColor,
          );
        } else {
          _showSnackBar(
            context,
            data['message'] ?? 'Failed to change password',
            Colors.redAccent,
          );
        }
      } else {
        _showSnackBar(
          context,
          'Failed to change password: ${response.statusCode}',
          Colors.redAccent,
        );
      }
    } catch (error) {
      clearLoading();
      if (!context.mounted) return;
      _showSnackBar(
        context,
        'Error: $error',
        Colors.redAccent,
      );
    }
  }

  void _showSnackBar(BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Clear user session data
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isRegistered', false);
              await prefs.remove('username');
              await prefs.remove('password');
              await prefs.remove('slex');
              
              // Navigate to login page and clear all previous routes
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the number of items from AppConstants
    final items = AppConstants.bottomNavItems;
    
    // Ensure selectedIndex is within valid range
    final safeSelectedIndex = selectedIndex < items.length ? selectedIndex : 0;
    
    return BottomNavigationBar(
      currentIndex: safeSelectedIndex,
      onTap: (index) => _onItemTapped(context, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.grey,
      items: items.map<BottomNavigationBarItem>((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon']),
          label: item['title'],
        );
      }).toList(),
    );
  }
}