import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../common/bottom_navigation_button.dart';
import '../common/pagination.dart';
import 'home_page.dart';
import 'report_page.dart';

class ReceivedAmount {
  final String rcpId;
  final String rcpNo;
  final String customerName;
  final String rcpDate;
  final String walletName;
  final String notes;
  final String rcpAmount;

  ReceivedAmount({
    required this.rcpId,
    required this.rcpNo,
    required this.customerName,
    required this.rcpDate,
    required this.walletName,
    required this.notes,
    required this.rcpAmount,
  });

  factory ReceivedAmount.fromJson(Map<String, dynamic> json) {
    return ReceivedAmount(
      rcpId: json['rcpid']?.toString() ?? '',
      rcpNo: json['rcp_no']?.toString() ?? '',
      customerName: json['custname']?.toString() ?? '',
      rcpDate: json['rcp_date']?.toString() ?? '',
      walletName: json['wlt_name']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      rcpAmount: json['rcp_amt']?.toString() ?? '',
    );
  }
}

class ReceivedAmountPage extends StatefulWidget {
  const ReceivedAmountPage({Key? key}) : super(key: key);

  @override
  State<ReceivedAmountPage> createState() => _ReceivedAmountPageState();
}

class _ReceivedAmountPageState extends State<ReceivedAmountPage> {
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  bool isLoading = false;
  int transactionTotal = 0;
  String totalReceivedAmount = '0';

  List<ReceivedAmount> _transactions = [];

  @override
  void initState() {
    super.initState();
    fetchReceivedAmountData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchReceivedAmountData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _showError('Missing credentials. Please login again.');
        return;
      }

      final response = await http.post(
        Uri.parse('$url/received-amount-with-me.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "srch": searchQuery,
          "page": currentPage.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['result'] == "1") {
          final List<dynamic> receivedAmountList = data['receivedamountdet'] ?? [];
          
          setState(() {
            // Handle totalReceivedAmount - ensure it's always a string
            totalReceivedAmount = data['ttl_received_amt']?.toString() ?? '0';
            
            // Handle transactionTotal - safely convert to int
            var totalCount = data['noofcashwithme'];
            if (totalCount is int) {
              transactionTotal = totalCount;
            } else if (totalCount is String) {
              transactionTotal = int.tryParse(totalCount) ?? 0;
            } else {
              transactionTotal = 0;
            }
            
            _transactions = receivedAmountList
                .map((json) => ReceivedAmount.fromJson(json))
                .toList();
          });

          if (receivedAmountList.isEmpty) {
            _showError('No received amount data found');
          }
        } else {
          _showError(data['message']?.toString() ?? 'Failed to fetch received amount data.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search'),
          content: TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Enter receipt no or name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _searchController.clear();
                setState(() {
                  searchQuery = '';
                  currentPage = 1;
                });
                fetchReceivedAmountData();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  searchQuery = _searchController.text;
                  currentPage = 1;
                });
                Navigator.of(context).pop();
                fetchReceivedAmountData();
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      } else if (dateStr.contains('/')) {
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (e) {}
    return null;
  }

  String _formatDate(String dateStr) {
    DateTime? date = _parseDate(dateStr);
    if (date != null) {
      return DateFormat('dd-MM-yyyy').format(date);
    }
    return dateStr;
  }

  String _formatAmount(String amount) {
    return amount.replaceAll(',', '');
  }

  String _getPaymentMethodFromWallet(String walletName) {
    switch (walletName.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      default:
        return walletName;
    }
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchReceivedAmountData();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Received Amount'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Received Amount'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          )
        ],
      ),
      body: Column(
        children: [
          // Total Received Amount Box
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Total Received',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatAmount(totalReceivedAmount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Transactions: $transactionTotal',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text("No transactions found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              // Header Section with Receipt Number and Date
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 5, 38, 76).withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Receipt No: ${transaction.rcpNo}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(255, 5, 38, 76),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          _formatDate(transaction.rcpDate),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Content Section
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    // Customer Name Section
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            transaction.customerName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    // Payment and Amount Details Section
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                      ),
                                      child: Row(
                                        children: [
                                          // Payment Method Section
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Payment',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _getPaymentMethodFromWallet(transaction.walletName),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Divider
                                          Container(
                                            height: 20,
                                            width: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                          
                                          // Amount Section
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Amount',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _formatAmount(transaction.rcpAmount),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Notes Section (if available) - Inline below payment/amount
                                    if (transaction.notes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Notes: ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              transaction.notes,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SlidingPaginationControls(
            currentPage: currentPage,
            totalItems: transactionTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0,
      ),
    );
  }
}