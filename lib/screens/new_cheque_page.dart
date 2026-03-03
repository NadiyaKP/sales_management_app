import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../common/bottom_navigation_button.dart';

class NewChequePage extends StatefulWidget {
  final Map<String, dynamic>? existingCheque;
  final bool isViewMode;
  final bool isEditMode;

  const NewChequePage({
    Key? key,
    this.existingCheque,
    this.isViewMode = false,
    this.isEditMode = false,
  }) : super(key: key);

  @override
  State<NewChequePage> createState() => _NewChequePageState();
}

class _NewChequePageState extends State<NewChequePage> {
  ApiServices apiServices = ApiServices();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _chequeDateController = TextEditingController();
  final TextEditingController _chequeNoController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController(); // NEW: Customer search controller
  
  // API-related variables
  List<String> customerNames = [];
  List<String> filteredCustomerNames = []; // NEW: Filtered customer names
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  bool isLoading = false;
  
  // For edit mode
  String? chequeId;
  bool _dataInitialized = false;
  
  // NEW: Customer dropdown state
  bool _showCustomerDropdown = false;
  final FocusNode _customerFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _chequeDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _customerSearchController.addListener(_filterCustomers); // NEW: Add customer filter listener
    _customerFocusNode.addListener(_onCustomerFocusChange); // NEW: Add focus listener
    _initializeData();
  }

  @override
  void dispose() {
    _customerSearchController.removeListener(_filterCustomers); // NEW: Remove customer filter listener
    _customerSearchController.dispose(); // NEW: Dispose customer search controller
    _customerFocusNode.removeListener(_onCustomerFocusChange); // NEW: Remove focus listener
    _customerFocusNode.dispose(); // NEW: Dispose focus node
    _chequeDateController.dispose();
    _chequeNoController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // NEW: Customer focus change handler
  void _onCustomerFocusChange() {
    setState(() {
      _showCustomerDropdown = _customerFocusNode.hasFocus && filteredCustomerNames.isNotEmpty;
    });
  }

  // NEW: Filter customers based on search text
  void _filterCustomers() {
    String query = _customerSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredCustomerNames = List.from(customerNames);
      } else {
        filteredCustomerNames = customerNames
            .where((customer) => customer.toLowerCase().contains(query))
            .toList();
      }
      _showCustomerDropdown = _customerFocusNode.hasFocus && filteredCustomerNames.isNotEmpty;
    });
  }

  // NEW: Handle customer selection from dropdown
  void _selectCustomer(String customerName) {
    setState(() {
      selectedCustomer = customerName;
      selectedCustId = customerIdMap[customerName];
      _customerSearchController.text = customerName;
      _showCustomerDropdown = false;
    });
    _customerFocusNode.unfocus();
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load customers first
      await loadCustomers();

      // Then initialize existing cheque data if available
      if (widget.existingCheque != null && !_dataInitialized) {
        _initializeExistingChequeData();
        _dataInitialized = true;
      }
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeExistingChequeData() {
    final existingCheque = widget.existingCheque!;
    
    // Set cheque ID for edit mode
    chequeId = existingCheque['chequeId'];
    
    // Set customer data
    String customerName = existingCheque['customerName'] ?? '';
    if (customerName.isNotEmpty) {
      _customerSearchController.text = customerName; // NEW: Set customer search controller
      
      // Check if customer exists in the loaded customers
      if (customerNames.contains(customerName)) {
        selectedCustomer = customerName;
        selectedCustId = customerIdMap[customerName];
      } else {
        // If customer doesn't exist in dropdown, add it temporarily
        setState(() {
          customerNames.add(customerName);
          String tempCustId = existingCheque['custId'] ?? '';
          if (tempCustId.isNotEmpty) {
            customerIdMap[customerName] = tempCustId;
            selectedCustId = tempCustId;
          }
          selectedCustomer = customerName;
        });
      }
    }
    
    // Set cheque number
    _chequeNoController.text = existingCheque['chequeNo'] ?? '';
    
    // Set amount
    _amountController.text = existingCheque['amount']?.toString() ?? '';
    
    // Set date - handle different date formats
    String chequeDate = existingCheque['chequeDate'] ?? '';
    if (chequeDate.isNotEmpty) {
      try {
        DateTime parsedDate;
        if (chequeDate.contains('-')) {
          // If already in dd-MM-yyyy format
          if (chequeDate.split('-')[0].length == 2) {
            _chequeDateController.text = chequeDate;
          } else {
            // If in yyyy-MM-dd format
            parsedDate = DateTime.parse(chequeDate);
            _chequeDateController.text = DateFormat('dd-MM-yyyy').format(parsedDate);
          }
        } else {
          parsedDate = DateTime.parse(chequeDate);
          _chequeDateController.text = DateFormat('dd-MM-yyyy').format(parsedDate);
        }
      } catch (e) {
        _chequeDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
      }
    }
  }

  Future<void> loadCustomers() async {
    try {
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      setState(() {
        customerNames = customers.map((e) => e["cust_name"]!).toList();
        customerIdMap = {
          for (var e in customers) e["cust_name"]!: e["custid"]!
        };
        filteredCustomerNames = List.from(customerNames); // NEW: Initialize filtered list
      });
    } catch (e) {
      _showError('Failed to load customers: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (widget.isViewMode) return;
    
    DateTime initialDate = DateTime.now();
    
    if (_chequeDateController.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd-MM-yyyy').parse(_chequeDateController.text);
      } catch (e) {
        initialDate = DateTime.now();
      }
    }
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _chequeDateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  Future<Map<String, dynamic>> _saveChequeData() async {
    if (!_formKey.currentState!.validate()) {
      return {"result": "0"};
    }

    if (selectedCustomer == null || selectedCustId == null) {
      _showError('Customer must be selected.');
      return {"result": "0"};
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      
      if (url == null || unid == null || slex == null) {
        _showError('Missing credentials. Please login again.');
        return {"result": "0"};
      }
      
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "custid": selectedCustId ?? '',
        "cust_name": selectedCustomer ?? '',
        "chq_no": _chequeNoController.text.trim(),
        "chq_date": _chequeDateController.text.trim(),
        "chq_amt": _amountController.text.trim(),
      };

      // Add action and chequeId for edit mode
      if (widget.isEditMode && chequeId != null) {
        requestBody["action"] = "update";
        requestBody["chqid"] = chequeId;
      } else {
        requestBody["action"] = "insert";
      }
      
      debugPrint('Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$url/action/cheques.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result["result"] == "1") {
          // Success message
          String successMessage = widget.isEditMode 
              ? "Cheque updated successfully!" 
              : "Cheque saved successfully!";
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMessage),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          // Navigate back with result
          Navigator.pop(context, result);
          return result;
        } else {
          _showError(result["message"] ?? "Failed to save cheque.");
          return {"result": "0", "message": result["message"] ?? "Failed to save cheque."};
        }
      } else {
        _showError("Server error: ${response.statusCode}");
        return {"result": "0", "message": "Server error: ${response.statusCode}"};
      }
    } catch (e) {
      debugPrint('Error saving cheque: $e');
      _showError("Network error: $e");
      return {"result": "0", "message": "Network error: $e"};
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _saveCheque() {
    if (widget.isViewMode) return;
    _saveChequeData();
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

  Widget _buildCustomerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Name', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.isViewMode
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Text(
                    selectedCustomer?.isNotEmpty == true ? selectedCustomer! : 'Not specified',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    TextField(
                      controller: _customerSearchController,
                      focusNode: _customerFocusNode,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        hintText: 'Type to search customer...',
                        suffixIcon: Icon(Icons.search, color: Colors.grey),
                      ),
                      onChanged: (value) {
                        // Update selected customer if exact match
                        if (customerNames.contains(value)) {
                          setState(() {
                            selectedCustomer = value;
                            selectedCustId = customerIdMap[value];
                          });
                        } else {
                          setState(() {
                            selectedCustomer = null;
                            selectedCustId = null;
                          });
                        }
                      },
                    ),
                    // NEW: Customer dropdown
                    if (_showCustomerDropdown && filteredCustomerNames.isNotEmpty)
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
                          itemCount: filteredCustomerNames.length,
                          itemBuilder: (context, index) {
                            String customerName = filteredCustomerNames[index];
                            return InkWell(
                              onTap: () => _selectCustomer(customerName),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: index < filteredCustomerNames.length - 1 
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
                                        customerName,
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
        if (selectedCustomer == null && !widget.isViewMode)
          const Padding(
            padding: EdgeInsets.only(top: 8.0, left: 12.0),
            child: Text(
              'Please select a customer',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cheque Date', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _chequeDateController,
            readOnly: true,
            enabled: !widget.isViewMode,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: widget.isViewMode 
                  ? null 
                  : IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () => _selectDate(context),
                    ),
            ),
            onTap: widget.isViewMode ? null : () => _selectDate(context),
          ),
        ),
      ],
    );
  }

  Widget _buildChequeNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cheque Number', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _chequeNoController,
            readOnly: widget.isViewMode,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Enter cheque number',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _amountController,
            readOnly: widget.isViewMode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'Enter amount',
              prefixText: '₹ ',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    if (widget.isViewMode) return const SizedBox.shrink();
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _saveCheque,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    widget.isEditMode ? 'Update Cheque' : 'Save Cheque', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && !_dataInitialized) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: Text(
            widget.isViewMode 
                ? 'VIEW CHEQUE' 
                : widget.isEditMode 
                    ? 'EDIT CHEQUE' 
                    : 'NEW CHEQUE',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading cheque data...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        title: Text(
          widget.isViewMode 
              ? 'VIEW CHEQUE' 
              : widget.isEditMode 
                  ? 'EDIT CHEQUE' 
                  : 'NEW CHEQUE',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCustomerField(),
                  const SizedBox(height: 16),
                  _buildDateField(),
                  const SizedBox(height: 16),
                  _buildChequeNumberField(),
                  const SizedBox(height: 16),
                  _buildAmountField(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0,
      ),
    );
  }
}