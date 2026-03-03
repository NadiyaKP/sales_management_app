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
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

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

  @override
  void initState() {
    super.initState();
    fetchReceiptDetails();
    loadCompanyDetails();
  }

  Future<void> fetchReceiptDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');

      if (url == null || unid == null || slex == null) {
        _showError('Missing credentials');
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          setState(() {
            receiptsData = data;
            isLoading = false;
          });
        } else {
          _showError(data['message'] ?? 'Failed to fetch receipt details.');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        _showError('Error: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      _showError('An error occurred: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadCompanyDetails() async {
    try {
      final companyDetails = await apiServices.fetchCompanyDetails();
      if (companyDetails != null) {
        setState(() {
          companyData = companyDetails;
        });
      } else {
        _showError("No company data found.");
      }
    } catch (e) {
      _showError("Error loading company details: $e");
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

  pw.Document generateReceiptPdf() {
    final pdf = pw.Document();
    
    if (companyData == null || receiptsData == null) {
      return pdf;
    }

    final companyDetails = companyData!['companydet'][0];
    final customerDetails = receiptsData!['customerdet'][0];

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
                          customerDetails['custname'] ?? '',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        if (customerDetails['address'] != null && customerDetails['address'].isNotEmpty)
                          pw.Text(customerDetails['address']),
                        if (customerDetails['phone'] != null && customerDetails['phone'].isNotEmpty)
                          pw.Text("Ph: ${customerDetails['phone']}"),
                        if (customerDetails['gst_no'] != null && customerDetails['gst_no'].isNotEmpty)
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
                            pw.Text(receiptsData!['rcp_date'] ?? ''),
                          ],
                        ),
                        pw.Row(
                          children: [
                            pw.Text(
                              "Receipt No: ",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(receiptsData!['rcp_no'] ?? ''),
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
                          receiptsData!['rcp_words'] ?? '',
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
                          receiptsData!['rcp_amt'] ?? '',
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
                        companyDetails['com_name'] ?? '',
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
    if (companyData != null) {
      final pdf = generateReceiptPdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } else {
      _showError('Company details not loaded. Cannot generate PDF.');
    }
  }

  Future<void> _shareReceipt() async {
    try {
      if (companyData == null || receiptsData == null) {
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
          title: const Text('RECEIPT VIEW'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (receiptsData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RECEIPT VIEW'),
          centerTitle: true,
          backgroundColor: AppTheme.primaryColor,
        ),
        body: const Center(
          child: Text(
            'Receipt data not found',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      );
    }

    final customerDetails = receiptsData!['customerdet']?[0] ?? {};
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('RECEIPT VIEW'),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt Header Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'RECEIPT',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF022E44),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Customer and Receipt Details Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Details
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Received From',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF022E44),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                capitalizeWords(customerDetails['custname'] ?? ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (customerDetails['phone'] != null && customerDetails['phone'].isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Ph: ${customerDetails['phone']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (customerDetails['address'] != null && customerDetails['address'].isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  capitalizeWords(customerDetails['address']),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (customerDetails['gst_no'] != null && customerDetails['gst_no'].isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'GST No: ${customerDetails['gst_no']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (customerDetails['state'] != null && customerDetails['state_code'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'State: ${customerDetails['state']} (${customerDetails['state_code']})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const VerticalDivider(),
                        const SizedBox(width: 16),
                        
                        // Receipt Details
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReceiptDetailRow('Date:', receiptsData!['rcp_date'] ?? ''),
                              const SizedBox(height: 8),
                              _buildReceiptDetailRow('Receipt No:', receiptsData!['rcp_no'] ?? ''),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Amount Details Row
                    Row(
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                receiptsData!['rcp_words'] ?? '',
                                style: const TextStyle(fontSize: 14),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
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
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                receiptsData!['rcp_amt'] ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Signatures Row
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Authorised Signature',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Approved',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Signature',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Company Name at bottom
                    if (companyData != null && companyData!['companydet'] != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            companyData!['companydet'][0]['com_name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// Helper function
String capitalizeWords(String text) {
  return text.split(' ').map((word) {
    return word.isNotEmpty
        ? word[0].toUpperCase() + word.substring(1).toLowerCase()
        : '';
  }).join(' ');
}