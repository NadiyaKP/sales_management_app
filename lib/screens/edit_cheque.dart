import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../common/bottom_navigation_button.dart';

class EditChequePage extends StatefulWidget {
  final Map<String, dynamic> chequeData;

  const EditChequePage({
    Key? key,
    required this.chequeData,
  }) : super(key: key);

  @override
  State<EditChequePage> createState() => _EditChequePageState();
}

class _EditChequePageState extends State<EditChequePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _chequeDateController = TextEditingController();
  final TextEditingController _chequeNoController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController(); // NEW: Customer search controller

  // Customer data
  List<String> customerNames = [];
  List<String> filteredCustomerNames = []; // NEW: Filtered customer names
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  bool isLoading = false;
  bool _isLoadingCustomers = true;
  ApiServices apiServices = ApiServices();

  // NEW: Customer dropdown state
  bool _showCustomerDropdown = false;
  final FocusNode _customerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _customerSearchController.addListener(_filterCustomers); // NEW: Add customer filter listener
    _customerFocusNode.addListener(_onCustomerFocusChange); // NEW: Add focus listener
    _initializeData();
  }

  @override
  void dispose() {
    _chequeDateController.dispose();
    _chequeNoController.dispose();
    _amountController.dispose();
    _customerSearchController.removeListener(_filterCustomers); // NEW: Remove customer filter listener
    _customerSearchController.dispose(); // NEW: Dispose customer search controller
    _customerFocusNode.removeListener(_onCustomerFocusChange); // NEW: Remove focus listener
    _customerFocusNode.dispose(); // NEW: Dispose focus node
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
      await _loadCustomers();

      // Then initialize form fields
      _initializeForm();
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCustomers() async {
    try {
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      setState(() {
        customerNames = customers.map((e) => e["cust_name"]!).toList();
        customerIdMap = {
          for (var e in customers) e["cust_name"]!: e["custid"]!
        };
        filteredCustomerNames = List.from(customerNames); // NEW: Initialize filtered list
        _isLoadingCustomers = false;
      });
    } catch (e) {
      _showError('Failed to load customers: $e');
      setState(() {
        _isLoadingCustomers = false;
      });
    }
  }

  void _initializeForm() {
    // Initialize form fields with existing cheque data
    _chequeNoController.text = widget.chequeData['chq_no'] ?? '';
    _amountController.text = _parseAmount(widget.chequeData['chq_amt'] ?? '');

    // Parse and format the date
    String dateStr = widget.chequeData['chq_date'] ?? '';
    if (dateStr.isNotEmpty) {
      try {
        DateTime parsedDate;
        if (dateStr.contains('/')) {
          parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
        } else {
          parsedDate = DateFormat('dd-MM-yyyy').parse(dateStr);
        }
        _chequeDateController.text = DateFormat('dd-MM-yyyy').format(parsedDate);
      } catch (e) {
        _chequeDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
      }
    } else {
      _chequeDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    }

    // Set customer data
    String customerName = widget.chequeData['custname'] ?? '';
    if (customerName.isNotEmpty) {
      _customerSearchController.text = customerName; // NEW: Set customer search controller
      
      // Check if customer exists in the loaded customers
      if (customerNames.contains(customerName)) {
        setState(() {
          selectedCustomer = customerName;
          selectedCustId = customerIdMap[customerName];
        });
      } else {
        // If customer doesn't exist in dropdown, add it temporarily
        setState(() {
          customerNames.add(customerName);
          String tempCustId = widget.chequeData['custid'] ?? '';
          if (tempCustId.isNotEmpty) {
            customerIdMap[customerName] = tempCustId;
            selectedCustId = tempCustId;
          }
          selectedCustomer = customerName;
        });
      }
    }
  }

  String _parseAmount(String amount) {
    return amount.replaceAll(',', '').replaceAll('₹', '').trim();
  }

  Future<void> _selectDate(BuildContext context) async {
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
            colorScheme: const ColorScheme.light(
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

  Future<void> _updateCheque() async {
    // Ensure customer is selected
    if (selectedCustomer == null || selectedCustId == null) {
      _showError('Customer must be selected.');
      return;
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
        return;
      }
      
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "action": "update",
        "chqid": widget.chequeData['chqid'] ?? '',
        "custid": selectedCustId ?? '',
        "cust_name": selectedCustomer ?? '',
        "chq_no": _chequeNoController.text.trim(),
        "chq_date": _chequeDateController.text.trim(),
        "chq_amt": _amountController.text.trim(),
      };

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
          _showSuccessMessage('Cheque updated successfully!');
          Navigator.pop(context, true);
        } else {
          _showError(result["message"] ?? "Failed to update cheque.");
        }
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error updating cheque: $e');
      _showError("Network error: $e");
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

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
          child: _isLoadingCustomers
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Loading customers...'),
                    ],
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
        if (selectedCustomer == null && !_isLoadingCustomers)
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
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
              ),
            ),
            onTap: () => _selectDate(context),
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

  @override
  Widget build(BuildContext context) {
    if (isLoading && _isLoadingCustomers) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: const Text(
            'EDIT CHEQUE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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
        title: const Text(
          'EDIT CHEQUE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _updateCheque,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'UPDATE CHEQUE', 
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                            ),
                    ),
                  ),
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