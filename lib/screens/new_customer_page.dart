import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sales_management_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../services/permission.dart';
//permission
String customerAdd = '';
String customerView = '';
String customerEdit = '';
String customerStatus = '';

class NewCustomerPage extends StatefulWidget {
  final bool isEditing;
  final String? custId;
  final Map<String, dynamic>? customerData;

  const NewCustomerPage({
    Key? key,
    this.isEditing = false,
    this.custId,
    this.customerData,
  }) : super(key: key);

  @override
  State<NewCustomerPage> createState() => _NewCustomerPageState();
}

class _NewCustomerPageState extends State<NewCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  ApiServices apiServices = ApiServices();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _gstController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _landPhoneController;
  late TextEditingController _addressController;
  late TextEditingController _stateController;
  late TextEditingController _stateCodeController;
  late TextEditingController _creditDaysController;
  late TextEditingController _balanceController;

  // State variables
  String? selectedType;
  String? selectedTypeId;
  String _balanceType = 'dr';
  bool isLoading = false;
  
  List<String> customerTypes = [];
  Map<String, String> customerTypeIdMap = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPermissions();
    loadCustomerTypes();
    
    if (widget.isEditing && widget.customerData != null) {
      _populateFields();
    } else {
      _setDefaultValues();
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _gstController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _landPhoneController = TextEditingController();
    _addressController = TextEditingController();
    _stateController = TextEditingController();
    _stateCodeController = TextEditingController();
    _creditDaysController = TextEditingController();
    _balanceController = TextEditingController();
  }

