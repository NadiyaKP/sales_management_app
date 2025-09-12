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
  final String notes;

  Orders({
    required this.orderId,
    required this.orderDate,
    required this.name,
    required this.orderNo,
    required this.notes,
  });

  factory Orders.fromJson(Map<String, dynamic> json) {
    return Orders(
      orderId: _safeString(json['ordid']),
      orderDate: _safeString(json['ord_date']),
      name: _safeString(json['cust_name']),
      orderNo: _safeString(json['ord_no']),
      notes: _safeString(json['notes']),
    );
  }

  // Helper method to safely convert any value to String
  static String _safeString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
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
          "unid": unid ?? '',
          "slex": slex ?? '',
          "srch": searchQuery,
          "page": currentPage.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          // Safe parsing of total orders
          ordersTotal = _safeInt(data['ttlorders']);
          final List<dynamic> ordersList = data['orderdet'] ?? [];
          
          setState(() {
            ordersTotal = ordersTotal;
            _orders = ordersList.map((json) {
              try {
                return Orders.fromJson(json);
              } catch (e) {
                debugPrint('Error parsing order: $e');
                debugPrint('Order data: $json');
                // Return a default order object to prevent crashes
                return Orders(
                  orderId: '',
                  orderDate: '',
                  name: 'Unknown',
                  orderNo: '',
                  notes: '',
                );
              }
            }).toList();
            filteredOrders = _orders;
          });
          
          if (ordersList.isEmpty) {
            _showError('No Orders data found');
          }
        } else {
          _showError(data['message']?.toString() ?? 'Failed to fetch orders.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Fetch orders error: $error');
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Helper method to safely convert any value to int
  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
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
            orderAdd = permissions['order_add']?.toString() ?? 'no';
            orderEdit = permissions['order_edit']?.toString() ?? 'no';
            orderView = permissions['order_view']?.toString() ?? 'no';
            orderReport = permissions['order_report']?.toString() ?? 'no';
            orderDelete = permissions['order_delete']?.toString() ?? 'no';
          });
        } else {
          _setDefaultPermissions();
        }
      } else {
        _setDefaultPermissions();
      }
    } catch (e) {
      debugPrint('Error fetching permissions: $e');
      _setDefaultPermissions();
    }
  }

  void _setDefaultPermissions() {
    setState(() {
      orderAdd = 'yes';
      orderEdit = 'yes';
      orderView = 'yes';
      orderReport = 'yes';
      orderDelete = 'yes';
    });
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
        "ordid": orderId ?? '',
      };

      final response = await http.post(
        Uri.parse('$url/action/order.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          "result": responseData['result']?.toString() ?? "0",
          "message": responseData['message']?.toString() ?? "Unknown error"
        };
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
      fetchOrders();
    }
  }

  void _navigateToEditOrder(Orders order) async {
    if (!context.mounted) return;
    
    final navigator = Navigator.of(context);
    final result = await navigator.push(
      MaterialPageRoute(
        builder: (_) => EditOrderScreen(order.orderId),
      ),
    );

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
                  _showError(result['message'] ?? 'Failed to delete order');
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

  DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.isEmpty) return null;
      
      if (dateStr.contains('-')) {
        return DateTime.parse(dateStr);
      } else if (dateStr.contains('/')) {
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (e) {
      debugPrint('Date parsing error: $e for date: $dateStr');
    }
    return null;
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    
    DateTime? date = _parseDate(dateStr);
    if (date != null) {
      return DateFormat('dd-MM-yyyy').format(date);
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _orders.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Orders'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
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
            child: _orders.isEmpty
                ? const Center(child: Text("No orders found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
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
                              // Header Section with Order Number and Date
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
                                        'Order No: ${order.orderNo.isEmpty ? 'N/A' : order.orderNo}',
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
                                          order.orderDate.isEmpty ? 'N/A' : _formatDate(order.orderDate),
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
                              
                              // Content Section
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Customer Name Section
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            order.name.isEmpty ? 'Unknown Customer' : order.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Notes Section - Only show if notes exist
                                    if (order.notes.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.note,
                                            size: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              order.notes,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.grey.shade700,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Action Buttons Section
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (orderView == "yes")
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
                                            onPressed: () {
                                              _navigateToViewOrder(order);
                                            },
                                            child: const Icon(Icons.visibility, size: 12, color: Colors.white),
                                          ),
                                        if (orderView == "yes") const SizedBox(width: 6),
                                        if (orderEdit == "yes")
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
                                            onPressed: () {
                                              _navigateToEditOrder(order);
                                            },
                                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                          ),
                                        if (orderEdit == "yes") const SizedBox(width: 6),
                                        if (orderDelete == "yes")
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
                                            onPressed: () {
                                              _deleteOrder(order);
                                            },
                                            child: const Icon(Icons.delete, size: 12, color: Colors.white),
                                          ),
                                      ],
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
}