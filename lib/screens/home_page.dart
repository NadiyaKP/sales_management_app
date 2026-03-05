import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/menu_item.dart';
import '../common/bottom_navigation_button.dart';
import '../common/financial_year_dialog.dart'; // ← shared dialog
import 'invoice/invoice_page.dart';
import 'sales_return/sales_return.dart';
import 'receipts/receipts_page.dart';
import 'order/orders_page.dart';
import 'customers/customers_page.dart';
import 'cheques/cheques_page.dart';
import 'discount/discounts_page.dart';
import 'stock/stocks_page.dart';
import 'received_amount_page.dart';
import 'report_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // After the first frame is rendered, check if a financial year has
    // already been selected. If not, force the user to pick one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFinancialYear();
    });
  }

  Future<void> _checkFinancialYear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // Check the label key — this is what gets written on a successful confirm.
    final savedYear = prefs.getString('selected_financial_year');

    if (!mounted) return;

    // Only show the dialog when nothing has ever been confirmed.
    if (savedYear == null || savedYear.isEmpty) {
      showFinancialYearDialog(
        context,
        barrierDismissible: false,
      );
    }
  }

  void _handleMenuItemTap(String title) {
    if (title == 'INVOICES') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const InvoicePage()));
    } else if (title == 'SALES RETURN') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SalesReturnPage()));
    } else if (title == 'RECEIPTS') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ReceiptsPage()));
    } else if (title == 'ORDER') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const OrdersPage()));
    } else if (title == 'CUSTOMERS') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => CustomersPage()));
    } else if (title == 'CHEQUES') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ChequesPage()));
    } else if (title == 'DISCOUNT') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const DiscountsPage()));
    } else if (title == 'STOCK') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const StocksPage()));
    } else if (title == 'RECEIVED AMOUNT') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ReceivedAmountPage()));
    } else if (title == 'REPORTS') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ReportPage()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title clicked')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HOME'),
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
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: AppConstants.menuItems.length,
                itemBuilder: (context, index) {
                  final item = AppConstants.menuItems[index];
                  return MenuItem(
                    title: item['title'],
                    icon: item['icon'],
                    onTap: () => _handleMenuItemTap(item['title']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavigationButton(selectedIndex: 0),
    );
  }
}