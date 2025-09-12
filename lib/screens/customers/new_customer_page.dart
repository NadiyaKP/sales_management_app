import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sales_management_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/permission.dart';

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
    
    if (data['balance'] != null && data['balance'].toString().isNotEmpty) {
      String balanceStr = data['balance'].toString();
      balanceStr = balanceStr.replaceAll(',', '').replaceAll('₹', '').trim();
      double balance = double.tryParse(balanceStr) ?? 0.0;
      _balanceController.text = balance.toInt().toString();
    }
    
    _balanceType = data['balanceType'] ?? 'dr';
  }

  void _setDefaultValues() {
    _balanceType = 'dr';
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
      print('========== FETCH PERMISSIONS API REQUEST ==========');
      print('Calling apiService.fetchPermissionDetails()');
      
      final apiService = ApiServices();
      final permissionData = await apiService.fetchPermissionDetails();

      print('========== FETCH PERMISSIONS API RESPONSE ==========');
      if (permissionData == null) {
        print('Response: null');
        throw Exception('Failed to fetch permissions: Data is null.');
      } else {
        print('Response received with ${permissionData.permissionDetails.length} permission details');
        for (int i = 0; i < permissionData.permissionDetails.length; i++) {
          print('Permission Detail $i: ${permissionData.permissionDetails[i].toString()}');
        }
      }
      print('=================================================');

      if (permissionData.permissionDetails.isEmpty) {
        throw Exception('Received empty permissions data from the API.');
      }

      return permissionData;
    } catch (e) {
      print('========== FETCH PERMISSIONS API ERROR ==========');
      print('Error: $e');
      print('============================================');
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
        
        print('========== PERMISSIONS LOADED ==========');
        print('Customer Add: $customerAdd');
        print('Customer Edit: $customerEdit');
        print('Customer Status: $customerStatus');
        print('Customer View: $customerView');
        print('=======================================');
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }

  Future<void> loadCustomerTypes() async {
    try {
      print('========== FETCH CUSTOMER TYPES API REQUEST ==========');
      print('Calling apiServices.fetchCustomersType()');
      
      List<Map<String, String>> customerType = await apiServices.fetchCustomersType();
      
      print('========== FETCH CUSTOMER TYPES API RESPONSE ==========');
      print('Response: $customerType');
      print('Number of customer types: ${customerType.length}');
      for (int i = 0; i < customerType.length; i++) {
        print('Customer Type $i: ${customerType[i]}');
      }
      print('======================================================');
      
      setState(() {
        customerTypes = customerType.map((e) => e["custtype_name"]!).toList();
        customerTypeIdMap = {for (var e in customerType) e["custtype_name"]!: e["custtypeid"]!};
        
        if (widget.isEditing && selectedType != null && customerTypeIdMap.containsKey(selectedType)) {
          selectedTypeId = customerTypeIdMap[selectedType];
        }
      });
      
      print('========== CUSTOMER TYPES PROCESSED ==========');
      print('Customer Types List: $customerTypes');
      print('Customer Type ID Map: $customerTypeIdMap');
      print('Selected Type: $selectedType');
      print('Selected Type ID: $selectedTypeId');
      print('=============================================');
    } catch (e) {
      print('========== FETCH CUSTOMER TYPES API ERROR ==========');
      print('Error: $e');
      print('===================================================');
      _showError(e.toString());
    }
  }

  Future<Map<String, dynamic>> _saveCustomerData(String action) async {
    try {
      print('========== SAVE CUSTOMER API REQUEST ==========');
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      print('Credentials from SharedPreferences:');
      print('URL: $url');
      print('UNID: $unid');
      print('SLEX: $slex');

      if (url == null || unid == null || slex == null) {
        print('Missing credentials - returning error');
        return {"result": "0", "message": "Missing credentials"};
      }

      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "action": action,
        "cust_name": _nameController.text.trim(),  
        "cust_type": selectedTypeId ?? "",
        "address": _addressController.text.trim(),
        "gst_number": _gstController.text.trim(), 
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "land_phone": _landPhoneController.text.trim(),
        "op_bln": _balanceController.text.trim().isEmpty ? "0" : _balanceController.text.trim(),
        "state": _stateController.text.trim(),
        "state_code": _stateCodeController.text.trim(),
        "credit_days": _creditDaysController.text.trim().isEmpty ? "35" : _creditDaysController.text.trim(),
        "op_acc": _balanceType,
        "status": "active",  
      };

      if (_balanceController.text.trim().isNotEmpty) {
        double balanceValue = double.tryParse(_balanceController.text.trim()) ?? 0.0;
        String balanceType = _balanceType.toUpperCase() == 'DR' ? 'Dr' : 'Cr';
        requestBody["balance"] = "${balanceValue.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
          (Match m) => '${m[1]},'
        )} $balanceType";
      }

      if (action == 'update' && widget.customerData != null) {
        if (widget.customerData!['custId'] != null) {
          requestBody["cust"] = widget.customerData!['custId'];
        } else if (widget.customerData!['cust'] != null) {
          requestBody["cust"] = widget.customerData!['cust'];
        }
      }

      String apiUrl = '$url/action/customers.php';
      print('API Endpoint: $apiUrl');
      print('Request Headers: {"Content-Type": "application/json"}');
      print('Request Body: ${jsonEncode(requestBody)}');
      print('============================================');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print('========== SAVE CUSTOMER API RESPONSE ==========');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Body: ${response.body}');
      print('===============================================');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        print('========== PARSED RESPONSE DATA ==========');
        print('Parsed Response: $responseData');
        print('Result: ${responseData['result']}');
        print('Message: ${responseData['message']}');
        print('========================================');
        return responseData;
      } else {
        print('========== API ERROR RESPONSE ==========');
        print('Failed with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        print('=====================================');
        return {"result": "0", "message": "Failed to save customer"};
      }
    } catch (e) {
      print('========== SAVE CUSTOMER API EXCEPTION ==========');
      print('Exception: $e');
      print('Exception Type: ${e.runtimeType}');
      print('Stack Trace: ${StackTrace.current}');
      print('===============================================');
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      if (selectedTypeId == null || selectedTypeId!.isEmpty) {
        _showError('Please select a customer type');
        return;
      }

      if (_nameController.text.trim().isEmpty) {
        _showError('Customer name cannot be empty');
        return;
      }

      setState(() {
        isLoading = true;
      });

      String action = widget.isEditing ? 'update' : 'insert';
      
      print('========== SAVE CUSTOMER INITIATED ==========');
      print('Action: $action');
      print('Is Editing: ${widget.isEditing}');
      print('Customer Data: ${widget.customerData}');
      print('Form Data:');
      print('  Name: ${_nameController.text.trim()}');
      print('  Type: $selectedType ($selectedTypeId)');
      print('  GST: ${_gstController.text.trim()}');
      print('  Phone: ${_phoneController.text.trim()}');
      print('  Email: ${_emailController.text.trim()}');
      print('  Land Phone: ${_landPhoneController.text.trim()}');
      print('  Address: ${_addressController.text.trim()}');
      print('  State: ${_stateController.text.trim()}');
      print('  State Code: ${_stateCodeController.text.trim()}');
      print('  Credit Days: ${_creditDaysController.text.trim()}');
      print('  Balance: ${_balanceController.text.trim()}');
      print('  Balance Type: $_balanceType');
      print('===========================================');
      
      Map<String, dynamic> result = await _saveCustomerData(action);

      setState(() {
        isLoading = false;
      });

      print('========== SAVE CUSTOMER RESULT ==========');
      print('Final Result: $result');
      print('Success: ${result['result'] == '1'}');
      print('Message: ${result['message']}');
      print('========================================');

      if (result['result'] == '1') {
        _showSuccess(result['message'] ?? 'Customer saved successfully');
        
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
        
        if (widget.isEditing && widget.customerData != null) {
          customerData['custId'] = widget.customerData!['custId'];
        }
        
        print('========== RETURNING CUSTOMER DATA ==========');
        print('Customer Data to return: $customerData');
        print('===========================================');
        
        Navigator.pop(context, customerData);
      } else {
        _showError(result['message'] ?? 'Failed to save customer');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    print('========== SHOWING ERROR ==========');
    print('Error Message: $message');
    print('=================================');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    print('========== SHOWING SUCCESS ==========');
    print('Success Message: $message');
    print('===================================');
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: const OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 13)),
        )).toList(),
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(
            fontSize: 13,
            color: readOnly ? Colors.grey[600] : null,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 12),
            border: const OutlineInputBorder(),
            alignLabelWithHint: maxLines > 1,
            filled: readOnly,
            fillColor: readOnly ? Colors.grey[200] : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
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
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 50,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildDropdownField(
                      'Type of Customer',
                      selectedType,
                      customerTypes,
                      (value) {
                        setState(() {
                          selectedType = value;
                          selectedTypeId = customerTypeIdMap[value];
                        });
                        print('========== DROPDOWN SELECTION CHANGED ==========');
                        print('Selected Type: $selectedType');
                        print('Selected Type ID: $selectedTypeId');
                        print('==============================================');
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a customer type';
                        }
                        return null;
                      },
                    ),

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

                    _buildTextField('GST Number', _gstController),

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

                    _buildTextField(
                      'Address',
                      _addressController,
                      maxLines: 2,
                    ),

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
                          readOnly: widget.isEditing,
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
                          readOnly: widget.isEditing,
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
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                child: TextFormField(
                                  controller: _balanceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                                  ],
                                  readOnly: widget.isEditing,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Opening Balance',
                                    labelStyle: TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    isDense: true,
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
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Dr', style: TextStyle(fontSize: 12)),
                                        value: 'dr',
                                        groupValue: _balanceType,
                                        onChanged: (value) {
                                          setState(() {
                                            _balanceType = value!;
                                          });
                                          print('========== BALANCE TYPE CHANGED ==========');
                                          print('Balance Type: $_balanceType');
                                          print('========================================');
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    Expanded(
                                      child: RadioListTile<String>(
                                        title: const Text('Cr', style: TextStyle(fontSize: 12)),
                                        value: 'cr',
                                        groupValue: _balanceType,
                                        onChanged: (value) {
                                          setState(() {
                                            _balanceType = value!;
                                          });
                                          print('========== BALANCE TYPE CHANGED ==========');
                                          print('Balance Type: $_balanceType');
                                          print('========================================');
                                        },
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
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

                    const SizedBox(height: 16),

                    SizedBox(
                      height: 45,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.isEditing ? 'UPDATE' : 'SAVE',
                                style: const TextStyle(
                                  fontSize: 14,
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

double parseFormattedAmount(String formattedAmount) {
  final cleanString = formattedAmount.replaceAll(',', '');
  return double.tryParse(cleanString) ?? 0.0;
}