import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'home_page.dart';
import 'report_page.dart';

class NewDiscountPage extends StatefulWidget {
  const NewDiscountPage({super.key});

  @override
  State<NewDiscountPage> createState() => _NewDiscountPageState();
}

class _NewDiscountPageState extends State<NewDiscountPage> {
  final _formKey = GlobalKey<FormState>();
  ApiServices apiServices = ApiServices();

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController(); // NEW: Customer search controller
  final TextEditingController _dueAmountController = TextEditingController();
  final TextEditingController _discountAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  bool _isCustomerDropdownOpen = false;
  bool _showCustomerDropdown = false; // NEW: Customer dropdown state
  bool _isEditing = false;
  bool _isLoading = false;
  int _selectedIndex = 2; 
  
  // API-based customer data
  List<String> customerNames = [];
  List<String> _filteredCustomers = [];
  Map<String, String> customerIdMap = {};
  Map<String, String> customerAmountMap = {};
  
  // NEW: Focus node for customer search
  final FocusNode _customerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    
    // NEW: Add listeners for customer search functionality
    _customerSearchController.addListener(_filterCustomers);
    _customerFocusNode.addListener(_onCustomerFocusChange);
    
    // Schedule initialization after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWithEditData();
    });
  }

  @override
  void dispose() {
    // NEW: Remove listeners and dispose controllers
    _customerSearchController.removeListener(_filterCustomers);
    _customerSearchController.dispose();
    _customerFocusNode.removeListener(_onCustomerFocusChange);
    _customerFocusNode.dispose();
    
    _customerNameController.dispose();
    _dueAmountController.dispose();
    _discountAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // NEW: Customer focus change handler
  void _onCustomerFocusChange() {
    setState(() {
      _showCustomerDropdown = _customerFocusNode.hasFocus && _filteredCustomers.isNotEmpty;
    });
  }

  // Load customers from API
  Future<void> _loadCustomers() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      setState(() {
        customerNames = customers.map((e) => e["cust_name"]!).toList();
        customerIdMap = {for (var e in customers) e["cust_name"]!: e["custid"]!};
        customerAmountMap = {for (var e in customers) e["cust_name"]!: e["outstand_amt"]!};
        _filteredCustomers = List.from(customerNames); // NEW: Initialize filtered list
      });
    } catch (e) {
      _showError('Error loading customers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Initialize with edit data if available
  void _initializeWithEditData() {
    // Check if we have route arguments for editing
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      // This is an edit operation
      setState(() {
        _isEditing = args['isEditing'] ?? false;
        
        // Get the initial data
        final initialData = args['initialData'];
        if (initialData != null && initialData is Map<String, dynamic>) {
          // Populate the form with initial data
          _selectedCustomerName = initialData['customerName'] ?? '';
          _customerNameController.text = _selectedCustomerName ?? '';
          _customerSearchController.text = _selectedCustomerName ?? ''; // NEW: Set customer search controller
          
          // Set due amount (comes from the parent)
          _dueAmountController.text = initialData['dueAmount'] ?? '0';
          
          // Parse the date
          if (initialData['discountDate'] != null) {
            try {
              _selectedDate = DateTime.parse(initialData['discountDate']);
            } catch (e) {
              // In case of parsing error, use current date
              _selectedDate = DateTime.now();
            }
          }
          
          // Set discount amount
          _discountAmountController.text = initialData['discountAmount'] ?? '';
          
          // Set notes
          _notesController.text = initialData['notes'] ?? '';
        }
      });
    }
  }

  // NEW: Filter customers based on search text
  void _filterCustomers() {
    String query = _customerSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = List.from(customerNames);
      } else {
        _filteredCustomers = customerNames
            .where((customer) => customer.toLowerCase().contains(query))
            .toList();
      }
      _showCustomerDropdown = _customerFocusNode.hasFocus && _filteredCustomers.isNotEmpty;
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // No action if current page
    
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportPage()));
    } else if (index == 2) {
      Navigator.pop(context); // Return to discounts page
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
    }
  }

  // NEW: Handle customer selection from dropdown
  void _selectCustomer(String customerName) {
    setState(() {
      _selectedCustomerId = customerIdMap[customerName];
      _selectedCustomerName = customerName;
      _customerNameController.text = customerName;
      _customerSearchController.text = customerName;
      _dueAmountController.text = customerAmountMap[customerName] ?? '0';
      _showCustomerDropdown = false;
      // Clear discount amount when customer changes to trigger validation
      if (_discountAmountController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
    _customerFocusNode.unfocus();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), 
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Save discount data using API
  Future<Map<String, dynamic>> _saveDiscountData(String action) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        return {"result": "0", "message": "Missing credentials"};
      }

      // Prepare request body
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "action": action,
        "cust_name": _selectedCustomerName ?? '',
        "custid": _selectedCustomerId ?? '',
        "notes": _notesController.text.trim(),
        "dsc_date": DateFormat('dd-MM-yyyy').format(_selectedDate),
        "dsc_amt": _discountAmountController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('$url/action/discounts.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to save discount"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String action = _isEditing ? "update" : "insert";
        Map<String, dynamic> result = await _saveDiscountData(action);

        if (result['result'] == '1') {
          _showSuccess(result['message'] ?? 'Discount saved successfully');
          // Return success to previous screen
          Navigator.pop(context, {'success': true, 'message': result['message']});
        } else {
          _showError(result['message'] ?? 'Failed to save discount');
        }
      } catch (e) {
        _showError('An error occurred: $e');
      } finally {
        setState(() {
          _isLoading = false;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  // NEW: Build customer search field similar to new_order_page.dart
  Widget _buildCustomerSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Name', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              TextField(
                controller: _customerSearchController,
                focusNode: _customerFocusNode,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  hintText: 'Type to search customer...',
                  suffixIcon: Icon(Icons.search, color: Colors.grey),
                ),
                onChanged: (value) {
                  // Update selected customer if exact match
                  if (customerNames.contains(value)) {
                    setState(() {
                      _selectedCustomerName = value;
                      _selectedCustomerId = customerIdMap[value];
                      _customerNameController.text = value;
                      _dueAmountController.text = customerAmountMap[value] ?? '0';
                    });
                  } else {
                    setState(() {
                      _selectedCustomerName = null;
                      _selectedCustomerId = null;
                      _customerNameController.text = value;
                      _dueAmountController.text = '0';
                    });
                  }
                  // Trigger form validation
                  if (_discountAmountController.text.isNotEmpty) {
                    _formKey.currentState?.validate();
                  }
                },
              ),
              // Customer dropdown
              if (_showCustomerDropdown && _filteredCustomers.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      String customerName = _filteredCustomers[index];
                      return InkWell(
                        onTap: () => _selectCustomer(customerName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedCustomerName == customerName
                                ? Colors.blue.withOpacity(0.1)
                                : null,
                            border: Border(
                              bottom: BorderSide(
                                color: index < _filteredCustomers.length - 1 
                                    ? Colors.grey.shade200 
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _capitalizeWords(customerName),
                                  style: const TextStyle(fontSize: 14),
                                ),
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
        // Validation error display
        if (_selectedCustomerName == null && _customerSearchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              'Please select a valid customer from the dropdown',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  String _capitalizeWords(String text) {
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && customerNames.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'EDIT DISCOUNT' : 'NEW DISCOUNT'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // NEW: Customer Name with Search functionality
                _buildCustomerSearchField(),
                const SizedBox(height: 16),

                // Due Amount - read-only
                TextFormField(
                  controller: _dueAmountController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Due Amount'),
                  readOnly: true, // Always read-only as it comes from API
                  enabled: false, // Disabled as it's auto-populated
                  validator: (value) {
                    if (_selectedCustomerName == null) {
                      return 'Please select a customer to see due amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Discount Date
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: _inputDecoration('Discount Date'),
                    child: Text(
                      DateFormat.yMMMMd().format(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Discount Amount
                TextFormField(
                  controller: _discountAmountController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Discount Amount'),
                  onChanged: (value) {
                    // Trigger validation on every change
                    _formKey.currentState?.validate();
                  },
                  validator: (value) {
                    if (_selectedCustomerName == null) {
                      return 'Please select a customer first';
                    }
                    if (value == null || value.isEmpty) {
                      return 'Please enter discount amount';
                    }
                    final number = double.tryParse(value);
                    if (number == null) {
                      return 'Please enter a valid amount';
                    }
                    if (number <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
                      return 'Enter a valid amount with up to 2 decimal places';
                    }
                    
                    // Validate against due amount
                    if (_dueAmountController.text.isNotEmpty) {
                      final dueAmount = double.tryParse(_dueAmountController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                      if (number > dueAmount) {
                        return 'Discount cannot exceed due amount';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Notes (2 lines)
                TextFormField(
                  controller: _notesController,
                  decoration: _inputDecoration('Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 30),

                // Save Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(_isEditing ? Icons.edit : Icons.save),
                  label: Text(
                    _isLoading 
                        ? 'Saving...'
                        : (_isEditing ? 'UPDATE' : 'SAVE'),
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? const Color.fromARGB(255, 32, 104, 163) : AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
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
}