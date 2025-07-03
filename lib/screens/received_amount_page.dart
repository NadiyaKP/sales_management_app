import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'home_page.dart';
import 'report_page.dart';

class ReceivedAmount {
  final String rcpId;
  final String rcpNo;
  final String customerName;
  final String rcpDate;
  final String walletName;
  final String notes;
  final String rcpAmount;

  ReceivedAmount({
    required this.rcpId,
    required this.rcpNo,
    required this.customerName,
    required this.rcpDate,
    required this.walletName,
    required this.notes,
    required this.rcpAmount,
  });

  factory ReceivedAmount.fromJson(Map<String, dynamic> json) {
    return ReceivedAmount(
      rcpId: json['rcpid'] ?? '',
      rcpNo: json['rcp_no'] ?? '',
      customerName: json['custname'] ?? '',
      rcpDate: json['rcp_date'] ?? '',
      walletName: json['wlt_name'] ?? '',
      notes: json['notes'] ?? '',
      rcpAmount: json['rcp_amt'] ?? '',
    );
  }
}

class ReceivedAmountPage extends StatefulWidget {
  const ReceivedAmountPage({Key? key}) : super(key: key);

  @override
  State<ReceivedAmountPage> createState() => _ReceivedAmountPageState();
}

class _ReceivedAmountPageState extends State<ReceivedAmountPage> {
  TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  int _selectedIndex = 0;
  bool hasShownNoDataSnackBar = false;
  bool isLoading = false;

  // API response data
  List<ReceivedAmount> receivedTransactions = [];
  List<ReceivedAmount> filteredTransactions = [];
  String totalReceivedAmount = '0';
  int noOfCashWithMe = 0;

  @override
  void initState() {
    super.initState();
    fetchReceivedAmountData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchReceivedAmountData() async {
    if (!mounted) return;
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
        return;
      }

      final response = await http.post(
        Uri.parse('$url/received-amount-with-me.php'),
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
        
        if (data['result'] == "1") {
          final List<dynamic> receivedAmountList = data['receivedamountdet'] ?? [];
          
          setState(() {
            totalReceivedAmount = data['ttl_received_amt'] ?? '0';
            noOfCashWithMe = data['noofcashwithme'] ?? 0;
            receivedTransactions = receivedAmountList
                .map((json) => ReceivedAmount.fromJson(json))
                .toList();
            _applyFilter();
          });

          if (receivedAmountList.isEmpty) {
            _showError('No received amount data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch received amount data.');
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

  void _applyFilter() {
    if (searchQuery.isEmpty) {
      filteredTransactions = receivedTransactions;
    } else {
      filteredTransactions = receivedTransactions.where((item) {
        return item.rcpNo.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.customerName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.walletName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.notes.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (filteredTransactions.isEmpty && searchQuery.isNotEmpty && !hasShownNoDataSnackBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sorry! No transaction found.')),
          );
        }
      });
      hasShownNoDataSnackBar = true;
    } else if (filteredTransactions.isNotEmpty) {
      hasShownNoDataSnackBar = false;
    }
  }

  int get totalPages => (filteredTransactions.length / itemsPerPage).ceil();

  List<ReceivedAmount> get currentTransactions {
    if (filteredTransactions.length <= itemsPerPage) {
      // If total items are less than or equal to items per page, show all
      return filteredTransactions;
    }
    
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage > filteredTransactions.length)
        ? filteredTransactions.length
        : start + itemsPerPage;
    return filteredTransactions.sublist(start, end);
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportPage()));
    } else if (index == 3) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, AppConstants.registerRoute);
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter receipt no, customer name, wallet or notes'
          ),
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
                _applyFilter();
              });
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
                currentPage = 1;
                _applyFilter();
              });
              Navigator.of(context).pop();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatAmount(String amount) {
    // Remove commas if present and add ₹ symbol
    String cleanAmount = amount.replaceAll(',', '');
    return '₹ $cleanAmount';
  }

  String _getPaymentMethodFromWallet(String walletName) {
    switch (walletName.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      default:
        return walletName.toUpperCase();
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
        title: const Text('RECEIVED AMOUNT'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchReceivedAmountData,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Total Received',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatAmount(totalReceivedAmount),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Transactions: $noOfCashWithMe',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: const [
                Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: currentTransactions.isEmpty
                ? const Center(child: Text('No received amounts found.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: currentTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = currentTransactions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            transaction.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Date: ${transaction.rcpDate}'),
                              Text('Receipt No: ${transaction.rcpNo}'),
                              Text('Payment: ${_getPaymentMethodFromWallet(transaction.walletName)}'),
                              if (transaction.notes.isNotEmpty)
                                Text('Notes: ${transaction.notes}'),
                            ],
                          ),
                          trailing: Text(
                            _formatAmount(transaction.rcpAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (filteredTransactions.isNotEmpty && filteredTransactions.length > itemsPerPage) _buildPagination(),
        ],
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

  Widget _buildPagination() {
    final List<Widget> pageButtons = [];

    final int visiblePages = totalPages.clamp(1, maxVisiblePages);
    int startPage = (currentPage - 1).clamp(0, totalPages - visiblePages) + 1;
    int endPage = (startPage + visiblePages - 1).clamp(startPage, totalPages);

    pageButtons.add(_paginationIcon(Icons.first_page,
        enabled: currentPage > 1, onTap: () => setState(() => currentPage = 1)));

    pageButtons.add(_paginationIcon(Icons.chevron_left,
        enabled: currentPage > 1, onTap: () => setState(() => currentPage--)));

    for (int i = startPage; i <= endPage; i++) {
      pageButtons.add(
        GestureDetector(
          onTap: () => setState(() => currentPage = i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: currentPage == i ? AppTheme.primaryColor : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$i',
              style: TextStyle(
                color: currentPage == i ? Colors.white : Colors.black,
                fontWeight: currentPage == i ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    pageButtons.add(_paginationIcon(Icons.chevron_right,
        enabled: currentPage < totalPages,
        onTap: () => setState(() => currentPage++)));

    pageButtons.add(_paginationIcon(Icons.last_page,
        enabled: currentPage < totalPages,
        onTap: () => setState(() => currentPage = totalPages)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: pageButtons,
      ),
    );
  }

  Widget _paginationIcon(IconData icon,
      {required bool enabled, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: enabled ? onTap : null,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}