import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import '../home_page.dart';
import '../report_page.dart';
import 'new_discount_page.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';

class Discount {
  final String date;
  final String name;
  final String notes;
  final String amount;
  final String dscId;

  Discount({
    required this.date,
    required this.name,
    required this.notes,
    required this.amount,
    required this.dscId,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      date: json['dsc_date'] ?? '',
      name: json['custname'] ?? '',
      notes: json['notes'] ?? '',
      amount: json['dsc_amt'] ?? '',
      dscId: json['dscid'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'no': dscId,
      'name': name,
      'date': date,
      'notes': notes,
      'discount': amount,
      'dscId': dscId,
    };
  }
}

String discountAdd = '';
String discountDueAmount = '';
String discountDateChange = '';
String discountAllowed = '';
String discountEdit = '';
String discountView = '';
String discountDelete = '';
String discountDeleteReason = '';

class DiscountsPage extends StatefulWidget {
  const DiscountsPage({Key? key}) : super(key: key);

  @override
  State<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends State<DiscountsPage> {
  ApiServices apiServices = ApiServices();
  
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;

  List<Discount> _discounts = [];
  int discountsTotal = 0;
  bool isLoading = false;

  List<String> customerNames = [];
  Map<String, String> customerIdMap = {};
  Map<String, String> customerAmountMap = {};
  bool _isLoadingCustomers = true;

  final TextEditingController deleteReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    loadCustomers();
    fetchDiscounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    deleteReasonController.dispose();
    super.dispose();
  }

