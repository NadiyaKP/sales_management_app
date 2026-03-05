import 'package:flutter/material.dart' show Icons;
class AppConstants {
  // App name
  static const String appName = "Sales Management";
  
  // Routes
  static const String splashRoute = '/';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String loginRoute = '/login';
  
  // Button texts
  static const String register = "Register";
  static const String login = "Login";
  
  // Form fields
  static const String applicationId = "Application ID";
  static const String userId = "User ID";
  static const String password = "Password";
  
  // Home menu items
  static const List<Map<String, dynamic>> menuItems = [
    {'title': 'INVOICES', 'icon': Icons.receipt},
    {'title': 'SALES RETURN', 'icon': Icons.assignment_return},
    {'title': 'ORDER', 'icon': Icons.shopping_cart},
    {'title': 'RECEIPTS', 'icon': Icons.description},
    {'title': 'CHEQUES', 'icon': Icons.check_circle},
    {'title': 'DISCOUNT', 'icon': Icons.percent},
    {'title': 'STOCK', 'icon': Icons.inventory},
    {'title': 'CUSTOMERS', 'icon': Icons.people},
    {'title': 'REPORTS', 'icon': Icons.bar_chart},
    {'title': 'RECEIVED AMOUNT', 'icon': Icons.account_balance_wallet},
    
  ];
  
  // Bottom navigation items
  static const List<Map<String, dynamic>> bottomNavItems = [
    {'title': 'Home', 'icon': Icons.home},
     {'title': 'Financial Year', 'icon': Icons.calendar_today_outlined},
    {'title': 'Punch In', 'icon': Icons.access_time},
    {'title': 'Account', 'icon': Icons.person_outline},
  ];
}