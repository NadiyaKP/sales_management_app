import 'package:flutter/material.dart';
import 'package:sales_management_app/screens/sales_return/sales_return.dart';
import 'package:sales_management_app/screens/all_reports/sales_return_report.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_item.dart';
import '../utils/constants.dart';
import 'home_page.dart';
import 'report_page.dart';
import 'all_reports/my_ledger_report.dart';
import 'all_reports/receipt_report_page.dart';
import 'all_reports/commission_report_page.dart';
import 'all_reports/discount_report_page.dart';
import 'all_reports/order_report_page.dart';
import 'all_reports/sales_report_page.dart'; 
import '../common/bottom_navigation_button.dart';

class AllReportPage extends StatefulWidget {
  const AllReportPage({Key? key}) : super(key: key);

  @override
  State<AllReportPage> createState() => _AllReportPageState();
}

class _AllReportPageState extends State<AllReportPage> {
  int _selectedIndex = 1; // Report tab active

  final List<Map<String, dynamic>> allReports = const [
    {'title': 'MY LEDGER', 'icon': Icons.bookmark},
    {'title': 'SALES', 'icon': Icons.shopping_cart},
    {'title': 'RECEIPT', 'icon': Icons.receipt},
    {'title': 'COMMISSIONS', 'icon': Icons.money},
    {'title': 'SALES RETURN', 'icon': Icons.undo},
    {'title': 'DISCOUNT', 'icon': Icons.percent},
    {'title': 'ORDER', 'icon': Icons.assignment},
  ];

  void _handleTap(BuildContext context, String title) {
    if (title == 'MY LEDGER') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MyLedgerReportPage()),
      );
    } else if (title == 'SALES') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SalesReportPage()),
      );
    } else if (title == 'RECEIPT') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReceiptReportPage()),
      );
    } else if (title == 'COMMISSIONS') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CommissionReportPage()),
      );
    } else if (title == 'DISCOUNT') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DiscountReportPage()),
      );
    } else if (title == 'ORDER') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OrderReportPage()),
      );
    } else if (title == 'SALES RETURN') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SalesReturnReportPage()),
      );
    }else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title tapped')),
      );
      
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReportPage()),
      );
    } else if (index == 3) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(
                  context,
                  AppConstants.registerRoute,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ALL REPORTS'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.0, // Changed from 0.85 to 1.0 to match home_page
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: allReports.length,
                itemBuilder: (context, index) {
                  final item = allReports[index];
                  return MenuItem(
                    title: item['title'],
                    icon: item['icon'],
                    onTap: () => _handleTap(context, item['title']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
       bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0, // Home page is at index 0
      ),
    );
  }
}