import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:whatsapp_unilink/whatsapp_unilink.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import '../home_page.dart';
import '../report_page.dart';
import 'new_receipt_page.dart';
import 'receipt_view.dart'; 

// Receipt permission variables
String receiptAdd = '';
String receiptDueAmount = '';
String receiptDateChange = '';
String receiptEdit = '';
String receiptView = '';
String receiptDelete = '';
String receiptDeleteReason = '';
String receiptWhatsapp = '';

class Receipts {
  final String receiptsNo;
  final String date;
  final String name;
  final String wallet;
  final String notes;
  final String amount;
  final String whatsappNo;
  final String whatsappContent;
  final String confirm;
  final String rcpId;
  final String? custId;
  final String? walletId;
  final String? dueAmount;

  Receipts({
    required this.receiptsNo,
    required this.date,
    required this.name,
    required this.wallet,
    required this.notes,
    required this.amount,
    required this.whatsappNo,
    required this.whatsappContent,
    required this.confirm,
    required this.rcpId,
    this.custId,
    this.walletId,
    this.dueAmount,
  });

  factory Receipts.fromJson(Map<String, dynamic> json) {
    return Receipts(
      receiptsNo: json['rcp_no'] ?? '',
      date: json['rcp_date'] ?? '',
      name: json['custname'] ?? '',
      wallet: json['wlt_name'] ?? '',
      notes: json['notes'] ?? '',
      amount: json['rcp_amt'] ?? '',
      whatsappNo: json['whatsapp_no'] ?? '',
      whatsappContent: json['whatsapp_content'] ?? '',
      confirm: json['confirm'] ?? '',
      rcpId: json['rcpid'] ?? '',
      custId: json['custid'] ?? '',
      walletId: json['wltid'] ?? '',
      dueAmount: json['due_amt'] ?? '',
    );
  }
}

class ReceiptsPage extends StatefulWidget {
  const ReceiptsPage({Key? key}) : super(key: key);

  @override
  State<ReceiptsPage> createState() => _ReceiptsPageState();
}

class _ReceiptsPageState extends State<ReceiptsPage> {
  ApiServices apiServices = ApiServices();
  TextEditingController _searchController = TextEditingController();
  final TextEditingController deleteReasonController = TextEditingController();
  
  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  
  List<Receipts> _receipts = [];
  List<Receipts> filteredReceipts = [];
  int receiptsTotal = 0;
  bool isLoading = false;

