import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sales_management_app/screens/order/editorder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import 'new_order_page.dart';
import 'view_order.dart';
import 'editorder.dart';

// Global permission variables
String orderAdd = '';
String orderEdit = '';
String orderView = '';
String orderDelete = '';
String orderReport = '';

class Orders {
  final String orderId;
  final String orderDate;
  final String name;
  final String orderNo;

  Orders({
    required this.orderId,
    required this.orderDate,
    required this.name,
    required this.orderNo,
  });

  factory Orders.fromJson(Map<String, dynamic> json) {
    return Orders(
      orderId: json['ordid'] ?? '',
      orderDate: json['ord_date'] ?? '',
      name: json['cust_name'] ?? '',
      orderNo: json['ord_no'] ?? '',
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({Key? key}) : super(key: key);

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  bool isLoading = false;
  
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  
  List<Orders> _orders = [];
  List<Orders> filteredOrders = [];
  int ordersTotal = 0;

  @override
  void initState() {
    super.initState();
    fetchOrders();
    _loadPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchOrders() async {
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
        Uri.parse('$url/orders.php'),
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
          ordersTotal = data['ttlorders'];
          final List<dynamic> ordersList = data['orderdet'] ?? [];
          setState(() {
            ordersTotal = ordersTotal;
            _orders = ordersList.map((json) => Orders.fromJson(json)).toList();
            filteredOrders = _orders;
          });
          if (ordersList.isEmpty) {
            _showError('No Orders data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch orders.');
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

  void _filterOrders() async {
    if (!mounted) {
      return;
    }
    setState(() {
      isLoading = true;
      currentPage = 1; //Reset 
    });

    try {
      await fetchOrders();
      if (filteredOrders.isEmpty) {
        _showError('No orders data found');
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

  Future<void> _loadPermissions() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _showError('Missing credentials for permissions');
        return;
      }

      final response = await http.post(
        Uri.parse('$url/permissions.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1" && data['permissions'] != null) {
          final permissions = data['permissions'];
          setState(() {
            orderAdd = permissions['order_add'] ?? 'no';
            orderEdit = permissions['order_edit'] ?? 'no';
            orderView = permissions['order_view'] ?? 'no';
            orderReport = permissions['order_report'] ?? 'no';
            orderDelete = permissions['order_delete'] ?? 'no';
          });
        } else {
          // Set default permissions if API call fails
          setState(() {
            orderAdd = 'yes';
            orderEdit = 'yes';
            orderView = 'yes';
            orderReport = 'yes';
            orderDelete = 'yes';
          });
        }
      } else {
        // Set default permissions if API call fails
        setState(() {
          orderAdd = 'yes';
          orderEdit = 'yes';
          orderView = 'yes';
          orderReport = 'yes';
          orderDelete = 'yes';
        });
      }
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
      // Set default permissions if there's an error
      setState(() {
        orderAdd = 'yes';
        orderEdit = 'yes';
        orderView = 'yes';
        orderReport = 'yes';
        orderDelete = 'yes';
      });
    }
  }

  Future<Map<String, dynamic>> _deleteOrderData({String? orderId}) async {
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
        "action": 'delete',
        "ordid": orderId,
      };

      final response = await http.post(
        Uri.parse('$url/action/order.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to delete order"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
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

  List<Orders> get currentPageOrders {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage > filteredOrders.length)
        ? filteredOrders.length
        : start + itemsPerPage;
    return filteredOrders.sublist(start, end);
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchOrders();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter order no or name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _searchController.clear();
              setState(() {
                searchQuery = '';
                currentPage = 1;
              });
              _filterOrders();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
                currentPage = 1;
              });
              Navigator.pop(context);
              _filterOrders();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewOrder() async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final result = await navigator.push(
      MaterialPageRoute(builder: (_) => const NewOrderPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      fetchOrders(); // Refresh orders after saving
    }
  }

  // Updated method to use EditOrderScreen
  
  void _navigateToEditOrder(Orders order) async {
    if (!context.mounted) return;
    
    final navigator = Navigator.of(context);
    final result = await navigator.push(
      MaterialPageRoute(
        builder: (_) => EditOrderScreen(order.orderId),
      ),
    );

    // Refresh orders after editing (whether successful or not)
    if (result != null || context.mounted) {
      fetchOrders();
    }
  }

  void _navigateToViewOrder(Orders order) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ViewOrderPage(orderId: order.orderId),
      ),
    );
  }

  void _deleteOrder(Orders order) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Order'),
          content: const Text('Are you sure that, you want to delete this order?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Map<String, dynamic> result =
                    await _deleteOrderData(orderId: order.orderId);
                if (!dialogContext.mounted) {
                  return;
                }
                if (result['result'] == '1') {
                  if (mounted) {
                    setState(() {
                      fetchOrders();
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  _showError(result['message']);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && filteredOrders.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ORDERS'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ORDERS'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: currentPageOrders.isEmpty
                ? const Center(
                    child: Text(
                      "No orders found.",
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentPageOrders.length,
                    itemBuilder: (context, index) {
                      final order = currentPageOrders[index];
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
                              Text(
                                'Order No: ${order.orderNo}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildRow('Name', order.name),
                              _buildRow('Date', order.orderDate),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (orderView == "yes")
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.visibility, size: 14, color: Colors.white),
                                      label: const Text('View', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 7, 63, 91),
                                        foregroundColor: Colors.white,
                                        elevation: 1,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () {
                                        _navigateToViewOrder(order);
                                      },
                                    ),
                                  if (orderView == "yes") const SizedBox(width: 6),
                                  if (orderEdit == "yes")
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                      label: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(255, 7, 63, 91),
                                        foregroundColor: Colors.white,
                                        elevation: 1,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () {
                                        _navigateToEditOrder(order);
                                      },
                                    ),
                                  if (orderEdit == "yes") const SizedBox(width: 6),
                                  if (orderDelete == "yes")
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.delete, size: 14, color: Colors.white),
                                      label: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                        elevation: 1,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: const Size(0, 28),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                      onPressed: () {
                                        _deleteOrder(order);
                                      },
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
            totalItems: ordersTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      floatingActionButton: orderAdd == "yes" ? FloatingActionButton(
        onPressed: _navigateToNewOrder,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0, 
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
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
}