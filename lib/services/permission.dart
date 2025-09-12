import 'dart:convert';

class PermissionResponse {
  final List<PermissionDetail> permissionDetails;

  PermissionResponse({
    required this.permissionDetails,
  });

  factory PermissionResponse.fromJson(Map<String, dynamic> json) {
    return PermissionResponse(
      permissionDetails: (json['permissiondet'] as List)
          .map((item) => PermissionDetail.fromJson(item))
          .toList(),
    );
  }
}

class PermissionDetail {
  final String invoiceView;
  final String creditNoteView;
  final String receiptAdd;
  final String receiptDueAmount;
  final String receiptDateChange;
  final String receiptEdit;
  final String receiptView;
  final String receiptDelete;
  final String receiptDeleteReason;
  final String receiptWhatsapp;
  final String chequeAdd;
  final String chequeView;
  final String chequeEdit;
  final String chequeClear;
  final String chequeBounce;
  final String chequeDelete;
  final String chequeDeleteReason;
  final String discountAdd;
  final String discountDueAmount;
  final String discountDateChange;
  final String discountAllowed;
  final String discountEdit;
  final String discountView;
  final String discountDelete;
  final String discountDeleteReason;
  final String stockView;
  final String customerAdd;
  final String customerView;
  final String customerEdit;
  final String customerStatus;
  final String agedReceivable;
  final String salesReport;
  final String salesDetail;
  final String salesOther;
  final String receiptReport;
  final String salesReturnReport;
  final String salesReturnDetail;
  final String discountReport;
  final String allReportExcel;
  final String debitors;
  final String debitorsWhatsapp;
  final String debitorsExcel;
  final String dayBook;
  final String customerLedger;
  final String ledgerExcel;
  final String accountSales;
  final String accountReceipt;
  final String accountSalesReturn;
  final String accountDiscount;
  final String salesExecutiveLedger;
  final String salesExecutiveWiseSales;
  final String salesExecutiveWiseCollection;
  final String salesExecutiveWiseCreditNote;
  final String salesExecutiveWiseDiscount;
  final String salesExecutiveWiseExcel;
  final String orderAdd;
  final String orderEdit;
  final String orderView;
  final String orderDelete;
  final String orderReport;
  final String salesExecutiveWiseOrder;
  final String salesExecutiveWiseFastestProduct;

  PermissionDetail({
    required this.invoiceView,
    required this.creditNoteView,
    required this.receiptAdd,
    required this.receiptDueAmount,
    required this.receiptDateChange,
    required this.receiptEdit,
    required this.receiptView,
    required this.receiptDelete,
    required this.receiptDeleteReason,
    required this.receiptWhatsapp,
    required this.chequeAdd,
    required this.chequeView,
    required this.chequeEdit,
    required this.chequeClear,
    required this.chequeBounce,
    required this.chequeDelete,
    required this.chequeDeleteReason,
    required this.discountAdd,
    required this.discountDueAmount,
    required this.discountDateChange,
    required this.discountAllowed,
    required this.discountEdit,
    required this.discountView,
    required this.discountDelete,
    required this.discountDeleteReason,
    required this.stockView,
    required this.customerAdd,
    required this.customerView,
    required this.customerEdit,
    required this.customerStatus,
    required this.agedReceivable,
    required this.salesReport,
    required this.salesDetail,
    required this.salesOther,
    required this.receiptReport,
    required this.salesReturnReport,
    required this.salesReturnDetail,
    required this.discountReport,
    required this.allReportExcel,
    required this.debitors,
    required this.debitorsWhatsapp,
    required this.debitorsExcel,
    required this.dayBook,
    required this.customerLedger,
    required this.ledgerExcel,
    required this.accountSales,
    required this.accountReceipt,
    required this.accountSalesReturn,
    required this.accountDiscount,
    required this.salesExecutiveLedger,
    required this.salesExecutiveWiseSales,
    required this.salesExecutiveWiseCollection,
    required this.salesExecutiveWiseCreditNote,
    required this.salesExecutiveWiseDiscount,
    required this.salesExecutiveWiseExcel,
    required this.orderAdd,
    required this.orderEdit,
    required this.orderView,
    required this.orderDelete,
    required this.orderReport,
    required this.salesExecutiveWiseOrder,
    required this.salesExecutiveWiseFastestProduct,
  });

