import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../common/financial_year_dialog.dart';
import '../screens/punchin/punchin_details.dart';
import '../screens/login_page.dart';
import '../screens/home_page.dart';

// ─── StatefulWidget so we can load + refresh the financial year label ─────────

class BottomNavigationButton extends StatefulWidget {
  final int selectedIndex;

  const BottomNavigationButton({
    Key? key,
    required this.selectedIndex,
  }) : super(key: key);

  @override
  State<BottomNavigationButton> createState() => _BottomNavigationButtonState();
}

class _BottomNavigationButtonState extends State<BottomNavigationButton> {
  /// The human-readable year stored in SharedPreferences, e.g. "2025 - 2026".
  /// Shown as the label under the calendar icon.
  String? _financialYearLabel;

  @override
  void initState() {
    super.initState();
    _loadFinancialYear();
  }

  // Reads the saved label from SharedPreferences and refreshes the nav bar.
  Future<void> _loadFinancialYear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final label = prefs.getString('selected_financial_year')
                ?? prefs.getString('current_financial_year');
    if (mounted) setState(() => _financialYearLabel = label);
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _onItemTapped(BuildContext context, int index) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (index == 0) {
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
      // Open the Financial Year dialog, then refresh the label when it closes.
      showFinancialYearDialog(context, barrierDismissible: true)
          .then((_) => _loadFinancialYear());
    } else if (index == 2) {
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

  // ─── Logout Options ──────────────────────────────────────────────────────────

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
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Change Password
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
                            horizontal: 24, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.lock_outline,
                              color: AppTheme.primaryColor, size: 18),
                        ),
                        title: Text(
                          'Change Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 14,
                            color: AppTheme.primaryColor.withOpacity(0.7)),
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
                    // Logout
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade50, Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.logout,
                              color: Colors.red.shade600, size: 20),
                        ),
                        title: Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.red.shade700,
                          ),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.red.shade300),
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

  // ─── Change Password ─────────────────────────────────────────────────────────

  void _handleChangePassword(BuildContext context) {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController =
        TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
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
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.lock_outline,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('Change Password',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPasswordField(
                    controller: currentPasswordController,
                    label: 'Current Password',
                    hint: 'Enter your current password',
                    icon: Icons.lock_outline,
                    iconColor: Colors.grey.shade600,
                    obscure: obscureCurrentPassword,
                    enabled: !isLoading,
                    onToggle: () => setState(() =>
                        obscureCurrentPassword = !obscureCurrentPassword),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: newPasswordController,
                    label: 'New Password',
                    hint: 'Enter your new password',
                    icon: Icons.lock,
                    iconColor: AppTheme.primaryColor,
                    obscure: obscureNewPassword,
                    enabled: !isLoading,
                    onToggle: () => setState(
                        () => obscureNewPassword = !obscureNewPassword),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: confirmPasswordController,
                    label: 'Confirm New Password',
                    hint: 'Confirm your new password',
                    icon: Icons.lock_reset,
                    iconColor: AppTheme.primaryColor,
                    obscure: obscureConfirmPassword,
                    enabled: !isLoading,
                    onToggle: () => setState(() =>
                        obscureConfirmPassword = !obscureConfirmPassword),
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
                              color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Text('Updating password...',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        currentPasswordController.dispose();
                        newPasswordController.dispose();
                        confirmPasswordController.dispose();
                        Navigator.pop(context);
                      },
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 12)),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        await _changePassword(
                          context,
                          currentPasswordController.text.trim(),
                          newPasswordController.text.trim(),
                          confirmPasswordController.text.trim(),
                          setState,
                          () => setState(() => isLoading = true),
                          () => setState(() => isLoading = false),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                ),
                child: const Text('Change Password',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool obscure,
    required bool enabled,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade600,
            size: 18,
          ),
          onPressed: onToggle,
        ),
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
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar(context, 'All fields are required', Colors.redAccent);
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar(context,
          'New password and confirm password do not match', Colors.redAccent);
      return;
    }
    if (newPassword.length < 4) {
      _showSnackBar(context,
          'New password must be at least 4 characters long', Colors.redAccent);
      return;
    }
    if (currentPassword == newPassword) {
      _showSnackBar(
          context,
          'New password must be different from current password',
          Colors.redAccent);
      return;
    }

    setLoading();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? url  = prefs.getString('url');
      final String? unid = prefs.getString('unid');
      final String? slex = prefs.getString('slex');

      if (url == null ||
          unid == null ||
          slex == null ||
          url.isEmpty ||
          unid.isEmpty ||
          slex.isEmpty) {
        clearLoading();
        if (!context.mounted) return;
        _showSnackBar(context, 'Session expired. Please login again.',
            Colors.redAccent);
        return;
      }

      final response = await http.post(
        Uri.parse('$url/action/change-password.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'unid': unid,
          'slex': slex,
          'old_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      clearLoading();
      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == '1') {
          await prefs.setString('password', newPassword);
          Navigator.pop(context);
          _showSnackBar(
              context,
              data['message'] ?? 'Password changed successfully',
              AppTheme.primaryColor);
        } else {
          _showSnackBar(context,
              data['message'] ?? 'Failed to change password', Colors.redAccent);
        }
      } else {
        _showSnackBar(
            context,
            'Failed to change password: ${response.statusCode}',
            Colors.redAccent);
      }
    } catch (error) {
      clearLoading();
      if (!context.mounted) return;
      _showSnackBar(context, 'Error: $error', Colors.redAccent);
    }
  }

  void _showSnackBar(
      BuildContext context, String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

 // ─── Logout ──────────────────────────────────────────────────────────────────

void _handleLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.logout, color: Colors.red.shade600, size: 24),
          const SizedBox(width: 8),
          const Text('Logout',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text('Are you sure you want to logout?',
          style: TextStyle(fontSize: 16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            
            // Just navigate to login page without removing any data
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) => const LoginPage()),
                (route) => false,
              );
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Logout',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeIndex = widget.selectedIndex < AppConstants.bottomNavItems.length
        ? widget.selectedIndex
        : 0;

    final items = AppConstants.bottomNavItems;

    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: (index) => _onItemTapped(context, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primaryColor,
      unselectedItemColor: Colors.grey,
      items: items.map<BottomNavigationBarItem>((item) {
        final isFinancialYear = item['title'] == 'Financial Year';
        return BottomNavigationBarItem(
          icon: Icon(item['icon']),
          // For the Financial Year tab: show the saved year (e.g. "2025 - 2026")
          // if available, otherwise fall back to the static title.
          label: isFinancialYear
              ? (_financialYearLabel ?? 'Financial Year')
              : item['title'],
        );
      }).toList(),
    );
  }
}