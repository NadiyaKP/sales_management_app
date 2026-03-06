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
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../home_page.dart';
import '../report_page.dart';
import '../all_report_page.dart';
import '../receipts/receipt_view.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../../common/bottom_navigation_button.dart';
import 'package:permission_handler/permission_handler.dart';

class CommissionReport {
  final String date;
  final String receiptNo;
  final String rcpId;
  final CommissionCustomer customer;
  final String walletName;
  final String notes;
  final String paidAmount;
  
  CommissionReport({
    required this.date,
    required this.receiptNo,
    required this.customer,
    required this.walletName,
    required this.notes,
    required this.paidAmount,
    required this.rcpId,
  });
  
  factory CommissionReport.fromJson(Map<String, dynamic> json) {
    return CommissionReport(
      date: json['paid_date'] ?? '',
      receiptNo: json['receipt_no'] ?? '',
      customer: json["customer"] != null
          ? CommissionCustomer.fromJson(json["customer"])
          : CommissionCustomer(
              customerName: 'Unknown',
              address: 'N/A',
              phone: 'N/A',
              state: 'N/A',
              stateCode: 'N/A',
              gstNo: 'N/A',
            ),
      walletName: json['wallet_name'] ?? '',
      notes: json['notes'] ?? '',
      paidAmount: json['paid_amount'] ?? '',
      rcpId: json['rcpid'] ?? '',
    );
  }
}

class CommissionCustomer {
  final String customerName;
  final String address;
  final String gstNo;
  final String phone;
  final String state;
  final String stateCode;
  
  CommissionCustomer({
    required this.customerName,
    required this.address,
    required this.phone,
    required this.state,
    required this.stateCode,
    required this.gstNo,
  });
  
  factory CommissionCustomer.fromJson(Map<String, dynamic> json) {
    return CommissionCustomer(
      customerName: json['custname'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstNo: json['gst_no'] ?? '',
    );
  }
}

class CommissionReportPage extends StatefulWidget {
  const CommissionReportPage({Key? key}) : super(key: key);

  @override
  State<CommissionReportPage> createState() => _CommissionReportPageState();
}

class _CommissionReportPageState extends State<CommissionReportPage> {
  int _selectedIndex = 1; 
  String _selectedRoute = 'Choose';
  String? selectedRouteId;
  DateTime _fromDate = DateTime(2025, 5, 1);
  DateTime _toDate = DateTime(2025, 5, 20);
  
  // API and data variables
  List<CommissionReport> allCommissionReports = []; // Store all commission reports
  List<CommissionReport> filteredCommissionReport = []; // Store filtered commission reports
  String? totalAmount;
  String? commissionTotal;
  String? mainTitle;
  String? routeTitle;
  ApiServices apiServices = ApiServices();
  bool isLoading = false;
  
  List<String> routes = [];
  List<String> allRoutes = [];
  Map<String, String> routeIdMap = {};
  
