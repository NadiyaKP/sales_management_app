import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ViewOrderPage extends StatefulWidget {
  final String orderId;
  
  const ViewOrderPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<ViewOrderPage> createState() => _ViewOrderPageState();
}

class _ViewOrderPageState extends State<ViewOrderPage> {
  Map<String, dynamic>? orderData;
  Map<String, dynamic>? companyDatas;
  bool isLoading = true;
  ApiServices apiServices = ApiServices();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Load both order details and company details concurrently
      await Future.wait([
        fetchOrderDetails(),
        loadCompanyDetails(),
      ]);
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchOrderDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      String orderId = widget.orderId;
      
      if (url == null || unid == null || slex == null) {
        throw Exception('Missing required parameters (url, unid, or slex)');
      }
      
      final response = await http.post(
        Uri.parse("$url/single-order-view.php"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "ordid": orderId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          setState(() {
            orderData = data;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch order details.');
        }
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchOrderDetails: $e');
      rethrow;
    }
  }

  Future<void> loadCompanyDetails() async {
    try {
      print('Starting to fetch company details...');
      final companyData = await apiServices.fetchCompanyDetails();
      print('Company data received: $companyData');
      
      if (companyData != null) {
        if (companyData.containsKey('companydet') && 
            companyData['companydet'] is List && 
            companyData['companydet'].isNotEmpty) {
          setState(() {
            companyDatas = companyData;
          });
          print('Company data set successfully');
        } else if (companyData.isNotEmpty) {
          setState(() {
            companyDatas = companyData;
          });
          print('Company data set with different structure');
        } else {
          throw Exception("Invalid or empty company data structure.");
        }
      } else {
        throw Exception("No company data received from API.");
      }
    } catch (e) {
      print('Error in loadCompanyDetails: $e');
      rethrow;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
    ));
  }

  pw.Document generateOrderPdf() {
    final pdf = pw.Document();
    
    Map<String, dynamic>? companyDetails;
    if (companyDatas != null) {
      if (companyDatas!.containsKey('companydet') && 
          companyDatas!['companydet'] is List && 
          companyDatas!['companydet'].isNotEmpty) {
        companyDetails = companyDatas!['companydet'][0];
      } else if (companyDatas!.isNotEmpty) {
        companyDetails = companyDatas;
      }
    }
    
    final customerDetails = orderData!['customerdet'][0];
    final items = orderData!['ordercartdet'] as List<dynamic>;

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
                    "Order Details",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Customer Details",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(customerDetails['custname'] ?? '',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(customerDetails['address'] ?? ''),
                        pw.Text("Ph: ${customerDetails['phone'] ?? ''}"),
                        pw.Text("GST: ${customerDetails['gst_no'] ?? ''}"),
                        pw.Text(
                            "State: ${customerDetails['state'] ?? ''} (${customerDetails['state_code'] ?? ''})"),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Order No: ${orderData!['ord_no'] ?? ''}"),
                        pw.Text("Date: ${orderData!['ord_date'] ?? ''}"),
                        pw.Text("Sales Executive: ${orderData!['salesexe_name'] ?? ''}"),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(width: 0.5),
                  verticalInside: pw.BorderSide(width: 0.5),
                  top: pw.BorderSide(width: 1),
                  bottom: pw.BorderSide(width: 1),
                  left: pw.BorderSide(width: 1),
                  right: pw.BorderSide(width: 1),
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Item Name",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.left),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Qty",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['prd_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.left),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['qty']?.toString() ?? '0',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Notes:'),
                  pw.Text('Signature:')
                ],
              ),
              pw.Text(companyDetails?['com_name'] ?? 'Company Name'),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> sharePdf() async {
    try {
      if (companyDatas == null) {
        _showError('Company details not available for PDF generation');
        return;
      }

      // Generate the PDF
      final pdf = generateOrderPdf();
      
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final path = directory.path;
      final file = File('$path/order_${widget.orderId}.pdf');
      
      // Save the PDF file
      await file.writeAsBytes(await pdf.save());
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Order Details - Order No: ${orderData!['ord_no'] ?? ''}',
        subject: 'Order Details',
      );
      
    } catch (e) {
      _showError('Error sharing PDF: $e');
    }
  }

  String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      return word.isNotEmpty
          ? word[0].toUpperCase() + word.substring(1).toLowerCase()
          : '';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (orderData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Failed to load order details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Please try again later.', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final customerDetails = orderData!['customerdet'][0];
    final items = orderData!['ordercartdet'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              if (companyDatas != null) {
                try {
                  final pdf = generateOrderPdf();
                  Printing.layoutPdf(
                      onLayout: (PdfPageFormat format) async => pdf.save());
                } catch (e) {
                  _showError('Error generating PDF: $e');
                }
              } else {
                _showError('Company details not available for PDF generation');
              }
            },
            icon: const Icon(Icons.print, color: Colors.white),
          ),
          IconButton(
            onPressed: sharePdf,
            icon: const Icon(Icons.share, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Information',
                      style:  TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Order No', orderData!['ord_no'] ?? 'N/A'),
                    _buildInfoRow('Order Date', orderData!['ord_date'] ?? 'N/A'),
                    _buildInfoRow('Sales Executive', orderData!['salesexe_name'] ?? 'N/A'),
                  ],
                ),
              ),
            ),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Details',
                      style:  TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Name', customerDetails['custname'] ?? 'N/A'),
                    if (customerDetails['phone'] != null && customerDetails['phone'].toString().isNotEmpty)
                      _buildInfoRow('Phone', customerDetails['phone'].toString()),
                    if (customerDetails['address'] != null && customerDetails['address'].toString().isNotEmpty)
                      _buildInfoRow('Address', capitalizeWords(customerDetails['address'].toString())),
                    if (customerDetails['gst_no'] != null && customerDetails['gst_no'].toString().isNotEmpty)
                      _buildInfoRow('GST No', customerDetails['gst_no'].toString()),
                    _buildInfoRow('State', "${customerDetails['state'] ?? 'N/A'} (${customerDetails['state_code'] ?? 'N/A'})"),
                  ],
                ),
              ),
            ),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Items',
                      style:  TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Table(
                      border: TableBorder.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Item Name",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Qty",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        ...items.map((item) {
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  item['prd_name'] ?? 'N/A',
                                  style: const TextStyle(fontSize: 11),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  item['qty']?.toString() ?? '0',
                                  style: const TextStyle(fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (companyDatas != null) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Information',
                        style:  TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (companyDatas!.containsKey('companydet') && 
                          companyDatas!['companydet'] is List && 
                          companyDatas!['companydet'].isNotEmpty) ...[
                        _buildInfoRow('Company Name', companyDatas!['companydet'][0]['com_name'] ?? 'N/A'),
                      ] else if (companyDatas!.containsKey('com_name')) ...[
                        _buildInfoRow('Company Name', companyDatas!['com_name'] ?? 'N/A'),
                      ] else ...[
                        const Text('Company details loaded successfully', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}