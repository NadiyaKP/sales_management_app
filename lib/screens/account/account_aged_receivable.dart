import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../../theme/app_theme.dart';

class AccountAgedReceivablePage extends StatefulWidget {
  final String? customerName;
  final String? custId;
  final DateTime? fromDate;
  final DateTime? toDate;

  const AccountAgedReceivablePage({
    Key? key,
    this.customerName,
    this.custId,
    this.fromDate,
    this.toDate,
  }) : super(key: key);

  @override
  State<AccountAgedReceivablePage> createState() => _AccountAgedReceivablePageState();
}

class _AccountAgedReceivablePageState extends State<AccountAgedReceivablePage> {
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  late DateTime _fromDate;
  late DateTime _toDate;
  
  List<InvoiceDue> invoiceList = [];
  double totalBalanceDue = 0.0;
  String? headerTitle;
  bool isLoading = false;

  // Store the customer details
  late String _customerName;
  late String _custId;

  // Company details
  String companyName = "GST 3.0";
  String companyAddress = "2/114B, Ayisha complex,\nMalappuram road,Kottakkal,\nMalappuram-676528";
  String companyPhone = "Mob : 9562500548\nPh : 9876543210";
  String companyEmail = "Email : info@coremicron.com";
  String companyGST = "GST : 123124141231132123";

