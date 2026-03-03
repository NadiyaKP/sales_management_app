import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class NewOrderPage extends StatefulWidget {
  final Map<String, dynamic>? existingOrder;
  final bool isViewMode;
  final bool isEditMode;

  const NewOrderPage({
    Key? key,
    this.existingOrder,
    this.isViewMode = false,
    this.isEditMode = false,
  }) : super(key: key);

  @override
  State<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<NewOrderPage> {
  ApiServices apiServices = ApiServices();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController(); // NEW: Customer search controller
  
  List<Map<String, dynamic>> products = [];
  List<String> filteredProductNames = [];
  Map<String, int> selectedQuantities = {}; // Product name -> quantity
  int _selectedIndex = 0;
  bool isLoading = false;
  
  // API-related variables
  List<String> customerNames = [];
  List<String> filteredCustomerNames = []; // NEW: Filtered customer names
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  List<String> productNames = [];
  Map<String, String> productIdMap = {};
  
  // For edit mode
  String? orderId;
  bool _dataInitialized = false;
  
  // NEW: Customer dropdown state
  bool _showCustomerDropdown = false;
  final FocusNode _customerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
    _searchController.addListener(_filterProducts);
    _customerSearchController.addListener(_filterCustomers); // NEW: Add customer filter listener
    _customerFocusNode.addListener(_onCustomerFocusChange); // NEW: Add focus listener
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
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

  void _filterProducts() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredProductNames = _getSortedProductNames();
      } else {
        List<String> searchResults = productNames
            .where((product) => product.toLowerCase().contains(query))
            .toList();
        filteredProductNames = _sortProductsBySelection(searchResults);
      }
    });
  }

  // NEW METHOD: Sort products with selected items at top
  List<String> _getSortedProductNames() {
    return _sortProductsBySelection(productNames);
  }

  // NEW METHOD: Sort a list of products putting selected ones first
  List<String> _sortProductsBySelection(List<String> products) {
    List<String> selectedProducts = [];
    List<String> unselectedProducts = [];
    
    for (String product in products) {
      if (selectedQuantities.containsKey(product) && selectedQuantities[product]! > 0) {
        selectedProducts.add(product);
      } else {
        unselectedProducts.add(product);
      }
    }
    
    // Sort selected products by quantity in descending order (highest quantity first)
    selectedProducts.sort((a, b) {
      int qtyA = selectedQuantities[a] ?? 0;
      int qtyB = selectedQuantities[b] ?? 0;
      return qtyB.compareTo(qtyA);
    });
    
    // Combine selected products at top, then unselected products
    return [...selectedProducts, ...unselectedProducts];
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Future.wait([
        loadCustomers(),
        loadProducts(),
      ]);

      if (widget.existingOrder != null && !_dataInitialized) {
        _initializeExistingOrderData();
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

  void _initializeExistingOrderData() {
    final existingOrder = widget.existingOrder!;
    
    orderId = existingOrder['orderId'];
    
    // Set customer data
    String customerName = existingOrder['customerName'] ?? '';
    if (customerName.isNotEmpty) {
      _nameController.text = customerName;
      _customerSearchController.text = customerName; // NEW: Set customer search controller
      
      if (customerNames.contains(customerName)) {
        selectedCustomer = customerName;
        selectedCustId = customerIdMap[customerName];
      } else {
        setState(() {
          customerNames.add(customerName);
          String tempCustId = existingOrder['custId'] ?? '';
          if (tempCustId.isNotEmpty) {
            customerIdMap[customerName] = tempCustId;
            selectedCustId = tempCustId;
          }
          selectedCustomer = customerName;
        });
      }
    }
    
    _notesController.text = existingOrder['notes'] ?? '';
    
    // Set date
    String orderDate = existingOrder['orderDate'] ?? '';
    if (orderDate.isNotEmpty) {
      try {
        DateTime parsedDate;
        if (orderDate.contains('-')) {
          if (orderDate.split('-')[0].length == 2) {
            _dateController.text = orderDate;
          } else {
            parsedDate = DateTime.parse(orderDate);
            _dateController.text = DateFormat('dd-MM-yyyy').format(parsedDate);
          }
        } else {
          parsedDate = DateTime.parse(orderDate);
          _dateController.text = DateFormat('dd-MM-yyyy').format(parsedDate);
        }
      } catch (e) {
        _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
      }
    }
    
    // Set products and quantities
    if (existingOrder['products'] != null) {
      List<Map<String, dynamic>> existingProducts = List<Map<String, dynamic>>.from(existingOrder['products']);
      
      for (var product in existingProducts) {
        String productName = product['prd_name'] ?? '';
        String productId = product['prd_id'] ?? '';
        int qty = int.tryParse(product['qty']?.toString() ?? '0') ?? 0;
        
        if (productName.isNotEmpty && !productNames.contains(productName)) {
          setState(() {
            productNames.add(productName);
            if (productId.isNotEmpty) {
              productIdMap[productName] = productId;
            }
          });
        }
        
        // Set the quantity for this product
        if (productName.isNotEmpty && qty > 0) {
          selectedQuantities[productName] = qty;
        }
      }
      
      setState(() {
        products = existingProducts;
      });
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
        filteredCustomerNames = List.from(customerNames); // NEW: Initialize filtered list
      });
    } catch (e) {
      _showError('Failed to load customers: $e');
    }
  }

  Future<void> loadProducts() async {
    try {
      List<Map<String, String>> productsList = await apiServices.fetchProducts();
      setState(() {
        productNames = productsList.map((e) => e["prd_name"]!).toList();
        productIdMap = {for (var e in productsList) e["prd_name"]!: e["prd_id"]!};
        filteredProductNames = _getSortedProductNames(); // MODIFIED: Use sorted list
      });
    } catch (e) {
      _showError('Failed to load products: $e');
    }
  }

  // NEW: Handle customer selection from dropdown
  void _selectCustomer(String customerName) {
    setState(() {
      selectedCustomer = customerName;
      selectedCustId = customerIdMap[customerName];
      _customerSearchController.text = customerName;
      _nameController.text = customerName;
      _showCustomerDropdown = false;
    });
    _customerFocusNode.unfocus();
  }

  void _incrementQuantity(String productName) {
    if (widget.isViewMode) return;
    
    setState(() {
      selectedQuantities[productName] = (selectedQuantities[productName] ?? 0) + 1;
      // MODIFIED: Re-sort the filtered list after quantity change
      _filterProducts();
    });
  }

  void _decrementQuantity(String productName) {
    if (widget.isViewMode) return;
    
    setState(() {
      int currentQty = selectedQuantities[productName] ?? 0;
      if (currentQty > 1) {
        selectedQuantities[productName] = currentQty - 1;
      } else {
        selectedQuantities.remove(productName);
      }
      // MODIFIED: Re-sort the filtered list after quantity change
      _filterProducts();
    });
  }

  Future<Map<String, dynamic>> _saveOrderData() async {
    if (selectedCustomer == null || selectedCustId == null) {
      _showError('Customer must be selected.');
      return {"result": "0"};
    }
    
    // Build products list from selected quantities
    List<Map<String, dynamic>> orderProducts = [];
    selectedQuantities.forEach((productName, quantity) {
      if (quantity > 0) {
        orderProducts.add({
          "prd_id": productIdMap[productName] ?? '',
          "prd_name": productName,
          "qty": quantity.toString()
        });
      }
    });
    
    if (orderProducts.isEmpty) {
      _showError('Please add at least one product.');
      return {"result": "0"};
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
        return {"result": "0"};
      }
      
      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "cust_name": selectedCustomer ?? '',
        "custid": selectedCustId ?? '',
        "ord_date": _dateController.text,
        "notes": _notesController.text.trim(),
        "prd_det": orderProducts
      };

      if (widget.isEditMode && orderId != null) {
        requestBody["action"] = "update";
        requestBody["ordid"] = orderId;
      } else {
        requestBody["action"] = "insert";
      }
      
      debugPrint('Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$url/action/order.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result["result"] == "1") {
          String successMessage = widget.isEditMode 
              ? "Order updated successfully!" 
              : "Order saved successfully!";
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMessage),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          Navigator.pop(context, result);
          return result;
        } else {
          _showError(result["message"] ?? "Failed to save order.");
          return {"result": "0", "message": result["message"] ?? "Failed to save order."};
        }
      } else {
        _showError("Server error: ${response.statusCode}");
        return {"result": "0", "message": "Server error: ${response.statusCode}"};
      }
    } catch (e) {
      debugPrint('Error saving order: $e');
      _showError("Network error: $e");
      return {"result": "0", "message": "Network error: $e"};
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _saveOrder() {
    if (widget.isViewMode) return;
    _saveOrderData();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Future<void> _selectDate(BuildContext context) async {
    if (widget.isViewMode) return;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
        _dateController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index != 2) {
      Navigator.pop(context);
    }
  }

  Widget _buildCustomerDateRow() {
    return Row(
      children: [
        // Customer Field - MODIFIED: Now with search functionality
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Name', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: widget.isViewMode
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Text(
                          selectedCustomer?.isNotEmpty == true ? selectedCustomer! : 'Not specified',
                          style: const TextStyle(fontSize: 16),
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
                                  _nameController.text = value;
                                });
                              } else {
                                setState(() {
                                  selectedCustomer = null;
                                  selectedCustId = null;
                                  _nameController.text = value;
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
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Date Field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Date', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  enabled: !widget.isViewMode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
                  ),
                  onTap: () => _selectDate(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    if (widget.isViewMode) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search Products', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              hintText: 'Search for products...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Products', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          height: 250, // Reduced height to prevent overflow
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: filteredProductNames.isEmpty
              ? const Center(
                  child: Text(
                    'No products found',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredProductNames.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    String productName = filteredProductNames[index];
                    int quantity = selectedQuantities[productName] ?? 0;
                    bool isSelected = quantity > 0;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      // MODIFIED: Add visual distinction for selected products
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : null,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected ? Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          width: 1,
                        ) : null,
                      ),
                      child: Row(
                        children: [
                          // MODIFIED: Add selection indicator
                          if (isSelected) ...[
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Product Name
                          Expanded(
                            child: Text(
                              productName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? AppTheme.primaryColor : Colors.black,
                              ),
                            ),
                          ),
                          // Quantity Controls
                          if (!widget.isViewMode) ...[
                            // Add Button
                            GestureDetector(
                              onTap: () => _incrementQuantity(productName),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Quantity Display
                            Container(
                              width: 50,
                              height: 32,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                                color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                              ),
                              child: Center(
                                child: Text(
                                  quantity.toString(),
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppTheme.primaryColor : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Remove Button
                            GestureDetector(
                              onTap: quantity > 0 ? () => _decrementQuantity(productName) : null,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: quantity > 0 ? Colors.red : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: quantity > 0 ? Colors.white : Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                          ] else if (quantity > 0) ...[
                            // View mode - just show quantity
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Qty: $quantity',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notes', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 2, // Reduced from 3 to 2 to save space
            minLines: 2,
            readOnly: widget.isViewMode,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintText: 'Enter any additional notes...',
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    if (widget.isViewMode) return const SizedBox.shrink();
    
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : _saveOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                widget.isEditMode ? 'Update Order' : 'Save Order', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
      ),
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
                ? 'VIEW ORDER' 
                : widget.isEditMode 
                    ? 'EDIT ORDER' 
                    : 'NEW ORDER',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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
              Text('Loading order data...'),
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
              ? 'VIEW ORDER' 
              : widget.isEditMode 
                  ? 'EDIT ORDER' 
                  : 'NEW ORDER',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: SafeArea(
          child: SingleChildScrollView( // MAIN FIX: Wrap content in SingleChildScrollView
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerDateRow(),
                const SizedBox(height: 16), // Reduced spacing
                if (!widget.isViewMode) ...[
                  _buildSearchBox(),
                  const SizedBox(height: 16), // Reduced spacing
                ],
                _buildProductsList(),
                const SizedBox(height: 16), // Reduced spacing
                _buildNotesField(),
                const SizedBox(height: 16), // Reduced spacing
                _buildSaveButton(),
                const SizedBox(height: 16), // Add bottom padding for safe area
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
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
    );
  }
}