import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/menu_item.dart';
import '../../common/bottom_navigation_button.dart';
import '../home_page.dart';
import '../report_page.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import 'account_sale.dart';
import 'customer_ledger_report.dart';
import '../account/account_receipt.dart';
import 'account_salesreturn.dart';
import 'account_discount.dart';
import 'account_aged_receivable.dart';

String customerLedger = '';
String ledgerExcel = '';

class AccountLedgerPage extends StatefulWidget {
  const AccountLedgerPage({Key? key}) : super(key: key);

  @override
  State<AccountLedgerPage> createState() => _AccountLedgerPageState();
}

class _AccountLedgerPageState extends State<AccountLedgerPage> {
  bool isLoading = false;
  
  ApiServices apiServices = ApiServices();
  
  // API-related variables for customers
  List<String> customerNames = [];
  Map<String, String> customerIdMap = {};
  bool customersLoaded = false;

  final List<Map<String, dynamic>> ledgerItems = const [
    {'title': 'LEDGER', 'icon': Icons.book},
    {'title': 'SALE', 'icon': Icons.shopping_cart},
    {'title': 'AGED RECEIVABLE', 'icon': Icons.receipt_long},
    {'title': 'RECEIPT', 'icon': Icons.receipt},
    {'title': 'SALES RETURN', 'icon': Icons.undo},
    {'title': 'DISCOUNT', 'icon': Icons.percent},
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    loadCustomers(); // Load customers on init
  }

  Future<void> loadCustomers() async {
    if (customersLoaded) return; // Avoid reloading if already loaded
    
    try {
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      setState(() {
        customerNames = customers.map((e) => e["cust_name"]!).toList();
        customerIdMap = {
          for (var e in customers) e["cust_name"]!: e["custid"]!
        };
        customersLoaded = true;
      });
    } catch (e) {
      _showError('Failed to load customers: $e');
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
          ledgerExcel = permissionDetail.ledgerExcel;
          customerLedger = permissionDetail.customerLedger;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  void _handleLedgerTap(BuildContext context, String title) {
    // Show the same dialog for all items
    _showEnterDetailsDialog(context, title);
  }

  void _showEnterDetailsDialog(BuildContext context, String selectedOption) {
    String? selectedCustomer;
    String? selectedCustId;
    // Set from date to first day of current month
    DateTime now = DateTime.now();
    DateTime fromDate = DateTime(now.year, now.month, 1);
    DateTime toDate = DateTime.now();
    bool dialogLoading = false;

    // Ensure customers are loaded before showing dialog
    if (!customersLoaded) {
      loadCustomers();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Enter Details - $selectedOption',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              content: dialogLoading 
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Searchable Customer Dropdown
                        SearchableDropdown(
                          items: customerNames,
                          selectedItem: selectedCustomer,
                          onChanged: (String? value) {
                            setDialogState(() {
                              selectedCustomer = value;
                              selectedCustId = customerIdMap[value];
                            });
                          },
                          hintText: 'Select Customer',
                          labelText: 'Customer Name',
                        ),
                        
                        const SizedBox(height: 16),
                        
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: fromDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    primaryColor: AppTheme.primaryColor,
                                    colorScheme: ColorScheme.light(
                                      primary: AppTheme.primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && picked != fromDate) {
                              setDialogState(() {
                                fromDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'From: ${fromDate.day}/${fromDate.month}/${fromDate.year}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: toDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    primaryColor: AppTheme.primaryColor,
                                    colorScheme: ColorScheme.light(
                                      primary: AppTheme.primaryColor,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && picked != toDate) {
                              setDialogState(() {
                                toDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'To: ${toDate.day}/${toDate.month}/${toDate.year}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                SizedBox(
                  height: 32, // Reduced height
                  child: ElevatedButton(
                    onPressed: dialogLoading ? null : () {
                      if (selectedCustomer != null && selectedCustId != null) {
                        Navigator.pop(context);
                        _handleSubmitAction(selectedOption, selectedCustomer!, selectedCustId!, fromDate, toDate);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a customer'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduced padding
                    ),
                    child: const Text(
                      'SUBMIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12, // Reduced font size
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleSubmitAction(String selectedOption, String customerName, String custId, DateTime fromDate, DateTime toDate) {
    switch (selectedOption) {
      case 'LEDGER':
        // Navigate to CustomerLedgerReportPage for LEDGER
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerLedgerReportPage(
              customerName: customerName,
              custId: custId,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
        break;
      case 'SALE':
        // Navigate to AccountSalePage for SALE with customer details and date range
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountSalePage(
              customerName: customerName,
              custId: custId,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
        break;
      case 'AGED RECEIVABLE':
        // Navigate to AccountAgedReceivablePage for AGED RECEIVABLE with customer details and date range
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountAgedReceivablePage(
              customerName: customerName,
              custId: custId,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
        break;
      case 'RECEIPT':
        // Navigate to AccountReceiptPage for RECEIPT with customer details and date range
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountReceiptPage(
              customerName: customerName,
              custId: custId,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
        break;
      case 'SALES RETURN':
        // Navigate to AccountSalesReturnPage for SALES RETURN with customer details and date range
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountSalesReturnPage(
              customerName: customerName,
              custId: custId,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
        break;
      case 'DISCOUNT':
        // Navigate to AccountDiscountPage for DISCOUNT with customer details and date range
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountDiscountPage(
              customerName: customerName,
              custId: custId,
              fromDate: fromDate,
              toDate: toDate,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unknown option: $selectedOption'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACCOUNT LEDGER'),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.0, // Changed from 0.85 to 1.0 to match home_page.dart
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: ledgerItems.length,
                itemBuilder: (context, index) {
                  final item = ledgerItems[index];
                  return MenuItem(
                    title: item['title'],
                    icon: item['icon'],
                    onTap: () => _handleLedgerTap(context, item['title']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 1,
      ),
    );
  }
}

// Custom Searchable Dropdown Widget
class SearchableDropdown extends StatefulWidget {
  final List<String> items;
  final String? selectedItem;
  final ValueChanged<String?> onChanged;
  final String hintText;
  final String labelText;

  const SearchableDropdown({
    Key? key,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.hintText,
    required this.labelText,
  }) : super(key: key);

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _filteredItems = [];
  bool _isDropdownOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    if (widget.selectedItem != null) {
      _searchController.text = widget.selectedItem!;
    }
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _openDropdown();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _closeDropdown();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items
            .where((item) => item.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    _updateOverlay();
  }

  void _openDropdown() {
    if (_isDropdownOpen) return;
    
    _isDropdownOpen = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    if (!_isDropdownOpen) return;
    
    _isDropdownOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    if (_isDropdownOpen) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    Size size = renderBox?.size ?? Size.zero;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 5.0),
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _filteredItems.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No customers found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return InkWell(
                          onTap: () {
                            widget.onChanged(item);
                            _searchController.text = item;
                            _closeDropdown();
                            _focusNode.unfocus();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: index < _filteredItems.length - 1
                                  ? Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          if (_isDropdownOpen) {
            _closeDropdown();
            _focusNode.unfocus();
          } else {
            _focusNode.requestFocus();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: _searchController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon: Icon(
                _isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey.shade600,
              ),
            ),
            onChanged: (value) {
              _filterItems(value);
              // Clear selection if text doesn't match any item
              if (!widget.items.contains(value)) {
                widget.onChanged(null);
              }
            },
            onTap: () {
              if (!_isDropdownOpen) {
                _openDropdown();
              }
            },
          ),
        ),
      ),
    );
  }
}