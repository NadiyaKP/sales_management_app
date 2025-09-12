import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import '../home_page.dart';
import '../report_page.dart';

String stockView = '';

class Stock {
  final String barcode;
  final String itemCode;
  final String itemName;
  final String unit;
  final String currentStock;

  Stock({
    required this.barcode,
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.currentStock,
  });

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      barcode: json['barcode'] ?? '',
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      unit: json['prd_unit'] ?? '',
      currentStock: json['prd_balance'] ?? '',
    );
  }
}

class StocksPage extends StatefulWidget {
  const StocksPage({Key? key}) : super(key: key);

  @override
  State<StocksPage> createState() => _StocksPageState();
}

class _StocksPageState extends State<StocksPage> {
  ApiServices apiServices = ApiServices();
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  
  List<Stock> _stocks = [];
  int stocksTotal = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    fetchStocks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchStocks() async {
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
        Uri.parse('$url/stocks.php'),
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
          // Fix: Handle both string and int types for stocksTotal
          var totalStocks = data['ttlstocks'];
          if (totalStocks is String) {
            stocksTotal = int.tryParse(totalStocks) ?? 0;
          } else if (totalStocks is int) {
            stocksTotal = totalStocks;
          } else {
            stocksTotal = 0;
          }
          
          final List<dynamic> stocksList = data['stockdet'] ?? [];
          setState(() {
            _stocks = stocksList.map((json) => Stock.fromJson(json)).toList();
          });
          
          if (stocksList.isEmpty) {
            _showError('No stocks data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch stocks.');
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
          stockView = permissionDetail.stockView;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
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

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchStocks();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
              hintText: 'Enter barcode, item code or name'),
          autofocus: true,
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
              fetchStocks();
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
              fetchStocks();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && _stocks.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stocks'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocks'),
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
            child: _stocks.isEmpty
                ? const Center(child: Text("No stocks found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _stocks.length,
                    itemBuilder: (context, index) {
                      final stock = _stocks[index];
                      final hasUnit = stock.unit.isNotEmpty;
                      
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
                              // Header Section with Item Code and Barcode
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
                                        'Code: ${stock.itemCode}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(255, 5, 38, 76),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Barcode: ${stock.barcode}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Content Section
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    // Item Name Section
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.inventory,
                                          size: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            stock.itemName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    // Stock Details Section
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                      ),
                                      child: Row(
                                        children: [
                                          // Unit Section - Always show
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Unit',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                if (hasUnit)
                                                  Text(
                                                    stock.unit,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Divider - Always show
                                          Container(
                                            height: 20,
                                            width: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                          
                                          // Current Stock Section
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Stock',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade700.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(
                                                          color: Colors.green.shade700,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        stock.currentStock.isEmpty ? '0' : stock.currentStock,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SlidingPaginationControls(
            currentPage: currentPage,
            totalItems: stocksTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0, 
      ),
    );
  }
}