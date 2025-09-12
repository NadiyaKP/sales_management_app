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
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    "Credit Note",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
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
                          "Customer Name",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          customerDetails['custname'] ?? '',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                        if (customerDetails['address']?.isNotEmpty == true)
                          pw.Text(
                            customerDetails['address'],
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        if (customerDetails['phone']?.isNotEmpty == true)
                          pw.Text(
                            "Ph: ${customerDetails['phone']}",
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        if (customerDetails['gst_no']?.isNotEmpty == true)
                          pw.Text(
                            "GST: ${customerDetails['gst_no']}",
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        pw.Text(
                          "State: ${customerDetails['state'] ?? ''} (${customerDetails['state_code'] ?? ''})",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              "Credit Note No: ",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                            pw.Text(
                              salesReturnData!['crd_no'] ?? '',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text(
                              "Date: ",
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                            pw.Text(
                              salesReturnData!['crd_date'] ?? '',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),
              if (style == "without_product")
                pw.Table(
                  border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(width: 0.3),
                    verticalInside: pw.BorderSide(width: 0.3),
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                    left: pw.BorderSide(width: 0.5),
                    right: pw.BorderSide(width: 0.5),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            "Particulars",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            "Amount",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
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
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              item['itm_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 7),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const pw.TextStyle(fontSize: 7),
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
                    horizontalInside: pw.BorderSide(width: 0.3),
                    verticalInside: pw.BorderSide(width: 0.3),
                    top: pw.BorderSide(width: 0.5),
                    bottom: pw.BorderSide(width: 0.5),
                    left: pw.BorderSide(width: 0.5),
                    right: pw.BorderSide(width: 0.5),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            "Item",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            "Particulars",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
                            ),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Text(
                            "Amount",
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
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
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              item['itm_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 7),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              item['itm_name'] ?? '',
                              style: const pw.TextStyle(fontSize: 7),
                              textAlign: pw.TextAlign.left,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(2),
                            child: pw.Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const pw.TextStyle(fontSize: 7),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Total Amount:",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          "GST Amount:",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (salesReturnData!['cess_name']?.isNotEmpty == true)
                          pw.Text(
                            "${salesReturnData!['cess_name']}:",
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        pw.Text(
                          "Discount Amount:",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (salesReturnData!['roundoff'] != null)
                          pw.Text(
                            "Round Off:",
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        pw.Text(
                          "Net Amount:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
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
                        pw.Text(
                          "${salesReturnData!['tax_value'] ?? '0.00'}",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          "${salesReturnData!['ttl_gst_amt'] ?? '0.00'}",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (salesReturnData!['cess_name']?.isNotEmpty == true)
                          pw.Text(
                            "${salesReturnData!['ttl_cess_amt'] ?? '0.00'}",
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        pw.Text(
                          "${salesReturnData!['ttl_disc_amt'] ?? '0.00'}",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (salesReturnData!['roundoff'] != null)
                          pw.Text(
                            "${salesReturnData!['roundoff'] ?? '0.00'}",
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        pw.Text(
                          "${salesReturnData!['ttl_amt'] ?? '0.00'}",
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
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Authorised Signature",
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    "Customer Signature",
                    style: const pw.TextStyle(fontSize: 8),
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
      final pdf = generateCreditNotePdf();
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final file = File('$path/credit_note_${salesReturnData!['crd_no']}.pdf');
      await file.writeAsBytes(await pdf.save());
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
          title: const Text('Sales Return', style: TextStyle(fontSize: 18)),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (salesReturnData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sales Return', style: TextStyle(fontSize: 18)),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Failed to load sales return details',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    final customerDetails = salesReturnData!['customerdet'][0];
    final items = salesReturnData!['invoicereturncartdet'];
    final style = salesReturnData!['style'] ?? 'with_product';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Return Details', style: TextStyle(fontSize: 18)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, size: 18),
            onPressed: () {
              final pdf = generateCreditNotePdf();
              Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => pdf.save(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 18),
            onPressed: sharePdf,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 8),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (customerDetails['phone']?.isNotEmpty == true) ...[
                          Text(
                            customerDetails['phone'],
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                        if (customerDetails['address']?.isNotEmpty == true) ...[
                          Text(
                            capitalizeWords(customerDetails['address']),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                        if (customerDetails['gst_no']?.isNotEmpty == true) ...[
                          Text(
                            'GST No: ${customerDetails['gst_no']}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                        Text(
                          "State: ${customerDetails['state'] ?? ''} (${customerDetails['state_code'] ?? ''})",
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 8, thickness: 0.5),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Credit Note No: ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              salesReturnData!['crd_no'] ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              "Date: ",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              salesReturnData!['crd_date'] ?? '',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(thickness: 0.5),
              const SizedBox(height: 4),
              if (style == "without_product")
                Table(
                  border: TableBorder.all(color: Colors.black, width: 0.5),
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(1),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.grey),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            "Particulars",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            "Amount",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
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
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              item['itm_name'] ?? '',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const TextStyle(fontSize: 9),
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
                  border: TableBorder.all(color: Colors.black, width: 0.5),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(color: Colors.grey),
                      children: [
                        Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            "Item",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            "Particulars",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Text(
                            "Amount",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
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
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              item['itm_name'] ?? '',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              item['itm_name'] ?? '',
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Text(
                              item['crt_ttl_amt'] ?? '0.00',
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              const SizedBox(height: 8),
              const Divider(thickness: 0.5),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Total Amount:",
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          "GST Amount:",
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          "Cess Amount:",
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          "Discount Amount:",
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          "Round Off:",
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          "Net Amount:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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
                        Text(
                          "${salesReturnData!['tax_value'] ?? '0.00'}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          "${salesReturnData!['ttl_gst_amt'] ?? '0.00'}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          "${salesReturnData!['ttl_cess_amt'] ?? '0.00'}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          "${salesReturnData!['ttl_disc_amt'] ?? '0.00'}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          "${salesReturnData!['roundoff'] ?? '0.00'}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          "${salesReturnData!['ttl_amt'] ?? '0.00'}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
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