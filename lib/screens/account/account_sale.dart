import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../invoice/invoice_view.dart';
import '../../theme/app_theme.dart';

class AccountSalePage extends StatefulWidget {
  final String? customerName;
  final String? custId;
  final DateTime? fromDate;
  final DateTime? toDate;
  
  const AccountSalePage({
    Key? key,
    this.customerName,
    this.custId,
    this.fromDate,
    this.toDate,
  }) : super(key: key);

  @override
  State<AccountSalePage> createState() => _AccountSalePageState();
}

class _AccountSalePageState extends State<AccountSalePage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  
  List<SalesRecord> salesRecords = [];
  SalesSummary? summary;
  String? headerTitle;
  bool isLoading = false;

  // Company details
  String companyName = "GST 3.0";
  String companyAddress = "2/114B, Ayisha complex,\nMalappuram road,Kottakkal,\nMalappuram-676528";
  String companyPhone = "Mob : 9562500548\nPh : 9876543210";
  String companyEmail = "Email : info@coremicron.com";
  String companyGST = "GST : 123124141231132123";

  @override
  void initState() {
    super.initState();
    // Use the dates passed from AccountLedgerPage or default to current month
    _fromDate = widget.fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = widget.toDate ?? DateTime.now();
    _fetchSalesData();
  }

  Future<void> _fetchSalesData() async {
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
        setState(() => isLoading = false);
        _showError('Missing configuration. Please login again.');
        return;
      }

      // Use provided customer info or default values
      String customerName = widget.customerName ?? "Aisha";
      String custId = widget.custId ?? "MTg-";

      print('\n' + '=' * 50);
      print('SALES API REQUEST:');
      print('URL: $url/account-ledger.php');
      print('Body: ${jsonEncode({
        "unid": unid,
        "slex": slex,
        "customer_name": customerName,
        "custid": custId,
        "from_date": DateFormat('dd-MM-yyyy').format(_fromDate),
        "to_date": DateFormat('dd-MM-yyyy').format(_toDate),
        "style": "sales",
      })}');
      print('=' * 50);

      final response = await http.post(
        Uri.parse('$url/account-ledger.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "customer_name": customerName,
          "custid": custId,
          "from_date": DateFormat('dd-MM-yyyy').format(_fromDate),
          "to_date": DateFormat('dd-MM-yyyy').format(_toDate),
          "style": "sales",
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );
      
      print('\n' + '=' * 50);
      print('SALES API RESPONSE:');
      print('Status Code: ${response.statusCode}');
      print('Response Body Length: ${response.body.length} characters');
      print('Full Response Body:');
      print(response.body);
      print('=' * 50 + '\n');

      if (response.statusCode == 200) {
        // Check if response body is empty
        if (response.body.isEmpty) {
          setState(() => isLoading = false);
          _showError('Received empty response from server');
          return;
        }

        try {
          // First, try to clean the response body if needed
          String cleanResponse = response.body.trim();
          
          // Remove any possible BOM or control characters at the start
          cleanResponse = cleanResponse.replaceAll(RegExp(r'^\uFEFF'), '');
          
          final data = jsonDecode(cleanResponse);
          
          if (data['result'] == "1") {
            final List<dynamic> salesList = data['invoice_details'] ?? [];
            final summaryData = data['totals'];
            
            setState(() {
              salesRecords = salesList
                  .map((json) => SalesRecord.fromJson(json))
                  .toList();
              if (summaryData != null) {
                summary = SalesSummary.fromJson(Map<String, dynamic>.from(summaryData));
              }
              headerTitle = data['hdr_name'];
              isLoading = false;
            });
            
            if (salesList.isEmpty) {
              _showInfo('No sales records found for ${widget.customerName ?? "the selected customer"} in the selected date range');
            }
          } else {
            setState(() => isLoading = false);
            _showError(data['message'] ?? 'Failed to fetch sales data.');
          }
        } catch (e) {
          print('JSON Decode Error: $e');
          print('Raw response: ${response.body}');
          
          // Try to fix common JSON issues
          try {
            String fixedJson = response.body.trim();
            
            // Remove any trailing commas before closing brackets
            fixedJson = fixedJson.replaceAll(RegExp(r',\s*\}'), '}');
            fixedJson = fixedJson.replaceAll(RegExp(r',\s*\]'), ']');
            
            final data = jsonDecode(fixedJson);
            
            if (data['result'] == "1") {
              final List<dynamic> salesList = data['invoice_details'] ?? [];
              final summaryData = data['totals'];
              
              setState(() {
                salesRecords = salesList
                    .map((json) => SalesRecord.fromJson(json))
                    .toList();
                if (summaryData != null) {
                  summary = SalesSummary.fromJson(Map<String, dynamic>.from(summaryData));
                }
                headerTitle = data['hdr_name'];
                isLoading = false;
              });
              
              _showInfo('Data loaded successfully with minor fixes');
            } else {
              setState(() => isLoading = false);
              _showError(data['message'] ?? 'Failed to fetch sales data.');
            }
          } catch (fixError) {
            print('JSON Fix Error: $fixError');
            setState(() => isLoading = false);
            _showError('Error processing server response: ${e.toString()}');
          }
        }
      } else {
        setState(() => isLoading = false);
        _showError('Server error: ${response.statusCode}');
      }
    } catch (error) {
      setState(() => isLoading = false);
      print('\n' + '=' * 50);
      print('SALES API ERROR:');
      print('Error: $error');
      print('=' * 50 + '\n');
      
      String errorMessage = 'An error occurred';
      if (error.toString().contains('timeout')) {
        errorMessage = 'Connection timeout. Please check your internet connection.';
      } else if (error.toString().contains('SocketException')) {
        errorMessage = 'Network error. Please check your connection.';
      } else {
        errorMessage = 'Error: $error';
      }
      
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            setState(() => isLoading = true);
            _fetchSalesData();
          },
        ),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToInvoiceView(String invoiceId, String invoiceNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceViewScreen(
          invId: invoiceId,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateForPrint(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String formatCurrencyForPrint(String? value) {
    if (value == null || value.isEmpty) return "0.00";
    String cleanValue = value.replaceAll(',', '').replaceAll('Dr', '').replaceAll('Cr', '').replaceAll('₹', '').trim();
    double amount = double.tryParse(cleanValue) ?? 0.0;
    return amount.toStringAsFixed(2);
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
    if (salesRecords.isEmpty) {
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
      Sheet sheetObject = excel['Sales Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Invoice No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Total Amount\nExe.gst';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'GST Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Cess Amount';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Disc Amount';
      sheetObject.cell(CellIndex.indexByString("H1")).value = 'Roundoff';
      sheetObject.cell(CellIndex.indexByString("I1")).value = 'Net Amount';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1', 'H1', 'I1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < salesRecords.length; i++) {
        final record = salesRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = record.date;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.invoiceNumber;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = formatCurrencyForPrint(record.beforeGst);
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = formatCurrencyForPrint(record.gstAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = formatCurrencyForPrint(record.cessAmount);
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = formatCurrencyForPrint(record.discountAmount);
        sheetObject.cell(CellIndex.indexByString("H$rowIndex")).value = formatCurrencyForPrint(record.roundOff);
        sheetObject.cell(CellIndex.indexByString("I$rowIndex")).value = formatCurrencyForPrint(record.totalAmount);
      }

      // Add summary row
      if (summary != null) {
        final summaryRow = salesRecords.length + 2;
        sheetObject.cell(CellIndex.indexByString("A$summaryRow")).value = '';
        sheetObject.cell(CellIndex.indexByString("B$summaryRow")).value = '';
        sheetObject.cell(CellIndex.indexByString("C$summaryRow")).value = 'Total';
        sheetObject.cell(CellIndex.indexByString("D$summaryRow")).value = formatCurrencyForPrint(summary!.beforeTax);
        sheetObject.cell(CellIndex.indexByString("E$summaryRow")).value = formatCurrencyForPrint(summary!.gstAmount);
        sheetObject.cell(CellIndex.indexByString("F$summaryRow")).value = formatCurrencyForPrint(summary!.cessAmount);
        sheetObject.cell(CellIndex.indexByString("G$summaryRow")).value = formatCurrencyForPrint(summary!.discountAmount);
        sheetObject.cell(CellIndex.indexByString("H$summaryRow")).value = formatCurrencyForPrint(summary!.roundOff);
        sheetObject.cell(CellIndex.indexByString("I$summaryRow")).value = formatCurrencyForPrint(summary!.totalAmount);

        // Style summary row
        for (String cellName in ['A$summaryRow', 'B$summaryRow', 'C$summaryRow', 'D$summaryRow', 
                                'E$summaryRow', 'F$summaryRow', 'G$summaryRow', 'H$summaryRow', 'I$summaryRow']) {
          var cell = sheetObject.cell(CellIndex.indexByString(cellName));
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#E0E0E0',
          );
        }
      }

      Directory? directory;
      String fileName = 'Sales_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
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
    if (salesRecords.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Invoice No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Total Amount\nExe.gst';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'GST Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Cess Amount';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Disc Amount';
      sheetObject.cell(CellIndex.indexByString("H1")).value = 'Roundoff';
      sheetObject.cell(CellIndex.indexByString("I1")).value = 'Net Amount';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1', 'H1', 'I1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < salesRecords.length; i++) {
        final record = salesRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = record.date;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.invoiceNumber;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = formatCurrencyForPrint(record.beforeGst);
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = formatCurrencyForPrint(record.gstAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = formatCurrencyForPrint(record.cessAmount);
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = formatCurrencyForPrint(record.discountAmount);
        sheetObject.cell(CellIndex.indexByString("H$rowIndex")).value = formatCurrencyForPrint(record.roundOff);
        sheetObject.cell(CellIndex.indexByString("I$rowIndex")).value = formatCurrencyForPrint(record.totalAmount);
      }

      // Add summary row
      if (summary != null) {
        final summaryRow = salesRecords.length + 2;
        sheetObject.cell(CellIndex.indexByString("A$summaryRow")).value = '';
        sheetObject.cell(CellIndex.indexByString("B$summaryRow")).value = '';
        sheetObject.cell(CellIndex.indexByString("C$summaryRow")).value = 'Total';
        sheetObject.cell(CellIndex.indexByString("D$summaryRow")).value = formatCurrencyForPrint(summary!.beforeTax);
        sheetObject.cell(CellIndex.indexByString("E$summaryRow")).value = formatCurrencyForPrint(summary!.gstAmount);
        sheetObject.cell(CellIndex.indexByString("F$summaryRow")).value = formatCurrencyForPrint(summary!.cessAmount);
        sheetObject.cell(CellIndex.indexByString("G$summaryRow")).value = formatCurrencyForPrint(summary!.discountAmount);
        sheetObject.cell(CellIndex.indexByString("H$summaryRow")).value = formatCurrencyForPrint(summary!.roundOff);
        sheetObject.cell(CellIndex.indexByString("I$summaryRow")).value = formatCurrencyForPrint(summary!.totalAmount);

        // Style summary row
        for (String cellName in ['A$summaryRow', 'B$summaryRow', 'C$summaryRow', 'D$summaryRow', 
                                'E$summaryRow', 'F$summaryRow', 'G$summaryRow', 'H$summaryRow', 'I$summaryRow']) {
          var cell = sheetObject.cell(CellIndex.indexByString(cellName));
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#E0E0E0',
          );
        }
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Sales_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
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
    if (salesRecords.isEmpty) {
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
    if (salesRecords.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Date', 'Invoice No', 'Total Amount\nExe.gst', 'GST Amount', 'Cess Amount', 'Disc Amount', 'Roundoff', 'Net Amount'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < salesRecords.length; i++) {
        final record = salesRecords[i];
        tableData.add([
          (i + 1).toString(),
          record.date,
          record.invoiceNumber,
          formatCurrencyForPrint(record.beforeGst),
          formatCurrencyForPrint(record.gstAmount),
          formatCurrencyForPrint(record.cessAmount),
          formatCurrencyForPrint(record.discountAmount),
          formatCurrencyForPrint(record.roundOff),
          formatCurrencyForPrint(record.totalAmount),
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
                  '${widget.customerName ?? "Customer"} Sales Report',
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
                  'Period: ${_formatDateForPrint(_fromDate)} to ${_formatDateForPrint(_toDate)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),

              // Table
              pw.Table.fromTextArray(
                context: context,
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                  8: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(50),
                  5: const pw.FixedColumnWidth(50),
                  6: const pw.FixedColumnWidth(50),
                  7: const pw.FixedColumnWidth(50),
                  8: const pw.FixedColumnWidth(60),
                },
              ),

              // Footer with totals
              if (summary != null) pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Amount Exe.gst:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(summary!.beforeTax), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total GST Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(summary!.gstAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Cess Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(summary!.cessAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Discount Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(summary!.discountAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Roundoff:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrencyForPrint(summary!.roundOff), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Net Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Text(formatCurrencyForPrint(summary!.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
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

  Widget _buildSalesReport() {
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
                                _formatDate(_fromDate),
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
                                _formatDate(_toDate),
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
                  widget.customerName ?? 'Sales Report',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'From ${_formatDate(_fromDate)} to ${_formatDate(_toDate)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Header Title Section (if available)
          if (headerTitle != null && headerTitle!.isNotEmpty) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Text(
                headerTitle!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          
          // Summary Card
          if (summary != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KFC: ${summary!.cessAmount}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Round Off: ${summary!.roundOff}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Discount: ${summary!.discountAmount}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            summary!.totalAmount,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            summary!.beforeTax,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTaxItem('CGST', summary!.cgstAmount),
                      _buildTaxItem('SGST', summary!.sgstAmount),
                      _buildTaxItem('IGST', summary!.igstAmount),
                      _buildTaxItem('GST', summary!.gstAmount),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Sales Records List
          Expanded(
            child: salesRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.customerName != null
                              ? 'No sales records found for ${widget.customerName}\nin the selected date range.'
                              : 'No sales records found for the selected date range.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: salesRecords.length,
                    itemBuilder: (context, index) {
                      final record = salesRecords[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Simplified clickable invoice number
                                GestureDetector(
                                  onTap: () => _navigateToInvoiceView(record.invId, record.invoiceNumber),
                                  child: Text(
                                    record.invoiceNumber,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Text(
                                  record.date,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(''),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      record.totalAmount,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      record.beforeGst,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildRecordItem('GST', record.gstAmount),
                                _buildRecordItem('KFC', record.cessAmount),
                                _buildRecordItem('Round Off', record.roundOff),
                                _buildRecordItem('Discount', record.discountAmount),
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

  Widget _buildTaxItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customerName != null 
              ? 'Sales Report - ${widget.customerName}'
              : 'Sales Report',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: isLoading ? const Center(child: CircularProgressIndicator()) : _buildSalesReport(),
    );
  }
}

// Data Models
class SalesRecord {
  final int slNo;
  final String date;
  final String invoiceNumber;
  final String invId;
  final String beforeGst;
  final String gstAmount;
  final String cessAmount;
  final String discountAmount;
  final String roundOff;
  final String totalAmount;

  SalesRecord({
    required this.slNo,
    required this.date,
    required this.invoiceNumber,
    required this.invId,
    required this.beforeGst,
    required this.gstAmount,
    required this.cessAmount,
    required this.discountAmount,
    required this.roundOff,
    required this.totalAmount,
  });

  factory SalesRecord.fromJson(Map<String, dynamic> json) {
    return SalesRecord(
      slNo: json['sl_no'] ?? 0,
      date: json['invoice_date'] ?? '',
      invoiceNumber: json['invoice_no'] ?? '',
      invId: json['invid'] ?? '',
      beforeGst: json['before_gst']?.toString() ?? '',
      gstAmount: json['gst_amount']?.toString() ?? '',
      cessAmount: json['cess_amount']?.toString() ?? '',
      discountAmount: json['discount_amount']?.toString() ?? '',
      roundOff: json['roundoff']?.toString() ?? '',
      totalAmount: json['total_amount']?.toString() ?? '',
    );
  }
}

class SalesSummary {
  final String beforeTax;
  final String gstAmount;
  final String cessAmount;
  final String discountAmount;
  final String roundOff;
  final String totalAmount;
  final String cgstAmount;
  final String sgstAmount;
  final String igstAmount;

  SalesSummary({
    required this.beforeTax,
    required this.gstAmount,
    required this.cessAmount,
    required this.discountAmount,
    required this.roundOff,
    required this.totalAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    return SalesSummary(
      beforeTax: json['before_tax']?.toString() ?? '',
      gstAmount: json['gst_amount']?.toString() ?? '',
      cessAmount: json['cess_amount']?.toString() ?? '',
      discountAmount: json['discount_amount']?.toString() ?? '',
      roundOff: json['roundoff']?.toString() ?? '',
      totalAmount: json['total_amount']?.toString() ?? '',
      cgstAmount: json['cgst_amount']?.toString() ?? '',
      sgstAmount: json['sgst_amount']?.toString() ?? '',
      igstAmount: json['igst_amount']?.toString() ?? '',
    );
  }
}