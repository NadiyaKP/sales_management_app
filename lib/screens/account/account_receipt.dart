import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../receipts/receipt_view.dart';

class AccountReceiptPage extends StatefulWidget {
  final String? customerName;
  final String? custId;
  final DateTime? fromDate;
  final DateTime? toDate;

  const AccountReceiptPage({
    Key? key,
    this.customerName,
    this.custId,
    this.fromDate,
    this.toDate,
  }) : super(key: key);

  @override
  State<AccountReceiptPage> createState() => _AccountReceiptPageState();
}

class _AccountReceiptPageState extends State<AccountReceiptPage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  
  List<ReceiptRecord> receiptRecords = [];
  String? totalAmount;
  String? headerTitle;
  bool isLoading = false;
  String? currentCustomerName;
  String? currentCustId;

  @override
  void initState() {
    super.initState();
    _fromDate = widget.fromDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = widget.toDate ?? DateTime.now();
    
    currentCustomerName = widget.customerName;
    currentCustId = widget.custId;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReceiptData();
    });
  }

  // Navigate to receipt view page
  void _navigateToReceiptView(ReceiptRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptViewPage(
          rcpId: record.rcpid,  
        ),
      ),
    );
  }

  Future<void> _fetchReceiptData() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      receiptRecords.clear();
      totalAmount = null;
      headerTitle = null;
    });
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _showError('Missing configuration. Please check your settings.');
        return;
      }

      String customerName = currentCustomerName ?? "Unknown Customer";
      String custId = currentCustId ?? "";

      print('Fetching receipt data for: $customerName (ID: $custId)');
      print('Date range: ${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}');

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
          "style": "receipt",
        }),
      );
      
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> receiptList = data['receipts'] ?? [];
          
          setState(() {
            receiptRecords = receiptList
                .map((json) => ReceiptRecord.fromJson(json))
                .toList();
            totalAmount = data['total_amount'] ?? '0.00';
            headerTitle = data['hdr_name'] ?? 'Receipt Report';
          });
          
          print('Found ${receiptRecords.length} receipt records');
          
          if (receiptList.isEmpty) {
            _showError('No receipt records found for $customerName in the selected date range');
          }
        } else {
          String errorMessage = data['message'] ?? 'Failed to fetch receipt data.';
          _showError(errorMessage);
          print('API Error: $errorMessage');
        }
      } else {
        String errorMessage = 'Server Error: ${response.statusCode}';
        _showError(errorMessage);
        print('HTTP Error: $errorMessage');
      }
    } catch (error) {
      String errorMessage = 'An error occurred: $error';
      _showError(errorMessage);
      print('Exception: $error');
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
        duration: const Duration(seconds: 4),
      ),
    );
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

  String _formatDateForPrint(String dateString) {
    try {
      // Assuming the date is in dd/MM/yyyy format from API
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  String _formatAmount(String amount) {
    try {
      // Remove commas if present
      String cleanAmount = amount.replaceAll(',', '');
      double value = double.parse(cleanAmount);
      return value.toStringAsFixed(2);
    } catch (e) {
      return amount;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
    if (receiptRecords.isEmpty) {
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
      Sheet sheetObject = excel['Receipt Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Receipt No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Payment Mode';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Notes';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Amount';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < receiptRecords.length; i++) {
        final record = receiptRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = _formatDateForPrint(record.paidDate);
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.receiptNo;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.walletName;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = record.notes.isEmpty ? '-' : record.notes;
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = _formatAmount(record.paidAmount);
      }

      // Add total row
      if (totalAmount != null) {
        int lastRow = receiptRecords.length + 2;
        sheetObject.cell(CellIndex.indexByString("E$lastRow")).value = 'Total Amount';
        sheetObject.cell(CellIndex.indexByString("F$lastRow")).value = _formatAmount(totalAmount!);
        
        // Style the total row
        for (String cellName in ['E$lastRow', 'F$lastRow']) {
          var cell = sheetObject.cell(CellIndex.indexByString(cellName));
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#FFEB3B',
          );
        }
      }

      Directory? directory;
      String fileName = 'Receipt_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
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
    if (receiptRecords.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Receipt Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Receipt No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Payment Mode';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Notes';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Amount';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1', 'F1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < receiptRecords.length; i++) {
        final record = receiptRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = _formatDateForPrint(record.paidDate);
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.receiptNo;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.walletName;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = record.notes.isEmpty ? '-' : record.notes;
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = _formatAmount(record.paidAmount);
      }

      // Add total row
      if (totalAmount != null) {
        int lastRow = receiptRecords.length + 2;
        sheetObject.cell(CellIndex.indexByString("E$lastRow")).value = 'Total Amount';
        sheetObject.cell(CellIndex.indexByString("F$lastRow")).value = _formatAmount(totalAmount!);
        
        // Style the total row
        for (String cellName in ['E$lastRow', 'F$lastRow']) {
          var cell = sheetObject.cell(CellIndex.indexByString(cellName));
          cell.cellStyle = CellStyle(
            bold: true,
            backgroundColorHex: '#FFEB3B',
          );
        }
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Receipt_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
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
    if (receiptRecords.isEmpty) {
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
    if (receiptRecords.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Date', 'Receipt No', 'Payment Mode', 'Notes', 'Amount'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < receiptRecords.length; i++) {
        final record = receiptRecords[i];
        tableData.add([
          (i + 1).toString(),
          _formatDateForPrint(record.paidDate),
          record.receiptNo,
          record.walletName,
          record.notes.isEmpty ? '-' : record.notes,
          _formatAmount(record.paidAmount),
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
                  '${currentCustomerName ?? "Customer"} Receipt Report',
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
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerRight,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(60),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FlexColumnWidth(),
                  4: const pw.FlexColumnWidth(),
                  5: const pw.FixedColumnWidth(60),
                },
              ),

              // Footer with total
              if (totalAmount != null) pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Total Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 10),
                    pw.Text(_formatAmount(totalAmount!), 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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

  Widget _buildReceiptReport() {
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
                  currentCustomerName ?? 'Receipt Report',
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
          
          // Total Amount Card
          if (totalAmount != null) ...[
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
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    totalAmount!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Receipt Records List
          Expanded(
            child: receiptRecords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentCustomerName != null
                              ? 'No receipt records found for ${currentCustomerName}\nin the selected date range.'
                              : 'No receipt records found for the selected date range.',
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
                    itemCount: receiptRecords.length,
                    itemBuilder: (context, index) {
                      final record = receiptRecords[index];
                      return GestureDetector(
                        onTap: () => _navigateToReceiptView(record),
                        child: Container(
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
                                  InkWell(
                                    onTap: () => _navigateToReceiptView(record),
                                    child: Text(
                                      'No: ${record.receiptNo}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    record.paidDate,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                record.paidAmount,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildRecordItem('Payment Mode', record.walletName),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              ? 'Receipts - ${currentCustomerName}'
              : 'Receipt Report',
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
      body: isLoading ? const Center(child: CircularProgressIndicator()) : _buildReceiptReport(),
    );
  }
}

// Data Models
class ReceiptRecord {
  final int slNo;
  final String paidDate;
  final String receiptNo;
  final String rcpid;
  final String walletName;
  final String notes;
  final String paidAmount;

  ReceiptRecord({
    required this.slNo,
    required this.paidDate,
    required this.receiptNo,
    required this.rcpid,
    required this.walletName,
    required this.notes,
    required this.paidAmount,
  });

  factory ReceiptRecord.fromJson(Map<String, dynamic> json) {
    return ReceiptRecord(
      slNo: json['sl_no'] ?? 0,
      paidDate: json['paid_date'] ?? '',
      receiptNo: json['receipt_no'] ?? '',
      rcpid: json['rcpid'] ?? '',
      walletName: json['wallet_name'] ?? '',
      notes: json['notes'] ?? '',
      paidAmount: json['paid_amount'] ?? '',
    );
  }
}