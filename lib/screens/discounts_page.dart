import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../common/bottom_navigation_button.dart';
import '../common/pagination.dart';
import 'home_page.dart';
import 'report_page.dart';
import 'new_discount_page.dart';
import '../services/api_service.dart';
import '../services/permission.dart';

// Discount model class
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

  // Convert to Map for easier handling
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

// Permission variables
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
  List<Discount> filteredDiscounts = [];
  int discountsTotal = 0;
  bool isLoading = false;

  List<String> customerNames = [];
  String? selectedCustomer;
  String? selectedCustId;
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
          discountsTotal = data['ttldiscounts'];
          final List<dynamic> discountsList = data['discountdet'] ?? [];
          setState(() {
            _discounts = discountsList.map((json) => Discount.fromJson(json)).toList();
            filteredDiscounts = _discounts;
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
      setState(() {
        customerNames = customers.map((e) => e["cust_name"]!).toList();
        customerIdMap = {for (var e in customers) e["cust_name"]!: e["custid"]!};
        customerAmountMap = {for (var e in customers) e["cust_name"]!: e["outstand_amt"]!};
        _isLoadingCustomers = false;
      });
    } catch (e) {
      _showError(e.toString());
      setState(() {
        _isLoadingCustomers = false;
      });
    }
  }

  Future<Map<String, dynamic>> _saveDiscountData(String action,
      {String? dscId, String reason = ""}) async {
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

    if (result != null) {
      fetchDiscounts(); // Refresh the list
      _showSuccess('New discount added successfully!');
    }
  }

  void _editDiscount(Discount discount) async {
    if (discountEdit != "yes") {
      _showError('You do not have permission to edit discounts');
      return;
    }

    // Show edit dialog instead of navigating to NewDiscountPage
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

    // Initialize with current discount data
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
          // Filter customers based on search text
          void filterCustomers() {
            final searchText = customerNameController.text.toLowerCase();
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

          // Handle customer selection from dropdown
          void selectCustomer(String customerName) {
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

          // Build customer dropdown widget
          Widget buildCustomerDropdown() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: customerNameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
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
                    suffixIcon: IconButton(
                      icon: Icon(isCustomerDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
                      onPressed: () {
                        setDialogState(() {
                          isCustomerDropdownOpen = !isCustomerDropdownOpen;
                          if (isCustomerDropdownOpen) {
                            filterCustomers();
                          }
                        });
                      },
                    ),
                  ),
                  onTap: () {
                    setDialogState(() {
                      isCustomerDropdownOpen = !isCustomerDropdownOpen;
                      if (isCustomerDropdownOpen) {
                        filterCustomers();
                      }
                    });
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
                    height: 200,
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
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        return ListTile(
                          title: Text(customer),
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

          InputDecoration inputDecoration(String label) {
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

          Future<void> selectDate(BuildContext context) async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(), 
            );
            if (picked != null && picked != selectedDate) {
              setDialogState(() {
                selectedDate = picked;
              });
            }
          }

          Future<void> submitForm() async {
            if (formKey.currentState!.validate()) {
              setDialogState(() {
                isLoading = true;
              });

              try {
                Map<String, dynamic> result = await _saveDiscountDataForEdit(
                  selectedCustomerName ?? '',
                  selectedCustomerId ?? '',
                  notesController.text.trim(),
                  DateFormat('dd-MM-yyyy').format(selectedDate),
                  discountAmountController.text.trim(),
                  discount.dscId,
                );

                if (result['result'] == '1') {
                  Navigator.pop(context);
                  fetchDiscounts(); // Refresh the list
                  _showSuccess(result['message'] ?? 'Discount updated successfully');
                } else {
                  _showError(result['message'] ?? 'Failed to update discount');
                }
              } catch (e) {
                _showError('An error occurred: $e');
              } finally {
                setDialogState(() {
                  isLoading = false;
                });
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
                  // Dialog Title
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'EDIT DISCOUNT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Dialog Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Customer Name with Dropdown
                            buildCustomerDropdown(),
                            const SizedBox(height: 16),

                            // Due Amount - read-only
                            TextFormField(
                              controller: dueAmountController,
                              keyboardType: TextInputType.number,
                              decoration: inputDecoration('Due Amount'),
                              readOnly: true,
                              enabled: false,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a customer to see due amount';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Discount Date
                            InkWell(
                              onTap: () => selectDate(context),
                              child: InputDecorator(
                                decoration: inputDecoration('Discount Date'),
                                child: Text(
                                  DateFormat.yMMMMd().format(selectedDate),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Discount Amount
                            TextFormField(
                              controller: discountAmountController,
                              keyboardType: TextInputType.number,
                              decoration: inputDecoration('Discount Amount'),
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
                                
                                // Validate against due amount
                                if (dueAmountController.text.isNotEmpty) {
                                  final dueAmount = double.tryParse(dueAmountController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                                  if (number > dueAmount) {
                                    return 'Discount cannot exceed due amount';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Notes
                            TextFormField(
                              controller: notesController,
                              decoration: inputDecoration('Notes'),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Dialog Actions
                  Container(
                    padding: const EdgeInsets.all(16),
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
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isLoading ? null : submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 32, 104, 163),
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('UPDATE'),
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

  // Save discount data for editing
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

      final response = await http.post(
        Uri.parse('$url/action/discounts.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to update discount"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  String _parseDateString(String dateStr) {
    try {
      DateTime parsedDate = DateFormat("dd/MM/yyyy").parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
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
        title: const Text("coremicron.in says"),
        content: const Text("Are you sure that you want to delete the discount?"),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              Map<String, dynamic> result = await _saveDiscountData('delete', dscId: discount.dscId);

              if (result['result'] == '1') {
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
        title: const Text('Delete Discount', style: TextStyle(color: Colors.red)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this discount?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDialogRow('Customer Name:', discount.name),
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
              child: const Text('Cancel', style: TextStyle(fontSize: 13)),
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

                if (result['result'] == '1') {
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
              child: const Text('Delete', style: TextStyle(fontSize: 13)),
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
            ),
          ),
        ],
      ),
    );
  }

  String _capitalizeWords(String text) {
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
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

    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage > filteredDiscounts.length)
        ? filteredDiscounts.length
        : start + itemsPerPage;
    final currentList = filteredDiscounts.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DISCOUNTS'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
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
            child: currentList.isEmpty
                ? const Center(child: Text('No discounts found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentList.length,
                    itemBuilder: (context, index) {
                      final discount = currentList[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow('Name', capitalizeWords(discount.name)),
                              _buildRow(
                                'Date',
                                _formatDate(discount.date),
                              ),
                              _buildRow('Notes', capitalizeWords(discount.notes)),
                              _buildRow('Discount', discount.amount, color: Colors.orange.shade700),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (discountEdit == "yes")
                                    _buildActionButton(
                                      icon: Icons.edit,
                                      label: 'Edit',
                                      backgroundColor: const Color.fromARGB(255, 5, 38, 76),
                                      onPressed: () => _editDiscount(discount),
                                    ),
                                  if (discountEdit == "yes" && discountDelete == "yes")
                                    const SizedBox(width: 6),
                                  if (discountDelete == "yes")
                                    _buildActionButton(
                                      icon: Icons.delete,
                                      label: 'Delete',
                                      backgroundColor: Colors.red.shade700,
                                      onPressed: () => _deleteDiscount(discount),
                                    ),
                                ],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color ?? Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      DateTime parsedDate = DateFormat("dd/MM/yyyy").parse(dateStr);
      return DateFormat.yMMMMd().format(parsedDate);
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }
}

// Helper functions
double parseFormattedAmount(String formattedAmount) {
  final cleanString = formattedAmount.replaceAll(',', ''); // Remove commas
  return double.tryParse(cleanString) ?? 0.0; // Convert to number
}

String capitalizeWords(String text) {
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}