class AccountDetails {
  final String id;
  final String accountHolderName;
  final String paymentMethod;
  final String accountNumber;
  final String? bankName;
  final String? ifscCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccountDetails({
    required this.id,
    required this.accountHolderName,
    required this.paymentMethod,
    required this.accountNumber,
    this.bankName,
    this.ifscCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountDetails.fromJson(Map<String, dynamic> json) {
    return AccountDetails(
      id: json['id'] as String,
      accountHolderName: json['account_holder_name'] as String,
      paymentMethod: json['payment_method'] as String,
      accountNumber: json['account_number'] as String,
      bankName: json['bank_name'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_holder_name': accountHolderName,
      'payment_method': paymentMethod,
      'account_number': accountNumber,
      'bank_name': bankName,
      'ifsc_code': ifscCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
