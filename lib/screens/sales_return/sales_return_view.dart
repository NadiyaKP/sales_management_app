import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class SalesReturnViewScreen extends StatefulWidget {
  final String crdId;
  final String typeofCreditNote;

  const SalesReturnViewScreen({
    Key? key,
    required this.crdId,
    required this.typeofCreditNote,
  }) : super(key: key);

  @override
  State<SalesReturnViewScreen> createState() => _SalesReturnViewScreenState();
}

class _SalesReturnViewScreenState extends State<SalesReturnViewScreen> {
  Map<String, dynamic>? salesReturnData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSalesReturnDetails();
  }

  Future<void> fetchSalesReturnDetails() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? url = prefs.getString('url');
      String? unid = prefs.getString('unid');
      String? slex = prefs.getString('slex');
      String crdId = widget.crdId;

      final response = await http.post(
        Uri.parse("$url/single-credit-note-view.php"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "unid": unid,
          "slex": slex,
          "crdid": crdId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == "1") {
          setState(() {
            salesReturnData = data;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          _showError(data['message'] ?? 'Failed to fetch sales return details.');
        }
      } else {
        setState(() {
          isLoading = false;
        });
        _showError('Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError('An error occurred: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  pw.Document generateCreditNotePdf() {
    final pdf = pw.Document();
    final customerDetails = salesReturnData!['customerdet'][0];
    final items = salesReturnData!['invoicereturncartdet'] as List<dynamic>;
    final style = salesReturnData!['style'] ?? 'with_product';

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
                    "Credit Note",
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
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Customer Name",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          customerDetails['custname'] ?? '',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        if (customerDetails['address']?.isNotEmpty == true)
                          pw.Text(customerDetails['address']),
                        if (customerDetails['phone']?.isNotEmpty == true)
                          pw.Text("Ph: ${customerDetails['phone']}"),
                        if (customerDetails['gst_no']?.isNotEmpty == true)
                          pw.Text("GST: ${customerDetails['gst_no']}"),
                        pw.Text(
                          "State: ${customerDetails['state'] ?? ''} (${customerDetails['state_code'] ?? ''})",
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              "Credit Note No: ",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(salesReturnData!['crd_no'] ?? ''),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          children: [
                            pw.Text(
                              "Date: ",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Text(salesReturnData!['crd_date'] ?? ''),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (style == "without_product")
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
                          child: pw.Text(
                            "Particulars",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            "Total Amount",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              item['itm_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                )
              else
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
                          child: pw.Text(
                            "Item",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            "Particulars",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            "Total Amount",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              item['itm_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              item['itm_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              pw.SizedBox(height: 16),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Total Amount:"),
                        pw.Text("GST Amount:"),
                        if (salesReturnData!['cess_name']?.isNotEmpty == true)
                          pw.Text("${salesReturnData!['cess_name']}:"),
                        pw.Text("Discount Amount:"),
                        if (salesReturnData!['roundoff'] != null)
                          pw.Text("Round Off:"),
                        pw.Text(
                          "Net Amount:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("${salesReturnData!['tax_value'] ?? '0.00'}"),
                        pw.Text("${salesReturnData!['ttl_gst_amt'] ?? '0.00'}"),
                        if (salesReturnData!['cess_name']?.isNotEmpty == true)
                          pw.Text("${salesReturnData!['ttl_cess_amt'] ?? '0.00'}"),
                        pw.Text("${salesReturnData!['ttl_disc_amt'] ?? '0.00'}"),
                        if (salesReturnData!['roundoff'] != null)
                          pw.Text("${salesReturnData!['roundoff'] ?? '0.00'}"),
                        pw.Text(
                          "${salesReturnData!['ttl_amt'] ?? '0.00'}",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                          ),
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
                  pw.Text(
                    "Authorised Signature",
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    "Customer Signature",
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> sharePdf() async {
    try {
      // Generate the PDF
      final pdf = generateCreditNotePdf();
      
      // Get the application documents directory
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      
      // Create a file to save the PDF
      final file = File('$path/credit_note_${salesReturnData!['crd_no']}.pdf');
      
      // Save the PDF to the file
      await file.writeAsBytes(await pdf.save());
      
      // Share the PDF file
      await Share.shareFiles(
        [file.path],
        text: 'Credit Note ${salesReturnData!['crd_no']}',
        subject: 'Credit Note from ${salesReturnData!['customerdet'][0]['custname']}',
      );
    } catch (e) {
      _showError('Failed to share PDF: $e');
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
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales Return'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (salesReturnData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales Return'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Failed to load sales return details',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final customerDetails = salesReturnData!['customerdet'][0];
    final items = salesReturnData!['invoicereturncartdet'];
    final style = salesReturnData!['style'] ?? 'with_product';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Return Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              final pdf = generateCreditNotePdf();
              Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdf.save(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: sharePdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerDetails['custname'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (customerDetails['phone']?.isNotEmpty == true) ...[
                          Text(
                            customerDetails['phone'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                        if (customerDetails['address']?.isNotEmpty == true) ...[
                          Text(capitalizeWords(customerDetails['address'])),
                        ],
                        if (customerDetails['gst_no']?.isNotEmpty == true) ...[
                          Text('GST No: ${customerDetails['gst_no']}'),
                        ],
                        Text(
                          "State: ${customerDetails['state'] ?? ''} (${customerDetails['state_code'] ?? ''})",
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Credit Note No: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(salesReturnData!['crd_no'] ?? ''),
                          ],
                        ),
                        Row(
                          children: [
                            const Text(
                              "Date: ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(salesReturnData!['crd_date'] ?? ''),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              if (style == "without_product")
                Table(
                  border: TableBorder.all(color: Colors.black),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.grey),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            "Particulars",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            "Amount",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              item['itm_name'] ?? '',
                              style: const TextStyle(fontSize: 6),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const TextStyle(fontSize: 6),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                )
              else
                Table(
                  border: TableBorder.all(color: Colors.black),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.grey),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            "Particulars",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            "Amount",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...items.map((item) {
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              item['itm_name'] ?? '',
                              style: const TextStyle(fontSize: 6),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const TextStyle(fontSize: 6),
                              textAlign: TextAlign.right,
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
              Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Total Amount:"),
                        Text("GST Amount:"),
                        Text("Cess Amount:"),
                        Text("Discount Amount:"),
                        Text("Round Off:"),
                        Text(
                          "Net Amount:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${salesReturnData!['tax_value'] ?? '0.00'}"),
                        Text("${salesReturnData!['ttl_gst_amt'] ?? '0.00'}"),
                        Text("${salesReturnData!['ttl_cess_amt'] ?? '0.00'}"),
                        Text("${salesReturnData!['ttl_disc_amt'] ?? '0.00'}"),
                        Text("${salesReturnData!['roundoff'] ?? '0.00'}"),
                        Text(
                          "${salesReturnData!['ttl_amt'] ?? '0.00'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}