  // Search functionality
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadRoutes();
    _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = DateTime.now();
    fetchCommission();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterCommissionReports() {
    if (searchQuery.isEmpty) {
      filteredCommissionReport = List.from(allCommissionReports);
    } else {
      filteredCommissionReport = allCommissionReports.where((report) {
        return report.customer.customerName
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.receiptNo
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.customer.phone
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.notes
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.walletName
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> loadRoutes() async {
    try {
      List<Map<String, String>> route = await apiServices.fetchRoutes();
      setState(() {
        routes = route.map((e) => e["route_name"]!).toList();
        allRoutes = ["Choose", ...routes];
        routeIdMap = {for (var e in route) e["route_name"]!: e["rtid"]!};
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> fetchCommission() async {
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
        Uri.parse('$url/commission-report.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "from_date": _formatDate(_fromDate),
          "to_date": _formatDate(_toDate),
          "route": selectedRouteId
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> commissionReportData = data['receipts'] ?? [];
          totalAmount = data['total_amount'];
          commissionTotal = data['commission'];
          mainTitle = data['hdr_name'];
          routeTitle = data['hdr_route_name'];
          
          setState(() {
            allCommissionReports = commissionReportData.map((json) => CommissionReport.fromJson(json)).toList();
            _filterCommissionReports(); 
          });
          
          if (commissionReportData.isEmpty) {
            _showError('No report data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch report.');
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

  // Check if permission handler is available
  Future<bool> _isPermissionHandlerAvailable() async {
    try {
      // Try to check a simple permission to see if plugin is available
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
      // Check if permission handler is available
      bool isAvailable = await _isPermissionHandlerAvailable();
      if (!isAvailable) {
        print('Permission handler not available, using internal storage');
        return false; // Will fallback to internal storage
      }

      if (Platform.isAndroid) {
        // Check Android version
        if (Platform.version.contains('API')) {
          // Extract API level if possible
          String version = Platform.version;
          print('Android version: $version');
        }

        // Try different permission approaches
        PermissionStatus status;
        
        
        try {
          status = await Permission.manageExternalStorage.status;
          if (status.isGranted) {
            return true;
          }
          
          status = await Permission.manageExternalStorage.request();
          if (status.isGranted) {
            return true;
          }
        } catch (e) {
          print('Manage external storage permission not available: $e');
        }
        
        // Fallback to regular storage permission
        try {
          status = await Permission.storage.status;
          if (status.isGranted) {
            return true;
          }
          
          status = await Permission.storage.request();
          if (status.isGranted) {
            return true;
          }
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
    if (filteredCommissionReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      // Check permissions
      bool hasPermission = await _checkStoragePermission();
      
      if (!hasPermission) {
        // Show dialog asking user to choose
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

      // Create Excel file
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Commission Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Receipt No';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Customer Name';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Wallet';

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
      for (int i = 0; i < filteredCommissionReport.length; i++) {
        final report = filteredCommissionReport[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = report.receiptNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = report.date;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = capitalizeWords(report.customer.customerName);
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = report.paidAmount;
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = report.walletName;
      }

      // Try to save to Downloads folder
      Directory? directory;
      String fileName = 'Commission_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
      if (Platform.isAndroid) {
        // Try multiple download directories
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
              // Test write permission
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
        
        // If no Downloads folder works, try external storage directory
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
      
      // Save file
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      
      // Verify file was created
      if (await file.exists()) {
        String locationMsg = directory.path.contains('Download') 
            ? 'Downloads folder' 
            : 'External storage';
        _showSuccess('Excel file saved to $locationMsg');
        
        // Try to open the file
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

  // Export to app's internal storage (always works, no permissions needed)
  Future<void> _exportToExcelInternal() async {
    if (filteredCommissionReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      // Create Excel workbook
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Commission Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Receipt No';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Customer Name';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Amount';
      sheetObject.cell(CellIndex.indexByString("F1")).value = 'Wallet';

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
      for (int i = 0; i < filteredCommissionReport.length; i++) {
        final report = filteredCommissionReport[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = report.receiptNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = report.date;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = capitalizeWords(report.customer.customerName);
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = report.paidAmount;
        sheetObject.cell(CellIndex.indexByString("F$rowIndex")).value = report.walletName;
      }

      // Use app's internal directory (no permissions needed)
      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Commission_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      String filePath = '${directory.path}/$fileName';
      
      // Save file
      File file = File(filePath);
      await file.writeAsBytes(excel.encode()!);
      
      _showSuccess('Excel file saved to app storage');
      
      // Try to open the file
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
    if (filteredCommissionReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    // Show loading indicator
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
      // Check if we can use external storage
      bool canUseExternal = await _checkStoragePermission();
      
      // Dismiss loading dialog
      Navigator.of(context).pop();
      
      if (canUseExternal) {
        // Use external storage
        await _exportToExcelExternal();
      } else {
        // Use internal storage
        await _exportToExcelInternal();
      }
    } catch (e) {
      // Dismiss loading dialog
      Navigator.of(context).pop();
      _showError('Export failed: $e');
    }
  }

  // Print Functionality
  Future<void> _printReport() async {
    if (filteredCommissionReport.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Receipt No', 'Date', 'Customer Name', 'Amount', 'Wallet'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < filteredCommissionReport.length; i++) {
        final report = filteredCommissionReport[i];
        tableData.add([
          (i + 1).toString(),
          report.receiptNo,
          report.date,
          capitalizeWords(report.customer.customerName),
          report.paidAmount,
          report.walletName,
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
                  'Commission Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              
              // Company name and route if available
              if (mainTitle != null && mainTitle!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    mainTitle!,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              
              if (routeTitle != null && routeTitle!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    routeTitle!,
                    style: const pw.TextStyle(fontSize: 14),
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
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(80),
                  3: const pw.FlexColumnWidth(),
                  4: const pw.FixedColumnWidth(60),
                  5: const pw.FixedColumnWidth(60),
                },
              ),

              // Footer with total count
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Receipts: ${filteredCommissionReport.length}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (totalAmount != null)
                      pw.Text(
                        'Total Amount: $totalAmount',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Print the document
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showError('Failed to print: $e');
    }
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
      fetchCommission(); // Fetch data when date changes
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
  
  // Search dialog similar to sales page
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
              hintText: 'Enter customer name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchController.clear();
              setState(() {
                searchQuery = '';
              });
              _filterCommissionReports();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
              });
              Navigator.of(context).pop();
              _filterCommissionReports();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
  
  double _calculateTotalReceived() {
    if (totalAmount == null || totalAmount!.isEmpty) return 0.0;
    return double.tryParse(totalAmount!) ?? 0.0;
  }

  double _calculateCommissionTotal() {
    if (commissionTotal == null || commissionTotal!.isEmpty) return 0.0;
    return double.tryParse(commissionTotal!) ?? 0.0;
  }

  String capitalizeWords(String text) {
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
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
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: const Text(
          'Commission Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AllReportPage()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter controls row
                  Row(
  children: [
    // Routes Dropdown
    Expanded(
      flex: 3, // Balanced flex for routes
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Routes', 
            style: TextStyle(fontSize: 11, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8), 
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedRoute,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(fontSize: 12, color: Colors.black), 
                items: allRoutes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRoute = newValue!;
                    selectedRouteId = newValue == "Routes" ? null : routeIdMap[newValue];
                  });
                  fetchCommission();
                },
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(width: 6), 
    // From Date
    Expanded(
      flex: 4, // More space for dates
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('From Date', 
            style: TextStyle(fontSize: 11, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
          InkWell(
            onTap: () => _selectDate(context, true),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
              width: double.infinity,
              child: Text(
                DateFormat('dd-MM-yyyy').format(_fromDate),
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
      flex: 4, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('To Date', 
            style: TextStyle(fontSize: 11, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
          ),
          InkWell(
            onTap: () => _selectDate(context, false),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), 
              width: double.infinity,
              child: Text(
                DateFormat('dd-MM-yyyy').format(_toDate),
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
                  
                  // Main title and route title
                  if (mainTitle != null && mainTitle!.isNotEmpty) ...[
                    Text(
                      mainTitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  
                  if (routeTitle != null && routeTitle!.isNotEmpty) ...[
                    Text(
                      routeTitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Search results count
                  if (searchQuery.isNotEmpty) ...[
                    Text(
                      'Found ${filteredCommissionReport.length} results for "$searchQuery"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Total Received Card (only show when not searching)
            if (searchQuery.isEmpty) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            totalAmount?.isNotEmpty == true ? totalAmount! : "No Data",
                            style: TextStyle(
                              fontSize:18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Commission',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            commissionTotal?.isNotEmpty == true ? commissionTotal! : "No Data",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Receipt List
            Expanded(
              child: filteredCommissionReport.isEmpty
                  ? Center(
                      child: Text(
                        searchQuery.isNotEmpty
                            ? 'No commission records found for "$searchQuery"'
                            : 'No reports available for the selected date range.',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredCommissionReport.length,
                      itemBuilder: (context, index) {
                        final report = filteredCommissionReport[index];
                        final isOdd = index % 2 != 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                          decoration: BoxDecoration(
                            color: isOdd ? Colors.grey.shade100 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                            
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReceiptViewPage(rcpId: report.rcpId),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        report.receiptNo,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      report.date,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            capitalizeWords(report.customer.customerName),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                          if (report.customer.phone.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              report.customer.phone,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ],
                                          if (report.customer.address.isNotEmpty) ...[
                                            Text(capitalizeWords(report.customer.address),style: TextStyle(fontSize: 12),),
                                          ],
                                          if (report.customer.gstNo.isNotEmpty) ...[
                                            Text('GST No: ${report.customer.gstNo}',style: TextStyle(fontSize: 12),),
                                          ],
                                          Text('${report.customer.state}, ${report.customer.stateCode}'),
                                          Text('Notes: ${report.notes}',style: TextStyle(fontSize: 12),),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          report.paidAmount,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        Text(
                                          report.walletName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.teal,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0, 
      ),
    );
  }
}