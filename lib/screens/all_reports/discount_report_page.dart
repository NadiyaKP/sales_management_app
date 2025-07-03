import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../home_page.dart';
import '../report_page.dart';
import '../all_report_page.dart';
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
import '../../common/bottom_navigation_button.dart';

// Data models from discountreport.dart
class DiscountsReport {
  final String date;
  final String transactionType;
  final DiscountsCustomer customer;
  final String givenAmount;
  final String notes;
  final String receivedAmount;
  
  DiscountsReport({
    required this.date,
    required this.transactionType,
    required this.customer,
    required this.givenAmount,
    required this.notes,
    required this.receivedAmount,
  });
  
  factory DiscountsReport.fromJson(Map<String, dynamic> json) {
    return DiscountsReport(
      date: json['discount_date'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      customer: json["customer"] != null
          ? DiscountsCustomer.fromJson(json["customer"])
          : DiscountsCustomer(
              customerName: 'Unknown',
              address: 'N/A',
              phone: 'N/A',
              state: 'N/A',
              stateCode: 'N/A',
              gstNo: 'N/A',
            ),
      givenAmount: json['given_amount'] ?? '',
      notes: json['notes'] ?? '',
      receivedAmount: json['received_amount'] ?? '',
    );
  }
}

class DiscountsCustomer {
  final String customerName;
  final String address;
  final String gstNo;
  final String phone;
  final String state;
  final String stateCode;
  
  DiscountsCustomer({
    required this.customerName,
    required this.address,
    required this.phone,
    required this.state,
    required this.stateCode,
    required this.gstNo,
  });
  
  factory DiscountsCustomer.fromJson(Map<String, dynamic> json) {
    return DiscountsCustomer(
      customerName: json['custname'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstNo: json['gst_no'] ?? '',
    );
  }
}

class DiscountTotal {
  final String totalGivenAmount;
  final String totalReceivedAmount;
  
  DiscountTotal({
    required this.totalGivenAmount,
    required this.totalReceivedAmount,
  });
  
  factory DiscountTotal.fromJson(Map<String, dynamic> json) {
    return DiscountTotal(
      totalGivenAmount: json['total_given_amount'] ?? '',
      totalReceivedAmount: json['total_received_amount'] ?? '',
    );
  }
}

class DiscountReportPage extends StatefulWidget {
  const DiscountReportPage({Key? key}) : super(key: key);

  @override
  State<DiscountReportPage> createState() => _DiscountReportPageState();
}

class _DiscountReportPageState extends State<DiscountReportPage> {
  int _selectedIndex = 1;
  String _selectedRoute = 'Routes';
  String? selectedRouteId;
  DateTime _fromDate = DateTime(2025, 4, 1);
  DateTime _toDate = DateTime(2025, 5, 21);

  List<String> _routes = ['Routes'];
  List<String> allRoutes = [];
  Map<String, String> routeIdMap = {};

  // API related variables
  List<DiscountsReport> allDiscountReports = []; // Store all discount reports
  List<DiscountsReport> filteredDiscountReport = []; // Store filtered discount reports
  DiscountTotal? discountTotal;
  String? mainTitle;
  String? routeTitle;
  ApiServices apiServices = ApiServices();
  bool isLoading = false;

  // Search functionality - similar to sales page
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadRoutes();
    _setInitialDates();
    fetchDiscountReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setInitialDates() {
    _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _toDate = DateTime.now();
  }

