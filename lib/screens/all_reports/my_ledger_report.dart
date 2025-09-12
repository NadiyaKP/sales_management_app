import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../home_page.dart';
import '../report_page.dart';
import '../all_report_page.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../receipts/receipt_view.dart';

String customerLedger = '';
String ledgerExcel = '';

class MyLedgerReport {
  final String date;
  final String voucherId;
  final String voucherNo;
  final String typeOfTransactions;
  final String notes;
  final String debit;
  final String credit;
  final String balance;
  
  MyLedgerReport({
    required this.date,
    required this.voucherId,
    required this.voucherNo,
    required this.typeOfTransactions,
    required this.notes,
    required this.debit,
    required this.credit,
    required this.balance,
  });
  
  factory MyLedgerReport.fromJson(Map<String, dynamic> json) {
    return MyLedgerReport(
      date: json['led_date'] ?? json['date'] ?? '', 
      voucherId: json['vcr_id'] ?? json['voucher_id'] ?? '',
      voucherNo: json['vcr_no'] ?? json['voucher_no'] ?? '',
      typeOfTransactions: json['type_of_trn'] ?? '',
      notes: json['notes'] ?? '',
      debit: json['debit']?.toString() ?? '0.00', 
      credit: json['credit']?.toString() ?? '0.00', 
      balance: json['bln_due'] ?? json['balance'] ?? '0.00',
    );
  }
}

class MyLedgerReportPage extends StatefulWidget {
  const MyLedgerReportPage({Key? key}) : super(key: key);

  @override
  State<MyLedgerReportPage> createState() => _MyLedgerReportPageState();
}

class _MyLedgerReportPageState extends State<MyLedgerReportPage> {
  int _selectedIndex = 1; // Report tab active
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  
  List<MyLedgerReport> filteredMyLedgerReport = [];
  ApiServices apiServices = ApiServices();
  
  String? closingBalance;
  String? totalDebit;
  String? totalCredit;
  String? receivedCheque;
  String? givenCheque;
  String? headerName;
  
  bool isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1); 
    _toDate = DateTime.now();
    fetchMyLedger();
  }
  
  Future<void> fetchMyLedger() async {
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
        Uri.parse('$url/my-ledger.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "from_date": _formatDateForApi(_fromDate),
          "to_date": _formatDateForApi(_toDate),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> myLedgerList = data['cart_items'] ?? [];
          setState(() {
            filteredMyLedgerReport = myLedgerList
                .map((json) => MyLedgerReport.fromJson(json))
                .toList();
            closingBalance = data['cls_bln'] ?? '0.00';
            totalCredit = data['ttl_cr_amt'] ?? '0.00';
            totalDebit = data['ttl_dr_amt'] ?? '0.00';
            receivedCheque = data['recv_chq'] ?? '0.00';
            givenCheque = data['givn_chq'] ?? '0.00';
            headerName = data['hdr_name'] ?? 'My Ledger Report';
          });
          if (myLedgerList.isEmpty) {
            _showError('No my ledger data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch my ledger.');
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
          ledgerExcel = permissionDetail.ledgerExcel;
          customerLedger = permissionDetail.customerLedger;
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
  
  String _formatDateForApi(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
  
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final lastDate = DateTime.now().add(const Duration(days: 365));
    final initialDate = isFromDate ? _fromDate : _toDate;
    final safeInitialDate = initialDate.isAfter(lastDate) ? lastDate : initialDate;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: AppTheme.primaryColor,
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
            buttonTheme: const ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      // Fetch new data when date changes
      fetchMyLedger();
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
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String formatTransactionValue(String debit, String credit, String transactionType) {
    // Handle null and empty values
    double debitAmount = double.tryParse(debit) ?? 0.0;
    double creditAmount = double.tryParse(credit) ?? 0.0;
    
    if (debitAmount > 0) {
      return "+${debitAmount.toStringAsFixed(2)}";
    } else if (creditAmount > 0) {
      // For Opening Balance, credit should be shown as positive
      if (transactionType.toLowerCase().contains('opening')) {
        return "+${creditAmount.toStringAsFixed(2)}";
      } else {
        return "-${creditAmount.toStringAsFixed(2)}";
      }
    }
    return "0.00";
  }

  
  String formatCurrency(String? value) {
    if (value == null || value.isEmpty) return "0.00";
    double amount = double.tryParse(value) ?? 0.0;
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(headerName ?? 'MY LEDGER'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AllReportPage()),
            );
          },
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date selection row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'From: ${_formatDate(_fromDate)}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'To: ${_formatDate(_toDate)}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Summary Box with improved formatting
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Closing Balance:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        closingBalance ?? "0.00",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Total Credit:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        formatCurrency(totalCredit),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Total Debit:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        formatCurrency(totalDebit),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (receivedCheque != null && receivedCheque != "0.00") ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Pending Received Cheque:',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatCurrency(receivedCheque),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (givenCheque != null && givenCheque != "0.00") ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Pending Given Cheque:',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatCurrency(givenCheque),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Transactions list
            Expanded(
              child: filteredMyLedgerReport.isEmpty
                  ? const Center(
                      child: Text(
                        'No reports available for the selected date range.',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredMyLedgerReport.length,
                      itemBuilder: (context, index) {
                        final report = filteredMyLedgerReport[index];
                        final transactionValue = formatTransactionValue(report.debit, report.credit, report.typeOfTransactions);
                        final isOdd = index % 2 != 0;

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.typeOfTransactions,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      transactionValue,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: transactionValue.startsWith('+')
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Show only debit (not individual credit)
                                if (report.debit != "0.00" && report.debit.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Text(
                                        'Debit: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(report.debit),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (report.balance.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Text(
                                        'Balance: ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        report.balance,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                // Always show Date section
                                Row(
                                  children: [
                                    const Text(
                                      'Date: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      report.date.isNotEmpty ? report.date : '',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Notes: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        report.notes.isNotEmpty ? report.notes : '',
                                        style: TextStyle(
                                          color: report.notes.isNotEmpty ? Colors.black87 : Colors.grey,
                                          fontStyle: report.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                          fontSize: 12,
                                        ),
                                      ),
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
}