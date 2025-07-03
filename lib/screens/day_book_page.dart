import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/permission.dart';
import 'invoice/invoice_view.dart';

// Data Models from daybook.dart
class DayBookInvoice {
  final String invoiceNo;
  final String invId;
  final String credit;
  final String debit;

  DayBookInvoice({
    required this.invoiceNo,
    required this.invId,
    required this.debit,
    required this.credit,
  });

  factory DayBookInvoice.fromJson(Map<String, dynamic> json) {
    return DayBookInvoice(
      invoiceNo: json['invoice_no'] ?? '',
      invId: json['invid'] ?? '',
      debit: json['debit'] ?? '',
      credit: json['credit'] ?? '',
    );
  }
}

class DayBookCredit {
  final String creditNo;
  final String crdId;
  final String credit;
  final String debit;

  DayBookCredit({
    required this.creditNo,
    required this.crdId,
    required this.credit,
    required this.debit,
  });

  factory DayBookCredit.fromJson(Map<String, dynamic> json) {
    return DayBookCredit(
      creditNo: json['credit_no'] ?? '',
      crdId: json['crdid'] ?? '',
      credit: json['credit'] ?? '',
      debit: json['debit'] ?? '',
    );
  }
}

class DayBookDiscount {
  final String customerName;
  final String credit;
  final String debit;

  DayBookDiscount({
    required this.customerName,
    required this.credit,
    required this.debit,
  });

  factory DayBookDiscount.fromJson(Map<String, dynamic> json) {
    return DayBookDiscount(
      customerName: json['cust_name'] ?? '',
      credit: json['credit'] ?? '',
      debit: json['debit'] ?? '',
    );
  }
}

String dayBook = '';

class DayBookPage extends StatefulWidget {
  const DayBookPage({Key? key}) : super(key: key);

  @override
  State<DayBookPage> createState() => _DayBookPageState();
}

class _DayBookPageState extends State<DayBookPage> {
  int _selectedIndex = 1; // Report tab is selected
  DateTime _selectedDate = DateTime.now();
  String _totalDebit = '0.00';
  String _totalCredit = '0.00';
  String _mainTitle = '';
  
  List<DayBookInvoice> _invoiceTransactions = [];
  List<DayBookCredit> _creditTransactions = [];
  List<DayBookDiscount> _discountTransactions = [];
  
  bool _isLoading = false;
  ApiServices apiServices = ApiServices();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchDayBookData(_selectedDate);
  }

  Future<void> _fetchDayBookData(DateTime date) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    // Format date for API
    String formattedDate = DateFormat('yyyy-MM-dd').format(date);

    try {
      final response = await http.post(
        Uri.parse('$url/day-book.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "from_date": formattedDate,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> invoiceDayBook = data['invoicedet'] ?? [];
          final List<dynamic> creditDayBook = data['creditnotedet'] ?? [];
          final List<dynamic> discountDayBook = data['discountdet'] ?? [];

          setState(() {
            _totalDebit = data['ttl_debit_amt'] ?? '0.00';
            _totalCredit = data['ttl_credit_amt'] ?? '0.00';
            _mainTitle = data['hdr_name'] ?? '';
            
            _invoiceTransactions = invoiceDayBook
                .map((json) => DayBookInvoice.fromJson(json))
                .toList();
            _creditTransactions = creditDayBook
                .map((json) => DayBookCredit.fromJson(json))
                .toList();
            _discountTransactions = discountDayBook
                .map((json) => DayBookDiscount.fromJson(json))
                .toList();
          });

          if (invoiceDayBook.isEmpty && creditDayBook.isEmpty && discountDayBook.isEmpty) {
            _showError('No report data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch report.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<PermissionResponse> _fetchPermissions() async {
    try {
      final apiService = ApiServices();
      final permissionData = await apiService.fetchPermissionDetails();

      if (permissionData == null) {
        throw Exception('Failed to fetch permissions: Data is null.');
      }

      if (permissionData.permissionDetails.isEmpty) {
        throw Exception('Received empty permissions data from the API.');
      }

      return permissionData;
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
      rethrow;
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final permissionResponse = await _fetchPermissions();
      if (permissionResponse.permissionDetails.isNotEmpty) {
        setState(() {
          final permissionDetail = permissionResponse.permissionDetails[0];
          dayBook = permissionDetail.dayBook;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchDayBookData(picked);
    }
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, yyyy');
    final formattedDate = dateFormat.format(_selectedDate);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('DAY BOOK'),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Date Selection Card
            Card(
              margin: const EdgeInsets.all(16.0),
              elevation: 2.0,
              child: InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(4.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Title
            if (_mainTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _mainTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Totals Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Total Debit Card
                  Expanded(
                    child: Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Debit',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalDebit.isNotEmpty ? _totalDebit : "No Data",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Total Credit Card
                  Expanded(
                    child: Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Credit',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _totalCredit.isNotEmpty ? _totalCredit : "No Data",
                              style: const TextStyle(
                                fontSize: 18,
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
            ),
            
            const SizedBox(height: 16),
            
            // Transactions List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '$formattedDate Day Book',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Transactions List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : (_invoiceTransactions.isEmpty && _creditTransactions.isEmpty && _discountTransactions.isEmpty)
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No data available for the selected date.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Invoice Transactions
                          ..._invoiceTransactions.map((invoice) => 
                            _buildInvoiceCard(invoice)
                          ).toList(),
                          
                          // Credit Transactions
                          ..._creditTransactions.map((credit) => 
                            _buildCreditCard(credit)
                          ).toList(),
                          
                          // Discount Transactions
                          ..._discountTransactions.map((discount) => 
                            _buildDiscountCard(discount)
                          ).toList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: AppConstants.bottomNavItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item['icon']),
            label: item['title'],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvoiceCard(DayBookInvoice invoice) {
    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceViewScreen(invId: invoice.invId),
                        ),
                      );
                    },
                    child: Text(
                      'Invoice No: ${invoice.invoiceNo}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${invoice.invId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Transaction amounts
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (invoice.debit.isNotEmpty && invoice.debit != '0')
                  Text(
                    invoice.debit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                if (invoice.credit.isNotEmpty && invoice.credit != '0')
                  Text(
                    invoice.credit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard(DayBookCredit credit) {
    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.credit_card,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credit Note: ${credit.creditNo}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${credit.crdId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Transaction amounts
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (credit.debit.isNotEmpty && credit.debit != '0')
                  Text(
                    credit.debit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (credit.credit.isNotEmpty && credit.credit != '0')
                  Text(
                    credit.credit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountCard(DayBookDiscount discount) {
    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.discount,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discount: ${discount.customerName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customer Discount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Transaction amounts
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (discount.debit.isNotEmpty && discount.debit != '0')
                  Text(
                    discount.debit,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (discount.credit.isNotEmpty && discount.credit != '0')
                  Text(
                    discount.credit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}