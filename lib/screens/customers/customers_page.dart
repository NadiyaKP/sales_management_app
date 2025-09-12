import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../home_page.dart';
import '../report_page.dart';
import 'new_customer_page.dart';
import 'view_customer.dart';

// Permission variables
String customerAdd = '';
String customerView = '';
String customerEdit = '';
String customerStatus = '';

class Customers {
  final String typeofCustomer;
  final String typeName;
  final String name;
  final String gstNo;
  final String phoneNo;
  final String balance;
  final String email;
  final String landPhone;
  final String address;
  final String state;
  final String stateCode;
  final String noOfCreditsDays;
  final String custId;
  final String status;
  final String openBalance;
  final String openAccount;

  Customers({
    required this.typeofCustomer,
    required this.typeName,
    required this.name,
    required this.openAccount,
    required this.openBalance,
    required this.status,
    required this.gstNo,
    required this.phoneNo,
    required this.balance,
    required this.address,
    required this.email,
    required this.landPhone,
    required this.noOfCreditsDays,
    required this.state,
    required this.stateCode,
    required this.custId,
  });

  factory Customers.fromJson(Map<String, dynamic> json) {
    return Customers(
      custId: json['custid'] ?? '',
      name: json['custname'] ?? '',
      typeofCustomer: json['cust_type'] ?? '',
      typeName: json['cust_type_name'] ?? '',
      address: json['address'] ?? '',
      gstNo: json['gst'] ?? '',
      phoneNo: json['phone'] ?? '',
      email: json['email'] ?? '',
      landPhone: json['land_phone'] ?? '',
      openBalance: json['op_bln'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      noOfCreditsDays: json['credit_days'] ?? '',
      openAccount: json['op_acc'] ?? '',
      status: json['status'] ?? '',
      balance: json['balance'] ?? '',
    );
  }
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({Key? key}) : super(key: key);

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Customers> _customers = [];
  List<Customers> filteredCustomers = [];
  ApiServices apiServices = ApiServices();

  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  bool isLoading = false;
  bool isPermissionsLoaded = false; 
  int customerTotal = 0;

  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  // Helper method to log API requests and responses
  void _logApiCall(String endpoint, Map<String, dynamic> requestBody, {http.Response? response, dynamic error}) {
    print('=== API CALL LOG ===');
    print('Endpoint: $endpoint');
    print('Request Body: ${jsonEncode(requestBody)}');
    print('Timestamp: ${DateTime.now().toIso8601String()}');
    
    if (response != null) {
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
    }
    
    if (error != null) {
      print('Error: $error');
    }
    
    print('==================');
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadPermissions();
    await fetchAllCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchAllCustomers() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');
    
    final endpoint = '$url/customers.php';
    final requestBody = {
      "unid": unid,
      "slex": slex,
      "srch": searchQuery,
      "page": currentPage.toString(),
    };

    print('=== FETCH ALL CUSTOMERS API CALL ===');
    print('URL: $endpoint');
    print('Request Body: ${jsonEncode(requestBody)}');
    print('Timestamp: ${DateTime.now().toIso8601String()}');
    
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('=====================================');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          // FIX: Convert string to int for ttlcustomers
          customerTotal = int.tryParse(data['ttlcustomers']?.toString() ?? '0') ?? 0;
          final List<dynamic> customersList = data['customerdet'] ?? [];
          setState(() {
            _customers = customersList.map((json) => Customers.fromJson(json)).toList();
            filteredCustomers = _customers;
          });
          if (customersList.isEmpty) {
            _showError('No customers data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch customers.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      print('API Error: $error');
      print('=====================================');
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<PermissionResponse> _fetchPermissions() async {
    try {
      final apiService = ApiServices();
      
      print('=== FETCH PERMISSIONS API CALL ===');
      print('Calling ApiServices.fetchPermissionDetails()');
      print('Timestamp: ${DateTime.now().toIso8601String()}');
      
      final permissionData = await apiService.fetchPermissionDetails();

      if (permissionData == null) {
        print('Permission Response: null');
        print('==================================');
        throw Exception('Failed to fetch permissions: Data is null.');
      }

      print('Permission Response: $permissionData');
      print('Permission Details Count: ${permissionData.permissionDetails.length}');
      if (permissionData.permissionDetails.isNotEmpty) {
        final detail = permissionData.permissionDetails[0];
        print('Customer Add: ${detail.customerAdd}');
        print('Customer Edit: ${detail.customerEdit}');
        print('Customer View: ${detail.customerView}');
        print('Customer Status: ${detail.customerStatus}');
      }
      print('==================================');

      if (permissionData.permissionDetails.isEmpty) {
        throw Exception('Received empty permissions data from the API.');
      }

      return permissionData;
    } catch (e) {
      print('Permission API Error: $e');
      print('==================================');
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
          customerAdd = permissionDetail.customerAdd;
          customerEdit = permissionDetail.customerEdit;
          customerStatus = permissionDetail.customerStatus;
          customerView = permissionDetail.customerView;
          isPermissionsLoaded = true; 
        });
        
        print('=== PERMISSIONS LOADED ===');
        print('Customer Add: $customerAdd');
        print('Customer Edit: $customerEdit');
        print('Customer Status: $customerStatus');
        print('Customer View: $customerView');
        print('==========================');
      } else {
        setState(() {
          isPermissionsLoaded = true; 
        });
        _showError('No permissions data available.');
      }
    } catch (e) {
      setState(() {
        isPermissionsLoaded = true; 
      });
      _showError('Error fetching permissions: $e');
    }
  }

  Future<Map<String, dynamic>> _saveCustomersData(String action, {String? custId}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        print('=== SAVE CUSTOMERS DATA ERROR ===');
        print('Missing credentials - URL: $url, UNID: $unid, SLEX: $slex');
        print('=================================');
        return {"result": "0", "message": "Missing credentials"};
      }

      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "action": action,
      };

