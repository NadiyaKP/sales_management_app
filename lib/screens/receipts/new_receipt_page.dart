import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../home_page.dart';
import '../report_page.dart';
import 'receipts_page.dart';

class NewReceiptPage extends StatefulWidget {
  final Map<String, dynamic>? editData;
  
  const NewReceiptPage({super.key, this.editData});

  @override
  State<NewReceiptPage> createState() => _NewReceiptPageState();
}

class _NewReceiptPageState extends State<NewReceiptPage> {
  final _formKey = GlobalKey<FormState>();
  ApiServices apiServices = ApiServices();

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _dueAmountController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _paymentMethod;
  String? _selectedCustomerId;
  String? _selectedWalletId;
  bool _isCustomerDropdownOpen = false;
  bool _isWalletDropdownOpen = false;
  bool _isEditing = false;
  bool _isLoading = false;
  int _selectedIndex = 2; 
  
  // API Data
  List<Map<String, String>> _customers = [];
  List<Map<String, String>> _wallets = [];
  Map<String, String> customerIdMap = {};
  Map<String, String> customerAmountMap = {};
  Map<String, String> walletIdMap = {};
  Map<String, String> walletNameMap = {}; 
  
  // Filtered lists for search
  List<Map<String, String>> _filteredCustomers = [];
  List<Map<String, String>> _filteredWallets = [];

