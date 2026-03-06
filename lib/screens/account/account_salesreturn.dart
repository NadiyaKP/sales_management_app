import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../sales_return/sales_return_view.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';

class AccountSalesReturnPage extends StatefulWidget {
  final String? customerName;
  final String? custId;
  final DateTime? fromDate;
  final DateTime? toDate;

  const AccountSalesReturnPage({
    Key? key,
    this.customerName,
    this.custId,
    this.fromDate,
    this.toDate,
  }) : super(key: key);

  @override
  State<AccountSalesReturnPage> createState() => _AccountSalesReturnPageState();
}

class _AccountSalesReturnPageState extends State<AccountSalesReturnPage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  
  List<SalesReturnRecord> salesReturnRecords = [];
  SalesReturnSummary? summary;
  String? headerTitle;
  bool isLoading = false;
  String? currentCustomerName;
  String? currentCustId;

  @override
  void initState() {
    super.initState();
    // Use the dates passed from parent or default to current month
    _fromDate = widget.fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = widget.toDate ?? DateTime.now();
    
    // Store current customer info
    currentCustomerName = widget.customerName;
    currentCustId = widget.custId;
    
    // Fetch data immediately when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSalesReturnData();
    });
  }

  Future<void> _fetchSalesReturnData() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      salesReturnRecords.clear();
      summary = null;
      headerTitle = null;
    });
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        setState(() => isLoading = false);
        _showError('Missing configuration. Please check your settings.');
        return;
      }

      String customerName = currentCustomerName ?? "Unknown Customer";
      String custId = currentCustId ?? "";

      print('\n' + '=' * 50);
      print('SALES RETURN API REQUEST:');
      print('URL: $url/account-ledger.php');
      print('Customer: $customerName (ID: $custId)');
      print('Date range: ${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}');
      print('Body: ${jsonEncode({
        "unid": unid,
        "slex": slex,
        "customer_name": customerName,
        "custid": custId,
        "from_date": DateFormat('dd-MM-yyyy').format(_fromDate),
        "to_date": DateFormat('dd-MM-yyyy').format(_toDate),
        "style": "sales_return",
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
          "style": "sales_return",
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );
      
      print('\n' + '=' * 50);
      print('SALES RETURN API RESPONSE:');
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
            final List<dynamic> salesReturnList = data['sales_returns'] ?? [];
            final summaryData = data['totals'];
            
            setState(() {
              salesReturnRecords = salesReturnList
                  .map((json) => SalesReturnRecord.fromJson(json))
                  .toList();
              if (summaryData != null) {
                summary = SalesReturnSummary.fromJson(Map<String, dynamic>.from(summaryData));
              }
              headerTitle = data['hdr_name']?.toString() ?? 'Sales Return Report';
              isLoading = false;
            });
            
            print('Found ${salesReturnRecords.length} sales return records');
            
            if (salesReturnList.isEmpty) {
              _showInfo('No sales return records found for $customerName in the selected date range');
            }
          } else {
            setState(() => isLoading = false);
            String errorMessage = data['message'] ?? 'Failed to fetch sales return data.';
            _showError(errorMessage);
            print('API Error: $errorMessage');
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
              final List<dynamic> salesReturnList = data['sales_returns'] ?? [];
              final summaryData = data['totals'];
              
              setState(() {
                salesReturnRecords = salesReturnList
                    .map((json) => SalesReturnRecord.fromJson(json))
                    .toList();
                if (summaryData != null) {
                  summary = SalesReturnSummary.fromJson(Map<String, dynamic>.from(summaryData));
                }
                headerTitle = data['hdr_name']?.toString() ?? 'Sales Return Report';
                isLoading = false;
              });
              
              _showInfo('Data loaded successfully with minor fixes');
            } else {
              setState(() => isLoading = false);
              _showError(data['message'] ?? 'Failed to fetch sales return data.');
            }
          } catch (fixError) {
            print('JSON Fix Error: $fixError');
            setState(() => isLoading = false);
            _showError('Error processing server response: ${e.toString()}');
          }
        }
      } else {
        setState(() => isLoading = false);
        String errorMessage = 'Server Error: ${response.statusCode}';
        _showError(errorMessage);
        print('HTTP Error: $errorMessage');
      }
    } catch (error) {
      setState(() => isLoading = false);
      print('\n' + '=' * 50);
      print('SALES RETURN API ERROR:');
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
            _fetchSalesReturnData();
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

  void _navigateToSalesReturnView(String crdId, String typeOfCredit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesReturnViewScreen(
          crdId: crdId,
          typeofCreditNote: typeOfCredit,
        ),
      ),
    );
  }

  String _formatDateForPrint(String dateString) {
    try {
      // Assuming the date is in dd-MM-yyyy format from API
      List<String> parts = dateString.split('-');
      if (parts.length == 3) {
        return '${parts[0]}/${parts[1]}/${parts[2]}';
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  String _formatAmount(String amount) {
    try {
      double value = double.parse(amount);
      return value.toStringAsFixed(2);
    } catch (e) {
      return amount;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
    if (salesReturnRecords.isEmpty) {
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
      Sheet sheetObject = excel['Sales Return Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Credit Note No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Notes';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Return Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Discount Amount';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Roundoff';
      sheetObject.cell(CellIndex.indexByString("H1")).value = 'Net Amount';
      sheetObject.cell(CellIndex.indexByString("I1")).value = 'Type';

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
      for (int i = 0; i < salesReturnRecords.length; i++) {
        final record = salesReturnRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = _formatDateForPrint(record.returnedDate);
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.creditNo;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.notes.isEmpty ? '-' : record.notes;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = _formatAmount(record.totalCartAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = _formatAmount(record.discountAmount);
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = _formatAmount(record.roundoff);
        sheetObject.cell(CellIndex.indexByString("H$rowIndex")).value = _formatAmount(record.totalAmount);
        sheetObject.cell(CellIndex.indexByString("I$rowIndex")).value = record.typeOfCredit;
      }

      // Add summary row if available
      if (summary != null) {
        int lastRow = salesReturnRecords.length + 2;
        sheetObject.cell(CellIndex.indexByString("D$lastRow")).value = 'Total Amount';
        sheetObject.cell(CellIndex.indexByString("E$lastRow")).value = _formatAmount(summary!.totalCartAmount);
        sheetObject.cell(CellIndex.indexByString("F$lastRow")).value = _formatAmount(summary!.totalDiscountAmount);
        sheetObject.cell(CellIndex.indexByString("G$lastRow")).value = _formatAmount(summary!.totalRoundoff);
        sheetObject.cell(CellIndex.indexByString("H$lastRow")).value = _formatAmount(summary!.totalAmount);
        
        // Style the summary row
        for (String cellName in ['D$lastRow', 'E$lastRow', 'F$lastRow', 'G$lastRow', 'H$lastRow']) {
          var cell = sheetObject.cell(CellIndex.indexByString(cellName));
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#FFEB3B',
          );
        }
      }

      Directory? directory;
      String fileName = 'Sales_Return_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
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
    if (salesReturnRecords.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales Return Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Credit Note No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Notes';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Return Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Discount Amount';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Roundoff';
      sheetObject.cell(CellIndex.indexByString("H1")).value = 'Net Amount';
      sheetObject.cell(CellIndex.indexByString("I1")).value = 'Type';

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
      for (int i = 0; i < salesReturnRecords.length; i++) {
        final record = salesReturnRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = _formatDateForPrint(record.returnedDate);
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.creditNo;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.notes.isEmpty ? '-' : record.notes;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = _formatAmount(record.totalCartAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = _formatAmount(record.discountAmount);
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = _formatAmount(record.roundoff);
        sheetObject.cell(CellIndex.indexByString("H$rowIndex")).value = _formatAmount(record.totalAmount);
        sheetObject.cell(CellIndex.indexByString("I$rowIndex")).value = record.typeOfCredit;
      }

      // Add summary row if available
      if (summary != null) {
        int lastRow = salesReturnRecords.length + 2;
        sheetObject.cell(CellIndex.indexByString("D$lastRow")).value = 'Total Amount';
        sheetObject.cell(CellIndex.indexByString("E$lastRow")).value = _formatAmount(summary!.totalCartAmount);
        sheetObject.cell(CellIndex.indexByString("F$lastRow")).value = _formatAmount(summary!.totalDiscountAmount);
        sheetObject.cell(CellIndex.indexByString("G$lastRow")).value = _formatAmount(summary!.totalRoundoff);
        sheetObject.cell(CellIndex.indexByString("H$lastRow")).value = _formatAmount(summary!.totalAmount);
        
        // Style the summary row
        for (String cellName in ['D$lastRow', 'E$lastRow', 'F$lastRow', 'G$lastRow', 'H$lastRow']) {
          var cell = sheetObject.cell(CellIndex.indexByString(cellName));
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#FFEB3B',
          );
        }
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Sales_Return_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
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
    if (salesReturnRecords.isEmpty) {
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
    if (salesReturnRecords.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Date', 'Credit Note No', 'Notes', 'Return Amount', 'Discount Amount', 'Roundoff', 'Net Amount', 'Type'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < salesReturnRecords.length; i++) {
        final record = salesReturnRecords[i];
        tableData.add([
          (i + 1).toString(),
          _formatDateForPrint(record.returnedDate),
          record.creditNo,
          record.notes.isEmpty ? '-' : record.notes,
          _formatAmount(record.totalCartAmount),
          _formatAmount(record.discountAmount),
          _formatAmount(record.roundoff),
          _formatAmount(record.totalAmount),
          record.typeOfCredit,
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
                  '${currentCustomerName ?? "Customer"} Sales Return Report',
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
                  'Period: ${_formatDate(_fromDate)} to ${_formatDate(_toDate)}',
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
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                  7: pw.Alignment.centerRight,
                  8: pw.Alignment.centerLeft,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FlexColumnWidth(),
                  4: const pw.FixedColumnWidth(60),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(50),
                  7: const pw.FixedColumnWidth(60),
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
                        pw.Text('Total Return Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatAmount(summary!.totalCartAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Discount Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatAmount(summary!.totalDiscountAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Roundoff:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatAmount(summary!.totalRoundoff), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Net Total Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(_formatAmount(summary!.totalAmount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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

  Widget _buildSalesReturnReport() {
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
                  currentCustomerName ?? 'Sales Return Report',
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
                            'Round Off: ${summary!.totalRoundoff}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Discount: ${summary!.totalDiscountAmount}',
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
                            summary!.totalCartAmount,
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
                      _buildTaxItem('KFC', summary!.cessAmount),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Sales Return Records List
          Expanded(
            child: salesReturnRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_return_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentCustomerName != null
                              ? 'No sales return records found for ${currentCustomerName}\nin the selected date range.'
                              : 'No sales return records found for the selected date range.',
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
                    itemCount: salesReturnRecords.length,
                    itemBuilder: (context, index) {
                      final record = salesReturnRecords[index];
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
                                // Clickable credit note number
                                GestureDetector(
                                  onTap: () => _navigateToSalesReturnView(record.crdId, record.typeOfCredit),
                                  child: Text(
                                    'No: ${record.creditNo}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                Text(
                                  record.returnedDate,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              record.totalAmount,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              record.totalCartAmount,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.teal,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildRecordItem('Round Off', record.roundoff),
                                _buildRecordItem('Discount', record.discountAmount),
                                _buildRecordItem('Type', record.typeOfCredit),
                              ],
                            ),
                            if (record.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Notes: ${record.notes}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
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
            fontSize: 12,
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
            fontSize: 12,
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
          currentCustomerName != null 
              ? 'Sales Return - ${currentCustomerName}'
              : 'Sales Return Report',
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
      body: isLoading ? const Center(child: CircularProgressIndicator()) : _buildSalesReturnReport(),
    );
  }
}

// Data Models
class SalesReturnRecord {
  final int slNo;
  final String returnedDate;
  final String creditNo;
  final String crdId;
  final String typeOfCredit;
  final String notes;
  final String totalCartAmount;
  final String discountAmount;
  final String roundoff;
  final String totalAmount;

  SalesReturnRecord({
    required this.slNo,
    required this.returnedDate,
    required this.creditNo,
    required this.crdId,
    required this.typeOfCredit,
    required this.notes,
    required this.totalCartAmount,
    required this.discountAmount,
    required this.roundoff,
    required this.totalAmount,
  });

  factory SalesReturnRecord.fromJson(Map<String, dynamic> json) {
    return SalesReturnRecord(
      slNo: json['sl_no'] ?? 0,
      returnedDate: json['returned_date']?.toString() ?? '',
      creditNo: json['credit_no']?.toString() ?? '',
      crdId: json['crdid']?.toString() ?? '',
      typeOfCredit: json['type_of_credit']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      totalCartAmount: json['total_cart_amount']?.toString() ?? '',
      discountAmount: json['discount_amount']?.toString() ?? '',
      roundoff: json['roundoff']?.toString() ?? '',
      totalAmount: json['total_amount']?.toString() ?? '',
    );
  }
}

class SalesReturnSummary {
  final String totalCartAmount;
  final String totalDiscountAmount;
  final String totalRoundoff;
  final String totalAmount;
  final String cgstAmount;
  final String sgstAmount;
  final String igstAmount;
  final String cessAmount;

  SalesReturnSummary({
    required this.totalCartAmount,
    required this.totalDiscountAmount,
    required this.totalRoundoff,
    required this.totalAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.cessAmount,
  });

  factory SalesReturnSummary.fromJson(Map<String, dynamic> json) {
    return SalesReturnSummary(
      totalCartAmount: json['total_cart_amount']?.toString() ?? '',
      totalDiscountAmount: json['total_discount_amount']?.toString() ?? '',
      totalRoundoff: json['total_roundoff']?.toString() ?? '',
      totalAmount: json['total_amount']?.toString() ?? '',
      cgstAmount: json['cgst_amount']?.toString() ?? '',
      sgstAmount: json['sgst_amount']?.toString() ?? '',
      igstAmount: json['igst_amount']?.toString() ?? '',
      cessAmount: json['cess_amount']?.toString() ?? '',
    );
  }
}