  Future<void> fetchDiscounts() async {
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
        Uri.parse('$url/discounts.php'),
        headers: {'Content-Type': 'application/json'},
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
          // FIX: Parse ttldiscounts as string and convert to int
          discountsTotal = int.tryParse(data['ttldiscounts']?.toString() ?? '0') ?? 0;
          final List<dynamic> discountsList = data['discountdet'] ?? [];
          setState(() {
            _discounts = discountsList.map((json) => Discount.fromJson(json)).toList();
          });
          if (discountsList.isEmpty) {
            _showError('No discounts data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch discounts.');
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
          discountAdd = permissionDetail.discountAdd;
          discountDueAmount = permissionDetail.discountDueAmount;
          discountDateChange = permissionDetail.discountDateChange;
          discountAllowed = permissionDetail.discountAllowed;
          discountEdit = permissionDetail.discountEdit;
          discountView = permissionDetail.discountView;
          discountDelete = permissionDetail.discountDelete;
          discountDeleteReason = permissionDetail.discountDeleteReason;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }

  Future<void> loadCustomers() async {
    try {
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      if (mounted) {
        setState(() {
          customerNames = customers.map((e) => e["cust_name"]!).toList();
          customerIdMap = {for (var e in customers) e["cust_name"]!: e["custid"]!};
          customerAmountMap = {for (var e in customers) e["cust_name"]!: e["outstand_amt"]!};
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      _showError(e.toString());
      if (mounted) {
        setState(() {
          _isLoadingCustomers = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _saveDiscountData(String action, {String? dscId, String reason = ""}) async {
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

      if (action == 'delete' && dscId != null) {
        requestBody["dscid"] = dscId;
        if (reason.isNotEmpty) {
          requestBody["reason"] = reason;
        }
      }

      final response = await http.post(
        Uri.parse('$url/action/discounts.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to delete"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchDiscounts();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter discount no or customer name'),
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
              fetchDiscounts();
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
              fetchDiscounts();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewDiscountPage() async {
    if (discountAdd != "yes") {
      _showError('You do not have permission to add discounts');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewDiscountPage()),
    );

    if (result != null && mounted) {
      fetchDiscounts(); 
      _showSuccess('New discount added successfully!');
    }
  }

  void _editDiscount(Discount discount) async {
    if (discountEdit != "yes") {
      _showError('You do not have permission to edit discounts');
      return;
    }
    _showEditDiscountDialog(discount);
  }

  void _showEditDiscountDialog(Discount discount) {
    final TextEditingController customerNameController = TextEditingController();
    final TextEditingController dueAmountController = TextEditingController();
    final TextEditingController discountAmountController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    String? selectedCustomerId;
    String? selectedCustomerName;
    bool isCustomerDropdownOpen = false;
    List<String> filteredCustomers = [];
    bool isLoading = false;

    try {
      selectedDate = DateFormat("dd/MM/yyyy").parse(discount.date);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    selectedCustomerName = discount.name;
    customerNameController.text = discount.name;
    selectedCustomerId = customerIdMap[discount.name];
    dueAmountController.text = customerAmountMap[discount.name] ?? '0';
    discountAmountController.text = parseFormattedAmount(discount.amount).toInt().toString();
    notesController.text = discount.notes;
    filteredCustomers = List.from(customerNames);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void filterCustomers() {
            final searchText = customerNameController.text.toLowerCase();
            if (mounted) {
              setDialogState(() {
                if (searchText.isEmpty) {
                  filteredCustomers = List.from(customerNames);
                } else {
                  filteredCustomers = customerNames
                      .where((customer) => customer.toLowerCase().contains(searchText))
                      .toList();
                }
              });
            }
          }

          void selectCustomer(String customerName) {
            if (mounted) {
              setDialogState(() {
                selectedCustomerId = customerIdMap[customerName];
                selectedCustomerName = customerName;
                customerNameController.text = customerName;
                dueAmountController.text = customerAmountMap[customerName] ?? '0';
                isCustomerDropdownOpen = false;
                if (discountAmountController.text.isNotEmpty) {
                  formKey.currentState?.validate();
                }
              });
            }
          }

          Widget buildCustomerDropdown() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: customerNameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    labelStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isCustomerDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 18,
                      ),
                      onPressed: () {
                        if (mounted) {
                          setDialogState(() {
                            isCustomerDropdownOpen = !isCustomerDropdownOpen;
                            if (isCustomerDropdownOpen) {
                              filterCustomers();
                            }
                          });
                        }
                      },
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onTap: () {
                    if (mounted) {
                      setDialogState(() {
                        isCustomerDropdownOpen = !isCustomerDropdownOpen;
                        if (isCustomerDropdownOpen) {
                          filterCustomers();
                        }
                      });
                    }
                  },
                  onChanged: (value) {
                    filterCustomers();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a customer';
                    }
                    return null;
                  },
                ),
                if (isCustomerDropdownOpen)
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            customer,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () {
                            selectCustomer(customer);
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          }

          Future<void> submitForm() async {
  if (formKey.currentState!.validate()) {
    if (mounted) {
      setDialogState(() {
        isLoading = true;
      });
    }

    try {
      Map<String, dynamic> result = await _saveDiscountDataForEdit(
        selectedCustomerName ?? '',
        selectedCustomerId ?? '',
        notesController.text.trim(),
        DateFormat('dd-MM-yyyy').format(selectedDate),
        discountAmountController.text.trim(),
        discount.dscId,
      );

      // Enhanced response handling
      print('Edit Discount Final Result: $result'); // Debug log
      
      if (result['result'] == '1' || result['result'] == 1) {
        Navigator.pop(context);
        if (mounted) {
          await fetchDiscounts(); // Ensure data refresh completes
          _showSuccess(result['message'] ?? 'Discount updated successfully');
        }
      } else {
        String errorMessage = result['message'] ?? 'Failed to update discount';
        
        // Handle specific error cases
        if (result.containsKey('errors') && result['errors'] is List) {
          List<dynamic> errors = result['errors'];
          if (errors.isNotEmpty) {
            errorMessage = errors.join(', ');
          }
        }
        
        _showError(errorMessage);
      }
    } catch (e) {
      print('Submit Form Error: $e'); // Debug log
      _showError('An error occurred while updating: $e');
    } finally {
      // FIX: Use a try-catch to handle the case where the dialog context is no longer valid
      try {
        // Check if the widget is still mounted and the dialog context is still valid
        if (mounted && Navigator.of(context).canPop()) {
          setDialogState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        // If we can't access the context, just set the loading state to false
        // This can happen if the dialog was already closed
        print('Error updating loading state: $e');
      }
    }
  }
}

          return Dialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius:  BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Discount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildCustomerDropdown(),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: dueAmountController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Due Amount'),
                              style: const TextStyle(fontSize: 12),
                              readOnly: true,
                              enabled: false,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a customer to see due amount';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _selectDate(context, setDialogState, selectedDate),
                              child: InputDecorator(
                                decoration: _inputDecoration('Discount Date'),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(selectedDate),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: discountAmountController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Discount Amount'),
                              style: const TextStyle(fontSize: 11),
                              onChanged: (value) {
                                formKey.currentState?.validate();
                              },
                              validator: (value) {
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
                                
                                if (dueAmountController.text.isNotEmpty) {
                                  final dueAmount = double.tryParse(dueAmountController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                                  if (number > dueAmount) {
                                    return 'Discount cannot exceed due amount';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: notesController,
                              decoration: _inputDecoration('Notes'),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('CANCEL', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 28,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 32, 104, 163),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: isLoading 
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('UPDATE', style: TextStyle(fontSize: 12)),
                          ),
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
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  Future<void> _selectDate(BuildContext context, StateSetter setDialogState, DateTime currentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(), 
    );
    if (picked != null && mounted) {
      setDialogState(() {
        // This will update the date in the dialog state
      });
    }
  }

  Future<Map<String, dynamic>> _saveDiscountDataForEdit(
    String customerName,
    String customerId,
    String notes,
    String discountDate,
    String discountAmount,
    String dscId,
  ) async {
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
        "action": "update",
        "cust_name": customerName,
        "custid": customerId,
        "notes": notes,
        "dsc_date": discountDate,
        "dsc_amt": discountAmount,
        "dscid": dscId,
      };

      print('Edit Discount Request: ${jsonEncode(requestBody)}'); // Debug log

      final response = await http.post(
        Uri.parse('$url/action/discounts.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print('Edit Discount Response Status: ${response.statusCode}'); // Debug log
      print('Edit Discount Response Body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Enhanced response validation
        if (responseData is Map<String, dynamic>) {
          return responseData;
        } else {
          return {"result": "0", "message": "Invalid response format from server"};
        }
      } else {
        return {
          "result": "0", 
          "message": "Server error: ${response.statusCode} - ${response.reasonPhrase}"
        };
      }
    } catch (e) {
      print('Edit Discount Error: $e'); // Debug log
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _deleteDiscount(Discount discount) {
    if (discountDelete != "yes") {
      _showError('You do not have permission to delete discounts');
      return;
    }

    if (discountDeleteReason == "yes") {
      _showDeleteWithReasonDialog(discount);
    } else {
      _showSimpleDeleteDialog(discount);
    }
  }

  void _showSimpleDeleteDialog(Discount discount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(""),
        content: const Text("Are you sure that you want to delete the discount?"),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              Map<String, dynamic> result = await _saveDiscountData('delete', dscId: discount.dscId);

              if (result['result'] == '1' && mounted) {
                setState(() {
                  fetchDiscounts();
                });
                _showSuccess(result['message']);
              } else {
                _showError(result['message']);
              }
            },
            child: const Text("Delete"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showDeleteWithReasonDialog(Discount discount) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discount', style: TextStyle(color: Colors.red, fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this discount?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _buildDialogRow('Name:', discount.name),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            height: 32,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason for deletion')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                
                Map<String, dynamic> result = await _saveDiscountData(
                  'delete',
                  dscId: discount.dscId,
                  reason: reasonController.text,
                );

                if (result['result'] == '1' && mounted) {
                  setState(() {
                    fetchDiscounts();
                  });
                  _showSuccess(result['message']);
                } else {
                  _showError(result['message']);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Delete', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
              maxLines: 1, 
              overflow: TextOverflow.ellipsis, 
              softWrap: false, 
            ),
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

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      } else if (dateStr.contains('/')) {
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (e) {}
    return null;
  }

  String _formatDate(String dateStr) {
    DateTime? date = _parseDate(dateStr);
    if (date != null) {
      return DateFormat('dd-MM-yyyy').format(date);
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _discounts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('DISCOUNTS'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discounts'),
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
            child: _discounts.isEmpty
                ? const Center(child: Text("No discounts found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _discounts.length,
                    itemBuilder: (context, index) {
                      final discount = _discounts[index];
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
                                        discount.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(255, 5, 38, 76),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          _formatDate(discount.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Notes',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  discount.notes,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            height: 24,
                                            width: 1,
                                            color: Colors.grey.shade300,
                                            margin: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Discount',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  discount.amount,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.orange.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          if (discountEdit == "yes")
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color.fromARGB(255, 5, 38, 76),
                                                foregroundColor: Colors.white,
                                                elevation: 1,
                                                padding: const EdgeInsets.all(6),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _editDiscount(discount),
                                              child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                            ),
                                          if (discountEdit == "yes" && discountDelete == "yes")
                                            const SizedBox(width: 6),
                                          if (discountDelete == "yes")
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red.shade600,
                                                foregroundColor: Colors.white,
                                                elevation: 1,
                                                padding: const EdgeInsets.all(6),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              onPressed: () => _deleteDiscount(discount),
                                              child: const Icon(Icons.delete, size: 12, color: Colors.white),
                                            ),
                                        ],
                                      ),
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
            totalItems: discountsTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      floatingActionButton: discountAdd == "yes" 
          ? FloatingActionButton(
              onPressed: _navigateToNewDiscountPage,
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

double parseFormattedAmount(String formattedAmount) {
  final cleanString = formattedAmount.replaceAll(',', '');
  return double.tryParse(cleanString) ?? 0.0;
}

String capitalizeWords(String text) {
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}