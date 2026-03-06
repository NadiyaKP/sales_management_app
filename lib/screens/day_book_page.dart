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
import '../common/bottom_navigation_button.dart';

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
  int _selectedIndex = 1; 
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

  String _formatDateForAPI(DateTime date) {
    // Try multiple formats to ensure compatibility
    // Common formats: dd-MM-yyyy, dd/MM/yyyy, yyyy-MM-dd
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> _fetchDayBookData(DateTime date) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      // Validate required parameters
      if (url == null || url.isEmpty) {
        _showError('Server URL not configured');
        return;
      }
      
      if (unid == null || unid.isEmpty) {
        _showError('User ID not found');
        return;
      }

      if (slex == null || slex.isEmpty) {
        _showError('Session not found');
        return;
      }

      // Format date for API - try dd-MM-yyyy format first
      String formattedDate = _formatDateForAPI(date);
      
      debugPrint('API Request - URL: $url/day-book.php');
      debugPrint('API Request - Date: $formattedDate');
      debugPrint('API Request - UNID: $unid');

      final requestBody = {
        "unid": unid,
        "slex": slex,
        "from_date": formattedDate,
      };

      debugPrint('API Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$url/day-book.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your connection.');
        },
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['result'] == "1") {
          final List<dynamic> invoiceDayBook = data['invoicedet'] ?? [];
          final List<dynamic> creditDayBook = data['creditnotedet'] ?? [];
          final List<dynamic> discountDayBook = data['discountdet'] ?? [];

          if (mounted) {
            setState(() {
              _totalDebit = data['ttl_debit_amt']?.toString() ?? '0.00';
              _totalCredit = data['ttl_credit_amt']?.toString() ?? '0.00';
              _mainTitle = data['hdr_name']?.toString() ?? '';
              
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
          }

          if (invoiceDayBook.isEmpty && creditDayBook.isEmpty && discountDayBook.isEmpty) {
            _showError('No transactions found for the selected date');
          }
        } else {
          // If the current format fails, try alternative formats
          if (data['message']?.toString().toLowerCase().contains('invalid date') ?? false) {
            await _tryAlternativeDateFormats(date, url, unid, slex);
          } else {
            _showError(data['message']?.toString() ?? 'Failed to fetch day book data.');
          }
        }
      } else {
        _showError('Server error: ${response.statusCode}. Please try again.');
      }
    } catch (error) {
      debugPrint('Error in _fetchDayBookData: $error');
      if (error.toString().contains('timeout')) {
        _showError('Request timeout. Please check your internet connection.');
      } else if (error.toString().contains('SocketException')) {
        _showError('Network error. Please check your internet connection.');
      } else {
        _showError('An error occurred: ${error.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tryAlternativeDateFormats(DateTime date, String url, String unid, String slex) async {
    // List of alternative date formats to try
    final List<String> dateFormats = [
      'yyyy-MM-dd',    // ISO format
      'dd/MM/yyyy',    // Common format
      'MM-dd-yyyy',    // US format
      'yyyy/MM/dd',    // Alternative ISO
    ];

    for (String format in dateFormats) {
      try {
        String alternativeDate = DateFormat(format).format(date);
        debugPrint('Trying alternative date format: $alternativeDate');

        final response = await http.post(
          Uri.parse('$url/day-book.php'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            "unid": unid,
            "slex": slex,
            "from_date": alternativeDate,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          if (data['result'] == "1") {
            final List<dynamic> invoiceDayBook = data['invoicedet'] ?? [];
            final List<dynamic> creditDayBook = data['creditnotedet'] ?? [];
            final List<dynamic> discountDayBook = data['discountdet'] ?? [];

            if (mounted) {
              setState(() {
                _totalDebit = data['ttl_debit_amt']?.toString() ?? '0.00';
                _totalCredit = data['ttl_credit_amt']?.toString() ?? '0.00';
                _mainTitle = data['hdr_name']?.toString() ?? '';
                
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
            }

            debugPrint('Success with date format: $format');
            return; // Exit if successful
          }
        }
      } catch (e) {
        debugPrint('Failed with format $format: $e');
        continue;
      }
    }

    // If all formats fail
    _showError('Unable to fetch data. Please contact support.');
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
      duration: const Duration(seconds: 4),
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
            colorScheme: const ColorScheme.light(
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
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedDate = dateFormat.format(_selectedDate);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Book'),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Date Selection Card
            Card(
              margin: const EdgeInsets.all(12.0),
              elevation: 2.0,
              child: InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(4.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Title
            if (_mainTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  _mainTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            
            const SizedBox(height: 6),
            
            // Totals Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  // Total Debit Card
                  Expanded(
                    child: Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Debit',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _totalDebit.isNotEmpty ? _totalDebit : "No Data",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total Credit Card
                  Expanded(
                    child: Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Credit',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _totalCredit.isNotEmpty ? _totalCredit : "No Data",
                              style: const TextStyle(
                                fontSize: 12,
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
            
            const SizedBox(height: 12),
            
            // Transactions List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.grey, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '$formattedDate Day Book',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 6),
            
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
                            size: 40,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No data available for the selected date.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
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
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0,
      ),
    );
  }

  Widget _buildInvoiceCard(DayBookInvoice invoice) {
    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.only(bottom: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.receipt,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${invoice.invId}',
                    style: TextStyle(
                      fontSize: 10,
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                if (invoice.credit.isNotEmpty && invoice.credit != '0')
                  Text(
                    invoice.credit,
                    style: const TextStyle(
                      fontSize: 10,
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
      margin: const EdgeInsets.only(bottom: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.credit_card,
                color: Colors.orange,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credit Note: ${credit.creditNo}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${credit.crdId}',
                    style: TextStyle(
                      fontSize: 10,
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (credit.credit.isNotEmpty && credit.credit != '0')
                  Text(
                    credit.credit,
                    style: const TextStyle(
                      fontSize: 10,
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
      margin: const EdgeInsets.only(bottom: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.discount,
                color: Colors.purple,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discount: ${discount.customerName}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customer Discount',
                    style: TextStyle(
                      fontSize: 10,
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (discount.credit.isNotEmpty && discount.credit != '0')
                  Text(
                    discount.credit,
                    style: const TextStyle(
                      fontSize: 10,
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