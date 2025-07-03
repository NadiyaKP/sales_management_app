import '../../services/api_service.dart';
import 'orders_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sales_management_app/screens/order/orders_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import 'package:intl/intl.dart';

class EditOrderScreen extends StatefulWidget {
  final String orderId;
  const EditOrderScreen(this.orderId, {super.key});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  ApiServices apiServices = ApiServices();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  
  bool isLoading = true;
  Map<String, dynamic>? orderData;
  String? customer;
  String? customerId;
  String? orderDate;
  String? notes;
  
  List<String> filteredProductNames = [];
  Map<String, int> selectedQuantities = {}; 
  List<String> customerNames = [];
  List<String> filteredCustomerNames = [];
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  List<String> productNames = [];
  Map<String, String> productIdMap = {};
  int _selectedIndex = 0; 
  bool _dataInitialized = false;
  
  final LayerLink _customerLayerLink = LayerLink();
  OverlayEntry? _customerOverlayEntry;
  final FocusNode _customerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProducts);
    _customerSearchController.addListener(_filterCustomers);
    _customerFocusNode.addListener(_onCustomerFocusChange);
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProducts);
    _searchController.dispose();
    _customerSearchController.removeListener(_filterCustomers);
    _customerSearchController.dispose();
    _customerFocusNode.removeListener(_onCustomerFocusChange);
    _customerFocusNode.dispose();
    _removeCustomerOverlay();
    super.dispose();
  }

  void _removeCustomerOverlay() {
    _customerOverlayEntry?.remove();
    _customerOverlayEntry = null;
  }

  void _onCustomerFocusChange() {
    if (_customerFocusNode.hasFocus) {
      _showCustomerDropdownOverlay();
    } else {
      _removeCustomerOverlay();
    }
  }

  void _showCustomerDropdownOverlay() {
    _removeCustomerOverlay();
    
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    
    _customerOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width * 0.9, // Same width as the customer field
        child: CompositedTransformFollower(
          link: _customerLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 60.0), // Position below the customer field
          child: Material(
            elevation: 4.0,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: filteredCustomerNames.length,
                itemBuilder: (context, index) {
                  String customerName = filteredCustomerNames[index];
                  return InkWell(
                    onTap: () => _selectCustomer(customerName),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_customerOverlayEntry!);
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
    });
    
    if (_customerOverlayEntry != null) {
      _customerOverlayEntry!.markNeedsBuild();
    }
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

  List<String> _getSortedProductNames() {
    return _sortProductsBySelection(productNames);
  }

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
    
    selectedProducts.sort((a, b) {
      int qtyA = selectedQuantities[a] ?? 0;
      int qtyB = selectedQuantities[b] ?? 0;
      return qtyB.compareTo(qtyA);
    });
    
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
        fetchSingleOrderDetails(),
      ]);
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() {
        isLoading = false;
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
        filteredCustomerNames = List.from(customerNames);
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
      });
    } catch (e) {
      _showError('Failed to load products: $e');
    }
  }

  Future<void> fetchSingleOrderDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      String orderId = widget.orderId;

      final response = await http.post(
        Uri.parse("$url/single-order-view.php"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "ordid": orderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          setState(() {
            orderData = data;
            final customerDetails = orderData!['customerdet'][0];
            customer = customerDetails['custname'];
            customerId = customerDetails['custid'];
            selectedCustomer = customer;
            selectedCustId = customerId;
            _customerSearchController.text = customer ?? '';
            
            orderDate = orderData!['ord_date'];
            if (orderDate != null) {
              try {
                DateTime parsedDate;
                if (orderDate!.contains('/')) {
                  orderDate = orderDate!.replaceAll('/', '-');
                  List<String> parts = orderDate!.split('-');
                  if (parts.length == 3) {
                    if (int.parse(parts[0]) > 12) {
                      _dateController.text = orderDate!;
                    } else {
                      _dateController.text = '${parts[1]}-${parts[0]}-${parts[2]}';
                    }
                  }
                } else if (orderDate!.contains('-')) {
                  if (orderDate!.split('-')[0].length == 4) {
                    parsedDate = DateTime.parse(orderDate!);
                    _dateController.text = DateFormat('dd-MM-yyyy').format(parsedDate);
                  } else {
                    _dateController.text = orderDate!;
                  }
                } else {
                  _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
                }
              } catch (e) {
                _dateController.text = DateFormat('dd-MM-yyyy').format(DateTime.now());
              }
            }
            
            List<dynamic> orderProducts = orderData!['ordercartdet'];
            selectedQuantities.clear();
            for (var product in orderProducts) {
              String productName = product['prd_name'];
              int qty = int.tryParse(product['qty'].toString()) ?? 0;
              if (qty > 0) {
                selectedQuantities[productName] = qty;
              }
            }
            
            filteredProductNames = _getSortedProductNames();
            
            notes = orderData!['notes'];
            _notesController.text = notes ?? '';
            _dataInitialized = true;
          });
        } else {
          _showError(data['message'] ?? 'Failed to fetch order details.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('An error occurred: $e');
    }
  }

  void _selectCustomer(String customerName) {
    setState(() {
      selectedCustomer = customerName;
      selectedCustId = customerIdMap[customerName];
      _customerSearchController.text = customerName;
    });
    _customerFocusNode.unfocus();
    _removeCustomerOverlay();
  }

  void _incrementQuantity(String productName) {
    setState(() {
      selectedQuantities[productName] = (selectedQuantities[productName] ?? 0) + 1;
      _filterProducts();
    });
  }

  void _decrementQuantity(String productName) {
    setState(() {
      int currentQty = selectedQuantities[productName] ?? 0;
      if (currentQty > 1) {
        selectedQuantities[productName] = currentQty - 1;
      } else {
        selectedQuantities.remove(productName);
      }
      _filterProducts();
    });
  }

  Future<Map<String, dynamic>> _updateOrderData() async {
    if (selectedCustomer == null || selectedCustId == null) {
      _showError('Customer must be selected.');
      return {"result": "0"};
    }
    
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
      String ordId = widget.orderId;

      Map<String, dynamic> requestBody = {
        "unid": unid,
        "slex": slex,
        "ordid": ordId,
        "action": "update",
        "cust_name": selectedCustomer,
        "custid": selectedCustId,
        "ord_date": _dateController.text,
        "notes": _notesController.text.trim(),
        "prd_det": orderProducts
      };

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OrdersPage()),
            );
          }
          return result;
        } else {
          _showError(result["message"] ?? "Failed to update order.");
          return {"result": "0", "message": result["message"] ?? "Failed to update order."};
        }
      } else {
        _showError("Server error: ${response.statusCode}");
        return {"result": "0", "message": "Server error: ${response.statusCode}"};
      }
    } catch (e) {
      debugPrint('Error updating order: $e');
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

  void _updateOrder() {
    _updateOrderData();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
    
    if (index != 0) { 
      Navigator.pop(context);
    }
  }

  Widget _buildCustomerDateRow() {
    return Row(
      children: [
        // Customer Field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer Name', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              CompositedTransformTarget(
                link: _customerLayerLink,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _customerSearchController,
                    focusNode: _customerFocusNode,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      hintText: 'Type to search customer...',
                      suffixIcon: Icon(Icons.search, color: Colors.grey),
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
          height: 250, 
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
            maxLines: 2,
            minLines: 2,
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

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : _updateOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Update Order', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
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
          title: const Text(
            'EDIT ORDER',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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
        title: const Text(
          'EDIT ORDER',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerDateRow(),
                const SizedBox(height: 16),
                _buildSearchBox(),
                const SizedBox(height: 16),
                _buildProductsList(),
                const SizedBox(height: 16),
                _buildNotesField(),
                const SizedBox(height: 16),
                _buildUpdateButton(),
                const SizedBox(height: 16),
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