  factory PermissionDetail.fromJson(Map<String, dynamic> json) {
    return PermissionDetail(
      invoiceView: json['invoice_view'] ?? '',
      creditNoteView: json['creditnote_view'] ?? '',
      receiptAdd: json['receipt_add'] ?? '',
      receiptDueAmount: json['receipt_due_amount'] ?? '',
      receiptDateChange: json['receipt_date_change'] ?? '',
      receiptEdit: json['receipt_edit'] ?? '',
      receiptView: json['receipt_view'] ?? '',
      receiptDelete: json['receipt_delete'] ?? '',
      receiptDeleteReason: json['receipt_delete_reason'] ?? '',
      receiptWhatsapp: json['receipt_whatsapp'] ?? '',
      chequeAdd: json['cheque_add'] ?? '',
      chequeView: json['cheque_view'] ?? '',
      chequeEdit: json['cheque_edit'] ?? '',
      chequeClear: json['cheque_clear'] ?? '',
      chequeBounce: json['cheque_bounce'] ?? '',
      chequeDelete: json['cheque_delete'] ?? '',
      chequeDeleteReason: json['cheque_delete_reason'] ?? '',
      discountAdd: json['discount_add'] ?? '',
      discountDueAmount: json['discount_due_amount'] ?? '',
      discountDateChange: json['discount_date_change'] ?? '',
      discountAllowed: json['discount_allowed'] ?? '',
      discountEdit: json['discount_edit'] ?? '',
      discountView: json['discount_view'] ?? '',
      discountDelete: json['discount_delete'] ?? '',
      discountDeleteReason: json['discount_delete_reason'] ?? '',
      stockView: json['stock_view'] ?? '',
      customerAdd: json['customer_add'] ?? '',
      customerView: json['customer_view'] ?? '',
      customerEdit: json['customer_edit'] ?? '',
      customerStatus: json['customer_status'] ?? '',
      agedReceivable: json['aged_receivable'] ?? '',
      salesReport: json['sales_report'] ?? '',
      salesDetail: json['sales_detail'] ?? '',
      salesOther: json['sales_other'] ?? '',
      receiptReport: json['receipt_report'] ?? '',
      salesReturnReport: json['sales_return_report'] ?? '',
      salesReturnDetail: json['sales_return_detail'] ?? '',
      discountReport: json['discount_report'] ?? '',
      allReportExcel: json['all_report_excel'] ?? '',
      debitors: json['debitors'] ?? '',
      debitorsWhatsapp: json['debitors_whatsapp'] ?? '',
      debitorsExcel: json['debitors_excel'] ?? '',
      dayBook: json['day_book'] ?? '',
      customerLedger: json['customer_ledger'] ?? '',
      ledgerExcel: json['ledger_excel'] ?? '',
      accountSales: json['account_sales'] ?? '',
      accountReceipt: json['account_receipt'] ?? '',
      accountSalesReturn: json['account_sales_return'] ?? '',
      accountDiscount: json['account_discount'] ?? '',
      salesExecutiveLedger: json['sales_executive_ledger'] ?? '',
      salesExecutiveWiseSales: json['sales_executive_wise_sales'] ?? '',
      salesExecutiveWiseCollection: json['sales_executive_wise_collection'] ?? '',
      salesExecutiveWiseCreditNote: json['sales_executive_wise_credit_note'] ?? '',
      salesExecutiveWiseDiscount: json['sales_executive_wise_discount'] ?? '',
      salesExecutiveWiseExcel: json['sales_executive_wise_excel'] ?? '',
      orderAdd: json['order_add'] ?? '',
      orderEdit: json['order_edit'] ?? '',
      orderView: json['order_view'] ?? '',
      orderDelete: json['order_delete'] ?? '',
      orderReport: json['order_report'] ?? '',
      salesExecutiveWiseOrder: json['sales_executive_wise_order'] ?? '',
      salesExecutiveWiseFastestProduct: json['sales_executive_wise_fastest_product'] ?? '',
    );
  }

