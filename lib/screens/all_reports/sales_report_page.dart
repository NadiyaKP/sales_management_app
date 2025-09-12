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
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../home_page.dart';
import '../report_page.dart';
import '../all_report_page.dart';
import '../invoice/invoice_view.dart';
import '../../common/bottom_navigation_button.dart';
import 'package:permission_handler/permission_handler.dart';

// Data Models
class SalesReport {
  final String date;
  final String invoiceNo;
  final String invId;
  final SalesCustomer customer;
  final String beforeGst;
  final String gstAmount;
  final String keralaFloodCess;
  final String discountAmount;
  final String roundOff;
  final String totalAmount;

  SalesReport({
    required this.date,
    required this.invoiceNo,
    required this.customer,
    required this.beforeGst,
    required this.gstAmount,
    required this.keralaFloodCess,
    required this.discountAmount,
    required this.roundOff,
    required this.totalAmount,
    required this.invId,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      date: json['invoice_date'] ?? '',
      invoiceNo: json['invoice_no'] ?? '',
      customer: json["customer"] != null
          ? SalesCustomer.fromJson(json["customer"])
          : SalesCustomer(
              customerName: 'Unknown',
              address: 'N/A',
              phone: 'N/A',
              state: 'N/A',
              stateCode: 'N/A',
              gstNo: 'N/A',
            ),
      beforeGst: json['before_gst'] ?? '',
      gstAmount: json['gst_amount'] ?? '',
      keralaFloodCess: json['cess_amount'] ?? '',
      discountAmount: json['discount_amount'] ?? '',
      roundOff: json['roundoff'] ?? '',
      totalAmount: json['total_amount'] ?? '',
      invId: json['invid'] ?? '',
    );
  }
}

class SalesCustomer {
  final String customerName;
  final String address;
  final String gstNo;
  final String phone;
  final String state;
  final String stateCode;

  SalesCustomer({
    required this.customerName,
    required this.address,
    required this.phone,
    required this.state,
    required this.stateCode,
    required this.gstNo,
  });

  factory SalesCustomer.fromJson(Map<String, dynamic> json) {
    return SalesCustomer(
      customerName: json['custname'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstNo: json['gst_no'] ?? '',
    );
  }
}

class SalesTotal {
  final String beforeTax;
  final String gstAmount;
  final String cessAmount;
  final String discountAmount;
  final String roundOff;
  final String totalAmount;
  final String cgstAmount;
  final String sgstAmount;
  final String igstAmount;