void _populateFields() {
  final data = widget.customerData!;
  
  // Debug prints
  print("Populating fields with data: $data");
  print("Customer name from data: '${data['name']}'");
  
  _nameController.text = data['name'] ?? '';
  selectedType = data['typeName'] ?? '';
  selectedTypeId = data['typeofCustomer'] ?? '';
  _gstController.text = data['gst'] ?? '';
  _phoneController.text = data['phone'] ?? '';
  _emailController.text = data['email'] ?? '';
  _landPhoneController.text = data['landPhone'] ?? '';
  _addressController.text = data['address'] ?? '';
  _stateController.text = data['state'] ?? '';
  _stateCodeController.text = data['stateCode'] ?? '';
  _creditDaysController.text = data['creditDays'] ?? '';
  
  // Handle balance field
  if (data['balance'] != null && data['balance'].toString().isNotEmpty) {
    String balanceStr = data['balance'].toString();
    // Remove any formatting and parse
    balanceStr = balanceStr.replaceAll(',', '').replaceAll('₹', '').trim();
    double balance = double.tryParse(balanceStr) ?? 0.0;
    _balanceController.text = balance.toInt().toString();
  }
  
  _balanceType = data['balanceType'] ?? 'dr';
  
  // Debug prints after population
  print("Name controller after population: '${_nameController.text}'");
  print("Selected type: '$selectedType'");
  print("Selected type ID: '$selectedTypeId'");
}

  void _setDefaultValues() {
    _balanceType = 'dr';
    _stateController.text = 'Kerala';
    _stateCodeController.text = '32';
    _creditDaysController.text = '35';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gstController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _landPhoneController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _stateCodeController.dispose();
    _creditDaysController.dispose();
    _balanceController.dispose();
    super.dispose();
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
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }

  Future<void> loadCustomerTypes() async {
    try {
      List<Map<String, String>> customerType = await apiServices.fetchCustomersType();
      setState(() {
        customerTypes = customerType.map((e) => e["custtype_name"]!).toList();
        customerTypeIdMap = {for (var e in customerType) e["custtype_name"]!: e["custtypeid"]!};
        
        // Set selectedTypeId if editing and selectedType is already set
        if (widget.isEditing && selectedType != null && customerTypeIdMap.containsKey(selectedType)) {
          selectedTypeId = customerTypeIdMap[selectedType];
        }
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

Future<Map<String, dynamic>> _saveCustomerData(String action) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    if (url == null || unid == null || slex == null) {
      return {"result": "0", "message": "Missing credentials"};
    }

    // Debug print to check if customer name is present
    print("Customer name being sent: '${_nameController.text}'");
    print("Action: $action");

    // Build request body based on the Postman examples
    Map<String, dynamic> requestBody = {
      "unid": unid,
      "slex": slex,
      "action": action,
      "cust_name": _nameController.text.trim(),  // Changed from "custname" to "cust_name"
      "cust_type": selectedTypeId ?? "",
      "address": _addressController.text.trim(),
      "gst_number": _gstController.text.trim(),  // Changed from "gst" to "gst_number"
      "phone": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
      "land_phone": _landPhoneController.text.trim(),
      "op_bln": _balanceController.text.trim().isEmpty ? "0" : _balanceController.text.trim(),
      "state": _stateController.text.trim(),
      "state_code": _stateCodeController.text.trim(),
      "credit_days": _creditDaysController.text.trim().isEmpty ? "35" : _creditDaysController.text.trim(),
      "op_acc": _balanceType,
      "status": "active",  // Added status field as shown in Postman
    };

    // Add balance field with formatting as shown in Postman
    if (_balanceController.text.trim().isNotEmpty) {
      double balanceValue = double.tryParse(_balanceController.text.trim()) ?? 0.0;
      String balanceType = _balanceType.toUpperCase() == 'DR' ? 'Dr' : 'Cr';
      requestBody["balance"] = "${balanceValue.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
        (Match m) => '${m[1]},'
      )} $balanceType";
    }

    // Add customer ID for update action (based on Postman example showing "cust": "NDI-")
    if (action == 'update' && widget.customerData != null) {
      if (widget.customerData!['custId'] != null) {
        // If you have the full customer ID, use it directly
        requestBody["cust"] = widget.customerData!['custId'];
      } else if (widget.customerData!['cust'] != null) {
        // If you have the cust field from the data
        requestBody["cust"] = widget.customerData!['cust'];
      }
    }

    // Debug print the full request body
    print("Request body: ${jsonEncode(requestBody)}");

    final response = await http.post(
      Uri.parse('$url/action/customers.php'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestBody),
    );

    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {"result": "0", "message": "Failed to save customer"};
    }
  } catch (e) {
    print("Error in _saveCustomerData: $e");
    return {"result": "0", "message": "Network error: $e"};
  }
}

  void _saveCustomer() async {
  if (_formKey.currentState!.validate()) {
    if (selectedTypeId == null || selectedTypeId!.isEmpty) {
      _showError('Please select a customer type');
      return;
    }

    // Additional validation for customer name
    if (_nameController.text.trim().isEmpty) {
      _showError('Customer name cannot be empty');
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Use the exact action values from Postman examples
    String action = widget.isEditing ? 'update' : 'insert';
    
    Map<String, dynamic> result = await _saveCustomerData(action);

    setState(() {
      isLoading = false;
    });

    if (result['result'] == '1') {
      _showSuccess(result['message'] ?? 'Customer saved successfully');
      
      // Return the updated customer data to the previous screen
      Map<String, dynamic> customerData = {
        'name': _nameController.text.trim(),
        'type': selectedTypeId,
        'gst': _gstController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'landPhone': _landPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'state': _stateController.text.trim(),
        'stateCode': _stateCodeController.text.trim(),
        'creditDays': _creditDaysController.text.trim(),
        'balance': double.tryParse(_balanceController.text.trim()) ?? 0.0,
        'balanceType': _balanceType,
      };
      
      // Add custId if editing
      if (widget.isEditing && widget.customerData != null) {
        customerData['custId'] = widget.customerData!['custId'];
      }
      
      Navigator.pop(context, customerData);
    } else {
      _showError(result['message'] ?? 'Failed to save customer');
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

  Widget _buildTextField(
    String label, 
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item),
        )).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildRowTextField(
    String label, 
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
    double flex = 1.0,
  }) {
    return Expanded(
      flex: flex.toInt(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          readOnly: readOnly,
          style: readOnly ? TextStyle(color: Colors.grey[600]) : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            alignLabelWithHint: maxLines > 1,
            filled: readOnly,
            fillColor: readOnly ? Colors.grey[200] : null,
          ),
          validator: validator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Customer' : 'Add Customer',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Customer Type Dropdown
                    _buildDropdownField(
                      'Type of Customer',
                      selectedType,
                      customerTypes,
                      (value) {
                        setState(() {
                          selectedType = value;
                          selectedTypeId = customerTypeIdMap[value];
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a customer type';
                        }
                        return null;
                      },
                    ),

                    // Customer Name
                    _buildTextField(
                      'Customer Name',
                      _nameController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Customer name is required';
                        }
                        return null;
                      },
                    ),

                    // GST Number
                    _buildTextField('GST Number', _gstController),

                    // Email
                    _buildTextField(
                      'Email',
                      _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),

                    // Phone Number
                    _buildTextField(
                      'Phone Number',
                      _phoneController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                            return 'Enter a valid phone number (10-15 digits)';
                          }
                        }
                        return null;
                      },
                    ),

                    // Land Phone Number
                    _buildTextField(
                      'Land Phone Number',
                      _landPhoneController,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!RegExp(r'^\+?[0-9\s\-()]{8,15}$').hasMatch(value)) {
                            return 'Enter a valid landline number';
                          }
                        }
                        return null;
                      },
                    ),

                    // Address
                    _buildTextField(
                      'Address',
                      _addressController,
                      maxLines: 3,
                    ),

                    // State and State Code Row
                    Row(
                      children: [
                        _buildRowTextField(
                          'State',
                          _stateController,
                          flex: 2.0,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'State is required';
                            }
                            return null;
                          },
                        ),
                        _buildRowTextField(
                          'State Code',
                          _stateCodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                          ],
                          flex: 1.0,
                          readOnly: widget.isEditing, // Make non-editable when editing
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a number';
                            }
                            if (num.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    // Credit Days and Opening Balance Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRowTextField(
                          'No of Credit Days',
                          _creditDaysController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                          ],
                          readOnly: widget.isEditing, // Make non-editable when editing
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a number';
                            }
                            if (num.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: TextFormField(
                                  controller: _balanceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                  ],
                                  readOnly: widget.isEditing,
                                  decoration: const InputDecoration(
                                    labelText: 'Opening Balance',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return null;
                                    }

                                    final number = double.tryParse(value);
                                    if (number == null) {
                                      return 'Please enter a valid amount';
                                    }

                                    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
                                      return 'Enter a valid amount with up to 2 decimal places';
                                    }

                                    return null;
                                  },
                                ),
                              ),
                              // Balance Type Radio Buttons
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Dr'),
                                        value: 'dr',
                                        groupValue: _balanceType,
                                        onChanged: (value) {
                                          setState(() {
                                            _balanceType = value!;
                                          });
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Cr'),
                                        value: 'cr',
                                        groupValue: _balanceType,
                                        onChanged: (value) {
                                          setState(() {
                                            _balanceType = value!;
                                          });
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF022E44),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                widget.isEditing ? 'Update Customer' : 'Save Customer',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Helper function to parse formatted amounts
double parseFormattedAmount(String formattedAmount) {
  final cleanString = formattedAmount.replaceAll(',', '');
  return double.tryParse(cleanString) ?? 0.0;
}