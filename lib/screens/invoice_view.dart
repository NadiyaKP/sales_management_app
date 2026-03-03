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
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
      
      final response = await http.post(
        Uri.parse("$url/single-invoice-view.php"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "invid": invId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          setState(() {
            invoiceData = data;
            isLoading = false;
          });
        } else {
          showError(data['message'] ?? 'Failed to fetch invoice details.');
        }
      } else {
        showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      showError('An error occurred: $e');
    }
  }

  Future<void> loadCompanyDetails() async {
    try {
      final companyData = await apiServices.fetchCompanyDetails();
      if (companyData != null) {
        setState(() {
          companyDatas = companyData;
        });
      } else {
        showError("No company data found.");
      }
    } catch (e) {
      showError("Error: $e");
    }
  }

  void showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ));
    }
  }

  // Helper function to clean HTML tags and special characters
  String cleanHtmlText(String? text) {
    if (text == null || text.isEmpty) return '';
    
    // Remove HTML tags
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Replace common HTML entities
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&#39;', "'");
    
    // Replace multiple spaces with single space
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim whitespace
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
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    "Invoice",
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
              // Company and Customer Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Company Details
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Company Details",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(cleanHtmlText(companyDetails['com_name']),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(cleanHtmlText(companyDetails['address'])),
                        pw.Text("Ph: ${cleanHtmlText(companyDetails['phone'])}"),
                        pw.Text("GST: ${cleanHtmlText(companyDetails['gst_no'])}"),
                        pw.Text("Invoice No: ${cleanHtmlText(invoiceData!['inv_no'])}", 
                               style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text("Date: ${cleanHtmlText(invoiceData!['inv_date'])}", 
                               style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  // Customer Details
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
                        pw.SizedBox(height: 4),
                        pw.Text(cleanHtmlText(customerDetails['custname']),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(cleanHtmlText(customerDetails['address'])),
                        pw.Text("Ph: ${cleanHtmlText(customerDetails['phone'])}"),
                        pw.Text("GST: ${cleanHtmlText(customerDetails['gst_no'])}"),
                        pw.Text("State: ${cleanHtmlText(customerDetails['state'])} (${cleanHtmlText(customerDetails['state_code'])})"),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              // Items Table
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
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Item Name",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.left),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("HSN Code",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.center),
                      ),
                      if (invoiceData?["batch_validate"] == "yes")
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text("Batch No",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              textAlign: pw.TextAlign.center),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Qty",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Rate",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("GST",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Disc",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text("Total",
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  // Table Data
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cleanHtmlText(item['itm_name']),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.left),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cleanHtmlText(item['hsncode']),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center),
                        ),
                        if (invoiceData?["batch_validate"] == "yes")
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(cleanHtmlText(item['batch']) ?? '',
                                style: const pw.TextStyle(fontSize: 10),
                                textAlign: pw.TextAlign.center),
                          ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(item['qty'].toString(),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cleanHtmlText(item['unrate']),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cleanHtmlText(item['gst']),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cleanHtmlText(item['spl_amt']),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(cleanHtmlText(item['crt_ttl_amt']),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
              // GST Breakdown and Totals
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
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                        pw.SizedBox(height: 8),
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
                          cellStyle: const pw.TextStyle(fontSize: 10),
                          headerStyle: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
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
                        pw.SizedBox(height: 16),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Taxable Value:"),
                        pw.Text("Total GST:"),
                        pw.Text("Discount:"),
                        pw.Text("Round Off:"),
                        pw.Text(
                          "Total Amount:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
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
                        pw.Text(cleanHtmlText(invoiceData!['tax_value'])),
                        pw.Text(cleanHtmlText(invoiceData!['ttl_gst_amt'])),
                        pw.Text(cleanHtmlText(invoiceData!['ttl_disc_amt'])),
                        pw.Text(cleanHtmlText(invoiceData!['roundoff'])),
                        pw.Text(
                          cleanHtmlText(invoiceData!['ttl_amt']),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.Text(cleanHtmlText(companyDetails['terms_cond'])),
              pw.Divider(),
              pw.Text(
                "Declaration: Certified that all the particulars shown in the above Tax invoice are true and correct and that my/our registration under GST Act-2017 is valid as on the date of bill.",
                style: const pw.TextStyle(fontSize: 10),
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
    if (isLoading || invoiceData == null || companyDatas == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Details'),
          backgroundColor: AppTheme.primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final companyDetails = companyDatas!['companydet'][0];
    final customerDetails = invoiceData!['customerdet'][0];
    final items = invoiceData!['invoicecartdet'];
    final invoiceGST = invoiceData!['invoicegst'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        backgroundColor: AppTheme.primaryColor,
        centerTitle: true,
        actions: [
          // Print Icon Button
          IconButton(
            icon: isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            onPressed: isPrinting ? null : printPdf,
            tooltip: 'Print',
          ),
          // Share Icon Button
          IconButton(
            icon: isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share),
            onPressed: isSharing ? null : sharePdf,
            tooltip: 'Share',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Company and Customer Details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company Details
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Company Details",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(cleanHtmlText(companyDetails['com_name']),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (cleanHtmlText(companyDetails['phone']).isNotEmpty) ...[
                          Text(cleanHtmlText(companyDetails['phone']), 
                               style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                        if (cleanHtmlText(companyDetails['address']).isNotEmpty) ...[
                          Text(capitalizeWords(cleanHtmlText(companyDetails['address']))),
                        ],
                        if (cleanHtmlText(companyDetails['gst_no']).isNotEmpty) ...[
                          Text('GST No: ${cleanHtmlText(companyDetails['gst_no'])}'),
                        ],
                        const SizedBox(height: 8),
                        Text("Invoice No: ${cleanHtmlText(invoiceData!['inv_no'])}", 
                             style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Date: ${cleanHtmlText(invoiceData!['inv_date'])}", 
                             style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  
                  // Spacer
                  const SizedBox(width: 16),
                  
                  // Customer Details
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Customer Details",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(cleanHtmlText(customerDetails['custname']),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (cleanHtmlText(customerDetails['phone']).isNotEmpty) ...[
                          Text(cleanHtmlText(customerDetails['phone']), 
                               style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                        if (cleanHtmlText(customerDetails['address']).isNotEmpty) ...[
                          Text(capitalizeWords(cleanHtmlText(customerDetails['address']))),
                        ],
                        if (cleanHtmlText(customerDetails['gst_no']).isNotEmpty) ...[
                          Text('GST No: ${cleanHtmlText(customerDetails['gst_no'])}'),
                        ],
                        Text("State: ${cleanHtmlText(customerDetails['state'])} (${cleanHtmlText(customerDetails['state_code'])})"),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Items Table
              Table(
                border: TableBorder.all(color: Colors.black),
                columnWidths: invoiceData?["batch_validate"] == "yes"
                    ? {
                        0: const FlexColumnWidth(3),
                        1: const FlexColumnWidth(2),
                        2: const FlexColumnWidth(2),
                        3: const FlexColumnWidth(2),
                        4: const FlexColumnWidth(2),
                        5: const FlexColumnWidth(2),
                        6: const FlexColumnWidth(2),
                        7: const FlexColumnWidth(2),
                      }
                    : {
                        0: const FlexColumnWidth(3),
                        1: const FlexColumnWidth(2),
                        2: const FlexColumnWidth(2),
                        3: const FlexColumnWidth(2),
                        4: const FlexColumnWidth(2),
                        5: const FlexColumnWidth(2),
                        6: const FlexColumnWidth(2),
                      },
                children: [
                  // Table Header
                  TableRow(
                    decoration: const BoxDecoration(color: Colors.grey),
                    children: invoiceData?["batch_validate"] == "yes"
                        ? const [
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Item Name",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.left),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("HSN Code",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Batch No",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Qty",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Rate",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Disc Amount",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("GST",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Total",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                          ]
                        : const [
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Item Name",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.left),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("HSN Code",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Qty",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Rate",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Disc Amount",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("GST",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.center),
                            ),
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text("Total",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8),
                                  textAlign: TextAlign.right),
                            ),
                          ],
                  ),
                  
                  // Table Data
                 ...items.map((item) {
  return TableRow(
    children: invoiceData?["batch_validate"] == "yes"
        ? [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['itm_name']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.left),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['hsncode']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['batch']) ?? "N/A",
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['qty'].toString()),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['unrate']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.right),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['spl_amt']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.right),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['gst']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['crt_ttl_amt']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.right),
            ),
          ]
        : [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['itm_name']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.left),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['hsncode']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['qty'].toString()),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['unrate']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.right),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['spl_amt']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.right),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['gst']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(cleanHtmlText(item['crt_ttl_amt']),
                  style: const TextStyle(fontSize: 6),
                  textAlign: TextAlign.right),
            ),
          ],
  );
}).toList(),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Totals Section
              Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Taxable Value:"),
                        Text("Total GST:"),
                        Text("Discount:"),
                        Text("Round Off:"),
                        Text(
                          "Total Amount:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${invoiceData!['tax_value']}"),
                        Text("${invoiceData!['ttl_gst_amt']}"),
                        Text("${invoiceData!['ttl_disc_amt']}"),
                        Text("${invoiceData!['roundoff']}"),
                        Text(
                          "${invoiceData!['ttl_amt']}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Amount in Words
              Text(
                "In Words: ${invoiceData!['ttl_amt_words']}",
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // GST Breakdown Table
              Table(
                border: TableBorder.all(width: 1),
                columnWidths: const {
                  0: FlexColumnWidth(),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                },
                children: [
                  // Table Header
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade400),
                    children: const [
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'GST',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'CGST',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'SGST',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      TableCell(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'IGST',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 8),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Table Rows (Data)
                  ...invoiceGST.map((gst) {
                    return TableRow(
                      children: [
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              gst['gst'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              gst['cgst_amt'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              gst['sgst_amt'].toString(),
                              style: const TextStyle(fontSize: 8),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
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
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Terms and Conditions
              if (companyDetails['terms_cond'] != null &&
                  companyDetails['terms_cond'].toString().isNotEmpty)
                Text(
                  companyDetails['terms_cond'],
                  style: const TextStyle(fontSize: 12),
                ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Declaration
              const Text(
                "Declaration: Certified that all the particulars shown in the above Tax invoice are true and correct and that my/our registration under GST Act-2017 is valid as on the date of bill.",
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}