  void _filterDiscountReports() {
    if (searchQuery.isEmpty) {
      filteredDiscountReport = List.from(allDiscountReports);
    } else {
      filteredDiscountReport = allDiscountReports.where((report) {
        return report.customer.customerName
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.transactionType
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.customer.phone
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.notes
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  Future<void> loadRoutes() async {
    try {
      List<Map<String, String>> route = await apiServices.fetchRoutes();
      setState(() {
        _routes = route.map((e) => e["route_name"]!).toList();
        allRoutes = ["Routes", ..._routes];
        routeIdMap = {for (var e in route) e["route_name"]!: e["rtid"]!};
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  // API Methods from discountreport.dart
  Future<void> fetchDiscountReport() async {
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
        Uri.parse('$url/discount-report.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "from_date": DateFormat('dd-MM-yyyy').format(_fromDate),
          "to_date": DateFormat('dd-MM-yyyy').format(_toDate),
          "route": selectedRouteId
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> discountReport = data['discounts'] ?? [];
          final dynamic discountsTotalData = data['totals'];
          mainTitle = data['hdr_name'];
          routeTitle = data['hdr_route_name'];
          
          setState(() {
            allDiscountReports = discountReport.map((json) => DiscountsReport.fromJson(json)).toList();
            _filterDiscountReports(); // Apply current search filter
            
            if (discountsTotalData is Map) {
              discountTotal = DiscountTotal.fromJson(Map<String, dynamic>.from(discountsTotalData));
            } else {
              discountTotal = null;
            }
          });
          
          if (discountReport.isEmpty) {
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
        
        // First try manage external storage (Android 11+)
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
        // iOS doesn't need storage permissions for app documents
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
    if (filteredDiscountReport.isEmpty) {
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
      Sheet sheetObject = excel['Discount Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Customer Name';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Transaction Type';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Discount Value';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < filteredDiscountReport.length; i++) {
        final discount = filteredDiscountReport[i];
        final rowIndex = i + 2;
        final discountValue = formatDiscountValue(discount.givenAmount, discount.receivedAmount);
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = discount.date;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = capitalizeWords(discount.customer.customerName);
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = discount.transactionType;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = discountValue;
      }

      // Try to save to Downloads folder
      Directory? directory;
      String fileName = 'Discount_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
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
    if (filteredDiscountReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      // Create Excel workbook
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Discount Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Customer Name';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Transaction Type';
      sheetObject.cell(CellIndex.indexByString("E1")).value = 'Discount Value';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1', 'E1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < filteredDiscountReport.length; i++) {
        final discount = filteredDiscountReport[i];
        final rowIndex = i + 2;
        final discountValue = formatDiscountValue(discount.givenAmount, discount.receivedAmount);
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = discount.date;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = capitalizeWords(discount.customer.customerName);
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = discount.transactionType;
        sheetObject.cell(CellIndex.indexByString("E$rowIndex")).value = discountValue;
      }

      // Use app's internal directory (no permissions needed)
      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Discount_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
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
    if (filteredDiscountReport.isEmpty) {
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
    if (filteredDiscountReport.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Date', 'Customer Name', 'Transaction Type', 'Discount Value'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < filteredDiscountReport.length; i++) {
        final discount = filteredDiscountReport[i];
        final discountValue = formatDiscountValue(discount.givenAmount, discount.receivedAmount);
        
        tableData.add([
          (i + 1).toString(),
          discount.date,
          capitalizeWords(discount.customer.customerName),
          discount.transactionType,
          discountValue,
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
                  'Discount Report',
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
                  'Period: ${DateFormat('dd-MM-yyyy').format(_fromDate)} to ${DateFormat('dd-MM-yyyy').format(_toDate)}',
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
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FlexColumnWidth(),
                  3: const pw.FixedColumnWidth(100),
                  4: const pw.FixedColumnWidth(80),
                },
              ),

              // Footer with totals if available
              if (discountTotal != null && searchQuery.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 16),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Discount Received: ${discountTotal!.totalReceivedAmount}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                      pw.Text(
                        'Total Discount Allowed: ${discountTotal!.totalGivenAmount}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                ),

              // Footer with total count
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Text(
                  'Total Records: ${filteredDiscountReport.length}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
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
            colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
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
      fetchDiscountReport(); // Refresh data when date changes
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ReportPage()));
    } else if (index == 3) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
              _filterDiscountReports();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
              });
              Navigator.of(context).pop();
              _filterDiscountReports();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  String formatDiscountValue(String allowed, String receivable) {
    if (allowed.isNotEmpty && allowed != "0") {
      return "-$allowed";
    } else if (receivable.isNotEmpty && receivable != "0") {
      return "+$receivable";
    }
    return "0";
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AllReportPage()));
          },
        ),
        title: const Text(
          'Discount Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
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
            // Header filter UI
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
            padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced padding
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedRoute,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                style: const TextStyle(fontSize: 12, color: Colors.black), // Smaller font
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
                  fetchDiscountReport();
                },
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(width: 6), // Reduced spacing
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Reduced horizontal padding
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
    const SizedBox(width: 6), // Reduced spacing
    // To Date
    Expanded(
      flex: 4, // More space for dates
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Reduced horizontal padding
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
                        icon: const Icon(Icons.file_download, size: 14),
                        label: const Text('Excel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800], // Dark green color
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Smaller padding
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _printReport,
                        icon: const Icon(Icons.print, size: 14),
                        label: const Text('Print'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor, // Using app primary color
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // Smaller padding
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  if (mainTitle != null && mainTitle!.isNotEmpty) ...[
                    Text(
                      mainTitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (routeTitle != null && routeTitle!.isNotEmpty) ...[
                    Text(
                      routeTitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Search results count
                  if (searchQuery.isNotEmpty) ...[
                    Text(
                      'Found ${filteredDiscountReport.length} results for "$searchQuery"',
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
            // Summary totals (only show when not searching)
            if (discountTotal != null && searchQuery.isEmpty)
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
                          const Text('Discount Received:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          Text(
                            discountTotal!.totalReceivedAmount,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount Allowed:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                          Text(
                            discountTotal!.totalGivenAmount,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            // List of filtered discounts
            Expanded(
              child: filteredDiscountReport.isEmpty
                  ? Center(
                      child: Text(
                        searchQuery.isNotEmpty
                            ? 'No discount records found for "$searchQuery"'
                            : 'No discount records in the selected date range.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filteredDiscountReport.length,
                      itemBuilder: (context, index) {
                        final report = filteredDiscountReport[index];
                        final discountValue = formatDiscountValue(report.givenAmount, report.receivedAmount);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
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
                                    Text(report.transactionType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                    Text(report.date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  capitalizeWords(report.customer.customerName),
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.blue.shade700),
                                ),
                                const SizedBox(height: 4),
                                if (report.customer.phone.isNotEmpty)
                                  Text(report.customer.phone),
                                if (report.customer.address.isNotEmpty)
                                  Text(capitalizeWords(report.customer.address)),
                                if (report.customer.gstNo.isNotEmpty)
                                  Text('GST No: ${report.customer.gstNo}'),
                                Text('${report.customer.state},${report.customer.stateCode}'),
                                if (report.notes.isNotEmpty)
                                  Text('Notes: ${report.notes}'),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      discountValue,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: discountValue.startsWith('+') ? Colors.green : Colors.red,
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
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 1, // Reports page is at index 1
      ),
    );
  }
}