  // Print all fields in a readable format
  @override
  String toString() {
    return '''
Invoice View: $invoiceView
Credit Note View: $creditNoteView
Receipt Add: $receiptAdd
Receipt Due Amount: $receiptDueAmount
Receipt Date Change: $receiptDateChange
Receipt Edit: $receiptEdit
Receipt View: $receiptView
Receipt Delete: $receiptDelete
Receipt Delete Reason: $receiptDeleteReason
Receipt Whatsapp: $receiptWhatsapp
Cheque Add: $chequeAdd
Cheque View: $chequeView
Cheque Edit: $chequeEdit
Cheque Clear: $chequeClear
Cheque Bounce: $chequeBounce
Cheque Delete: $chequeDelete
Cheque Delete Reason: $chequeDeleteReason
Discount Add: $discountAdd
Discount Due Amount: $discountDueAmount
Discount Date Change: $discountDateChange
Discount Allowed: $discountAllowed
Discount Edit: $discountEdit
Discount View: $discountView
Discount Delete: $discountDelete
Discount Delete Reason: $discountDeleteReason
Stock View: $stockView
Customer Add: $customerAdd
Customer View: $customerView
Customer Edit: $customerEdit
Customer Status: $customerStatus
Aged Receivable: $agedReceivable
Sales Report: $salesReport
Sales Detail: $salesDetail
Sales Other: $salesOther
Receipt Report: $receiptReport
Sales Return Report: $salesReturnReport
Sales Return Detail: $salesReturnDetail
Discount Report: $discountReport
All Report Excel: $allReportExcel
Debitors: $debitors
Debitors Whatsapp: $debitorsWhatsapp
Debitors Excel: $debitorsExcel
Day Book: $dayBook
Customer Ledger: $customerLedger
Ledger Excel: $ledgerExcel
Account Sales: $accountSales
Account Receipt: $accountReceipt
Account Sales Return: $accountSalesReturn
Account Discount: $accountDiscount
Sales Executive Ledger: $salesExecutiveLedger
Sales Executive Wise Sales: $salesExecutiveWiseSales
Sales Executive Wise Collection: $salesExecutiveWiseCollection
Sales Executive Wise Credit Note: $salesExecutiveWiseCreditNote
Sales Executive Wise Discount: $salesExecutiveWiseDiscount
Sales Executive Wise Excel: $salesExecutiveWiseExcel
Order Add: $orderAdd
Order Edit: $orderEdit
Order View: $orderView
Order Delete: $orderDelete
Order Report: $orderReport
Sales Executive Wise Order: $salesExecutiveWiseOrder
Sales Executive Wise Fastest Product: $salesExecutiveWiseFastestProduct
''';
  }
}

// Example usage
void main() {
  // Sample JSON response (you can replace it with API response)
  String response = '''
  {
    "permissiondet": [
      {
        "invoice_view": "1",
        "creditnote_view": "1",
        "receipt_add": "0",
        "receipt_due_amount": "1",
        "order_add": "1",
        "order_view": "1",
        "customer_add": "0"
      }
    ]
  }
  ''';

  Map<String, dynamic> jsonData = json.decode(response);
  PermissionResponse permissionResponse = PermissionResponse.fromJson(jsonData);

  for (var detail in permissionResponse.permissionDetails) {
    print(detail); // will call toString()
  }
}