  // Customer and Wallet data
  List<String> customerNames = [];
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};
  Map<String, String> customerAmountMap = {};

  List<String> wallets = [];
  String? selectedWallet;
  String? selectedWalletId;
  Map<String, String> walletIdMap = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    loadCustomers();
    loadWallets();
    fetchReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    deleteReasonController.dispose();
    super.dispose();
  }

  // Load permissions from API
  Future<void> _loadPermissions() async {
    try {
      final permissionResponse = await _fetchPermissions();
      if (permissionResponse.permissionDetails.isNotEmpty) {
        setState(() {
          final permissionDetail = permissionResponse.permissionDetails[0];
          receiptAdd = permissionDetail.receiptAdd;
          receiptDueAmount = permissionDetail.receiptDueAmount;
          receiptDateChange = permissionDetail.receiptDateChange;
          receiptEdit = permissionDetail.receiptEdit;
          receiptView = permissionDetail.receiptView;
          receiptDelete = permissionDetail.receiptDelete;
          receiptDeleteReason = permissionDetail.receiptDeleteReason;
          receiptWhatsapp = permissionDetail.receiptWhatsapp;
        });
      } else {
        _showError('No permissions data available.');
      }
    } catch (e) {
      _showError('Error fetching permissions: $e');
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

  // Load customers from API
  Future<void> loadCustomers() async {
    try {
      List<Map<String, String>> customers = await apiServices.fetchCustomers();
      setState(() {
        customerNames = customers.map((e) => e["cust_name"]!).toList();
        customerIdMap = {for (var e in customers) e["cust_name"]!: e["custid"]!};
        customerAmountMap = {for (var e in customers) e["cust_name"]!: e["outstand_amt"]!};
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  // Load wallets from API
  Future<void> loadWallets() async {
    try {
      List<Map<String, String>> wallet = await apiServices.fetchWallets();
      setState(() {
        wallets = wallet.map((e) => e["wlt_name"]!).toList();
        walletIdMap = {for (var e in wallet) e["wlt_name"]!: e["wltid"]!};
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  // Fetch receipts from API
  Future<void> fetchReceipts() async {
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
        Uri.parse('$url/receipts.php'),
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
          receiptsTotal = data['ttlreceipts'] ?? 0;
          final List<dynamic> receiptsList = data['receiptdet'] ?? [];
          setState(() {
            _receipts = receiptsList.map((json) => Receipts.fromJson(json)).toList();
            filteredReceipts = _receipts;
          });
          if (receiptsList.isEmpty) {
            _showError('No receipts data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch receipts.');
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

  // Save/Update/Delete receipt data
  Future<Map<String, dynamic>> _saveReceiptData(String action,
      {String? rcpId, String reason = ""}) async {
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

      if (action == 'delete' && rcpId != null) {
        requestBody["rcpid"] = rcpId;
        if (reason.isNotEmpty) {
          requestBody["reason"] = reason;
        }
      }

      final response = await http.post(
        Uri.parse('$url/action/receipt.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to process receipt"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  //  WhatsApp functionality to navigate to WhatsApp chat
  void openWhatsAppChat(BuildContext context, Receipts receipt) async {
    String phoneNumber = receipt.whatsappNo.trim();

    if (phoneNumber.isEmpty) {
      _showError("Invalid phone number!");
      return;
    }

    // Create WhatsApp URL to open chat without pre-filled message
    final link = WhatsAppUnilink(
      phoneNumber: phoneNumber,
      text: '', // Empty text to just open the chat
    );

    final Uri whatsappUrl = Uri.parse(link.toString());

    try {
      bool canLaunch = await canLaunchUrl(whatsappUrl);
      if (canLaunch) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        _showError("WhatsApp is not installed!");
      }
    } catch (e) {
      _showError("Error: Could not open WhatsApp");
    }
  }

  List<Receipts> get currentPageReceipts {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage > filteredReceipts.length)
        ? filteredReceipts.length
        : start + itemsPerPage;
    return filteredReceipts.sublist(start, end);
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchReceipts();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter receipt no or name'),
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
              fetchReceipts();
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
              fetchReceipts();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewReceiptPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewReceiptPage()),
    );

    if (result != null) {
      // Refresh receipts after adding new one
      fetchReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New receipt added successfully!')),
      );
    }
  }

  
  void _editReceipt(Receipts receipt) async {
    //receipt data for editing - matching NewReceiptPage editData parameter
    final editData = {
      'rcpId': receipt.rcpId,
      'customerName': receipt.name,
      'custId': receipt.custId ?? customerIdMap[receipt.name] ?? '',
      'receivedDate': receipt.date,
      'receivedAmount': parseFormattedAmount(receipt.amount).toString(),
      'paymentMethod': receipt.wallet,
      'walletId': receipt.walletId ?? walletIdMap[receipt.wallet] ?? '',
      'notes': receipt.notes,
      // Ensure due amount is properly formatted and never empty
      'dueAmount': _formatDueAmount(receipt.dueAmount),
    };

    // Navigate to NewReceiptPage with editData
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewReceiptPage(editData: editData),
      ),
    );

    // Handle the result returned from NewReceiptPage
    if (result != null && result is Map<String, dynamic>) {
      if (result['success'] == true) {
        // Refresh the receipts list to show updated data
        fetchReceipts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Handle update failure if needed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update receipt. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewReceipt(Receipts receipt) async {
    // Navigate to ReceiptView page with the receipt data
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptViewPage(rcpId: receipt.rcpId),
      ),
    );
  }

  void _deleteReceipt(Receipts receipt) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt', style: TextStyle(color: Colors.red)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this receipt?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildDialogRow('Receipt No:', receipt.receiptsNo),
              _buildDialogRow('Name:', receipt.name),
              const SizedBox(height: 16),
              if (receiptDeleteReason == "yes")
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
                
                if (receiptDeleteReason == "yes" && reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason for deletion')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                
                // Call API to delete receipt
                Map<String, dynamic> result = await _saveReceiptData(
                  'delete',
                  rcpId: receipt.rcpId,
                  reason: reasonController.text,
                );
                
                if (result['result'] == '1') {
                  setState(() {
                    fetchReceipts();
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

  void _simpleDeleteReceipt(Receipts receipt) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
        
          content: const Text("Are you sure that you want to delete the receipt?"),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                Map<String, dynamic> result = await _saveReceiptData('delete', rcpId: receipt.rcpId);

                if (!dialogContext.mounted) return;

                if (result['result'] == '1') {
                  setState(() {
                    fetchReceipts();
                  });
                  _showSuccess(result['message']);
                } else {
                  _showError(result['message']);
                }

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text("Delete"),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
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
            maxLines: 1, // Ensure single line
            overflow: TextOverflow.ellipsis, // Add ellipsis if text is too long
            softWrap: false, // Prevent text wrapping
          ),
        ),
      ],
    ),
  );
}
  // Helper method to format due amount properly
  String _formatDueAmount(String? dueAmount) {
    if (dueAmount == null || dueAmount.isEmpty) {
      return '0.00';
    }
    
    // Parse and reformat to ensure valid decimal format
    double amount = parseFormattedAmount(dueAmount);
    return amount.toStringAsFixed(2);
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
    if (isLoading && filteredReceipts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RECEIPTS'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('RECEIPTS'),
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
            child: currentPageReceipts.isEmpty
                ? const Center(child: Text('No receipts found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentPageReceipts.length,
                    itemBuilder: (context, index) {
                      final receipt = currentPageReceipts[index];
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
                                'No: ${receipt.receiptsNo}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              _buildRow('Name', capitalizeWords(receipt.name)),
                              _buildRow('Date', receipt.date),
                              _buildRow('Wallet', capitalizeWords(receipt.wallet)),
                              _buildRow('Notes', receipt.notes.isEmpty ? 'No notes' : receipt.notes),
                              _buildRow('Received', receipt.amount, color: Colors.green.shade700),
                              if (receipt.dueAmount != null && receipt.dueAmount!.isNotEmpty)
                                _buildRow('Due Amount', receipt.dueAmount!, color: Colors.red.shade700),
                              const SizedBox(height: 16),
                              // Action buttons in a single row with proper spacing
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (receiptEdit == "yes" && receipt.confirm == "verification_pending")
                                    _buildActionButton(
                                      icon: Icons.edit,
                                      label: 'Edit',
                                      backgroundColor: const Color.fromARGB(255, 5, 38, 76),
                                      onPressed: () => _editReceipt(receipt),
                                    ),
                                  if (receiptEdit == "yes" && receipt.confirm == "verification_pending")
                                    const SizedBox(width: 6),
                                  if (receiptView == "yes")
                                    _buildActionButton(
                                      icon: Icons.visibility,
                                      label: 'View',
                                      backgroundColor: const Color.fromARGB(255, 5, 38, 76),
                                      onPressed: () => _viewReceipt(receipt),
                                    ),
                                  if (receiptView == "yes")
                                    const SizedBox(width: 6),
                                  if (receiptWhatsapp == "yes")
                                    _buildActionButton(
                                      icon: Icons.message,
                                      label: 'WhatsApp',
                                      backgroundColor: Colors.green.shade700,
                                      onPressed: () => openWhatsAppChat(context, receipt),
                                    ),
                                  if (receiptWhatsapp == "yes" && receiptDelete == "yes" && receipt.confirm == "verification_pending")
                                    const SizedBox(width: 6),
                                  if (receiptDelete == "yes" && receipt.confirm == "verification_pending")
                                    _buildActionButton(
                                      icon: Icons.delete,
                                      label: 'Delete',
                                      backgroundColor: Colors.red.shade700,
                                      onPressed: () {
                                        if (receiptDeleteReason == "yes") {
                                          _deleteReceipt(receipt);
                                        } else {
                                          _simpleDeleteReceipt(receipt);
                                        }
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
            totalItems: receiptsTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      floatingActionButton: receiptAdd == "yes" 
          ? FloatingActionButton(
              onPressed: _navigateToNewReceiptPage,
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
    return Flexible(
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
      ),
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
}

// Helper functions
double parseFormattedAmount(String formattedAmount) {
  final cleanString = formattedAmount.replaceAll(',', '');
  return double.tryParse(cleanString) ?? 0.0;
}

String capitalizeWords(String text) {
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}