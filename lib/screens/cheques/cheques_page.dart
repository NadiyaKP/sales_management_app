import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../common/bottom_navigation_button.dart';
import '../../common/pagination.dart';
import '../home_page.dart';
import '../report_page.dart';
import 'new_cheque_page.dart';
import 'edit_cheque.dart';
import '../../services/api_service.dart';
import '../../services/permission.dart';

// Cheque permission variables
String chequeAdd = '';
String chequeView = '';
String chequeEdit = '';
String chequeClear = '';
String chequeBounce = '';
String chequeDelete = '';
String chequeDeleteReason = '';

class Cheque {
  final String chequeNo;
  final String date;
  final String name;
  final String bank;
  final String transactionType;
  final String amount;
  final String status;
  final String chqId;
  final String custid;
  final String branch;
  final String notes;

  Cheque({
    required this.chequeNo,
    required this.date,
    required this.name,
    required this.bank,
    required this.transactionType,
    required this.amount,
    required this.status,
    required this.chqId,
    required this.custid,
    required this.branch,
    required this.notes,
  });

  factory Cheque.fromJson(Map<String, dynamic> json) {
    return Cheque(
      chequeNo: json['chq_no'] ?? '',
      date: json['chq_date'] ?? '',
      name: json['custname'] ?? '',
      bank: json['bank'] ?? '',
      transactionType: json['notes'] ?? '',
      amount: json['chq_amt'] ?? '',
      status: json['chq_status'] ?? '',
      chqId: json['chqid'] ?? '',
      custid: json['custid'] ?? '',
      branch: json['branch'] ?? '',
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chq_no': chequeNo,
      'chq_date': date,
      'custname': name,
      'bank': bank,
      'notes': transactionType,
      'chq_amt': amount,
      'chq_status': status,
      'chqid': chqId,
      'custid': custid,
      'branch': branch,
      'notes': notes,
    };
  }
}

class ChequesPage extends StatefulWidget {
  const ChequesPage({Key? key}) : super(key: key);

  @override
  State<ChequesPage> createState() => _ChequesPageState();
}

