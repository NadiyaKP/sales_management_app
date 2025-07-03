class Customer {
  final String typeofCustomer;
  final String typeName;
  final String name;
  final String gstNo;
  final String phoneNo;
  final String balance;
  final String email;
  final String landPhone;
  final String address;
  final String state;
  final String stateCode;
  final String noOfCreditsDays;
  final String custId;
  final String status;
  final String openBalance;
  final String openAccount;

  Customer({
    required this.typeofCustomer,
    required this.typeName,
    required this.name,
    required this.openAccount,
    required this.openBalance,
    required this.status,
    required this.gstNo,
    required this.phoneNo,
    required this.balance,
    required this.address,
    required this.email,
    required this.landPhone,
    required this.noOfCreditsDays,
    required this.state,
    required this.stateCode,
    required this.custId,
  });

  // Factory constructor for creating Customer from JSON
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      typeofCustomer: json['typeofCustomer'] ?? '',
      typeName: json['typeName'] ?? '',
      name: json['name'] ?? '',
      openAccount: json['openAccount'] ?? '',
      openBalance: json['openBalance'] ?? '',
      status: json['status'] ?? '',
      gstNo: json['gstNo'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      balance: json['balance'] ?? '',
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      landPhone: json['landPhone'] ?? '',
      noOfCreditsDays: json['noOfCreditsDays'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['stateCode'] ?? '',
      custId: json['custId'] ?? '',
    );
  }

  // Method to convert Customer to JSON
  Map<String, dynamic> toJson() {
    return {
      'typeofCustomer': typeofCustomer,
      'typeName': typeName,
      'name': name,
      'openAccount': openAccount,
      'openBalance': openBalance,
      'status': status,
      'gstNo': gstNo,
      'phoneNo': phoneNo,
      'balance': balance,
      'address': address,
      'email': email,
      'landPhone': landPhone,
      'noOfCreditsDays': noOfCreditsDays,
      'state': state,
      'stateCode': stateCode,
      'custId': custId,
    };
  }

  // Copy with method for creating modified copies
  Customer copyWith({
    String? typeofCustomer,
    String? typeName,
    String? name,
    String? gstNo,
    String? phoneNo,
    String? balance,
    String? email,
    String? landPhone,
    String? address,
    String? state,
    String? stateCode,
    String? noOfCreditsDays,
    String? custId,
    String? status,
    String? openBalance,
    String? openAccount,
  }) {
    return Customer(
      typeofCustomer: typeofCustomer ?? this.typeofCustomer,
      typeName: typeName ?? this.typeName,
      name: name ?? this.name,
      gstNo: gstNo ?? this.gstNo,
      phoneNo: phoneNo ?? this.phoneNo,
      balance: balance ?? this.balance,
      email: email ?? this.email,
      landPhone: landPhone ?? this.landPhone,
      address: address ?? this.address,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      noOfCreditsDays: noOfCreditsDays ?? this.noOfCreditsDays,
      custId: custId ?? this.custId,
      status: status ?? this.status,
      openBalance: openBalance ?? this.openBalance,
      openAccount: openAccount ?? this.openAccount,
    );
  }

  @override
  String toString() {
    return 'Customer{custId: $custId, name: $name, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.custId == custId;
  }

  @override
  int get hashCode => custId.hashCode;
}