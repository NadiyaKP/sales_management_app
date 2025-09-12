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

  Future<void> fetchReceipts() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    final requestBody = {
      "unid": unid,
      "slex": slex,
      "srch": searchQuery,
      "page": currentPage.toString(),
    };

    try {
      debugPrint("📤 API REQUEST [Receipts]: $requestBody");

      final response = await http.post(
        Uri.parse('$url/receipts.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint("📥 API RESPONSE [Receipts]: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          // FIX: Parse string to int for ttlreceipts
          receiptsTotal = int.tryParse(data['ttlreceipts']?.toString() ?? '0') ?? 0;
          final List<dynamic> receiptsList = data['receiptdet'] ?? [];
          setState(() {
            _receipts = receiptsList.map((json) => Receipts.fromJson(json)).toList();
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
      debugPrint("❌ API ERROR [Receipts]: $error");
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

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

      debugPrint("📤 API REQUEST [SaveReceiptData]: $requestBody");

      final response = await http.post(
        Uri.parse('$url/action/receipt.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      debugPrint("📥 API RESPONSE [SaveReceiptData]: ${response.body}");

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to process receipt"};
      }
    } catch (e) {
      debugPrint("❌ API ERROR [SaveReceiptData]: $e");
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void openWhatsAppChat(BuildContext context, Receipts receipt) async {
    String phoneNumber = receipt.whatsappNo.trim();

    if (phoneNumber.isEmpty) {
      _showError("Invalid phone number!");
      return;
    }

    final link = WhatsAppUnilink(
      phoneNumber: phoneNumber,
      text: '',
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

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchReceipts();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Search'),
          content: TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Enter receipt no or name'),
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
        );
      },
    );
  }

  void _navigateToNewReceiptPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewReceiptPage()),
    );

    if (result != null) {
      fetchReceipts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New receipt added successfully!')),
      );
    }
  }

  void _editReceipt(Receipts receipt) async {
    final editData = {
      'rcpId': receipt.rcpId,
      'customerName': receipt.name,
      'custId': receipt.custId ?? customerIdMap[receipt.name] ?? '',
      'receivedDate': receipt.date,
      'receivedAmount': parseFormattedAmount(receipt.amount).toString(),
      'paymentMethod': receipt.wallet,
      'walletId': receipt.walletId ?? walletIdMap[receipt.wallet] ?? '',
      'notes': receipt.notes,
      'dueAmount': _formatDueAmount(receipt.dueAmount),
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewReceiptPage(editData: editData),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      if (result['success'] == true) {
        fetchReceipts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
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
        title: const Text('Delete Receipt', style: TextStyle(color: Colors.red, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this receipt?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildDialogRow('Receipt No:', receipt.receiptsNo),
              _buildDialogRow('Name:', receipt.name),
              const SizedBox(height: 12),
              if (receiptDeleteReason == "yes")
                TextField(
                  controller: reasonController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    labelStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  maxLines: 2,
                ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            height: 30,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 11)),
            ),
          ),
          SizedBox(
            height: 30,
            child: ElevatedButton(
              onPressed: () async {
                if (receiptDeleteReason == "yes" && reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide a reason for deletion')),
                  );
                  return;
                }
                
                Navigator.pop(context);
                
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
              child: const Text('Delete', style: TextStyle(fontSize: 11)),
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
          title: const Text('Delete Receipt', style: TextStyle(color: Colors.red, fontSize: 16)),
          content: const Text(
            "Are you sure that you want to delete the receipt?",
            style: TextStyle(fontSize: 13),
          ),
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
              child: const Text("Delete", style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text("Close", style: TextStyle(fontSize: 11)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

  String _formatDueAmount(String? dueAmount) {
    if (dueAmount == null || dueAmount.isEmpty) {
      return '0.00';
    }
    double amount = parseFormattedAmount(dueAmount);
    return amount.toStringAsFixed(2);
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
    if (isLoading && _receipts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipts'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
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
            child: _receipts.isEmpty
                ? const Center(child: Text("No receipts found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _receipts.length,
                    itemBuilder: (context, index) {
                      final receipt = _receipts[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade200, width: 0.5),
                          ),
                          child: Column(
                            children: [
                              // Header Section with Receipt Number and Date
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 5, 38, 76).withOpacity(0.08),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Receipt No: ${receipt.receiptsNo}',
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
                                          _formatDate(receipt.date),
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
                                padding: const EdgeInsets.all(8),
                                child: Column(
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
                                            receipt.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    // Wallet and Received Amount Section
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey.shade200, width: 0.5),
                                      ),
                                      child: Row(
                                        children: [
                                          // Wallet Section
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Wallet',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  receipt.wallet,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Vertical divider
                                          Container(
                                            height: 20,
                                            width: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                          
                                          // Received Amount Section
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Received',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  receipt.amount,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Due Amount Section (if available)
                                    if (receipt.dueAmount != null && receipt.dueAmount!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
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
                                                    'Due',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey.shade600,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    receipt.dueAmount!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.red.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    
                                    const SizedBox(height: 6),
                                    
                                    // Action Buttons Section
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (receiptView == "yes")
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
                                              _viewReceipt(receipt);
                                            },
                                            child: const Icon(Icons.visibility, size: 12, color: Colors.white),
                                          ),
                                        if (receiptView == "yes") const SizedBox(width: 6),
                                        if (receiptEdit == "yes" && receipt.confirm == "verification_pending")
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
                                              _editReceipt(receipt);
                                            },
                                            child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                          ),
                                        if (receiptEdit == "yes" && receipt.confirm == "verification_pending") const SizedBox(width: 6),
                                        if (receiptWhatsapp == "yes")
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
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
                                              openWhatsAppChat(context, receipt);
                                            },
                                            child: const Icon(Icons.message, size: 12, color: Colors.white),
                                          ),
                                        if (receiptWhatsapp == "yes") const SizedBox(width: 6),
                                        if (receiptDelete == "yes" && receipt.confirm == "verification_pending")
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
                                              if (receiptDeleteReason == "yes") {
                                                _deleteReceipt(receipt);
                                              } else {
                                                _simpleDeleteReceipt(receipt);
                                              }
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
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0,
      ),
    );
  }
}

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