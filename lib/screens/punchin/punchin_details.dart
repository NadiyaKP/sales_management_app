import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sales_management_app/theme/app_theme.dart';
import 'package:sales_management_app/common/bottom_navigation_button.dart';
import 'package:sales_management_app/common/pagination.dart';
import 'punch.dart';
import '../home_page.dart';

class Customer {
  final String id;
  final String name;

  Customer({required this.id, required this.name});

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class PunchIn {
  final String attid;
  final String custname;
  final String custid;
  final String date;
  final String location;
  final String notes;

  PunchIn({
    required this.attid,
    required this.custname,
    required this.custid,
    required this.date,
    required this.location,
    required this.notes,
  });

  factory PunchIn.fromJson(Map<String, dynamic> json) {
    return PunchIn(
      attid: json['attid'] ?? '',
      custname: json['custname'] ?? '',
      custid: json['custid'] ?? '',
      date: json['date'] ?? '',
      location: json['location'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  String get id => attid;
  String get name => custname;
  String get note => notes;
}

class PunchInDetailsPage extends StatefulWidget {
  const PunchInDetailsPage({Key? key}) : super(key: key);

  @override
  State<PunchInDetailsPage> createState() => _PunchInDetailsPageState();
}

class _PunchInDetailsPageState extends State<PunchInDetailsPage> {
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;

  List<PunchIn> _punchIns = [];
  int punchInsTotal = 0;
  bool isLoading = false;
  List<Customer> _customers = [];
  bool _isLoadingCustomers = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    fetchPunchIns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchPunchIns() async {
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
        Uri.parse('$url/punch-in.php'),
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
          // FIX: Convert string to int for ttlattend
          punchInsTotal = int.tryParse(data['ttlattend']?.toString() ?? '0') ?? 0;
          final List<dynamic> punchInsList = data['punchindet'] ?? [];
          setState(() {
            _punchIns = punchInsList.map((json) => PunchIn.fromJson(json)).toList();
          });
          if (punchInsList.isEmpty) {
            _showError('No punch-in data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch punch-ins.');
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

  Future<void> _loadCustomers() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        throw Exception('Missing configuration data');
      }

      final response = await http.post(
        Uri.parse('$url/customers.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"unid": unid, "slex": slex}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['result'] == '1') {
          final List<dynamic> customerList = responseData['customers'] ?? [];
          setState(() {
            _customers = customerList.map((json) => Customer.fromJson(json)).toList();
            _isLoadingCustomers = false;
          });
        }
      }
    } catch (e) {
      _showError("Error loading customers: $e");
      setState(() {
        _isLoadingCustomers = false;
      });
    }
  }

  Future<Map<String, dynamic>> _savePunchInData(String action, {String? attid, String? custId, String? custName, String? location, String? notes}) async {
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

      if (action == 'delete' && attid != null) {
        requestBody["attid"] = attid;
      } else if (action == 'update' && attid != null) {
        requestBody["attid"] = attid;
        requestBody["cust_id"] = custId;
        requestBody["customer_name"] = custName;
        requestBody["location"] = location;
        requestBody["notes"] = notes;
      }

      final response = await http.post(
        Uri.parse('$url/action/punch-in.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to process request"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchPunchIns();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter customer name or location'),
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
              fetchPunchIns();
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
              fetchPunchIns();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToNewPunchPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPageScreen()),
    );
    if (result != null) {
      fetchPunchIns();
      _showSuccess('New punch-in added successfully!');
    }
  }

  void _editPunchIn(PunchIn punchIn) {
    _showEditPunchInDialog(punchIn);
  }

  void _showEditPunchInDialog(PunchIn punchIn) {
    final TextEditingController customerNameController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();
    String? selectedCustomerId;
    String? selectedCustomerName;
    bool isCustomerDropdownOpen = false;
    List<String> customerNames = _customers.map((e) => e.name).toList();
    List<String> filteredCustomers = [];
    bool isLoading = false;

    try {
      selectedDate = DateFormat("dd/MM/yyyy").parse(punchIn.date);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    selectedCustomerName = punchIn.custname;
    customerNameController.text = punchIn.custname;
    selectedCustomerId = punchIn.custid;
    locationController.text = punchIn.location;
    notesController.text = punchIn.notes;
    filteredCustomers = List.from(customerNames);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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

          void selectCustomer(String customerName) {
            setDialogState(() {
              final customer = _customers.firstWhere((c) => c.name == customerName);
              selectedCustomerId = customer.id;
              selectedCustomerName = customerName;
              customerNameController.text = customerName;
              isCustomerDropdownOpen = false;
            });
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
                        setDialogState(() {
                          isCustomerDropdownOpen = !isCustomerDropdownOpen;
                          if (isCustomerDropdownOpen) {
                            filterCustomers();
                          }
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
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
              setDialogState(() {
                isLoading = true;
              });

              try {
                Map<String, dynamic> result = await _savePunchInData(
                  'update',
                  attid: punchIn.attid,
                  custId: selectedCustomerId,
                  custName: selectedCustomerName,
                  location: locationController.text.trim(),
                  notes: notesController.text.trim(),
                );

                if (result['result'] == '1') {
                  Navigator.pop(context);
                  fetchPunchIns();
                  _showSuccess(result['message'] ?? 'Punch-in updated successfully');
                } else {
                  _showError(result['message'] ?? 'Failed to update punch-in');
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
                            'Edit Punch-in',
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
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null && picked != selectedDate) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Date',
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
                                ),
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(selectedDate),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: locationController,
                              decoration: InputDecoration(
                                labelText: 'Location',
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
                              ),
                              style: const TextStyle(fontSize: 12),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter location';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: notesController,
                              decoration: InputDecoration(
                                labelText: 'Notes',
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
                              ),
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

  void _deletePunchIn(PunchIn punchIn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Punch-in', style: TextStyle(color: Colors.red, fontSize: 14)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this punch-in?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _buildDialogRow('Customer:', punchIn.custname),
              _buildDialogRow('Date:', _formatDate(punchIn.date)),
              _buildDialogRow('Location:', punchIn.location),
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
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                Map<String, dynamic> result = await _savePunchInData(
                  'delete',
                  attid: punchIn.attid,
                );

                if (result['result'] == '1') {
                  setState(() {
                    fetchPunchIns();
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

  String _capitalizeWords(String text) {
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomePage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _punchIns.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Punch-in-Details'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateToHome,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PUNCH-IN DETAILS'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigateToHome,
        ),
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
            child: _punchIns.isEmpty
                ? const Center(child: Text("No punch-ins found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _punchIns.length,
                    itemBuilder: (context, index) {
                      final punchIn = _punchIns[index];
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
                                      _capitalizeWords(punchIn.custname),
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
                                        _formatDate(punchIn.date),
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
                                                'Location',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _capitalizeWords(punchIn.location),
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
                                                'Notes',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                punchIn.notes.isEmpty ? 'No notes' : _capitalizeWords(punchIn.notes),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black54
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
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color.fromARGB(255, 5, 38, 76),
                                            foregroundColor: Colors.white,
                                            elevation: 1,
                                            padding: const EdgeInsets.all(4),
                                            minimumSize: const Size(28, 28),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => _editPunchIn(punchIn),
                                          child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                        ),
                                        const SizedBox(width: 4),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            elevation: 1,
                                            padding: const EdgeInsets.all(4),
                                            minimumSize: const Size(28, 28),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => _deletePunchIn(punchIn),
                                          child: const Icon(Icons.delete, size: 10, color: Colors.white),
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
            totalItems: punchInsTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToNewPunchPage,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 2, 
      ),
    );
  }
}