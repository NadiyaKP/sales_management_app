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
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class InvoiceViewScreen extends StatefulWidget {
  final String invId;
  
  const InvoiceViewScreen({
    Key? key,
    required this.invId,
  }) : super(key: key);

  @override
  State<InvoiceViewScreen> createState() => _InvoiceViewScreenState();
}

class _InvoiceViewScreenState extends State<InvoiceViewScreen> {
  ApiServices apiServices = ApiServices();
  Map<String, dynamic>? invoiceData;
  Map<String, dynamic>? companyDatas;
  bool isLoading = true;
  bool isSharing = false;
  bool isPrinting = false;

  @override
  void initState() {
    super.initState();
    fetchInvoiceDetails();
    loadCompanyDetails();
  }

  Future<void> fetchInvoiceDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      String invId = widget.invId;
      
      print("=" * 60);
      print("📤 INVOICE API REQUEST");
      print("=" * 60);
      print("🌐 URL: $url/single-invoice-view.php");
      print("🆔 Invoice ID: $invId");
      print("👤 User ID: $unid");
      print("🔑 Session: $slex");
      
      final requestBody = {
        "unid": unid,
        "slex": slex,
        "invid": invId,
      };
      
      print("📦 Request Body: ${jsonEncode(requestBody)}");
      print("-" * 60);

