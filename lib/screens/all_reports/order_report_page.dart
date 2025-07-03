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
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../order/view_order.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../common/bottom_navigation_button.dart';

// Order Report Model Classes
class OrderReport {
  final OrderCustomer customer;
  final String date;
  final String orderNo;
  final String ordId;
  
  OrderReport({
    required this.customer,
    required this.date,
    required this.orderNo,
    required this.ordId,
  });
  
  factory OrderReport.fromJson(Map<String, dynamic> json) {
    return OrderReport(
      date: json['order_date'] ?? '',
      orderNo: json['order_no'] ?? '',
      customer: json["customer_name"] != null
          ? OrderCustomer.fromJson(json["customer_name"])
          : OrderCustomer(
              customerName: 'Unknown',
              address: 'N/A',
              phone: 'N/A',
              state: 'N/A',
              stateCode: 'N/A',
              gstNo: 'N/A',
            ),
      ordId: json['ordid'] ?? '',
    );
  }
}

class OrderCustomer {
  final String customerName;
  final String address;
  final String gstNo;
  final String phone;
  final String state;
  final String stateCode;
  
  OrderCustomer({
    required this.customerName,
    required this.address,
    required this.phone,
    required this.state,
    required this.stateCode,
    required this.gstNo,
  });
  
  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      customerName: json['custname'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstNo: json['gst_no'] ?? '',
    );
  }
}

class OrderReportPage extends StatefulWidget {
  const OrderReportPage({Key? key}) : super(key: key);

  @override
  State<OrderReportPage> createState() => _OrderReportPageState();
}

class _OrderReportPageState extends State<OrderReportPage> {
  int _selectedIndex = 1;
  String _selectedRoute = 'Routes';
  String? selectedRouteId;
  DateTime _fromDate = DateTime(2025, 4, 1);
  DateTime _toDate = DateTime(2025, 5, 21);

  List<String> _routes = ['Routes'];
  List<String> allRoutes = [];
  Map<String, String> routeIdMap = {};
  
  // Search functionality - similar to sales page
  List<OrderReport> allOrderReports = []; // Store all order reports
  List<OrderReport> _filteredOrderData = []; // Store filtered order reports
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  
  String? mainTitle;
  String? routeTitle;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadRoutes();
    _setInitialDates();
    fetchOrderReport();
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

  // Filter order reports based on search query
  void _filterOrderReports() {
    if (searchQuery.isEmpty) {
      _filteredOrderData = List.from(allOrderReports);
    } else {
      _filteredOrderData = allOrderReports.where((report) {
        return report.customer.customerName
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.orderNo
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.customer.phone
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
      }).toList();
    }
  }

  // Load routes from API using the same approach as the original file
  Future<void> loadRoutes() async {
    try {
      final apiServices = ApiServices();
      List<Map<String, String>> routes = await apiServices.fetchRoutes();
      
      setState(() {
        _routes = routes.map((e) => e["route_name"]!).toList();
        allRoutes = ["Routes", ..._routes];
        routeIdMap = {for (var e in routes) e["route_name"]!: e["rtid"]!};
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  // Fetch order report from API with proper route filtering
  Future<void> fetchOrderReport() async {
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
        Uri.parse('$url/order-report.php'),
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
          final List<dynamic> orderReport = data['orders'] ?? [];
          setState(() {
            mainTitle = data['hdr_name'];
            routeTitle = data['hdr_route_name'];
            allOrderReports = orderReport.map((json) => OrderReport.fromJson(json)).toList();
            _filterOrderReports(); // Apply current search filter
          });
          
          if (orderReport.isEmpty) {
            _showError('No order report data found for the selected criteria');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch orders.');
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
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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
    if (_filteredOrderData.isEmpty) {
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
      Sheet sheetObject = excel['Order Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Order No';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Customer Name';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < _filteredOrderData.length; i++) {
        final order = _filteredOrderData[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = order.orderNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = order.date;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = capitalizeWords(order.customer.customerName);
      }

      // Try to save to Downloads folder
      Directory? directory;
      String fileName = 'Order_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
      
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
    if (_filteredOrderData.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      // Create Excel workbook
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Order Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Order No';
      sheetObject.cell(CellIndex.indexByString("C1")).value = 'Date';
      sheetObject.cell(CellIndex.indexByString("D1")).value = 'Customer Name';

      // Style headers
      for (String cellName in ['A1', 'B1', 'C1', 'D1']) {
        var cell = sheetObject.cell(CellIndex.indexByString(cellName));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#4CAF50',
          fontColorHex: '#FFFFFF',
        );
      }

      // Add data rows
      for (int i = 0; i < _filteredOrderData.length; i++) {
        final order = _filteredOrderData[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = order.orderNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = order.date;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = capitalizeWords(order.customer.customerName);
      }

      // Use app's internal directory (no permissions needed)
      Directory directory = await getApplicationDocumentsDirectory();
      String fileName = 'Order_Report_${DateFormat('dd_MM_yyyy_HH_mm_ss').format(DateTime.now())}.xlsx';
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
    if (_filteredOrderData.isEmpty) {
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
    if (_filteredOrderData.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Order No', 'Date', 'Customer Name'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < _filteredOrderData.length; i++) {
        final order = _filteredOrderData[i];
        tableData.add([
          (i + 1).toString(),
          order.orderNo,
          order.date,
          capitalizeWords(order.customer.customerName),
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
                  'Order Report',
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
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FixedColumnWidth(120),
                  2: const pw.FixedColumnWidth(100),
                  3: const pw.FlexColumnWidth(),
                },
              ),

              // Footer with total count
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Text(
                  'Total Orders: ${_filteredOrderData.length}',
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
      fetchOrderReport();
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
              hintText: 'Enter customer name, order no, or phone'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchController.clear();
              setState(() {
                searchQuery = '';
              });
              _filterOrderReports();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
              });
              Navigator.of(context).pop();
              _filterOrderReports();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
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
          'Order Report',
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
                  fetchOrderReport();
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
                      'Found ${_filteredOrderData.length} results for "$searchQuery"',
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
            Expanded(
              child: _filteredOrderData.isEmpty
                  ? Center(
                      child: Text(
                        searchQuery.isNotEmpty
                            ? 'No order records found for "$searchQuery"'
                            : 'No order reports available for the selected date range and route.',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredOrderData.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrderData[index];
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
                                        // Navigate to order details - Fixed line
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => ViewOrderPage(orderId: order.ordId)));
                                      },
                                      child: Text(
                                        'Order No: ${order.orderNo}',
                                        style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      order.date,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  capitalizeWords(order.customer.customerName),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (order.customer.phone.isNotEmpty) ...[
                                  Text(
                                    order.customer.phone,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (order.customer.address.isNotEmpty) ...[
                                  Text(
                                    capitalizeWords(order.customer.address),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                if (order.customer.gstNo.isNotEmpty) ...[
                                  Text(
                                    'GST No: ${order.customer.gstNo}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  '${order.customer.state}, ${order.customer.stateCode}',
                                  style: const TextStyle(fontSize: 14),
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
        selectedIndex: 1, // Home page is at index 0
      ),
    );
  }
}