import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';

class AccountLedgerReport {
  final String date;
  final String voucherId;
  final String voucherNo;
  final String typeOfTransactions;
  final String notes;
  final String debit;
  final String credit;
  final String balance;

  AccountLedgerReport({
    required this.date,
    required this.voucherId,
    required this.voucherNo,
    required this.typeOfTransactions,
    required this.notes,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory AccountLedgerReport.fromJson(Map<String, dynamic> json) {
    return AccountLedgerReport(
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

class CustomerLedgerReportPage extends StatefulWidget {
  final String customerName;
  final String custId;
  final DateTime fromDate;
  final DateTime toDate;

  const CustomerLedgerReportPage({
    Key? key,
    required this.customerName,
    required this.custId,
    required this.fromDate,
    required this.toDate,
  }) : super(key: key);

  @override
  State<CustomerLedgerReportPage> createState() => _CustomerLedgerReportPageState();
}

class _CustomerLedgerReportPageState extends State<CustomerLedgerReportPage> {
  bool isLoading = true;
  List<AccountLedgerReport> filteredAccountLedgerReport = [];

  String? closingBalance;
  String? totalDebit;
  String? totalCredit;
  String? receivedCheque;
  String? givenCheque;
  String? headerName;

  @override
  void initState() {
    super.initState();
    fetchAccountLedger();
  }

  Future<void> fetchAccountLedger() async {
    if (!mounted) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    try {
      final response = await http.post(
        Uri.parse('$url/account-ledger.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "customer_name": widget.customerName,
          "custid": widget.custId,
          "from_date": _formatDateForApi(widget.fromDate),
          "to_date": _formatDateForApi(widget.toDate),
          "style": "ledger",
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> accountLedgerList = data['cart_items'] ?? [];
          setState(() {
            filteredAccountLedgerReport = accountLedgerList
                .map((json) => AccountLedgerReport.fromJson(json))
                .toList();
            closingBalance = data['cls_bln'] ?? '0.00';
            totalCredit = data['ttl_cr_amt'] ?? '0.00';
            totalDebit = data['ttl_dr_amt'] ?? '0.00';
            receivedCheque = data['recv_chq'] ?? '0.00';
            givenCheque = data['givn_chq'] ?? '0.00';
            headerName = data['hdr_name'] ?? 'Account Ledger Report';
            isLoading = false;
          });
          if (accountLedgerList.isEmpty) {
            _showError('No account ledger data found');
          }
        } else {
          setState(() => isLoading = false);
          _showError(data['message'] ?? 'Failed to fetch account ledger.');
        }
      } else {
        setState(() => isLoading = false);
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() => isLoading = false);
      _showError('An error occurred: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  String _formatDateForApi(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String formatTransactionValue(String debit, String credit, String transactionType) {
    double debitAmount = double.tryParse(debit.replaceAll(',', '')) ?? 0.0;
    double creditAmount = double.tryParse(credit.replaceAll(',', '')) ?? 0.0;
    if (debitAmount > 0) {
      return "+₹${debitAmount.toStringAsFixed(2)}";
    } else if (creditAmount > 0) {
      if (transactionType.toLowerCase().contains('opening')) {
        return "+₹${creditAmount.toStringAsFixed(2)}";
      } else {
        return "-₹${creditAmount.toStringAsFixed(2)}";
      }
    }
    return "₹0.00";
  }

  String formatCurrency(String? value) {
    if (value == null || value.isEmpty) return "₹0.00";
    String cleanValue = value.replaceAll(',', '').replaceAll('Dr', '').replaceAll('Cr', '').trim();
    double amount = double.tryParse(cleanValue) ?? 0.0;
    return "₹${amount.toStringAsFixed(2)}";
  }

  Widget _buildLedgerReport() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'From: ${_formatDate(widget.fromDate)} - To: ${_formatDate(widget.toDate)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
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
                    const Text('Closing Balance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      closingBalance ?? "₹0.00",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Total Credit:'),
                    const Spacer(),
                    Text(formatCurrency(totalCredit), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Total Debit:'),
                    const Spacer(),
                    Text(formatCurrency(totalDebit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (receivedCheque != null && receivedCheque != "0.00") ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Pending Received Cheque:', style: TextStyle(fontSize: 12, color: Colors.blue)),
                      const Spacer(),
                      Text(formatCurrency(receivedCheque), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ],
                if (givenCheque != null && givenCheque != "0.00") ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Pending Given Cheque:', style: TextStyle(fontSize: 12, color: Colors.blue)),
                      const Spacer(),
                      Text(formatCurrency(givenCheque), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredAccountLedgerReport.isEmpty
                ? const Center(
                    child: Text('No reports available for the selected date range.', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: filteredAccountLedgerReport.length,
                    itemBuilder: (context, index) {
                      final report = filteredAccountLedgerReport[index];
                      final transactionValue = formatTransactionValue(report.debit, report.credit, report.typeOfTransactions);
                      final isOdd = index % 2 != 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isOdd ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(color: Colors.teal.shade200, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    report.typeOfTransactions,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: Colors.indigo),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  transactionValue,
                                  style: TextStyle(
                                    fontSize: 20.0,
                                    color: transactionValue.startsWith('+') ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (report.debit != "0.00" && report.debit.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Text('Debit: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                  Text(formatCurrency(report.debit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (report.balance.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Text('Balance: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                  Text(report.balance, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                const Text('Date: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text(report.date.isNotEmpty ? report.date : 'N/A', style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Notes: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Expanded(
                                  child: Text(
                                    report.notes.isNotEmpty ? report.notes : 'No notes available',
                                    style: TextStyle(
                                      color: report.notes.isNotEmpty ? Colors.black87 : Colors.grey,
                                      fontStyle: report.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customerName} Ledger Report'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : _buildLedgerReport(),
    );
  }
}
