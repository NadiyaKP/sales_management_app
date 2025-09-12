import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';

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

  // Company details
  String companyName = "GST 3.0";
  String companyAddress = "2/114B, Ayisha complex,\nMalappuram road,Kottakkal,\nMalappuram-676528";
  String companyPhone = "Mob : 9562500548\nPh : 9876543210";
  String companyEmail = "Email : info@coremicron.com";
  String companyGST = "GST : 123124141231132123";

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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDateForApi(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateForPrint(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

String formatTransactionValue(String debit, String credit, String transactionType) {
    double debitAmount = double.tryParse(debit.replaceAll(',', '')) ?? 0.0;
    double creditAmount = double.tryParse(credit.replaceAll(',', '')) ?? 0.0;
    if (debitAmount > 0) {
      return "+${debitAmount.toStringAsFixed(2)}";
    } else if (creditAmount > 0) {
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
    String cleanValue = value.replaceAll(',', '').replaceAll('Dr', '').replaceAll('Cr', '').trim();
    double amount = double.tryParse(cleanValue) ?? 0.0;
    return amount.toStringAsFixed(2);
  }

  String formatCurrencyForPrint(String? value) {
    if (value == null || value.isEmpty) return "0.00";
    String cleanValue = value.replaceAll(',', '').replaceAll('Dr', '').replaceAll('Cr', '').replaceAll('₹', '').trim();
    double amount = double.tryParse(cleanValue) ?? 0.0;
    return amount.toStringAsFixed(2);
  }

  String _getDisplayDate(AccountLedgerReport report) {
    if (report.typeOfTransactions.toLowerCase().contains('opening')) {
      return _formatDate(widget.fromDate);
    }
    return report.date.isNotEmpty ? report.date : 'N/A';
  }

  // Check if permission handler is available
  Future<bool> _isPermissionHandlerAvailable() async {
    try {
      await Permission.storage.status;
      return true;
    } catch (e) {
      print('Permission handler not available: $e');
      return false;
    }
  }

  // Robust permission checking method
  Future<bool> _checkStoragePermission() async {
    try {
      bool isAvailable = await _isPermissionHandlerAvailable();
      if (!isAvailable) {
        print('Permission handler not available, using internal storage');
        return false;
      }

      if (Platform.isAndroid) {
        PermissionStatus status;
        
        try {
          status = await Permission.manageExternalStorage.status;
          if (status.isGranted) return true;
          
          status = await Permission.manageExternalStorage.request();
          if (status.isGranted) return true;
        } catch (e) {
          print('Manage external storage permission not available: $e');
        }
        
        try {
          status = await Permission.storage.status;
          if (status.isGranted) return true;
          
          status = await Permission.storage.request();
          if (status.isGranted) return true;
        } catch (e) {
          print('Storage permission not available: $e');
        }
        
        return false;
      } else {
        return true;
      }
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }

  // Show export options dialog
  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Options'),
          content: const Text('Choose where to save the Excel file:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exportToExcelInternal();
              },
              child: const Text('App Storage\n(Always works)'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _exportToExcelExternal();
              },
              child: const Text('Downloads\n(Requires permission)'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Export to external storage (Downloads folder)
  Future<void> _exportToExcelExternal() async {
    if (filteredAccountLedgerReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      bool hasPermission = await _checkStoragePermission();
      
      if (!hasPermission) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Storage Permission Required'),
              content: const Text(
                'Storage permission is required to save to Downloads folder. '
                'Would you like to save to app storage instead?'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _exportToExcelInternal();
                  },
                  child: const Text('Use App Storage'),
                ),
              ],
            );
          },
        );
        return;
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Ledger Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Voucher No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Transaction Type';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Notes';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Debit';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Credit';
      sheetObject.cell(CellIndex.indexByString("H1")).value = 'Balance';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1', 'H1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < filteredAccountLedgerReport.length; i++) {
        final ledger = filteredAccountLedgerReport[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = _getDisplayDate(ledger);
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = ledger.voucherNo;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = ledger.typeOfTransactions;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = ledger.notes;
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = ledger.debit != "0.00" ? formatCurrencyForPrint(ledger.debit) : "";
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = ledger.credit != "0.00" ? formatCurrencyForPrint(ledger.credit) : "";
        sheetObject.cell(CellIndex.indexByString("H$rowIndex")).value = ledger.balance;
      }

      Directory? directory;
      String fileName = 'Ledger_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
      if (Platform.isAndroid) {
        List<String> downloadPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];
        
        for (String path in downloadPaths) {
          Directory testDir = Directory(path);
          if (await testDir.exists()) {
            try {
              String testPath = '$path/test_write_${DateTime.now().millisecond}.txt';
              File testFile = File(testPath);
              await testFile.writeAsString('test');
              await testFile.delete();
              
              directory = testDir;
              break;
            } catch (e) {
              print('Cannot write to $path: $e');
              continue;
            }
          }
        }
        
        if (directory == null) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        _showError('Cannot access storage. Using app storage instead.');
        _exportToExcelInternal();
        return;
      }

      String filePath = '${directory.path}/$fileName';
      
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      
      if (await file.exists()) {
        String locationMsg = directory.path.contains('Download') 
            ? 'Downloads folder' 
            : 'External storage';
        _showSuccess('Excel file saved to $locationMsg');
        
        try {
          await OpenFile.open(filePath);
        } catch (e) {
          print('Could not open file automatically: $e');
          _showSuccess('File saved at: $filePath');
        }
      } else {
        _showError('Failed to save file');
      }
      
    } catch (e) {
      print('Export error: $e');
      _showError('Export failed. Trying app storage instead.');
      _exportToExcelInternal();
    }
  }

  // Export to app's internal storage
  Future<void> _exportToExcelInternal() async {
    if (filteredAccountLedgerReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Ledger Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Voucher No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Transaction Type';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Notes';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Debit';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Credit';
      sheetObject.cell(CellIndex.indexByString("H1")).value = 'Balance';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1', 'H1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < filteredAccountLedgerReport.length; i++) {
        final ledger = filteredAccountLedgerReport[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = _getDisplayDate(ledger);
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = ledger.voucherNo;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = ledger.typeOfTransactions;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = ledger.notes;
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = ledger.debit != "0.00" ? formatCurrencyForPrint(ledger.debit) : "";
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = ledger.credit != "0.00" ? formatCurrencyForPrint(ledger.credit) : "";
        sheetObject.cell(CellIndex.indexByString("H$rowIndex")).value = ledger.balance;
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Ledger_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      String filePath = '${directory.path}/$fileName';
      
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      
      _showSuccess('Excel file saved to app storage');
      
      try {
        await OpenFile.open(filePath);
      } catch (e) {
        print('Could not open file: $e');
        _showSuccess('File saved at: $filePath');
      }
      
    } catch (e) {
      _showError('Failed to export Excel: $e');
    }
  }

  // Main export method - chooses the best option automatically
  Future<void> _exportToExcel() async {
    if (filteredAccountLedgerReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Exporting...'),
            ],
          ),
        );
      },
    );

    try {
      bool canUseExternal = await _checkStoragePermission();
      
      Navigator.of(context).pop();
      
      if (canUseExternal) {
        await _exportToExcelExternal();
      } else {
        await _exportToExcelInternal();
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Export failed: $e');
    }
  }

  // Print Functionality
  Future<void> _printReport() async {
    if (filteredAccountLedgerReport.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Date', 'Voucher No', 'Transaction Type', 'Notes', 'Debit', 'Credit', 'Balance'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < filteredAccountLedgerReport.length; i++) {
        final ledger = filteredAccountLedgerReport[i];
        tableData.add([
          (i + 1).toString(),
          _getDisplayDate(ledger),
          ledger.voucherNo,
          ledger.typeOfTransactions,
          ledger.notes,
          ledger.debit != "0.00" ? formatCurrencyForPrint(ledger.debit) : "",
          ledger.credit != "0.00" ? formatCurrencyForPrint(ledger.credit) : "",
          ledger.balance,
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  '${widget.customerName} Ledger Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              
              // Date range
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Text(
                  'Period: ${_formatDateForPrint(widget.fromDate)} to ${_formatDateForPrint(widget.toDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),

              // Table
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FixedColumnWidth(100),
                  4: const pw.FlexColumnWidth(),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(60),
                  7: const pw.FixedColumnWidth(80),
                },
              ),

              // Footer with totals
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Debit:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(totalDebit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Credit:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(totalCredit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Closing Balance:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(closingBalance ?? "0.00", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showError('Failed to print: $e');
    }
  }

  Widget _buildLedgerReport() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // From Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('From Date', 
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                          InkWell(
                            onTap: () {},
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              width: double.infinity,
                              child: Text(
                                _formatDate(widget.fromDate),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // To Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('To Date', 
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                          InkWell(
                            onTap: () {},
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                              width: double.infinity,
                              child: Text(
                                _formatDate(widget.toDate),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Excel and Print buttons
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    ElevatedButton.icon(
      onPressed: _exportToExcel,
      icon: const Icon(Icons.file_download, size: 12),
      label: const Text('Excel'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 10),
        minimumSize: const Size(60, 28),
      ),
    ),
    const SizedBox(width: 6),
    ElevatedButton.icon(
      onPressed: _printReport,
      icon: const Icon(Icons.print, size: 12),
      label: const Text('Print'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 10),
        minimumSize: const Size(60, 28),
      ),
    ),
  ],
),
const SizedBox(height: 8),
                
                // Customer name and date range
                Text(
                  widget.customerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${_formatDate(widget.fromDate)} to ${_formatDate(widget.toDate)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: filteredAccountLedgerReport.isEmpty
                ? Center(
                    child: Text(
                      'No ledger records in the selected date range.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Summary card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Debit:', style: TextStyle(fontWeight: FontWeight.bold,fontSize: 14)),
                                  Text(formatCurrency(totalDebit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Credit:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(formatCurrency(totalCredit), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Closing Balance:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(closingBalance ?? "0.00", style: TextStyle(fontSize: 14, color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (receivedCheque != null && receivedCheque != "0.00") ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Pending Received Cheque:', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                    Text(formatCurrency(receivedCheque), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                              ],
                              if (givenCheque != null && givenCheque != "0.00") ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Pending Given Cheque:', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                    Text(formatCurrency(givenCheque), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
 // Ledger entries
...filteredAccountLedgerReport.map((ledger) {
  final transactionValue = formatTransactionValue(ledger.debit, ledger.credit, ledger.typeOfTransactions);
  
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey.shade300, width: 1),
    ),
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  ledger.typeOfTransactions,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 12.0,  
                    color: Colors.indigo
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                transactionValue,
                style: TextStyle(
                  fontSize: 16.0,  
                  color: transactionValue.startsWith('+') ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ledger.debit != "0.00" && ledger.debit.isNotEmpty) ...[
            Row(
              children: [
                const Text('Debit: ', style: TextStyle(fontWeight: FontWeight.w500)),
                Text(formatCurrency(ledger.debit), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (ledger.balance.isNotEmpty) ...[
            Row(
              children: [
                const Text('Balance: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                Text(ledger.balance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              const Text('Date: ', style: TextStyle(fontWeight: FontWeight.w500)),
              Text(_getDisplayDate(ledger), style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notes: ', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Text(
                  ledger.notes.isNotEmpty ? ledger.notes : '',
                  style: TextStyle(
                    color: ledger.notes.isNotEmpty ? Colors.black87 : Colors.grey,
                    fontStyle: ledger.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
})
                    ],
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: isLoading ? const Center(child: CircularProgressIndicator()) : _buildLedgerReport(),
  );
}
}