  // Permission variables
  String receiptAdd = '';
  String receiptDueAmount = '';
  String receiptDateChange = '';
  String receiptEdit = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadPermissions();
      await _loadCustomers();
      await _loadWallets();
      // Initialize edit data after all data is loaded
      _initializeWithEditData();
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final permissionResponse = await _fetchPermissions();
      if (permissionResponse.permissionDetails.isNotEmpty) {
        setState(() {
          final permissionDetail = permissionResponse.permissionDetails[0];
          receiptAdd = permissionDetail.receiptAdd;
          receiptDueAmount = permissionDetail.receiptDueAmount;
          receiptDateChange = permissionDetail.receiptDateChange;
          receiptEdit = permissionDetail.receiptEdit;
        });
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
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

  Future<void> _loadCustomers() async {
    try {
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      setState(() {
        _customers = customers;
        _filteredCustomers = List.from(_customers);
        customerIdMap = {for (var e in customers) e["cust_name"]!: e["custid"]!};
        customerAmountMap = {for (var e in customers) e["cust_name"]!: e["outstand_amt"]!};
      });
    } catch (e) {
      _showError('Failed to load customers: $e');
    }
  }

  Future<void> _loadWallets() async {
    try {
      List<Map<String, String>> wallets = await apiServices.fetchWallets();
      setState(() {
        _wallets = wallets;
        _filteredWallets = List.from(_wallets);
        walletIdMap = {for (var e in wallets) e["wlt_name"]!: e["wltid"]!};
        walletNameMap = {for (var e in wallets) e["wltid"]!: e["wlt_name"]!}; // Added reverse mapping
      });
    } catch (e) {
      _showError('Failed to load wallets: $e');
    }
  }
  
  void _initializeWithEditData() {
    if (widget.editData != null) {
      setState(() {
        _isEditing = true;
        
        // Populate customer data
        final customerName = widget.editData!['customerName'] ?? '';
        _customerNameController.text = customerName;
        
        // Set customer ID - try from edit data first, then from map
        _selectedCustomerId = widget.editData!['custId'];
        if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
          _selectedCustomerId = customerIdMap[customerName];
        }
        
        // Find and set the current due amount for the selected customer
        String dueAmount = '0';
        if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
          // Find customer by ID to get current due amount
          final customerData = _customers.firstWhere(
            (customer) => customer['custid'] == _selectedCustomerId,
            orElse: () => <String, String>{},
          );
          if (customerData.isNotEmpty) {
            dueAmount = customerData['outstand_amt'] ?? '0';
          }
        } else if (customerName.isNotEmpty) {
          // Fallback: find by name
          dueAmount = customerAmountMap[customerName] ?? '0';
          // Also set the customer ID if found by name
          _selectedCustomerId = customerIdMap[customerName];
        }
        
        _dueAmountController.text = dueAmount;
        
        // Set date - parse from the format received from API
        if (widget.editData!['receivedDate'] != null) {
          try {
            String dateStr = widget.editData!['receivedDate'];
            // Handle both ISO format and dd-MM-yyyy format
            if (dateStr.contains('-') && dateStr.length > 10) {
              _selectedDate = DateTime.parse(dateStr);
            } else {
              // Parse dd-MM-yyyy format
              _selectedDate = DateFormat('dd-MM-yyyy').parse(dateStr);
            }
          } catch (e) {
            _selectedDate = DateTime.now();
          }
        }
        
        // Set amount
        _amountController.text = widget.editData!['receivedAmount'] ?? '';
        
        // Set wallet/payment method - improved logic with better validation
        String? walletId = widget.editData!['walletId'];
        String? paymentMethodName = widget.editData!['paymentMethod'];
        
        if (walletId != null && walletId.isNotEmpty) {
          // If we have wallet ID, use it and find the corresponding name
          _selectedWalletId = walletId;
          String? walletName = walletNameMap[walletId];
          if (walletName != null) {
            _paymentMethod = walletName;
          } else {
            // Fallback to provided payment method name
            _paymentMethod = paymentMethodName;
          }
        } else if (paymentMethodName != null && paymentMethodName.isNotEmpty) {
          // If we only have payment method name, find the corresponding ID
          _paymentMethod = paymentMethodName;
          String? walletId = walletIdMap[paymentMethodName];
          if (walletId != null) {
            _selectedWalletId = walletId;
          } else {
            // Search for wallet with case-insensitive matching
            for (var wallet in _wallets) {
              if (wallet['wlt_name']?.toLowerCase() == paymentMethodName.toLowerCase()) {
                _selectedWalletId = wallet['wltid'];
                _paymentMethod = wallet['wlt_name'];
                break;
              }
            }
          }
        }
        
        // If still not found, set the first available wallet as fallback for edit mode
        if ((_selectedWalletId == null || _selectedWalletId!.isEmpty) && _wallets.isNotEmpty) {
          debugPrint('Warning: Could not find matching wallet, using first available');
          _selectedWalletId = _wallets.first['wltid'];
          _paymentMethod = _wallets.first['wlt_name'];
        }
        
        // Set notes
        _notesController.text = widget.editData!['notes'] ?? '';
      });
    } else {
      // For new receipt, set today's date
      setState(() {
        _selectedDate = DateTime.now();
      });
    }
  }

  void _filterCustomers() {
    final searchText = _customerNameController.text.toLowerCase();
    setState(() {
      if (searchText.isEmpty) {
        _filteredCustomers = List.from(_customers);
      } else {
        _filteredCustomers = _customers
            .where((customer) => 
                customer['cust_name']!.toLowerCase().contains(searchText))
            .toList();
      }
    });
  }

  void _filterWallets(String searchText) {
    setState(() {
      if (searchText.isEmpty) {
        _filteredWallets = List.from(_wallets);
      } else {
        _filteredWallets = _wallets
            .where((wallet) => 
                wallet['wlt_name']!.toLowerCase().contains(searchText.toLowerCase()))
            .toList();
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ReportPage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ReceiptsPage()));
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

  void _selectCustomer(Map<String, String> customer) {
    setState(() {
      _selectedCustomerId = customer['custid'];
      _customerNameController.text = customer['cust_name']!;
      
      // Always update due amount when customer is selected (both new and edit mode)
      _dueAmountController.text = customer['outstand_amt']!;
      
      _isCustomerDropdownOpen = false;
    });
  }

  void _selectWallet(Map<String, String> wallet) {
    setState(() {
      _selectedWalletId = wallet['wltid'];
      _paymentMethod = wallet['wlt_name'];
      _isWalletDropdownOpen = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: receiptDateChange == "yes" ? DateTime(2101) : DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<Map<String, dynamic>> _saveReceiptData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        return {"result": "0", "message": "Missing credentials"};
      }

      String action = _isEditing ? 'update' : 'insert';
      
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "action": action,
        "cust_name": _customerNameController.text,
        "custid": _selectedCustomerId ?? '',
        "wallet": _selectedWalletId ?? '',
        "pd_date": DateFormat('dd-MM-yyyy').format(_selectedDate),
        "pd_amt": _amountController.text.trim(),
        "notes": _notesController.text.trim(),
      };

      if (_isEditing && widget.editData?['rcpId'] != null) {
        requestBody["rcpid"] = widget.editData!['rcpId'];
      }

      final response = await http.post(
        Uri.parse('$url/action/receipt.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to save receipt"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Enhanced validation for dropdowns with better error messages
      bool hasValidationErrors = false;
      
      // Check customer selection
      if (_selectedCustomerId == null || _selectedCustomerId!.isEmpty) {
        _showError('Please select a customer from the dropdown');
        hasValidationErrors = true;
      }
      
      // Check wallet selection
      if (_selectedWalletId == null || _selectedWalletId!.isEmpty) {
        _showError('Please select a payment method from the dropdown');
        hasValidationErrors = true;
      }
      
      // For edit mode, additional validation to ensure the selections are still valid
      if (_isEditing) {
        // Validate customer still exists in current customer list
        bool customerExists = _customers.any((customer) => customer['custid'] == _selectedCustomerId);
        if (!customerExists) {
          _showError('Selected customer is no longer available. Please select a different customer.');
          hasValidationErrors = true;
        }
        
        // Validate wallet still exists in current wallet list
        bool walletExists = _wallets.any((wallet) => wallet['wltid'] == _selectedWalletId);
        if (!walletExists) {
          _showError('Selected payment method is no longer available. Please select a different payment method.');
          hasValidationErrors = true;
        }
      }
      
      if (hasValidationErrors) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        Map<String, dynamic> result = await _saveReceiptData();
        
        if (result['result'] == '1') {
          _showSuccess(result['message']);
          
          // Create updated receipt data to return
          Map<String, dynamic> updatedReceiptData = {
            'success': true,
            'rcpId': widget.editData?['rcpId'],
            'customerName': _customerNameController.text,
            'custId': _selectedCustomerId,
            'dueAmount': _dueAmountController.text,
            'receivedDate': DateFormat('dd-MM-yyyy').format(_selectedDate),
            'receivedAmount': _amountController.text.trim(),
            'paymentMethod': _paymentMethod,
            'walletId': _selectedWalletId,
            'notes': _notesController.text.trim(),
          };
          
          // Wait a moment before navigating back
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context, updatedReceiptData);
          }
        } else {
          _showError(result['message']);
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
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
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

  // Updated customer dropdown with improved scrolling
  Widget _buildCustomerDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _customerNameController,
          decoration: _inputDecoration('Customer Name').copyWith(
            suffixIcon: GestureDetector(
              onTap: () {
                // Close keyboard if open
                FocusScope.of(context).unfocus();
                
                setState(() {
                  _isCustomerDropdownOpen = !_isCustomerDropdownOpen;
                  if (_isCustomerDropdownOpen) {
                    // Reset filter to show all customers when opening dropdown
                    _filteredCustomers = List.from(_customers);
                  }
                });
              },
              child: Icon(
                _isCustomerDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
          ),
          onChanged: (value) {
            if (!_isEditing) {
              setState(() {
                _isCustomerDropdownOpen = true;
                _selectedCustomerId = null; // Clear selection when typing for new entries
                _dueAmountController.clear(); // Clear due amount when typing for new entries
                _filterCustomers();
              });
            } else {
              // For editing, allow search but don't clear selection immediately
              setState(() {
                _isCustomerDropdownOpen = true;
                _filterCustomers();
              });
            }
          },
          onTap: () {
            setState(() {
              _isCustomerDropdownOpen = true;
              _filterCustomers();
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter or select customer name';
            }
            return null;
          },
        ),
        if (_isCustomerDropdownOpen)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _filteredCustomers.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No customers found',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                : Scrollbar(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredCustomers.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final customer = _filteredCustomers[index];
                        final isSelected = _selectedCustomerId == customer['custid'];
                        
                        return ListTile(
                          title: Text(
                            _capitalizeWords(customer['cust_name']!),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryColor : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Due: ₹${customer['outstand_amt']}',
                            style: TextStyle(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected 
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                )
                              : null,
                          onTap: () => _selectCustomer(customer),
                          tileColor: isSelected 
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        );
                      },
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildWalletDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isWalletDropdownOpen = !_isWalletDropdownOpen;
              if (_isWalletDropdownOpen) {
                _filterWallets('');
              }
            });
          },
          child: InputDecorator(
            decoration: _inputDecoration('Amount To').copyWith(
              suffixIcon: Icon(
                _isWalletDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: AppTheme.primaryColor,
              ),
            ),
            child: Text(
              _paymentMethod ?? 'Select account',
              style: TextStyle(
                color: _paymentMethod != null ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
        ),
        if (_isWalletDropdownOpen)
          Container(
            height: 200,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _filteredWallets.isEmpty
                ? const Center(child: Text('No wallets found'))
                : Scrollbar(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredWallets.length,
                      itemBuilder: (context, index) {
                        final wallet = _filteredWallets[index];
                        final isSelected = _selectedWalletId == wallet['wltid'];
                        return ListTile(
                          title: Text(
                            _capitalizeWords(wallet['wlt_name']!),
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.primaryColor : Colors.black87,
                            ),
                          ),
                          trailing: isSelected 
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                )
                              : null,
                          onTap: () => _selectWallet(wallet),
                          tileColor: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : null,
                        );
                      },
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        // Close dropdowns when tapping outside
        if (_isCustomerDropdownOpen || _isWalletDropdownOpen) {
          setState(() {
            _isCustomerDropdownOpen = false;
            _isWalletDropdownOpen = false;
          });
        }
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'EDIT RECEIPT' : 'NEW RECEIPT'),
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
                  // Customer Name with Dropdown
                  _buildCustomerDropdown(),
                  const SizedBox(height: 16),

                  // Due Amount - show only if permission allows
                  if (receiptDueAmount == "yes")
                    Column(
                      children: [
                        TextFormField(
                          controller: _dueAmountController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Due Amount'),
                          readOnly: true,
                          enabled: false,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Received Date
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: _inputDecoration('Received Date'),
                      child: Text(
                        DateFormat('dd-MM-yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Received Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Received Amount'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Received amount is required';
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Amount To (Wallet Dropdown)
                  _buildWalletDropdown(),
                  if (_paymentMethod == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please select an account',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Notes 
                  TextFormField(
                    controller: _notesController,
                    decoration: _inputDecoration('Notes'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 30),

                  // Save Button
                ElevatedButton(
  onPressed: _isLoading ? null : _submitForm,
  child: _isLoading 
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'SAVING...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        )
      : Text(
          _isEditing ? 'UPDATE' : 'SAVE',
          style: const TextStyle(fontSize: 16),
        ),
  style: ElevatedButton.styleFrom(
    backgroundColor: _isEditing 
        ? const Color.fromARGB(255, 32, 104, 163) 
        : AppTheme.primaryColor,
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
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _dueAmountController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}