      final response = await http.post(
        Uri.parse("$url/single-invoice-view.php"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print("📥 INVOICE API RESPONSE");
      print("=" * 60);
      print("📊 Status Code: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");
      print("-" * 60);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("🔍 Parsed Data Result: ${data['result']}");
        print("📝 Message: ${data['message'] ?? 'No message'}");
        
        if (data.containsKey('customerdet')) {
          print("👤 Customer Data: ${data['customerdet']}");
        }
        if (data.containsKey('invoicecartdet')) {
          print("🛒 Cart Items Count: ${(data['invoicecartdet'] as List).length}");
        }
        if (data.containsKey('invoicegst')) {
          print("💰 GST Details: ${data['invoicegst']}");
        }
        print("-" * 60);
        
        // FIX: Check if result is "1" or 1 (string or int)
        if (data['result'] == "1" || data['result'] == 1) {
          setState(() {
            invoiceData = data;
            isLoading = false;
          });
          print("✅ Invoice data loaded successfully");
          print("=" * 60);
        } else {
          String errorMsg = data['message'] ?? 'Failed to fetch invoice details.';
          print("❌ API returned result != 1 → ${data['result']}");
          print("❌ Error message: $errorMsg");
          print("=" * 60);
          showError(errorMsg);
          setState(() {
            isLoading = false;
          });
        }
      } else {
        String errorMsg = 'HTTP Error: ${response.statusCode}';
        print("❌ HTTP Error: ${response.statusCode}");
        print("=" * 60);
        showError(errorMsg);
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ EXCEPTION in fetchInvoiceDetails");
      print("=" * 60);
      print("💥 Error: $e");
      print("=" * 60);
      showError('An error occurred: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadCompanyDetails() async {
    try {
      print("🏢 Loading company details...");
      final companyData = await apiServices.fetchCompanyDetails();
      if (companyData != null && companyData.isNotEmpty) {
        setState(() {
          companyDatas = companyData;
        });
        print("✅ Company data loaded successfully");
        if (companyData.containsKey('companydet')) {
          print("🏭 Company Name: ${companyData['companydet'][0]['com_name']}");
        }
      } else {
        print("⚠️ No company data found");
        // Create a default company data structure
        setState(() {
          companyDatas = {
            'companydet': [
              {
                'com_name': 'Company Name',
                'address': 'Company Address',
                'phone': 'Phone Number',
                'gst_no': 'GST Number',
                'terms_cond': 'Terms and Conditions'
              }
            ]
          };
        });
        print("ℹ️ Using default company data");
      }
    } catch (e) {
      print("❌ Error loading company details: $e");
      // Create a default company data structure in case of error
      setState(() {
        companyDatas = {
          'companydet': [
            {
              'com_name': 'Company Name',
              'address': 'Company Address',
              'phone': 'Phone Number',
              'gst_no': 'GST Number',
              'terms_cond': 'Terms and Conditions'
            }
          ]
        };
      });
      print("ℹ️ Using default company data due to error");
    }
  }

  void showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  String cleanHtmlText(String? text) {
    if (text == null || text.isEmpty) return '';
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&#39;', "'");
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  Future<File> savePdfToFile() async {
    final pdf = generateInvoicePdf();
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/invoice_${widget.invId}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> sharePdf() async {
    try {
      setState(() {
        isSharing = true;
      });

      final file = await savePdfToFile();
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice ${invoiceData!['inv_no']}',
        subject: 'Invoice from ${companyDatas!['companydet'][0]['com_name']}',
      );
    } catch (e) {
      showError('Failed to share PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSharing = false;
        });
      }
    }
  }

  Future<void> printPdf() async {
    try {
      setState(() {
        isPrinting = true;
      });

      final pdf = generateInvoicePdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      showError('Failed to print PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          isPrinting = false;
        });
      }
    }
  }

  pw.Document generateInvoicePdf() {
    final pdf = pw.Document();
    final companyDetails = companyDatas!['companydet'][0];
    final customerDetails = invoiceData!['customerdet'][0];
    final items = invoiceData!['invoicecartdet'] as List<dynamic>;
    final invoiceGST = invoiceData!['invoicegst'] as List<dynamic>;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    "Invoice",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ]
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Company Details",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(cleanHtmlText(companyDetails['com_name'])),
                        pw.Text(cleanHtmlText(companyDetails['address'])),
                        pw.Text("Ph: ${cleanHtmlText(companyDetails['phone'])}", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("GST: ${cleanHtmlText(companyDetails['gst_no'])}", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Invoice No: ${cleanHtmlText(invoiceData!['inv_no'])}", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Date: ${cleanHtmlText(invoiceData!['inv_date'])}", style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Customer Details",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(cleanHtmlText(customerDetails['custname'])),
                        pw.Text(cleanHtmlText(customerDetails['address'])),
                        pw.Text("Ph: ${cleanHtmlText(customerDetails['phone'])}", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("GST: ${cleanHtmlText(customerDetails['gst_no'])}", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("State: ${cleanHtmlText(customerDetails['state'])} (${cleanHtmlText(customerDetails['state_code'])})", style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 4),
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
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("Item Name",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.left),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("HSN Code",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.center),
                      ),
                      if (invoiceData?["batch_validate"] == "yes")
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text("Batch No",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("Qty",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("Rate",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("GST",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("Disc",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Text("Total",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(cleanHtmlText(item['itm_name']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.left),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(cleanHtmlText(item['hsncode']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        if (invoiceData?["batch_validate"] == "yes")
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(cleanHtmlText(item['batch']) ?? '',
                                style: const pw.TextStyle(fontSize: 8),
                                textAlign: pw.TextAlign.center),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(item['qty'].toString(),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(cleanHtmlText(item['unrate']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(cleanHtmlText(item['gst']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(cleanHtmlText(item['spl_amt']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(cleanHtmlText(item['crt_ttl_amt']),
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "In Words: ${cleanHtmlText(invoiceData!['ttl_amt_words'])}",
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        if (invoiceGST.isNotEmpty)
                        pw.TableHelper.fromTextArray(
                          headers: ["GST", "CGST", "SGST", "IGST"],
                          data: invoiceGST.map((gst) {
                            return [
                              cleanHtmlText(gst['gst']),
                              cleanHtmlText(gst['cgst_amt']),
                              cleanHtmlText(gst['sgst_amt'].toString()),
                              cleanHtmlText(gst['igst_amt']),
                            ];
                          }).toList(),
                          cellStyle: const pw.TextStyle(fontSize: 8),
                          headerStyle: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          border: const pw.TableBorder(
                            top: pw.BorderSide(width: 1),
                            bottom: pw.BorderSide(width: 1),
                            left: pw.BorderSide(width: 1),
                            right: pw.BorderSide(width: 1),
                          ),
                          cellAlignment: pw.Alignment.center,
                        ),
                        pw.SizedBox(height: 8),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Taxable Value:", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Total GST:", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Discount:", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text("Round Off:", style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                          "Total Amount:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(cleanHtmlText(invoiceData!['tax_value']), style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(cleanHtmlText(invoiceData!['ttl_gst_amt']), style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(cleanHtmlText(invoiceData!['ttl_disc_amt']), style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(cleanHtmlText(invoiceData!['roundoff']), style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                          cleanHtmlText(invoiceData!['ttl_amt']),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.Text(cleanHtmlText(companyDetails['terms_cond']), style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              pw.Text(
                "Declaration: Certified that all the particulars shown in the above Tax invoice are true and correct and that my/our registration under GST Act-2017 is valid as on the date of bill.",
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
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
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Details', style: TextStyle(fontSize: 18)),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state if data failed to load
    if (invoiceData == null || companyDatas == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Details', style: TextStyle(fontSize: 18)),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load invoice details', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                  });
                  fetchInvoiceDetails();
                  loadCompanyDetails();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final companyDetails = companyDatas!['companydet'][0];
    final customerDetails = invoiceData!['customerdet'][0];
    final items = invoiceData!['invoicecartdet'] as List<dynamic>;
    final invoiceGST = invoiceData!['invoicegst'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details', style: TextStyle(fontSize: 18)),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print, size: 20),
            onPressed: isPrinting ? null : printPdf,
            tooltip: 'Print',
          ),
          IconButton(
            icon: isSharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share, size: 20),
            onPressed: isSharing ? null : sharePdf,
            tooltip: 'Share',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Company Details",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(cleanHtmlText(companyDetails['com_name']), style: const TextStyle(fontSize: 10)),
                        if (cleanHtmlText(companyDetails['phone']).isNotEmpty) ...[
                          Text(cleanHtmlText(companyDetails['phone']), style: const TextStyle(fontSize: 10)),
                        ],
                        if (cleanHtmlText(companyDetails['address']).isNotEmpty) ...[
                          Text(capitalizeWords(cleanHtmlText(companyDetails['address'])), style: const TextStyle(fontSize: 10)),
                        ],
                        if (cleanHtmlText(companyDetails['gst_no']).isNotEmpty) ...[
                          Text('GST No: ${cleanHtmlText(companyDetails['gst_no'])}', style: const TextStyle(fontSize: 10)),
                        ],
                        const SizedBox(height: 4),
                        Text("Invoice No: ${cleanHtmlText(invoiceData!['inv_no'])}", style: const TextStyle(fontSize: 10)),
                        Text("Date: ${cleanHtmlText(invoiceData!['inv_date'])}", style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Customer Details",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(cleanHtmlText(customerDetails['custname']), style: const TextStyle(fontSize: 10)),
                        if (cleanHtmlText(customerDetails['phone']).isNotEmpty) ...[
                          Text(cleanHtmlText(customerDetails['phone']), style: const TextStyle(fontSize: 10)),
                        ],
                        if (cleanHtmlText(customerDetails['address']).isNotEmpty) ...[
                          Text(capitalizeWords(cleanHtmlText(customerDetails['address'])), style: const TextStyle(fontSize: 10)),
                        ],
                        if (cleanHtmlText(customerDetails['gst_no']).isNotEmpty) ...[
                          Text('GST No: ${cleanHtmlText(customerDetails['gst_no'])}', style: const TextStyle(fontSize: 10)),
                        ],
                        Text("State: ${cleanHtmlText(customerDetails['state'])} (${cleanHtmlText(customerDetails['state_code'])})", style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.black, width: 0.5),
                columnWidths: invoiceData?["batch_validate"] == "yes"
                    ? {
                        0: const FlexColumnWidth(3),
                        1: const FlexColumnWidth(1.5),
                        2: const FlexColumnWidth(1.5),
                        3: const FlexColumnWidth(1),
                        4: const FlexColumnWidth(1.5),
                        5: const FlexColumnWidth(1),
                        6: const FlexColumnWidth(1.5),
                        7: const FlexColumnWidth(1.5),
                      }
                    : {
                        0: const FlexColumnWidth(3),
                        1: const FlexColumnWidth(1.5),
                        2: const FlexColumnWidth(1),
                        3: const FlexColumnWidth(1.5),
                        4: const FlexColumnWidth(1),
                        5: const FlexColumnWidth(1.5),
                        6: const FlexColumnWidth(1.5),
                      },
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.grey),
                    children: invoiceData?["batch_validate"] == "yes"
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Item Name",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.left),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("HSN Code",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Batch No",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Qty",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Rate",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Disc",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("GST",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Total",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                          ]
                        : [
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Item Name",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.left),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("HSN Code",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Qty",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Rate",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Disc",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("GST",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Text("Total",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                          ],
                  ),
                  ...items.map((item) {
                    return TableRow(
                      children: invoiceData?["batch_validate"] == "yes"
                          ? [
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['itm_name']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.left),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['hsncode']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['batch']) ?? "N/A",
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['qty'].toString()),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['unrate']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.right),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['spl_amt']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.right),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['gst']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['crt_ttl_amt']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.right),
                              ),
                            ]
                          : [
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['itm_name']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.left),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['hsncode']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['qty'].toString()),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['unrate']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.right),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['spl_amt']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.right),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['gst']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.center),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Text(cleanHtmlText(item['crt_ttl_amt']),
                                    style: const TextStyle(fontSize: 8),
                                    textAlign: TextAlign.right),
                              ),
                            ],
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Taxable Value:", style: TextStyle(fontSize: 10)),
                        Text("Total GST:", style: TextStyle(fontSize: 10)),
                        Text("Discount:", style: TextStyle(fontSize: 10)),
                        Text("Round Off:", style: TextStyle(fontSize: 10)),
                        Text(
                          "Total Amount:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${invoiceData!['tax_value']}", style: const TextStyle(fontSize: 10)),
                        Text("${invoiceData!['ttl_gst_amt']}", style: const TextStyle(fontSize: 10)),
                        Text("${invoiceData!['ttl_disc_amt']}", style: const TextStyle(fontSize: 10)),
                        Text("${invoiceData!['roundoff']}", style: const TextStyle(fontSize: 10)),
                        Text(
                          "${invoiceData!['ttl_amt']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "In Words: ${invoiceData!['ttl_amt_words']}",
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              if (invoiceGST.isNotEmpty)
              Table(
                border: TableBorder.all(width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade400),
                    children: const [
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            'GST',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            'CGST',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            'SGST',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            'IGST',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...invoiceGST.map((gst) {
                    return TableRow(
                      children: [
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              gst['gst'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              gst['cgst_amt'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              gst['sgst_amt'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              gst['igst_amt'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              if (companyDetails['terms_cond'] != null &&
                  companyDetails['terms_cond'].toString().isNotEmpty)
                Text(
                  companyDetails['terms_cond'],
                  style: const TextStyle(fontSize: 10),
                ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "Declaration: Certified that all the particulars shown in the above Tax invoice are true and correct and that my/our registration under GST Act-2017 is valid as on the date of bill.",
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}