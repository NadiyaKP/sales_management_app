import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

class ReceiptViewPage extends StatefulWidget {
  final String rcpId;
  
  const ReceiptViewPage({
    Key? key,
    required this.rcpId,
  }) : super(key: key);

  @override
  State<ReceiptViewPage> createState() => _ReceiptViewPageState();
}

class _ReceiptViewPageState extends State<ReceiptViewPage> {
  ApiServices apiServices = ApiServices();

  Map<String, dynamic>? receiptsData;
  Map<String, dynamic>? companyData;

  bool isLoading = true;
  bool companyDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      fetchReceiptDetails(),
      loadCompanyDetails(),
    ]);
  }

  Future<void> fetchReceiptDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _showError('Missing credentials');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse("$url/single-receipt-view.php"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "rcpid": widget.rcpId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          setState(() {
            receiptsData = data;
          });
        } else {
          _showError(data['message'] ?? 'Failed to fetch receipt details.');
        }
      } else {
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('An error occurred: $e');
    } finally {
      _checkLoadingComplete();
    }
  }

  Future<void> loadCompanyDetails() async {
    try {
      // First try to get from API service
      final companyDetails = await apiServices.fetchCompanyDetails();
      if (companyDetails != null && companyDetails.isNotEmpty) {
        setState(() {
          companyData = companyDetails;
          companyDataLoaded = true;
        });
        return;
      }

      // If API service fails, try direct API call as fallback
      await _loadCompanyDetailsDirectly();
    } catch (e) {
      print("Error from API service: $e");
      // Try direct API call as fallback
      await _loadCompanyDetailsDirectly();
    } finally {
      _checkLoadingComplete();
    }
  }

  Future<void> _loadCompanyDetailsDirectly() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _setDefaultCompanyData();
        return;
      }

      final response = await http.post(
        Uri.parse("$url/company-details.php"), // Adjust endpoint as needed
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1" && data['companydet'] != null) {
          setState(() {
            companyData = data;
            companyDataLoaded = true;
          });
        } else {
          _setDefaultCompanyData();
        }
      } else {
        _setDefaultCompanyData();
      }
    } catch (e) {
      print("Direct API call failed: $e");
      _setDefaultCompanyData();
    }
  }

  void _setDefaultCompanyData() {
    // Set default company data as fallback
    setState(() {
      companyData = {
        'companydet': [
          {
            'com_name': 'Your Company Name', // You can customize this
            'com_address': '',
            'com_phone': '',
            'com_email': '',
          }
        ]
      };
      companyDataLoaded = true;
    });
  }

  void _checkLoadingComplete() {
    if (receiptsData != null && companyDataLoaded) {
      setState(() {
        isLoading = false;
      });
    } else if (!isLoading) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  pw.Document generateReceiptPdf() {
    final pdf = pw.Document();
    
    if (receiptsData == null) {
      return pdf;
    }

    final companyDetails = companyData?['companydet']?[0] ?? {'com_name': 'Your Company'};
    final customerDetails = receiptsData!['customerdet']?[0] ?? {};

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    "Receipt",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Customer Details
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Received From",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.Text(
                          customerDetails['custname'] ?? 'N/A',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        if (customerDetails['address'] != null && customerDetails['address'].toString().isNotEmpty)
                          pw.Text(customerDetails['address']),
                        if (customerDetails['phone'] != null && customerDetails['phone'].toString().isNotEmpty)
                          pw.Text("Ph: ${customerDetails['phone']}"),
                        if (customerDetails['gst_no'] != null && customerDetails['gst_no'].toString().isNotEmpty)
                          pw.Text("GST: ${customerDetails['gst_no']}"),
                        if (customerDetails['state'] != null && customerDetails['state_code'] != null)
                          pw.Text("State: ${customerDetails['state']} (${customerDetails['state_code']})"),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Receipt Details
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              "Date: ",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(receiptsData!['rcp_date'] ?? 'N/A'),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text(
                              "Receipt No: ",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(receiptsData!['rcp_no'] ?? 'N/A'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Amount in words
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Amount In Words:",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          receiptsData!['rcp_words'] ?? 'N/A',
                          style: const pw.TextStyle(fontSize: 14),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Amount:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.Text(
                          receiptsData!['rcp_amt'] ?? '0.00',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Authorised Signature"),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        companyDetails['com_name'] ?? 'Company Name',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Text("Approved", textAlign: pw.TextAlign.center),
                  pw.Text("Signature", textAlign: pw.TextAlign.center),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> _printReceipt() async {
    if (receiptsData != null) {
      try {
        final pdf = generateReceiptPdf();
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
        _showSuccess('Receipt sent to printer successfully!');
      } catch (e) {
        _showError('Error printing receipt: $e');
      }
    } else {
      _showError('Receipt data not loaded. Cannot generate PDF.');
    }
  }

  Future<void> _shareReceipt() async {
    try {
      if (receiptsData == null) {
        _showError('Receipt data not loaded. Cannot share PDF.');
        return;
      }

      // Generate PDF
      final pdf = generateReceiptPdf();
      final pdfBytes = await pdf.save();

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String receiptNo = receiptsData!['rcp_no'] ?? 'receipt';
      final String fileName = 'Receipt_${receiptNo.replaceAll('/', '_')}.pdf';
      final File file = File('${tempDir.path}/$fileName');

      // Write PDF to file
      await file.writeAsBytes(pdfBytes);

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Receipt ${receiptsData!['rcp_no'] ?? ''} - ${receiptsData!['rcp_date'] ?? ''}',
        subject: 'Receipt ${receiptsData!['rcp_no'] ?? ''}',
      );

      _showSuccess('Receipt shared successfully!');
    } catch (e) {
      _showError('Error sharing receipt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipt View'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading receipt details...'),
            ],
          ),
        ),
      );
    }

    if (receiptsData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipt View'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Receipt data not found',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  _initializeData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final customerDetails = receiptsData!['customerdet']?[0] ?? {};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt View'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        actions: [
          // Print Button
          IconButton(
            onPressed: _printReceipt,
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Print Receipt',
          ),
          // Share Button
          IconButton(
            onPressed: _shareReceipt,
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Receipt',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show company data status
            if (!companyDataLoaded)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Company details could not be loaded. Using default settings.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Receipt Header Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'RECEIPT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF022E44),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    
                    // Use responsive layout based on screen width
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // If screen width is less than 600, use Column layout
                        if (constraints.maxWidth < 600) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer Details Section
                              _buildCustomerDetailsSection(customerDetails),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              // Receipt Details Section
                              _buildReceiptDetailsSection(),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              // Amount Details Section
                              _buildAmountDetailsSection(),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              // Signatures Section
                              _buildSignaturesSection(),
                              const SizedBox(height: 30),
                              // Company Name
                              _buildCompanyNameSection(),
                            ],
                          );
                        } else {
                          // For larger screens, use the original Row layout
                          return Column(
                            children: [
                              // Customer and Receipt Details Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Customer Details
                                  Expanded(
                                    flex: 2,
                                    child: _buildCustomerDetailsSection(customerDetails),
                                  ),
                                  const SizedBox(width: 12),
                                  const VerticalDivider(),
                                  const SizedBox(width: 12),
                                  // Receipt Details
                                  Expanded(
                                    flex: 2,
                                    child: _buildReceiptDetailsSection(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              // Amount Details
                              _buildAmountDetailsSection(),
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              // Signatures
                              _buildSignaturesSection(),
                              const SizedBox(height: 30),
                              // Company Name
                              _buildCompanyNameSection(),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDetailsSection(Map<String, dynamic> customerDetails) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Received From',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF022E44),
          ),
          overflow: TextOverflow.visible,
          softWrap: false,
        ),
        const SizedBox(height: 6),
        Text(
          capitalizeWords(customerDetails['custname']?.toString() ?? 'N/A'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        if (customerDetails['phone'] != null && customerDetails['phone'].toString().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'Ph: ${customerDetails['phone']}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
        if (customerDetails['address'] != null && customerDetails['address'].toString().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            capitalizeWords(customerDetails['address'].toString()),
            style: const TextStyle(fontSize: 10),
          ),
        ],
        if (customerDetails['gst_no'] != null && customerDetails['gst_no'].toString().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'GST No: ${customerDetails['gst_no']}',
            style: const TextStyle(fontSize: 10),
          ),
        ],
        if (customerDetails['state'] != null && customerDetails['state_code'] != null) ...[
          const SizedBox(height: 3),
          Text(
            'State: ${customerDetails['state']} (${customerDetails['state_code']})',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ],
    );
  }

  Widget _buildReceiptDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReceiptDetailRow('Date:', receiptsData!['rcp_date']?.toString() ?? 'N/A'),
        const SizedBox(height: 6),
        _buildReceiptDetailRow('Receipt No:', receiptsData!['rcp_no']?.toString() ?? 'N/A'),
      ],
    );
  }

  Widget _buildAmountDetailsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          // Stack vertically on smaller screens
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount in Words
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount In Words:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    receiptsData!['rcp_words']?.toString() ?? 'N/A',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Amount:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        receiptsData!['rcp_amt']?.toString() ?? '0.00',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        } else {
          // Use Row layout for larger screens
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount in Words
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount In Words:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      receiptsData!['rcp_words']?.toString() ?? 'N/A',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Amount
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Amount:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      receiptsData!['rcp_amt']?.toString() ?? '0.00',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSignaturesSection() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Authorised Signature',
          style: TextStyle(fontSize: 10),
        ),
        Text(
          'Approved',
          style: TextStyle(fontSize: 10),
        ),
        Text(
          'Signature',
          style: TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCompanyNameSection() {
    String companyName = 'Your Company Name'; // Default fallback
    
    if (companyData != null && 
        companyData!['companydet'] != null && 
        companyData!['companydet'].isNotEmpty) {
      companyName = companyData!['companydet'][0]['com_name']?.toString() ?? companyName;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          companyName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

// Helper function
String capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}