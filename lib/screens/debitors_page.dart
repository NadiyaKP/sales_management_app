import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../services/permission.dart';

// Global permission variables
String debitors = '';
String debitorsWhatsapp = '';
String debitorsExcel = '';

class Debitors {
  final DebitorCustomer customer;
  final String phoneNo;
  final String content;
  final String amount;
  
  Debitors({
    required this.customer,
    required this.phoneNo,
    required this.content,
    required this.amount,
  });
  
  factory Debitors.fromJson(Map<String, dynamic> json) {
    return Debitors(
      customer: json["customer"] != null
          ? DebitorCustomer.fromJson(json["customer"])
          : DebitorCustomer(
              customerName: 'Unknown',
              address: 'N/A',
              phone: 'N/A',
              state: 'N/A',
              stateCode: 'N/A',
              gstNo: 'N/A',
            ),
      phoneNo: json['whats_app_number'] ?? '',
      content: json['whats_app_content'] ?? '',
      amount: json['dbt_amt'] ?? '',
    );
  }
}

class DebitorCustomer {
  final String customerName;
  final String address;
  final String gstNo;
  final String phone;
  final String state;
  final String stateCode;
  
  DebitorCustomer({
    required this.customerName,
    required this.address,
    required this.phone,
    required this.state,
    required this.stateCode,
    required this.gstNo,
  });
  
  factory DebitorCustomer.fromJson(Map<String, dynamic> json) {
    return DebitorCustomer(
      customerName: json['custname'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstNo: json['gst_no'] ?? '',
    );
  }
}

class DebitorsPage extends StatefulWidget {
  const DebitorsPage({Key? key}) : super(key: key);

  @override
  State<DebitorsPage> createState() => _DebitorsPageState();
}

class _DebitorsPageState extends State<DebitorsPage> {
  int _selectedIndex = 1;
  bool _isLoading = false;
  String _financialYear = '01/04/2025 to 31/03/2026';
  String _totalAmount = '0';
  String _mainTitle = '';
  List<Debitors> _debitors = [];
  ApiServices apiServices = ApiServices();

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchDebitorsData();
  }

  Future<void> _fetchDebitorsData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('url');
    String? unid = prefs.getString('unid');
    String? slex = prefs.getString('slex');

    try {
      final response = await http.post(
        Uri.parse('$url/debitors.php'),
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
          final List<dynamic> debitors = data['debitors'] ?? [];
          setState(() {
            _totalAmount = data['ttl_dbt_amt'] ?? '0';
            _mainTitle = data['hdr_name'] ?? '';
            _debitors = debitors.map((json) => Debitors.fromJson(json)).toList();
          });
          
          if (debitors.isEmpty) {
            _showError('No data found');
          }
        } else {
          _showError(data['message'] ?? 'Failed to fetch data.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (error) {
      _showError('An error occurred: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          debitors = permissionDetail.debitors;
          debitorsExcel = permissionDetail.debitorsExcel;
          debitorsWhatsapp = permissionDetail.debitorsWhatsapp;
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

  void openWhatsApp(BuildContext context, {Debitors? debitor}) async {
    if (debitor == null) {
      _showError("Invalid phone number or message!");
      return;
    }
    
    String phoneNo = debitor.phoneNo.trim();
    String message = debitor.content.trim();
    
    if (phoneNo.isEmpty || message.isEmpty) {
      _showError("Invalid phone number or message!");
      return;
    }
    
    final Uri whatsappUrl = Uri.parse("https://wa.me/$phoneNo?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        _showError("Could not open WhatsApp");
      }
    } catch (e) {
      _showError("Error: $e");
    }
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      Navigator.pop(context);
    }
  }

  String capitalizeWords(String text) {
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEBITORS'),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    child: Center(
                      child: Text(
                        _mainTitle.isNotEmpty ? _mainTitle : 'Debitors Report from $_financialYear',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 2.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _totalAmount.isNotEmpty ? _totalAmount : "No Data",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Debitors List',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_debitors.length} Debitors',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _debitors.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No debitors available.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _debitors.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final debitor = _debitors[index];
                              return DebitorListItem(
                                debitor: debitor,
                                onWhatsAppTap: () => openWhatsApp(context, debitor: debitor),
                              );
                            },
                          ),
                  ),
                ],
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

class DebitorListItem extends StatelessWidget {
  final Debitors debitor;
  final VoidCallback? onWhatsAppTap;

  const DebitorListItem({
    Key? key,
    required this.debitor,
    this.onWhatsAppTap,
  }) : super(key: key);

  String capitalizeWords(String text) {
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  debitor.customer.customerName.isNotEmpty
                      ? debitor.customer.customerName.substring(0, 1).toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capitalizeWords(debitor.customer.customerName),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (debitor.customer.phone.isNotEmpty)
                    Text(
                      debitor.customer.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  debitor.amount,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                if (debitor.phoneNo.isNotEmpty && onWhatsAppTap != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: GestureDetector(
                      onTap: onWhatsAppTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.message,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

