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
  
  List<AgedReceivableRecord> agedReceivableRecords = [];
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
    
    // Initialize controllers with formatted dates
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
    });
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _showError('Missing configuration data. Please check your settings.');
        return;
      }

      // Prepare the request body
      final requestBody = {
        "unid": unid,
        "slex": slex,
        "customer_name": _customerName,
        "custid": _custId,
        "from_date": _fromDateController.text,
        "to_date": _toDateController.text,
        "style": "aged",
      };

      final response = await http.post(
        Uri.parse('$url/account-ledger.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> agedReceivablesList = data['agedcartdet'] ?? [];
          
          setState(() {
            agedReceivableRecords = agedReceivablesList
                .map((json) => AgedReceivableRecord.fromJson(json))
                .toList();
            headerTitle = data['hdr_name'];
          });
          
          if (agedReceivablesList.isEmpty) {
            _showError('No aged receivable records found for $_customerName in the selected date range');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch aged receivable data.');
        }
      } else {
        _showError('Server error: ${response.statusCode}. Please try again later.');
      }
    } catch (error) {
      _showError('Network error occurred. Please check your connection and try again.');
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
    if (agedReceivableRecords.isEmpty) {
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
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Invoice Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Invoice No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Description';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Outstanding Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Days Outstanding';

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
      for (int i = 0; i < agedReceivableRecords.length; i++) {
        final record = agedReceivableRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = record.invoiceDate;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.invoiceNumber;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.description;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = formatCurrencyForPrint(record.outstandingAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = record.daysOutstanding;
      }

      // Add summary row
      final summaryRow = agedReceivableRecords.length + 2;
      sheetObject.cell(CellIndex.indexByString("A$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("B$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("C$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("D$summaryRow")).value = 'Total Outstanding:';
      sheetObject.cell(CellIndex.indexByString("E$summaryRow")).value = formatCurrencyForPrint(
        agedReceivableRecords.fold(0.0, (sum, record) {
          return sum + (double.tryParse(record.outstandingAmount.replaceAll(',', '')) ?? 0.0);
        }).toString()
      );
      sheetObject.cell(CellIndex.indexByString("F$summaryRow")).value = '';

      // Style summary row
      for (String cellName in ['A$summaryRow', 'B$summaryRow', 'C$summaryRow', 'D$summaryRow', 'E$summaryRow', 'F$summaryRow']) {
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

  // Export to app's internal storage
  Future<void> _exportToExcelInternal() async {
    if (agedReceivableRecords.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Aged Receivable Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Invoice Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Invoice No';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Description';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Outstanding Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Days Outstanding';

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
      for (int i = 0; i < agedReceivableRecords.length; i++) {
        final record = agedReceivableRecords[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = record.invoiceDate;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = record.invoiceNumber;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = record.description;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = formatCurrencyForPrint(record.outstandingAmount);
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = record.daysOutstanding;
      }

      // Add summary row
      final summaryRow = agedReceivableRecords.length + 2;
      sheetObject.cell(CellIndex.indexByString("A$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("B$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("C$summaryRow")).value = '';
      sheetObject.cell(CellIndex.indexByString("D$summaryRow")).value = 'Total Outstanding:';
      sheetObject.cell(CellIndex.indexByString("E$summaryRow")).value = formatCurrencyForPrint(
        agedReceivableRecords.fold(0.0, (sum, record) {
          return sum + (double.tryParse(record.outstandingAmount.replaceAll(',', '')) ?? 0.0);
        }).toString()
      );
      sheetObject.cell(CellIndex.indexByString("F$summaryRow")).value = '';

      // Style summary row
      for (String cellName in ['A$summaryRow', 'B$summaryRow', 'C$summaryRow', 'D$summaryRow', 'E$summaryRow', 'F$summaryRow']) {
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

  // Main export method - chooses the best option automatically
  Future<void> _exportToExcel() async {
    if (agedReceivableRecords.isEmpty) {
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
    if (agedReceivableRecords.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Calculate total outstanding
      double totalOutstanding = agedReceivableRecords.fold(0.0, (sum, record) {
        return sum + (double.tryParse(record.outstandingAmount.replaceAll(',', '')) ?? 0.0);
      });

      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Invoice Date', 'Invoice No', 'Description', 'Outstanding Amount', 'Days Outstanding'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < agedReceivableRecords.length; i++) {
        final record = agedReceivableRecords[i];
        tableData.add([
          (i + 1).toString(),
          record.invoiceDate,
          record.invoiceNumber,
          record.description,
          formatCurrencyForPrint(record.outstandingAmount),
          record.daysOutstanding.toString(),
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
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FixedColumnWidth(120),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FixedColumnWidth(50),
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
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Outstanding Amount:', 
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.Text(formatCurrencyForPrint(totalOutstanding.toString()), 
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

  Color _getAgeColor(int days) {
    if (days <= 30) {
      return Colors.green;
    } else if (days <= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
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
      body: SingleChildScrollView(
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                         
                        ),
                        child: TextField(
                          controller: _fromDateController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _fromDateController, true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          
                        ),
                        child: TextField(
                          controller: _toDateController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
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
                  icon: const Icon(Icons.file_download, size: 14),
                  label: const Text('Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.print, size: 14),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Report Title  
            Center(
              child: Text(
                headerTitle?.replaceAll('&amp;', '&') ?? 
                'Aged Receivable Report From ${_fromDateController.text} To ${_toDateController.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Loading indicator or aged receivable records
            if (isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading aged receivable data...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else if (agedReceivableRecords.isEmpty)
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
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_fromDateController.text} to ${_toDateController.text}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchAgedReceivableData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              // Aged Receivable Records List
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aged Receivable Records (${agedReceivableRecords.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...agedReceivableRecords.map((record) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                     
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Invoice #${record.invoiceNumber}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                record.invoiceDate,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Outstanding Amount:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '₹${record.outstandingAmount}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Days Outstanding:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getAgeColor(record.daysOutstanding).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${record.daysOutstanding} days',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _getAgeColor(record.daysOutstanding),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (record.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Description:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                             
                            ),
                            child: Text(
                              record.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )).toList(),
                ],
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Data Model for Aged Receivable Record
class AgedReceivableRecord {
  final int slNo;
  final String invoiceDate;
  final String invoiceNumber;
  final String description;
  final String outstandingAmount;
  final int daysOutstanding;

  AgedReceivableRecord({
    required this.slNo,
    required this.invoiceDate,
    required this.invoiceNumber,
    required this.description,
    required this.outstandingAmount,
    required this.daysOutstanding,
  });

  factory AgedReceivableRecord.fromJson(Map<String, dynamic> json) {
    return AgedReceivableRecord(
      slNo: json['sl_no'] ?? 0,
      invoiceDate: json['invoice_date'] ?? '',
      invoiceNumber: json['invoice_number'] ?? '',
      description: json['description'] ?? '',
      outstandingAmount: json['outstanding_amount'] ?? '0.00',
      daysOutstanding: json['days_outstanding'] ?? 0,
    );
  }
}