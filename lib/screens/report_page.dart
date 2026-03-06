import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_item.dart';
import '../utils/constants.dart';
import 'home_page.dart';
import 'all_report_page.dart';
import 'account/account_ledger_page.dart';
import 'day_book_page.dart';
import 'debitors_page.dart';
import 'aged_receivable_page.dart';
import '../common/bottom_navigation_button.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  int _selectedIndex = 1; // Report tab selected

  final List<Map<String, dynamic>> reportItems = const [
    {'title': 'ALL REPORTS', 'icon': Icons.analytics},
    {'title': 'AGED RECEIVABLE', 'icon': Icons.receipt_long},
    {'title': 'DAY BOOK', 'icon': Icons.book},
    {'title': 'DEBTORS', 'icon': Icons.people},
    {'title': 'ACCOUNT LEDGER', 'icon': Icons.account_balance},
  ];

  void _handleReportTap(BuildContext context, String title) {
    if (title == 'ALL REPORTS') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AllReportPage()),
      );
    } else if (title == 'ACCOUNT LEDGER') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountLedgerPage()),
      );
    } else if (title == 'DAY BOOK') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DayBookPage()),
      );
    } else if (title == 'DEBTORS') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DebitorsPage()),
      );
    } else if (title == 'AGED RECEIVABLE') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AgedReceivableReportPage()),
      );
    } else {
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
                Navigator.pushReplacementNamed(context, AppConstants.registerRoute);
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
        title: const Text('REPORTS'),
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
                  childAspectRatio: 1.0, // Changed from 0.85 to 1.0 to match home_page.dart
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: reportItems.length,
                itemBuilder: (context, index) {
                  final item = reportItems[index];
                  return MenuItem(
                    title: item['title'],
                    icon: item['icon'],
                    onTap: () => _handleReportTap(context, item['title']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
       
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0, // Report page is at index 1
      ),
    );
  }
}