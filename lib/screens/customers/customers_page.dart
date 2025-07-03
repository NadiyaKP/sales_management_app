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

  //Convert customer object to Map
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
  // List to store customers dynamically
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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // Combined initialization method
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
    
    try {
      final response = await http.post(
        Uri.parse('$url/customers.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "srch": searchQuery,
          "page": currentPage.toString(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          customerTotal = data['ttlcustomers'];
          final List<dynamic> customersList = data['customerdet'] ?? [];
          setState(() {
            customerTotal = customerTotal;
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
          customerAdd = permissionDetail.customerAdd;
          customerEdit = permissionDetail.customerEdit;
          customerStatus = permissionDetail.customerStatus;
          customerView = permissionDetail.customerView;
          isPermissionsLoaded = true; 
        });
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

      final response = await http.post(
        Uri.parse('$url/action/customers.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to update customer status"};
      }
    } catch (e) {
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
        title: const Text('Search Customers'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter name or GST number'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
              Navigator.pop(context);
              fetchAllCustomers();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewCustomer() async {
    // Check if permissions are loaded first
    if (!isPermissionsLoaded) {
      _showError('Loading permissions, please wait...');
      return;
    }

    // Check permission
    if (customerAdd.toLowerCase() != "yes" && customerAdd != "1") {
      _showError('You do not have permission to add customers');
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewCustomerPage()),
      );

      // Check if result is returned (customer was successfully saved)
      if (result != null && result is Map<String, dynamic>) {
        // Show success message - the saving is already handled in NewCustomerPage
        _showSuccess('Customer added successfully');
        
        // Refresh the customer list to show the new customer
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

    if (customerEdit.toLowerCase() != "yes" && customerEdit != "1") {
      _showError('You do not have permission to edit customers');
      return;
    }

    // Convert Customers object to Map for compatibility with NewCustomerPage
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

      // Check if result is returned (customer was successfully updated)
      if (result != null && result is Map<String, dynamic>) {
        // Show success message - the saving is already handled in NewCustomerPage
        _showSuccess('Customer updated successfully');
        
        // Refresh the customer list to show updated data
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

    if (customerView.toLowerCase() != "yes" && customerView != "1") {
      _showError('You do not have permission to view customer details');
      return;
    }

    // Navigate to ViewCustomer page
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

    if (customerStatus.toLowerCase() != "yes" && customerStatus != "1") {
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
        title: const Text('INACTIVATE'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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
            style: TextButton.styleFrom(
              foregroundColor: customer.status == "active" ? Colors.red : Colors.green
            ),
            child: Text(action.toUpperCase()),
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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CUSTOMERS'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _showSearchDialog),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: currentCustomers.isEmpty
                ? const Center(child: Text("No customers found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: currentCustomers.length,
                    itemBuilder: (context, index) {
                      final cust = currentCustomers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildRow('Name', cust.name),
                              _buildRow('GST No', cust.gstNo),
                              _buildRow('Phone', cust.phoneNo),
                              _buildRow('Balance', '₹${cust.balance}'),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPermissionsLoaded && (customerView.toLowerCase() == "yes" || customerView == "1"))
                                    _actionButton(Icons.visibility, "View", () => _viewCustomer(cust), const Color.fromARGB(255, 7, 63, 91)),
                                  if (isPermissionsLoaded && (customerView.toLowerCase() == "yes" || customerView == "1")) const SizedBox(width: 6),
                                  if (isPermissionsLoaded && (customerEdit.toLowerCase() == "yes" || customerEdit == "1"))
                                    _actionButton(Icons.edit, "Edit", () => _editCustomer(cust), const Color.fromARGB(255, 7, 63, 91)),
                                  if (isPermissionsLoaded && (customerEdit.toLowerCase() == "yes" || customerEdit == "1")) const SizedBox(width: 6),
                                  if (isPermissionsLoaded && (customerStatus.toLowerCase() == "yes" || customerStatus == "1"))
                                    _actionButton(
                                      cust.status == "active" ? Icons.lock : Icons.lock_open,
                                      cust.status == "active" ? "Inactivate" : "Activate",
                                      () => _inactivateCustomer(cust),
                                      cust.status == "active" ? Colors.red : Colors.green,
                                    ),
                                ],
                              )
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
      floatingActionButton: (isPermissionsLoaded && (customerAdd.toLowerCase() == "yes" || customerAdd == "1"))
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

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 11),
        elevation: 1,
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}