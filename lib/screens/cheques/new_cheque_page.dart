import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../common/bottom_navigation_button.dart';

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
  final TextEditingController _customerSearchController = TextEditingController(); 
  
  List<String> customerNames = [];
  List<String> filteredCustomerNames = []; 
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  bool isLoading = false;
  
  String? chequeId;
  bool _dataInitialized = false;
  
  bool _showCustomerDropdown = false;
  final FocusNode _customerFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    _chequeDateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _customerSearchController.addListener(_filterCustomers);
    _customerFocusNode.addListener(_onCustomerFocusChange);
    _initializeData();
  }

  @override
  void dispose() {
    _customerSearchController.removeListener(_filterCustomers); 
    _customerSearchController.dispose();
    _customerFocusNode.removeListener(_onCustomerFocusChange); 
    _customerFocusNode.dispose();
    _chequeDateController.dispose();
    _chequeNoController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onCustomerFocusChange() {
    setState(() {
      _showCustomerDropdown = _customerFocusNode.hasFocus && filteredCustomerNames.isNotEmpty;
    });
  }

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
      await loadCustomers();

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
    
    // Initialize cheque ID - handle both 'chequeId' and 'chqid' keys
    chequeId = existingCheque['chequeId'] ?? existingCheque['chqid'];
    
    String customerName = existingCheque['customerName'] ?? existingCheque['cust_name'] ?? '';
    if (customerName.isNotEmpty) {
      _customerSearchController.text = customerName; 
      
      if (customerNames.contains(customerName)) {
        selectedCustomer = customerName;
        selectedCustId = customerIdMap[customerName];
      } else {
        setState(() {
          customerNames.add(customerName);
          String tempCustId = existingCheque['custId'] ?? existingCheque['custid'] ?? '';
          if (tempCustId.isNotEmpty) {
            customerIdMap[customerName] = tempCustId;
            selectedCustId = tempCustId;
          }
          selectedCustomer = customerName;
        });
      }
    }
    
    _chequeNoController.text = existingCheque['chequeNo'] ?? existingCheque['chq_no'] ?? '';
    
    // Handle amount field
    var amount = existingCheque['amount'] ?? existingCheque['chq_amt'];
    _amountController.text = amount?.toString() ?? '';
    
    // Handle date field
    String chequeDate = existingCheque['chequeDate'] ?? existingCheque['chq_date'] ?? '';
    if (chequeDate.isNotEmpty) {
      try {
        DateTime parsedDate;
        if (chequeDate.contains('-')) {
          if (chequeDate.split('-')[0].length == 2) {
            _chequeDateController.text = chequeDate;
          } else {
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
        filteredCustomerNames = List.from(customerNames);
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
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return {"result": "0", "message": "Please fill all required fields"};
    }

    // Validate customer selection
    if (selectedCustomer == null || selectedCustId == null) {
      _showError('Customer must be selected.');
      return {"result": "0", "message": "Customer must be selected"};
    }

    // Validate required fields
    if (_chequeNoController.text.trim().isEmpty) {
      _showError('Cheque number is required.');
      return {"result": "0", "message": "Cheque number is required"};
    }

    if (_amountController.text.trim().isEmpty) {
      _showError('Amount is required.');
      return {"result": "0", "message": "Amount is required"};
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
        return {"result": "0", "message": "Missing credentials"};
      }
      
      // Prepare request body according to your API structure
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "custid": selectedCustId!,
        "cust_name": selectedCustomer!.toLowerCase(),
        "chq_no": _chequeNoController.text.trim(),
        "chq_date": _chequeDateController.text.trim(),
        "chq_amt": _amountController.text.trim(),
      };

      if (widget.isEditMode && chequeId != null && chequeId!.isNotEmpty) {
        requestBody["action"] = "update";
        requestBody["chqid"] = chequeId!;
      } else {
        requestBody["action"] = "insert";
      }
      
      debugPrint('Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$url/action/cheques.php'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final result = json.decode(response.body);
          
          if (result["result"] == "1" || result["result"] == 1) {
            String successMessage = widget.isEditMode 
                ? (result["message"] ?? "Cheque updated successfully!")
                : (result["message"] ?? "Cheque saved successfully!");
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(successMessage),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            
            Navigator.pop(context, result);
            return result;
          } else {
            String errorMessage = result["message"] ?? "Failed to save cheque.";
            _showError(errorMessage);
            return {"result": "0", "message": errorMessage};
          }
        } catch (jsonError) {
          debugPrint('JSON parsing error: $jsonError');
          _showError("Invalid response format from server.");
          return {"result": "0", "message": "Invalid response format"};
        }
      } else {
        String errorMessage = "Server error: ${response.statusCode}";
        _showError(errorMessage);
        return {"result": "0", "message": errorMessage};
      }
    } catch (e) {
      debugPrint('Error saving cheque: $e');
      String errorMessage = "Network error: ${e.toString()}";
      _showError(errorMessage);
      return {"result": "0", "message": errorMessage};
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
        duration: Duration(seconds: 4),
      ),
    );
  }

  Widget _buildCustomerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Customer Name *', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.isViewMode
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text(
                    selectedCustomer?.isNotEmpty == true ? selectedCustomer! : 'Not specified',
                    style: const TextStyle(fontSize: 13),
                  ),
                )
              : Column(
                  children: [
                    TextField(
                      controller: _customerSearchController,
                      focusNode: _customerFocusNode,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        hintText: 'Type to search customer...',
                        hintStyle: TextStyle(fontSize: 13),
                        suffixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                      ),
                      onChanged: (value) {
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
                    if (_showCustomerDropdown && filteredCustomerNames.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 120),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                    const Icon(Icons.person, color: Colors.grey, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        customerName,
                                        style: const TextStyle(fontSize: 12),
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
            padding: EdgeInsets.only(top: 6.0, left: 10.0),
            child: Text(
              'Please select a customer',
              style: TextStyle(color: Colors.red, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cheque Date *', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
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
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              suffixIcon: widget.isViewMode 
                  ? null 
                  : IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
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
        const Text('Cheque Number *', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: _chequeNoController,
            readOnly: widget.isViewMode,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              hintText: 'Enter cheque number',
              hintStyle: TextStyle(fontSize: 13),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Cheque number is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amount *', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextFormField(
            controller: _amountController,
            readOnly: widget.isViewMode,
            style: const TextStyle(fontSize: 13),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              hintText: 'Enter amount',
              hintStyle: TextStyle(fontSize: 13),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Amount is required';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'Enter valid amount';
              }
              return null;
            },
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
          height: 46,
          child: ElevatedButton(
            onPressed: isLoading ? null : _saveCheque,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: isLoading 
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    widget.isEditMode ? 'UPDATE' : 'SAVE', 
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
        const SizedBox(height: 12),
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
                    ? 'Edit Cheque' 
                    : 'New Cheque',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text('Loading cheque data...', style: TextStyle(fontSize: 12)),
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
                  ? 'Edit Cheque' 
                  : 'New Cheque',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCustomerField(),
                  const SizedBox(height: 12),
                  _buildDateField(),
                  const SizedBox(height: 12),
                  _buildChequeNumberField(),
                  const SizedBox(height: 12),
                  _buildAmountField(),
                  const SizedBox(height: 18),
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