  SalesTotal({
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

  factory SalesTotal.fromJson(Map<String, dynamic> json) {
    return SalesTotal(
      beforeTax: json['before_tax'] ?? '',
      gstAmount: json['gst_amount'] ?? '',
      cessAmount: json['cess_amount'] ?? '',
      discountAmount: json['discount_amount'] ?? '',
      roundOff: json['roundoff'] ?? '',
      totalAmount: json['total_amount'] ?? '',
      cgstAmount: json['cgst_amount'] ?? '',
      sgstAmount: json['sgst_amount'] ?? '',
      igstAmount: json['igst_amount'] ?? '',
    );
  }
}

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({Key? key}) : super(key: key);

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  int _selectedIndex = 1;
  String _selectedRoute = 'Routes';
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  
  List<String> routes = [];
  String? selectedRouteId;
  List<String> allRoutes = [];
  Map<String, String> routeIdMap = {};
  
  List<SalesReport> allSalesReports = []; // Store all sales reports
  List<SalesReport> filteredSaleReport = []; // Store filtered sales reports
  SalesTotal? filteredSaleTotal;
  String? mainTitle;
  String? routeTitle;
  
  // Search functionality
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  
  ApiServices apiServices = ApiServices();
  bool isLoading = false;
  
  // Permission variables
  String salesReport = '';
  String salesDetail = '';
  String salesOther = '';
  
  @override
  void initState() {
    super.initState();
    _loadPermissions();
    loadRoutes();
    fetchSalesReport();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterSalesReports() {
    if (searchQuery.isEmpty) {
      filteredSaleReport = List.from(allSalesReports);
    } else {
      filteredSaleReport = allSalesReports.where((report) {
        return report.customer.customerName
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.invoiceNo
            .toLowerCase()
            .contains(searchQuery.toLowerCase()) ||
            report.customer.phone
            .toLowerCase()
            .contains(searchQuery.toLowerCase());
      }).toList();
    }
  }
  
  Future<void> fetchSalesReport() async {
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
        Uri.parse('$url/sales-report.php'),
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
          final List<dynamic> saleReport = data['invoice_details'] ?? [];
          final dynamic saleTotalData = data['totals'];
          mainTitle = data['hdr_name'];
          routeTitle = data['hdr_route_name'];
          
          setState(() {
            allSalesReports = saleReport.map((json) => SalesReport.fromJson(json)).toList();
            _filterSalesReports(); // Apply current search filter
            if (saleTotalData is Map) {
              filteredSaleTotal = SalesTotal.fromJson(Map<String, dynamic>.from(saleTotalData));
            } else {
              filteredSaleTotal = null;
            }
          });
          
          if (saleReport.isEmpty) {
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
  
  Future<void> loadRoutes() async {
    try {
      List<Map<String, String>> route = await apiServices.fetchRoutes();
      setState(() {
        routes = route.map((e) => e["route_name"]!).toList();
        allRoutes = ["Routes", ...routes];
        routeIdMap = {for (var e in route) e["route_name"]!: e["rtid"]!};
      });
    } catch (e) {
      _showError(e.toString());
    }
  }
  
  Future<PermissionResponse> _fetchPermissions() async {
    try {
      final apiService = ApiServices();
      final permissionData = await apiService.fetchPermissionDetails();

      if (permissionData == null) {
        throw Exception('Failed to fetch permissions: Data is null.');
      }

      if (permissionData.permissionDetails.isEmpty) {
        throw Exception('Received empty permissions data from the API.');
      }

      return permissionData;
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
      rethrow;
    }
  }
  
  Future<void> _loadPermissions() async {
    try {
      final permissionResponse = await _fetchPermissions();
      if (permissionResponse.permissionDetails.isNotEmpty) {
        setState(() {
          final permissionDetail = permissionResponse.permissionDetails[0];
          salesDetail = permissionDetail.salesDetail;
          salesOther = permissionDetail.salesOther;
          salesReport = permissionDetail.salesOther;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }
  
  void _showError(String message) {
    if (!mounted) {
      return;
    }

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
    if (filteredSaleReport.isEmpty) {
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
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Invoice No';
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
      for (int i = 0; i < filteredSaleReport.length; i++) {
        final sale = filteredSaleReport[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = sale.invoiceNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = sale.date;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = capitalizeWords(sale.customer.customerName);
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
    if (filteredSaleReport.isEmpty) {
      _showError('No data available to export');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sales Report'];

      // Add headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = 'SI.No.';
      sheetObject.cell(CellIndex.indexByString("B1")).value = 'Invoice No';
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
      for (int i = 0; i < filteredSaleReport.length; i++) {
        final sale = filteredSaleReport[i];
        final rowIndex = i + 2;
        
        sheetObject.cell(CellIndex.indexByString("A$rowIndex")).value = i + 1;
        sheetObject.cell(CellIndex.indexByString("B$rowIndex")).value = sale.invoiceNo;
        sheetObject.cell(CellIndex.indexByString("C$rowIndex")).value = sale.date;
        sheetObject.cell(CellIndex.indexByString("D$rowIndex")).value = capitalizeWords(sale.customer.customerName);
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

  // Print Functionality
  Future<void> _printReport() async {
    if (filteredSaleReport.isEmpty) {
      _showError('No data available to print');
      return;
    }

    try {
      final pdf = pw.Document();
      
      // Create table data
      final List<List<String>> tableData = [
        ['SI.No.', 'Invoice No', 'Date', 'Customer Name'], // Header
      ];
      
      // Add data rows
      for (int i = 0; i < filteredSaleReport.length; i++) {
        final sale = filteredSaleReport[i];
        tableData.add([
          (i + 1).toString(),
          sale.invoiceNo,
          sale.date,
          capitalizeWords(sale.customer.customerName),
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
                  'Sales Report',
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
                  'Total Invoices: ${filteredSaleReport.length}',
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

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showError('Failed to print: $e');
    }
  }

  // Main export method - chooses the best option automatically
  Future<void> _exportToExcel() async {
    if (filteredSaleReport.isEmpty) {
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
      fetchSalesReport();
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
              _filterSalesReports();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
              });
              Navigator.of(context).pop();
              _filterSalesReports();
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
          'Sales Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
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
                  fetchSalesReport();
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
                  if (mainTitle != null && mainTitle!.isNotEmpty) ...[
                    Text(
                      mainTitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                  if (searchQuery.isNotEmpty) ...[
                    Text(
                      'Found ${filteredSaleReport.length} results for "$searchQuery"',
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
              child: filteredSaleReport.isEmpty
                  ? Center(
                      child: Text(
                        searchQuery.isNotEmpty
                            ? 'No sales records found for "$searchQuery"'
                            : 'No sales records in the selected date range.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (filteredSaleTotal != null && searchQuery.isEmpty) 
                          _buildTotalSaleReport(),
                        
                        ...filteredSaleReport.map((report) => _buildSalesEntryCard(report)),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 1,
      ),
    );
  }

  Widget _buildTotalSaleReport() {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KFC: ${filteredSaleTotal!.cessAmount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Round Off: ${filteredSaleTotal!.roundOff}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Discount: ${filteredSaleTotal!.discountAmount}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  filteredSaleTotal!.totalAmount,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              alignment: Alignment.centerRight,
              child: Text(
                filteredSaleTotal!.beforeTax,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF26A69A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CGST', style: TextStyle(fontSize: 14)),
                    Text(filteredSaleTotal!.cgstAmount, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SGST', style: TextStyle(fontSize: 14)),
                    Text(filteredSaleTotal!.sgstAmount, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('IGST', style: TextStyle(fontSize: 14)),
                    Text(filteredSaleTotal!.igstAmount, style: const TextStyle(fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GST', style: TextStyle(fontSize: 14)),
                    Text(filteredSaleTotal!.gstAmount, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesEntryCard(SalesReport report) {
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
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InvoiceViewScreen(invId: report.invId),
                      ),
                    );
                  },
                  child: Text(
                    report.invoiceNo,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                Text(
                  report.date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              capitalizeWords(report.customer.customerName),
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (report.customer.phone.isNotEmpty) ...[
  Text(
    report.customer.phone,
    style: const TextStyle(fontSize: 12),
  ),
],
if (report.customer.address.isNotEmpty) ...[
  Text(
    capitalizeWords(report.customer.address),
    style: const TextStyle(fontSize: 12),
  ),
],
if (report.customer.gstNo.isNotEmpty) ...[
  Text(
    'GST No: ${report.customer.gstNo}',
    style: const TextStyle(fontSize: 12),
  ),
],
            Text('${report.customer.state},${report.customer.stateCode}'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('GST', style: TextStyle(fontSize: 12)),
                            Text(report.gstAmount, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('KFC', style: TextStyle(fontSize: 12)),
                            Text(report.keralaFloodCess, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Round Off', style: TextStyle(fontSize: 12)),
                            Text(report.roundOff, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Discount', style: TextStyle(fontSize: 12)),
                            Text(report.discountAmount, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      report.totalAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      report.beforeGst,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF26A69A),
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
  }
}