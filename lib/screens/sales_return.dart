import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../common/bottom_navigation_button.dart';
import '../common/pagination.dart';
import 'sales_return_view.dart';

class SalesReturn {
  final String creditNoteNo;
  final String date;
  final String name;
  final String typeofCreditNote;
  final String totalAmount;
  final String notes;
  final String crdId;

  SalesReturn({
    required this.creditNoteNo,
    required this.date,
    required this.name,
    required this.typeofCreditNote,
    required this.totalAmount,
    required this.notes,
    required this.crdId,
  });

  factory SalesReturn.fromJson(Map<String, dynamic> json) {
    return SalesReturn(
      creditNoteNo: json['crd_no']?.toString() ?? '',
      date: json['crd_date']?.toString() ?? '',
      name: json['custname']?.toString() ?? '',
      typeofCreditNote: json['type_of_credit']?.toString() ?? '',
      totalAmount: json['crd_amt']?.toString() ?? '0',
      notes: json['notes']?.toString() ?? '',
      crdId: json['crdid']?.toString() ?? '',
    );
  }
}

class SalesReturnPage extends StatefulWidget {
  const SalesReturnPage({Key? key}) : super(key: key);

  @override
  State<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends State<SalesReturnPage> {
  int currentPage = 1;
  final int itemsPerPage = 20;
  final int maxVisiblePages = 3;
  int salesReturnTotal = 0;
  bool isLoading = false;

  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  List<SalesReturn> _salesReturns = [];

  @override
  void initState() {
    super.initState();
    fetchSalesReturn();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchSalesReturn() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    try {
      final response = await http.post(
        Uri.parse('$url/sales-return.php'),
        headers: {'Content-Type': 'application/json'},
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
          salesReturnTotal = data['ttlsalesreturn'] is int
              ? data['ttlsalesreturn']
              : int.tryParse(data['ttlsalesreturn'].toString()) ?? 0;
          final List<dynamic> salesReturnList = data['creditnotedet'] ?? [];

          setState(() {
            _salesReturns = salesReturnList
                .map((json) => SalesReturn.fromJson(json))
                .toList();
          });

          if (salesReturnList.isEmpty) {
            _showError('No sales return data found');
          }
        } else {
          _showError(data['message']?.toString() ?? 'Failed to fetch sales returns.');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchSalesReturn();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search'),
          content: TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Enter credit no or customer name'),
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
                fetchSalesReturn();
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
                fetchSalesReturn();
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
    } catch (_) {}
    return null;
  }

  String _formatDate(String dateStr) {
    DateTime? date = _parseDate(dateStr);
    if (date != null) {
      return DateFormat.yMMMMd().format(date);
    }
    return dateStr;
  }

  String _formatAmount(String amount) {
    if (amount.isEmpty || amount == '0') return '₹0.00';
    try {
      final double value = double.parse(amount);
      return '₹${value.toStringAsFixed(2)}';
    } catch (_) {
      return '₹$amount';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _salesReturns.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SALES RETURN'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SALES RETURN'),
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
            child: _salesReturns.isEmpty
                ? const Center(child: Text("No sales returns found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _salesReturns.length,
                    itemBuilder: (context, index) {
                      final salesReturn = _salesReturns[index];
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Credit No: ${salesReturn.creditNoteNo}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              _buildRow('Customer', salesReturn.name),
                              _buildRow('Date', _formatDate(salesReturn.date)),
                              if (salesReturn.typeofCreditNote.isNotEmpty)
                                _buildRow('Type', salesReturn.typeofCreditNote),
                              _buildRow('Notes', salesReturn.notes.isNotEmpty ? salesReturn.notes : 'N/A'),
                              _buildRow('Amount', _formatAmount(salesReturn.totalAmount),
                                  color: Colors.green.shade700),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.print, size: 18, color: Colors.white),
                                    label: const Text('Credit Note', style: TextStyle(color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SalesReturnViewScreen(
                                            crdId: salesReturn.crdId,
                                            typeofCreditNote: salesReturn.typeofCreditNote,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
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
            totalItems: salesReturnTotal,
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

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: color ?? Colors.black87),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
