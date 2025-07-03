import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/permission.dart';
import 'invoice/invoice_view.dart';

// Data Models
class AgedInvoice {
  final String invId;
  final String invoiceNo;
  final String invoiceDate;
  final int dueDays;
  final String invoiceAmount;
  final String receivedAmount;
  final String balanceDueAmount;

  AgedInvoice({
    required this.invId,
    required this.invoiceNo,
    required this.dueDays,
    required this.invoiceDate,
    required this.invoiceAmount,
    required this.receivedAmount,
    required this.balanceDueAmount,
  });

  factory AgedInvoice.fromJson(Map<String, dynamic> json) {
    return AgedInvoice(
      invId: json['inv_id'] ?? '',
      invoiceNo: json['inv_no'] ?? '',
      invoiceDate: json['inv_date'] ?? '',
      dueDays: (json['due_days'] as num?)?.toInt() ?? 0,
      invoiceAmount: json['inv_amt'] ?? '',
      receivedAmount: json['rcp_amt'] ?? '',
      balanceDueAmount: json['bln_due'] ?? '',
    );
  }
}

class AgedCustomers {
  final String name;
  final String address;
  final String gstNo;
  final String phone;
  final String state;
  final String stateCode;

  AgedCustomers({
    required this.name,
    required this.address,
    required this.gstNo,
    required this.phone,
    required this.state,
    required this.stateCode,
  });

  factory AgedCustomers.fromJson(Map<String, dynamic> json) {
    return AgedCustomers(
      name: json['custname'] ?? '',
      address: json['address'] ?? '',
      gstNo: json['gst_no'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
    );
  }
}

class Aged {
  List<AgedCustomers> agedCustomers;
  List<AgedInvoice> agedInvoices;
  final int customerTotalBalance;

  Aged({
    required this.agedCustomers,
    required this.agedInvoices,
    required this.customerTotalBalance,
  });

  factory Aged.fromJson(Map<String, dynamic> json) {
    return Aged(
      agedCustomers: (json['customerdet'] as List<dynamic>?)
              ?.map((cust) => AgedCustomers.fromJson(cust))
              .toList() ??
          [],
      agedInvoices: (json['customer_invoice_due'] as List<dynamic>?)
              ?.map((inv) => AgedInvoice.fromJson(inv))
              .toList() ??
          [],
      customerTotalBalance: (json['customer_ttl_bln_due'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgedReceivableReportPage extends StatefulWidget {
  const AgedReceivableReportPage({Key? key}) : super(key: key);

  @override
  State<AgedReceivableReportPage> createState() => _AgedReceivableReportPageState();
}

class _AgedReceivableReportPageState extends State<AgedReceivableReportPage> {
  final TextEditingController _daysController = TextEditingController();
  String _selectedCustomerType = 'All';
  List<String> _customerTypes = ['All'];
  Map<String, String> _customerTypeIdMap = {};
  String? _selectedTypeId;
  
  // API related variables
  ApiServices apiServices = ApiServices();
  List<Aged> _aged = [];
  List<Aged> _filteredAged = [];
  bool _isLoading = false;
  bool _showReport = false;
  String? _mainTitle;
  String? _subTitle;
  String _agedReceivable = '';

  int _selectedIndex = 1; // Report tab selected

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadCustomerTypes();
  }

  Future<void> _fetchAgedReceivables() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    try {
      final response = await http.post(
        Uri.parse('$url/aged-receivables.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "days": _daysController.text,
          "cust_type": _selectedTypeId
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          final List<dynamic> agedList = data['agedcartdet'] ?? [];
          _mainTitle = data['main_title'];
          _subTitle = data['sub_title'];
          
          setState(() {
            _aged = agedList.map((json) => Aged.fromJson(json)).toList();
            _filteredAged = _aged;
            _showReport = true;
          });
          
          if (agedList.isEmpty) {
            _showError('No aged receivables data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          _agedReceivable = permissionDetail.agedReceivable;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }

  Future<void> _loadCustomerTypes() async {
    try {
      List<Map<String, String>> customerType = await apiServices.fetchCustomersType();
      setState(() {
        List<String> types = customerType.map((e) => e["custtype_name"]!).toList();
        _customerTypes = ["All", ...types];
        _customerTypeIdMap = {
          for (var e in customerType) e["custtype_name"]!: e["custtypeid"]!
        };
      });
    } catch (e) {
      _showError(e.toString());
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

  void _searchAgedReceivable() {
    setState(() {
      _selectedTypeId = _selectedCustomerType == "All" ? null : _customerTypeIdMap[_selectedCustomerType];
    });
    _fetchAgedReceivables();
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      Navigator.pop(context);
    }
  }

  String get _currentDate => DateFormat('dd/MM/yyyy').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AGED RECEIVABLE'),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters Section with improved alignment
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type of Customer
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppTheme.primaryColor),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    isDense: true,
                                  ),
                                  isExpanded: true,
                                  value: _selectedCustomerType,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedCustomerType = newValue!;
                                    });
                                  },
                                  items: _customerTypes
                                      .map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value, 
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Days
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Days',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                child: TextField(
                                  controller: _daysController,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade400),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: AppTheme.primaryColor),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    isDense: true,
                                    hintText: 'Enter days',
                                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                  ],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Search Button positioned at bottom right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 80, // Reduced width
                          height: 36, // Reduced height
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _searchAgedReceivable,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'SEARCH',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Report Section
            if (_showReport && !_isLoading) ...[
              const SizedBox(height: 16),
              // Report Title
              if (_mainTitle != null)
                Center(
                  child: Text(
                    _mainTitle!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_subTitle != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _subTitle!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // Report Data
              Expanded(
                child: _filteredAged.isEmpty
                    ? const Center(
                        child: Text(
                          'No data found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredAged.length,
                        itemBuilder: (context, index) {
                          final aged = _filteredAged[index];
                          if (aged.agedInvoices.isEmpty) {
                            return const SizedBox();
                          }
                          return _buildAgedCard(aged);
                        },
                      ),
              ),
            ],
            
            // Loading indicator
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: AppConstants.bottomNavItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item['icon']),
            label: item['title'],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAgedCard(Aged aged) {
    // Check if this customer has opening balance entries
    bool hasOpeningBalance = aged.agedInvoices.any((invoice) => invoice.invoiceNo == "Opening Balance");
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer name
          if (aged.agedCustomers.isNotEmpty)
            Text(
              aged.agedCustomers.first.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          const SizedBox(height: 12),
          
          // Improved Table with consistent row heights
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Header Row
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: hasOpeningBalance
                          ? [
                              _buildHeaderCell('Invoice', flex: 3),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Invoice\nAmount', flex: 2),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Received\nAmount', flex: 2),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Due\nAmount', flex: 2),
                            ]
                          : [
                              _buildHeaderCell('Invoice\nDate', flex: 2),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Invoice\nNo', flex: 2),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Due\nDays', flex: 1),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Invoice\nAmount', flex: 2),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Received\nAmount', flex: 2),
                              _buildVerticalDivider(),
                              _buildHeaderCell('Due\nAmount', flex: 2),
                            ],
                    ),
                  ),
                ),
                