  @override
  void initState() {
    super.initState();
    
    // Initialize customer details from widget parameters
    _customerName = widget.customerName ?? "Default Customer";
    _custId = widget.custId ?? "DEFAULT";
    
    // Use the dates passed from parent or default dates
    _fromDate = widget.fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = widget.toDate ?? DateTime.now();
    
    _fromDateController.text = DateFormat('dd-MM-yyyy').format(_fromDate);
    _toDateController.text = DateFormat('dd-MM-yyyy').format(_toDate);
    
    _fetchAgedReceivableData();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgedReceivableData() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      invoiceList = [];
      totalBalanceDue = 0.0;
    });
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        setState(() => isLoading = false);
        _showError('Missing configuration data. Please check your settings.');
        return;
      }

      //request body
      final requestBody = {
        "unid": unid,
        "slex": slex,
        "customer_name": _customerName,
        "custid": _custId,
        "from_date": _fromDateController.text,
        "to_date": _toDateController.text,
        "style": "aged",
      };

      print('\n' + '=' * 50);
      print('AGED RECEIVABLE API REQUEST:');
      print('URL: $url/account-ledger.php');
      print('Customer: $_customerName (ID: $_custId)');
      print('Date range: ${_fromDateController.text} to ${_toDateController.text}');
      print('Body: ${jsonEncode(requestBody)}');
      print('=' * 50);

      final response = await http.post(
        Uri.parse('$url/account-ledger.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Please check your internet connection.');
        },
      );
      
      print('\n' + '=' * 50);
      print('AGED RECEIVABLE API RESPONSE:');
      print('Status Code: ${response.statusCode}');
      print('Response Body:');
      print(response.body);
      print('=' * 50 + '\n');
      
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          setState(() => isLoading = false);
          _showError('Received empty response from server');
          return;
        }

        try {
          String cleanResponse = response.body.trim();
          cleanResponse = cleanResponse.replaceAll(RegExp(r'^\uFEFF'), '');
          
          final data = jsonDecode(cleanResponse);
          
          if (data['result'] == "1") {
            final List<dynamic> agedCartDet = data['agedcartdet'] ?? [];
            
            if (agedCartDet.isNotEmpty) {
              final customerData = agedCartDet[0];
              final List<dynamic> invoiceDueList = customerData['customer_invoice_due'] ?? [];
              
              setState(() {
                invoiceList = invoiceDueList
                    .map((json) => InvoiceDue.fromJson(json))
                    .toList();
                totalBalanceDue = (customerData['customer_ttl_bln_due'] as num?)?.toDouble() ?? 0.0;
                headerTitle = data['hdr_name']?.toString();
                isLoading = false;
              });
              
              if (invoiceDueList.isEmpty) {
                _showInfo('No aged receivable records found for $_customerName in the selected date range');
              }
            } else {
              setState(() => isLoading = false);
              _showInfo('No aged receivable data found');
            }
          } else {
            setState(() => isLoading = false);
            _showError(data['message'] ?? 'Failed to fetch aged receivable data.');
          }
        } catch (e) {
          print('JSON Decode Error: $e');
          setState(() => isLoading = false);
          _showError('Error processing server response: ${e.toString()}');
        }
      } else {
        setState(() => isLoading = false);
        _showError('Server error: ${response.statusCode}. Please try again later.');
      }
    } catch (error) {
      setState(() => isLoading = false);
      print('\n' + '=' * 50);
      print('AGED RECEIVABLE API ERROR:');
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
            _fetchAgedReceivableData();
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
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
          if (_fromDate.isAfter(_toDate)) {
            _toDate = _fromDate;
            _toDateController.text = DateFormat('dd-MM-yyyy').format(_toDate);
          }
        } else {
          _toDate = picked;
          if (_toDate.isBefore(_fromDate)) {
            _fromDate = _toDate;
            _fromDateController.text = DateFormat('dd-MM-yyyy').format(_fromDate);
          }
        }
        controller.text = DateFormat('dd-MM-yyyy').format(picked);
      });
      _fetchAgedReceivableData();
    }
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

  Future<bool> _isPermissionHandlerAvailable() async {
    try {
      await Permission.storage.status;
      return true;
    } catch (e) {
      print('Permission handler not available: $e');
      return false;
    }
  }

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

  Future<void> _exportToExcelExternal() async {
    if (invoiceList.isEmpty) {
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
      Sheet sheetObject = excel['Aged Receivable Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Invoice No';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Invoice Date';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Due Days';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Invoice Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Receipt Amount';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Balance Due';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < invoiceList.length; i++) {
        final record = invoiceList[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = record.invoiceNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.invoiceDate;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.dueDays;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = double.parse(record.invoiceAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = double.parse(record.receiptAmount);
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = double.parse(record.balanceDue);
      }

      // Add summary row
      final summaryRow = invoiceList.length + 2;
      sheetObject.cell(CellIndex.indexByString("A$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("B$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("C$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("D$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("E$summaryRow")).value = 'Total Balance Due:';
      sheetObject.cell(CellIndex.indexByString("F$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("G$summaryRow")).value = totalBalanceDue;

      // Style summary row
      for (String cellName in ['A$summaryRow', 'B$summaryRow', 'C$summaryRow', 'D$summaryRow', 'E$summaryRow', 'F$summaryRow', 'G$summaryRow']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#E0E0E0',
        );
      }

      Directory? directory;
      String fileName = 'Aged_Receivable_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
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

  Future<void> _exportToExcelInternal() async {
    if (invoiceList.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Aged Receivable Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Invoice No';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Invoice Date';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Due Days';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Invoice Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Receipt Amount';
      sheetObject.cell(CellIndex.indexByString("G1")).value = 'Balance Due';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1', 'G1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < invoiceList.length; i++) {
        final record = invoiceList[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = record.invoiceNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.invoiceDate;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.dueDays;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = double.parse(record.invoiceAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = double.parse(record.receiptAmount);
        sheetObject.cell(CellIndex.indexByString("G$rowIndex")).value = double.parse(record.balanceDue);
      }

      // Add summary row
      final summaryRow = invoiceList.length + 2;
      sheetObject.cell(CellIndex.indexByString("A$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("B$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("C$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("D$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("E$summaryRow")).value = 'Total Balance Due:';
      sheetObject.cell(CellIndex.indexByString("F$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("G$summaryRow")).value = totalBalanceDue;

      // Style summary row
      for (String cellName in ['A$summaryRow', 'B$summaryRow', 'C$summaryRow', 'D$summaryRow', 'E$summaryRow', 'F$summaryRow', 'G$summaryRow']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#E0E0E0',
        );
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Aged_Receivable_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
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

  Future<void> _exportToExcel() async {
    if (invoiceList.isEmpty) {
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

  Future<void> _printReport() async {
    if (invoiceList.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Invoice No', 'Invoice Date', 'Due Days', 'Invoice Amt', 'Receipt Amt', 'Balance Due'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < invoiceList.length; i++) {
        final record = invoiceList[i];
        tableData.add([
          (i + 1).toString(),
          record.invoiceNo,
          record.invoiceDate,
          record.dueDays.toString(),
          double.parse(record.invoiceAmount).toStringAsFixed(2),
          double.parse(record.receiptAmount).toStringAsFixed(2),
          double.parse(record.balanceDue).toStringAsFixed(2),
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Header with company details
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    companyAddress,
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    companyPhone,
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    companyEmail,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    companyGST,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 16),
                ],
              ),

              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Aged Receivable Report - $_customerName',
                  style: pw.TextStyle(
                    fontSize: 18,
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
                  fontSize: 8,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerRight,
                  6: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(60),
                  3: const pw.FixedColumnWidth(30),
                  4: const pw.FixedColumnWidth(40),
                  5: const pw.FixedColumnWidth(40),
                  6: const pw.FixedColumnWidth(40),
                },
              ),

              // Footer with totals
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text('Total Balance Due: ', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text(totalBalanceDue.toStringAsFixed(2), 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text('Prepared By', style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 20),
                            pw.Text('________________', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 20),
                            pw.Text('________________', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
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

  Color _getDueDaysColor(int days) {
    if (days <= 30) {
      return Colors.green;
    } else if (days <= 60) {
      return Colors.orange;
    } else if (days <= 90) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  String _formatCurrency(String amount) {
    double value = double.tryParse(amount) ?? 0.0;
    return '₹ ${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Aged Receivable - $_customerName',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Selection Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'From Date',
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6), 
                          Container(
                            height: 36, 
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6), 
                            ),
                            child: TextField(
                              controller: _fromDateController,
                              style: const TextStyle(
                                fontSize: 11, 
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, 
                                  vertical: 8,    
                                ),
                                suffixIcon: Icon(
                                  Icons.calendar_today, 
                                  color: Colors.grey,
                                  size: 16, 
                                ),
                                isDense: true, 
                              ),
                              readOnly: true,
                              onTap: () => _selectDate(context, _fromDateController, true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12), 
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'To Date',
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6), 
                          Container(
                            height: 36, 
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6), 
                            ),
                            child: TextField(
                              controller: _toDateController,
                              style: const TextStyle(
                                fontSize: 11, 
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, 
                                  vertical: 8,    
                                ),
                                suffixIcon: Icon(
                                  Icons.calendar_today, 
                                  color: Colors.grey,
                                  size: 16, 
                                ),
                                isDense: true,
                              ),
                              readOnly: true,
                              onTap: () => _selectDate(context, _toDateController, false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

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
                
                // Report Title  
                Center(
                  child: Text(
                    headerTitle?.replaceAll('&amp;', '&') ?? 
                    'Aged Receivable Report From ${_fromDateController.text} To ${_toDateController.text}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Loading or Empty State or Records
                if (invoiceList.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No aged receivable records found for $_customerName\nin the selected date range.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_fromDateController.text} to ${_toDateController.text}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  )
                else
                  // Aged Receivable Records List
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Card with Total Balance
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade700, Colors.blue.shade900],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Total Balance Due',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCurrency(totalBalanceDue.toString()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${invoiceList.length} Invoice(s) Pending',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Invoice List Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Invoice Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Total: ${invoiceList.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Invoice Cards
                      ...invoiceList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final record = entry.value;
                        final dueDaysColor = _getDueDaysColor(record.dueDays);
                        
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Header with Invoice Number and Due Days
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                  border: const Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${index + 1}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  record.invoiceNo == 'Opening Balance' 
                                                      ? 'OPENING BALANCE'
                                                      : 'INVOICE #${record.invoiceNo}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                Text(
                                                  'Date: ${record.invoiceDate}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: dueDaysColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: dueDaysColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: dueDaysColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${record.dueDays} days',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: dueDaysColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Amount Details
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Invoice Amount Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.receipt,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Invoice Amount:',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatCurrency(record.invoiceAmount),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Receipt Amount Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.payment,
                                              size: 16,
                                              color: Colors.green.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Receipt Amount:',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatCurrency(record.receiptAmount),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Divider
                                    Divider(
                                      color: Colors.grey.shade300,
                                      thickness: 1,
                                    ),
                                    const SizedBox(height: 12),

                                    // Balance Due Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.account_balance_wallet,
                                              size: 16,
                                              color: Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Balance Due:',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatCurrency(record.balanceDue),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Footer with Invoice ID (if not Opening Balance)
                              if (record.invoiceNo != 'Opening Balance')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    border: const Border(
                                      top: BorderSide(
                                        color: Color(0xFFE0E0E0),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Invoice ID: ${record.invoiceId}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 8),
                    ],
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }
}

// Updated Data Model for Invoice Due
class InvoiceDue {
  final String invoiceId;
  final String invoiceNo;
  final String invoiceDate;
  final int dueDays;
  final String invoiceAmount;
  final String receiptAmount;
  final String balanceDue;

  InvoiceDue({
    required this.invoiceId,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.dueDays,
    required this.invoiceAmount,
    required this.receiptAmount,
    required this.balanceDue,
  });

  factory InvoiceDue.fromJson(Map<String, dynamic> json) {
    return InvoiceDue(
      invoiceId: json['inv_id']?.toString() ?? '',
      invoiceNo: json['inv_no']?.toString() ?? '',
      invoiceDate: json['inv_date']?.toString() ?? '',
      dueDays: json['due_days'] ?? 0,
      invoiceAmount: json['inv_amt']?.toString() ?? '0.00',
      receiptAmount: json['rcp_amt']?.toString() ?? '0.00',
      balanceDue: json['bln_due']?.toString() ?? '0.00',
    );
  }
}