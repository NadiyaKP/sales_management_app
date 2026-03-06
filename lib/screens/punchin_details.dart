import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../common/bottom_navigation_button.dart';
import '../common/pagination.dart';
import 'punch.dart';

// Customer model for dropdown
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

// PunchIn model class - updated to match API response
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

  // For backward compatibility with existing UI code
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
  List<PunchIn> filteredPunchIns = [];
  int punchInsTotal = 0;
  bool isLoading = false;

  // Customer list for dropdown
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadPunchInData();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['result'] == '1') {
          final List<dynamic> customerList = responseData['customers'] ?? [];
          setState(() {
            _customers = customerList
                .map((json) => Customer.fromJson(json))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading customers: $e");
    }
  }

  Future<void> _loadPunchInData() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        throw Exception('Missing configuration data. Please login again.');
      }

      final response = await http.post(
        Uri.parse('$url/punch-in.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "page": "",
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - server took too long to respond');
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Server returned empty response');
        }

        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(response.body);
        } catch (e) {
          throw Exception('Invalid JSON response from server');
        }

        if (responseData['result'] == '1') {
          final List<dynamic> punchInList = responseData['punchindet'] ?? [];
          final int totalAttendance = responseData['ttlattend'] ?? 0;

          List<PunchIn> fetchedPunchIns = punchInList
              .map((json) => PunchIn.fromJson(json))
              .toList();

          setState(() {
            _punchIns = fetchedPunchIns;
            filteredPunchIns = _punchIns;
            punchInsTotal = totalAttendance;
            isLoading = false;
          });
        } else {
          String message = responseData['message'] ?? 'Failed to load punch-in data';
          throw Exception(message);
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error loading punch-in data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showError('Error loading data: ${e.toString()}');
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadPunchInData();
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter customer name or location',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _searchController.clear();
              setState(() {
                searchQuery = '';
                currentPage = 1;
                filteredPunchIns = _punchIns;
                punchInsTotal = _punchIns.length;
              });
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text.toLowerCase();
                currentPage = 1;
                if (searchQuery.isEmpty) {
                  filteredPunchIns = _punchIns;
                } else {
                  filteredPunchIns = _punchIns.where((punchIn) {
                    return punchIn.custname.toLowerCase().contains(searchQuery) ||
                           punchIn.location.toLowerCase().contains(searchQuery);
                  }).toList();
                }
                punchInsTotal = filteredPunchIns.length;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewPunchPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraPageScreen()),
    );

    if (result != null) {
      _showSuccess('New punch-in added successfully!');
      _refreshData();
    }
  }

  void _editPunchIn(PunchIn punchIn) {
    _showEditPunchInDialog(punchIn);
  }

  void _showEditPunchInDialog(PunchIn punchIn) {
    final TextEditingController locationController = TextEditingController(text: punchIn.location);
    final TextEditingController noteController = TextEditingController(text: punchIn.notes);

    DateTime selectedDate = DateTime.now();
    try {
      selectedDate = DateFormat("dd/MM/yyyy").parse(punchIn.date);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    String? selectedCustomerId = punchIn.custid.isNotEmpty ? punchIn.custid : null;
    String selectedCustomerName = punchIn.custname;

    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
              if (selectedCustomerId == null || selectedCustomerId!.isEmpty) {
                _showError('Please select a customer');
                return;
              }

              setDialogState(() {
                isLoading = true;
              });

              try {
                await _updatePunchInRecord(
                  punchIn.attid,
                  selectedCustomerId!,
                  selectedCustomerName,
                  locationController.text,
                  noteController.text,
                  selectedDate,
                );

                Navigator.pop(context);
                _showSuccess('Punch-in updated successfully');
                _refreshData();
              } catch (e) {
                _showError('Failed to update: ${e.toString()}');
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
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'EDIT PUNCH-IN',
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
                            // Customer Dropdown
                            DropdownButtonFormField<String>(
                              value: selectedCustomerId,
                              decoration: inputDecoration('Customer Name *'),
                              isExpanded: true,
                              items: [
                                if (punchIn.custid.isNotEmpty && !_customers.any((c) => c.id == punchIn.custid))
                                  DropdownMenuItem<String>(
                                    value: punchIn.custid,
                                    child: Text(_capitalizeWords(punchIn.custname)),
                                  ),
                                ..._customers.map((customer) => DropdownMenuItem<String>(
                                  value: customer.id,
                                  child: Text(_capitalizeWords(customer.name)),
                                )),
                              ],
                              onChanged: (String? newValue) {
                                setDialogState(() {
                                  selectedCustomerId = newValue;
                                  if (newValue != null) {
                                    final customer = _customers.firstWhere(
                                      (c) => c.id == newValue,
                                      orElse: () => Customer(id: newValue, name: punchIn.custname),
                                    );
                                    selectedCustomerName = customer.name;
                                  }
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a customer';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Date
                            InkWell(
                              onTap: () => selectDate(context),
                              child: InputDecorator(
                                decoration: inputDecoration('Date'),
                                child: Text(
                                  DateFormat.yMMMMd().format(selectedDate),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Location
                            TextFormField(
                              controller: locationController,
                              decoration: inputDecoration('Location *'),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter location';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Note
                            TextFormField(
                              controller: noteController,
                              decoration: inputDecoration('Note'),
                              maxLines: 3,
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

  Future<void> _updatePunchInRecord(String attid, String customerId, String customerName, String location, String notes, DateTime date) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        throw Exception('Missing configuration data');
      }

      final requestBody = {
        "unid": unid,
        "slex": slex,
        "customer_name": customerName,
        "cust_id": customerId,
        "action": "update",
        "attid": attid,
        "notes": notes,
      };

      debugPrint("Update request body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        Uri.parse('$url/action/punch-in.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['result'] != '1') {
          throw Exception(responseData['message'] ?? 'Update failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error updating punch-in record: $e");
      rethrow;
    }
  }

  void _deletePunchIn(PunchIn punchIn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("DELETE"),
        content: const Text("Are you sure that you want to delete this punch-in record?"),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _deletePunchInRecord(punchIn.attid);
                _showSuccess('The selected details has been deleted successfully.');
                _refreshData();
              } catch (e) {
                _showError('Failed to delete: ${e.toString()}');
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

  Future<void> _deletePunchInRecord(String attid) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        throw Exception('Missing configuration data');
      }

      final requestBody = {
        "unid": unid,
        "slex": slex,
        "action": "delete",
        "attid": attid,
      };

      debugPrint("Delete request body: ${jsonEncode(requestBody)}");

      final response = await http.post(
        Uri.parse('$url/action/punch-in.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['result'] != '1') {
          throw Exception(responseData['message'] ?? 'Delete failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error deleting punch-in record: $e");
      rethrow;
    }
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
      return Scaffold(
        appBar: AppBar(
          title: const Text('PUNCH IN DETAILS'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage > filteredPunchIns.length)
        ? filteredPunchIns.length
        : start + itemsPerPage;
    final currentList = filteredPunchIns.sublist(start, end);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PUNCH IN DETAILS'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (punchInsTotal > 0)
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Total Records: $punchInsTotal',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          Expanded(
            child: currentList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No punch-in records found for "$searchQuery".'
                              : 'No punch-in records found.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                _searchController.clear();
                                filteredPunchIns = _punchIns;
                                punchInsTotal = _punchIns.length;
                                currentPage = 1;
                              });
                            },
                            child: const Text('Clear Search'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final punchIn = currentList[index];
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
                                _buildRow('Customer', _capitalizeWords(punchIn.custname)),
                                _buildRow('Date', _formatDate(punchIn.date)),
                                _buildRow('Location', _capitalizeWords(punchIn.location)),
                                _buildRow('Notes', _capitalizeWords(punchIn.notes.isEmpty ? 'No notes' : punchIn.notes)),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _buildActionButton(
                                      icon: Icons.edit,
                                      label: 'Edit',
                                      backgroundColor: const Color.fromARGB(255, 5, 38, 76),
                                      onPressed: () => _editPunchIn(punchIn),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildActionButton(
                                      icon: Icons.delete,
                                      label: 'Delete',
                                      backgroundColor: Colors.red.shade700,
                                      onPressed: () => _deletePunchIn(punchIn),
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
          ),
          if (filteredPunchIns.length > itemsPerPage)
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

  // ── Matches discounts_page.dart exactly ──────────────────────────────────
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: onPressed,
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

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
      return dateStr;
    }
  }
}

// Helper function
String capitalizeWords(String text) {
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}