      if (action == 'customerstatus' && custId != null) {
        requestBody["custid"] = custId;
      }

      final endpoint = '$url/action/customers.php';
      
      print('=== SAVE CUSTOMERS DATA API CALL ===');
      print('URL: $endpoint');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('Timestamp: ${DateTime.now().toIso8601String()}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('===================================');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to update customer status"};
      }
    } catch (e) {
      print('Save Customers Data API Error: $e');
      print('===================================');
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  List<Customers> get currentCustomers {
    return filteredCustomers;
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
      fetchAllCustomers();
    });
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter name or GST number'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchController.clear();
              setState(() {
                searchQuery = '';
                currentPage = 1;
              });
              fetchAllCustomers();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
                currentPage = 1;
              });
              Navigator.of(context).pop();
              fetchAllCustomers();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewCustomer() async {
    if (!isPermissionsLoaded) {
      _showError('Loading permissions, please wait...');
      return;
    }

    if (customerAdd != "yes") {
      _showError('You do not have permission to add customers');
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewCustomerPage()),
      );

      if (result != null) {
        _showSuccess('New customer added successfully!');
        await fetchAllCustomers();
      }
    } catch (e) {
      _showError('Navigation error: $e');
    }
  }

  void _editCustomer(Customers customer) async {
    if (!isPermissionsLoaded) {
      _showError('Loading permissions, please wait...');
      return;
    }

    if (customerEdit != "yes") {
      _showError('You do not have permission to edit customers');
      return;
    }

    Map<String, dynamic> customerData = {
      'custId': customer.custId,
      'name': customer.name,
      'typeName': customer.typeName,
      'typeofCustomer': customer.typeofCustomer,
      'gst': customer.gstNo,
      'phone': customer.phoneNo,
      'balance': customer.openBalance.isNotEmpty ? customer.openBalance : '0',
      'balanceType': customer.openAccount.isNotEmpty ? customer.openAccount : 'dr',
      'email': customer.email,
      'landPhone': customer.landPhone,
      'address': customer.address,
      'state': customer.state,
      'stateCode': customer.stateCode,
      'creditDays': customer.noOfCreditsDays,
      'cust': customer.custId,
    };

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewCustomerPage(
            isEditing: true,
            customerData: customerData,
          ),
        ),
      );

      if (result != null) {
        _showSuccess('Customer updated successfully!');
        await fetchAllCustomers();
      }
    } catch (e) {
      _showError('Navigation error: $e');
    }
  }

  void _viewCustomer(Customers customer) async {
    if (!isPermissionsLoaded) {
      _showError('Loading permissions, please wait...');
      return;
    }

    if (customerView != "yes") {
      _showError('You do not have permission to view customer details');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewCustomer(customer: customer),
      ),
    );
  }

  void _inactivateCustomer(Customers customer) {
    if (!isPermissionsLoaded) {
      _showError('Loading permissions, please wait...');
      return;
    }

    if (customerStatus != "yes") {
      _showError('You do not have permission to change customer status');
      return;
    }

    String action = customer.status == "active" ? "inactivate" : "activate";
    String message = customer.status == "active" 
        ? "Are you sure you want to inactivate this customer?"
        : "Are you sure you want to activate this customer?";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('INACTIVATE',style: TextStyle(fontSize: 14, color: Colors.red),),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                isLoading = true;
              });

              Map<String, dynamic> result = await _saveCustomersData(
                "customerstatus",
                custId: customer.custId,
              );

              setState(() {
                isLoading = false;
              });

              if (result['result'] == '1') {
                fetchAllCustomers();
                _showSuccess(result['message']);
              } else {
                _showError(result['message']);
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _customers.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _customers.isEmpty
                ? const Center(child: Text("No customers found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1.5,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              // Header Section with Customer Name and GST
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 5, 38, 76).withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        customer.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(255, 5, 38, 76),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'GST: ${customer.gstNo.isNotEmpty ? customer.gstNo : "N/A"}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Content Section
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    // Phone, Balance and Inactive Button Section
                                    Row(
                                      children: [
                                        // Phone Number Section
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Phone no:',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  customer.phoneNo.isNotEmpty ? customer.phoneNo : "N/A",
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 8),
                                        
                                        // Balance Section
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Balance',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  customer.balance.isNotEmpty ? customer.balance : "0",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        
                                        // Inactivate/Activate Button (without white background)
                                        if (customerStatus == "yes") ...[
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            icon: Icon(
                                              customer.status == "active" ? Icons.lock : Icons.lock_open, 
                                              size: 10, 
                                              color: Colors.white
                                            ),
                                            label: Text(
                                              customer.status == "active" ? 'Inactivate' : 'Activate', 
                                              style: const TextStyle(color: Colors.white, fontSize: 9)
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: customer.status == "active" ? Colors.red.shade600 : Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                              elevation: 1,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              minimumSize: const Size(0, 0),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            onPressed: () => _inactivateCustomer(customer),
                                          ),
                                        ],
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    // View and Edit Buttons positioned at bottom right
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (customerView == "yes")
                                          Container(
                                            width: 28,
                                            height: 28,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color.fromARGB(255, 5, 38, 76),
                                                foregroundColor: Colors.white,
                                                elevation: 1,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _viewCustomer(customer),
                                              child: const Icon(Icons.visibility, size: 12),
                                            ),
                                          ),
                                        if (customerView == "yes" && customerEdit == "yes")
                                          const SizedBox(width: 4),
                                        if (customerEdit == "yes")
                                          Container(
                                            width: 28,
                                            height: 28,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color.fromARGB(255, 5, 38, 76),
                                                foregroundColor: Colors.white,
                                                elevation: 1,
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _editCustomer(customer),
                                              child: const Icon(Icons.edit, size: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SlidingPaginationControls(
            currentPage: currentPage,
            totalItems: customerTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      floatingActionButton: customerAdd == "yes" 
          ? FloatingActionButton(
              onPressed: _navigateToNewCustomer,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0, 
      ),
    );
  }
}