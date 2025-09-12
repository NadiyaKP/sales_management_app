import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import 'invoice_view.dart'; 

class Invoice {
  final String invoiceNo;
  final String date;
  final String name;
  final String discountAmount;
  final String totalAmount;
  final String invId;

  Invoice({
    required this.invoiceNo,
    required this.date,
    required this.name,
    required this.discountAmount,
    required this.totalAmount,
    required this.invId,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      invoiceNo: json['inv_no']?.toString() ?? '',
      date: json['inv_date']?.toString() ?? '',
      name: json['custname']?.toString() ?? '',
      discountAmount: json['disc_amt']?.toString() ?? '',
      totalAmount: json['inv_amt']?.toString() ?? '',
      invId: json['invid']?.toString() ?? '',
    );
  }
}

class InvoicePage extends StatefulWidget {
  const InvoicePage({Key? key}) : super(key: key);

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  int invoiceTotal = 0;
  bool isLoading = false;

  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    fetchInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchInvoices() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    try {
      final requestBody = {
        "unid": unid,
        "slex": slex,
        "srch": searchQuery,
        "page": currentPage.toString(),
      };

      /// 🔹 Print API request details
      print("📤 API REQUEST to: $url/invoices.php");
      print("📦 Request Body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        Uri.parse('$url/invoices.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      /// 🔹 Print API response details
      print("📥 Response Code: ${response.statusCode}");
      print("📥 Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          invoiceTotal = int.tryParse(data['ttlinvoices'].toString()) ?? 0;
          final List<dynamic> invoiceList = data['invoicedet'] ?? [];

          setState(() {
            _invoices = invoiceList.map((json) => Invoice.fromJson(json)).toList();
          });

          /// Debug print parsed invoices
          print("✅ Parsed Invoices: ${_invoices.length}");
        } else {
          _showError(data['message'] ?? 'Failed to fetch invoices.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      _showError('An error occurred: $error');
      print("❌ API ERROR: $error");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchInvoices();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search'),
          content: TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Enter invoice no or name'),
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
                fetchInvoices();
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
                fetchInvoices();
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
    } catch (e) {
      print("⚠️ Date parsing error: $e");
    }
    return null;
  }

  String _formatDate(String dateStr) {
    DateTime? date = _parseDate(dateStr);
    if (date != null) {
      return DateFormat('dd-MM-yyyy').format(date);
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _invoices.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoices'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
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
          Expanded(
            child: _invoices.isEmpty
                ? const Center(child: Text("No invoices found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              // Header Section
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                        'Invoice No: ${invoice.invoiceNo}',
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
                                          _formatDate(invoice.date),
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
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 12, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            invoice.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Discount',
                                                          style: TextStyle(
                                                              fontSize: 9,
                                                              color: Colors.grey.shade600,
                                                              fontWeight: FontWeight.w500)),
                                                      const SizedBox(height: 2),
                                                      Text(invoice.discountAmount,
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.orange.shade700)),
                                                    ],
                                                  ),
                                                ),
                                                Container(height: 24, width: 1, color: Colors.grey.shade300),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text('Total',
                                                          style: TextStyle(
                                                              fontSize: 9,
                                                              color: Colors.grey.shade600,
                                                              fontWeight: FontWeight.w500)),
                                                      const SizedBox(height: 2),
                                                      Text(invoice.totalAmount,
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.green.shade700)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.visibility, size: 10, color: Colors.white),
                                          label: const Text('Invoice', style: TextStyle(color: Colors.white, fontSize: 9)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color.fromARGB(255, 5, 38, 76),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            minimumSize: const Size(0, 0),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => InvoiceViewScreen(invId: invoice.invId),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
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
            totalItems: invoiceTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigationButton(selectedIndex: 0),
    );
  }
}