                // Data Rows
                ...aged.agedInvoices.asMap().entries.map((entry) {
                  int index = entry.key;
                  AgedInvoice agedInvoice = entry.value;
                  bool isLastRow = index == aged.agedInvoices.length - 1;
                  
                  return Container(
                    decoration: BoxDecoration(
                      border: isLastRow ? null : Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: hasOpeningBalance
                            ? [
                                _buildDataCell(
                                  agedInvoice.invoiceNo,
                                  flex: 3,
                                  alignment: TextAlign.center,
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.invoiceAmount,
                                  flex: 2,
                                  alignment: TextAlign.right,
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.receivedAmount,
                                  flex: 2,
                                  alignment: TextAlign.right,
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.balanceDueAmount,
                                  flex: 2,
                                  alignment: TextAlign.right,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ]
                            : [
                                _buildDataCell(
                                  agedInvoice.invoiceDate,
                                  flex: 2,
                                  alignment: TextAlign.center,
                                ),
                                _buildVerticalDivider(),
                                _buildClickableDataCell(
                                  agedInvoice.invoiceNo,
                                  flex: 2,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InvoiceViewScreen(invId: agedInvoice.invId),
                                      ),
                                    );
                                  },
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.dueDays.toString(),
                                  flex: 1,
                                  alignment: TextAlign.center,
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.invoiceAmount,
                                  flex: 2,
                                  alignment: TextAlign.right,
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.receivedAmount,
                                  flex: 2,
                                  alignment: TextAlign.right,
                                ),
                                _buildVerticalDivider(),
                                _buildDataCell(
                                  agedInvoice.balanceDueAmount,
                                  flex: 2,
                                  alignment: TextAlign.right,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          // Balance Due row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Balance Due:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  aged.customerTotalBalance.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDataCell(
    String text, {
    required int flex,
    TextAlign alignment = TextAlign.left,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: fontWeight,
            height: 1.2,
          ),
          textAlign: alignment,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildClickableDataCell(
    String text, {
    required int flex,
    VoidCallback? onTap,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: InkWell(
          onTap: onTap,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blue,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      color: Colors.grey.shade300,
    );
  }
  
  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }
}