class _ChequesPageState extends State<ChequesPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _deleteReasonController = TextEditingController();
  final TextEditingController _bouncedReasonController = TextEditingController();
  final TextEditingController _receivedDateController = TextEditingController();
  final TextEditingController _receivedAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String searchQuery = '';
  int currentPage = 1;
  final int itemsPerPage = 100;
  final int maxVisiblePages = 3;
  bool isLoading = false;
  int chequesTotal = 0;

  List<Cheque> _cheques = [];
  List<Cheque> filteredCheques = [];

  List<String> customerNames = [];
  String? selectedCustomer;
  String? selectedCustId;
  Map<String, String> customerIdMap = {};

  List<Map<String, String>> wallets = [];
  String? selectedWallet;
  String? selectedWalletId;
  bool _isWalletDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: initState called');
    
    // TEMPORARY FIX: Set permissions manually
    chequeAdd = "yes";
    chequeView = "yes";
    chequeEdit = "yes";
    chequeClear = "yes";
    chequeBounce = "yes";
    chequeDelete = "yes";
    chequeDeleteReason = "yes";
    print('DEBUG: Permissions set manually - Edit: $chequeEdit, Clear: $chequeClear');
    
    _loadPermissions();
    fetchCheques();
    loadCustomers();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    try {
      final walletsData = await ApiServices().fetchWallets();
      setState(() {
        wallets = walletsData;
        if (wallets.isNotEmpty) {
          selectedWallet = wallets.first['wlt_name'];
          selectedWalletId = wallets.first['wltid'];
        }
      });
    } catch (e) {
      _showError('Failed to load wallets: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _deleteReasonController.dispose();
    _bouncedReasonController.dispose();
    _receivedDateController.dispose();
    _receivedAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> fetchCheques() async {
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
        Uri.parse('$url/cheques.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "srch": _searchController.text,
          "page": currentPage.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          // FIX: Convert string to int for ttlcheques
          chequesTotal = int.tryParse(data['ttlcheques']?.toString() ?? '0') ?? 0;
          final List<dynamic> chequesList = data['chequedet'] ?? [];
          setState(() {
            _cheques = chequesList.map((json) => Cheque.fromJson(json)).toList();
            filteredCheques = _cheques;
          });
          if (chequesList.isEmpty) {
            _showError('No cheques data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch cheques.');
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

  Future<void> loadCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      final response = await http.post(
        Uri.parse('$url/customers.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"unid": unid, "slex": slex}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          List<dynamic> customers = data['customers'] ?? [];
          setState(() {
            customerNames = customers.map((e) => e['cust_name'].toString()).toList();
            customerIdMap = {
              for (var e in customers) e['cust_name'].toString(): e['custid'].toString()
            };
          });
        }
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _loadPermissions() async {
    print('DEBUG: _loadPermissions method called');
    try {
      final prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      print('DEBUG: Loading permissions with url: $url, unid: $unid, slex: $slex');

      final response = await http.post(
        Uri.parse('$url/permissions.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"unid": unid, "slex": slex}),
      );

      print('DEBUG: Permissions response status code: ${response.statusCode}');
      print('DEBUG: Permissions response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('DEBUG: Decoded permissions data: $data');
        
        if (data['result'] == "1") {
          setState(() {
            chequeAdd = data['chequeAdd'] ?? '';
            chequeView = data['chequeView'] ?? '';
            chequeEdit = data['chequeEdit'] ?? '';
            chequeClear = data['chequeClear'] ?? '';
            chequeBounce = data['chequeBounce'] ?? '';
            chequeDelete = data['chequeDelete'] ?? '';
            chequeDeleteReason = data['chequeDeleteReason'] ?? '';
          });
          
          print('DEBUG: Permissions loaded from API - Edit: $chequeEdit, Clear: $chequeClear, Bounce: $chequeBounce, Delete: $chequeDelete');
        } else {
          print('DEBUG: Permissions API returned result != 1: ${data['result']}');
        }
      } else {
        print('DEBUG: Permissions API failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Exception in _loadPermissions: $e');
      _showError('Error loading permissions: $e');
    }
  }

  Future<Map<String, dynamic>> _saveChequeData(String action,
      {String? chqId, String reason = ""}) async {
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
        "cust_name": selectedCustomer ?? '',
        "custid": selectedCustId ?? '',
        "chqid": chqId ?? '',
      };

      if (action == 'delete' && reason.isNotEmpty) {
        requestBody["reason"] = reason;
      }
      if (action == 'bounced' && reason.isNotEmpty) {
        requestBody["reason"] = reason;
      }
      if (action == 'receivedchequecleared') {
        requestBody["wallet"] = selectedWalletId;
        requestBody["notes"] = _notesController.text.trim();
        requestBody["pd_date"] = _receivedDateController.text;
        requestBody["pd_amt"] = _receivedAmountController.text;
      }

      final response = await http.post(
        Uri.parse('$url/action/cheques.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {"result": "0", "message": "Failed to update cheques"};
      }
    } catch (e) {
      return {"result": "0", "message": "Network error: $e"};
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: 'Enter cheque no, name or cheque number'),
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
              fetchCheques();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchQuery = _searchController.text;
                currentPage = 1;
              });
              fetchCheques();
              Navigator.of(context).pop();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _navigateToNewChequePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewChequePage()),
    );

    if (result != null && result == true) {
      fetchCheques();
      _showSuccess('Cheque added successfully!');
    }
  }

  void _editCheque(Cheque cheque) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditChequePage(
          chequeData: cheque.toJson(),
        ),
      ),
    );

    if (result != null && result == true) {
      fetchCheques();
      _showSuccess('Cheque updated successfully!');
    }
  }

  void _showClearedChequeDialog(Cheque cheque) {
    _notesController.text = "Cleared Cheque no ${cheque.chequeNo}";
    
    if (wallets.isNotEmpty) {
      selectedWallet = wallets.first['wlt_name'];
      selectedWalletId = wallets.first['wltid'];
    } else {
      selectedWallet = null;
      selectedWalletId = null;
    }
    
    try {
      DateTime parsedDate = DateFormat("dd/MM/yyyy").parse(cheque.date);
      _receivedDateController.text = DateFormat("dd-MM-yyyy").format(parsedDate);
    } catch (e) {
      _receivedDateController.text = '';
    }
    _receivedAmountController.text = parseFormattedAmount(cheque.amount).toInt().toString();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        color: Colors.green,
                        padding: const EdgeInsets.all(6),
                        child: const Center(
                          child: Text(
                            'Cleared Cheque',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cheque No: ${cheque.chequeNo}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          _selectDate(context, _receivedDateController);
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _receivedDateController,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              labelText: 'Received Date',
                              labelStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _receivedAmountController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Received Amount',
                          labelStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                _isWalletDropdownOpen = !_isWalletDropdownOpen;
                              });
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Amount To',
                                labelStyle: const TextStyle(fontSize: 12),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                suffixIcon: Icon(
                                  _isWalletDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                  color: AppTheme.primaryColor,
                                  size: 16,
                                ),
                              ),
                              child: Text(
                                selectedWallet ?? 'Select wallet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: selectedWallet != null ? Colors.black : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          if (_isWalletDropdownOpen)
                            Container(
                              height: 100,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: wallets.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No wallets found',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: wallets.length,
                                      itemBuilder: (context, index) {
                                        final wallet = wallets[index];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                          title: Text(
                                            wallet['wlt_name'] ?? '',
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                          onTap: () {
                                            setDialogState(() {
                                              selectedWallet = wallet['wlt_name'];
                                              selectedWalletId = wallet['wltid'];
                                              _isWalletDropdownOpen = false;
                                            });
                                          },
                                          tileColor: selectedWallet == wallet['wlt_name']
                                              ? Colors.blue.withOpacity(0.1)
                                              : null,
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Notes',
                        style: TextStyle(fontSize: 12),
                      ),
                      TextField(
                        controller: _notesController,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: () async {
                              if (selectedWallet == null || selectedWalletId == null) {
                                _showError('Please select a wallet');
                                return;
                              }

                              if (_receivedAmountController.text.trim().isEmpty) {
                                _showError('Please enter received amount');
                                return;
                              }

                              Map<String, dynamic> result = await _saveChequeData(
                                'receivedchequecleared',
                                chqId: cheque.chqId,
                              );

                              if (result['result'] == '1') {
                                if (mounted) {
                                  setState(() {
                                    _showSuccess(result['message']);
                                    fetchCheques();
                                  });
                                }
                              } else {
                                _showError(result['message']);
                              }

                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF022E44),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBouncedChequeDialog(Cheque cheque) {
    _bouncedReasonController.text = "Bounced Cheque No ${cheque.chequeNo}";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.orange,
                  padding: const EdgeInsets.all(6),
                  child: const Center(
                    child: Text(
                      'Bounced Cheque',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cheque No: ${cheque.chequeNo}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reason',
                  style: TextStyle(fontSize: 12),
                ),
                TextField(
                  controller: _bouncedReasonController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    ElevatedButton(
                      onPressed: () async {
                        if (_bouncedReasonController.text.trim().isEmpty) {
                          _showError('Please enter a reason');
                          return;
                        }

                        Map<String, dynamic> result = await _saveChequeData(
                          'bounced',
                          chqId: cheque.chqId,
                          reason: _bouncedReasonController.text,
                        );

                        if (result['result'] == '1') {
                          if (mounted) {
                            setState(() {
                              _showSuccess(result['message']);
                              fetchCheques();
                            });
                          }
                        } else {
                          _showError(result['message']);
                        }

                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF022E44),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteCheque(Cheque cheque) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Cheque',
          style: TextStyle(color: Colors.red, fontSize: 12),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this cheque?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDialogRow('Cheque No:', cheque.chequeNo,),
              _buildDialogRow('Name:', cheque.name),
              const SizedBox(height: 8),
              if (chequeDeleteReason == "yes")
                TextField(
                  controller: _deleteReasonController,
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (chequeDeleteReason == "yes" && _deleteReasonController.text.trim().isEmpty) {
                _showError('Please provide a reason for deletion');
                return;
              }

              Navigator.pop(context);
              Map<String, dynamic> result = await _saveChequeData(
                'delete',
                chqId: cheque.chqId,
                reason: _deleteReasonController.text,
              );

              if (result['result'] == '1') {
                if (mounted) {
                  setState(() {
                    _showSuccess(result['message']);
                    fetchCheques();
                  });
                }
              } else {
                _showError(result['message']);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(40, 20),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = DateFormat('dd-MM-yyyy').format(picked);
    }
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildChequeCard(Cheque cheque) {
    String normalizedStatus = cheque.status.toLowerCase().trim();
    bool showClearedMessage = normalizedStatus == "cleared";
    bool showBouncedMessage = normalizedStatus == "bounced";
    bool showButtons = normalizedStatus == "pending" || (!showClearedMessage && !showBouncedMessage);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        child: Column(
          children: [
            // Header Section with Cheque Number and Date
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
                      'Cheque No: ${cheque.chequeNo}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 5, 38, 76),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 10,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _formatDate(cheque.date),
                        style: TextStyle(
                          fontSize: 11,
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
                        size: 11,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cheque.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Bank and Amount Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade200, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        // Bank Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bank',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cheque.bank,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Vertical divider
                        Container(
                          height: 24,
                          width: 0.8,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        
                        // Amount Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Amount',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cheque.amount,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status messages
                  if (showClearedMessage)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Cheque has been cleared.",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  if (showBouncedMessage)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "Cheque has been bounced.",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  
                  // Action buttons row
                  if (showButtons) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        
                        Row(
                          children: [
                            if (chequeClear == "yes")
                              _buildActionButton(
                                icon: Icons.check,
                                text: 'Clear',
                                bgColor: Colors.green,
                                onPressed: () => _showClearedChequeDialog(cheque),
                              ),
                            if (chequeClear == "yes")
                              const SizedBox(width: 4),
                            if (chequeBounce == "yes")
                              _buildActionButton(
                                icon: Icons.close,
                                text: 'Bounce',
                                bgColor: Colors.orange,
                                onPressed: () => _showBouncedChequeDialog(cheque),
                              ),
                          ],
                        ),
                        
                        // Modified edit and delete buttons to match orders_page.dart
                        Row(
                          children: [
                            if (chequeEdit == "yes")
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
                                onPressed: () => _editCheque(cheque),
                                child: const Icon(Icons.edit, size: 12, color: Colors.white),
                              ),
                            if (chequeEdit == "yes") const SizedBox(width: 6),
                            if (chequeDelete == "yes")
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
                                  if (chequeDeleteReason == "yes") {
                                    _deleteCheque(cheque);
                                  } else {
                                    _simpleDeleteCheque(cheque);
                                  }
                                },
                                child: const Icon(Icons.delete, size: 12, color: Colors.white),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required Color bgColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 12, color: Colors.white),
      label: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  Future<void> _simpleDeleteCheque(Cheque cheque) async {
    final result = await _saveChequeData('delete', chqId: cheque.chqId);
    if (result['result'] == '1') {
      if (mounted) {
        setState(() {
          _showSuccess(result['message']);
          fetchCheques();
        });
      }
    } else {
      _showError(result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && filteredCheques.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cheques'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheques'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          if (chequeView == "yes")
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showSearchDialog,
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: filteredCheques.isEmpty
                ? const Center(child: Text("No cheques found.", style: TextStyle(fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: filteredCheques.length,
                    itemBuilder: (context, index) {
                      final cheque = filteredCheques[index];
                      return _buildChequeCard(cheque);
                    },
                  ),
          ),
          SlidingPaginationControls(
            currentPage: currentPage,
            totalItems: chequesTotal,
            itemsPerPage: itemsPerPage,
            maxVisiblePages: maxVisiblePages,
            onPageChanged: _onPageChanged,
            isLoading: isLoading,
          ),
        ],
      ),
      floatingActionButton: chequeAdd == "yes"
          ? FloatingActionButton(
              onPressed: _navigateToNewChequePage,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: const BottomNavigationButton(
        selectedIndex: 0,
      ),
    );
  }

  void _onPageChanged(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    fetchCheques();
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