class Transaction {
  final int? id;
  final int categoryId;
  final double amount;
  final String datePaid; // ISO-8601 date string
  final String? note;

  // Joined fields populated by queries
  final String? categoryName;
  final String? categoryType;

  const Transaction({
    this.id,
    required this.categoryId,
    required this.amount,
    required this.datePaid,
    this.note,
    this.categoryName,
    this.categoryType,
  });

  Transaction copyWith({
    int? id,
    int? categoryId,
    double? amount,
    String? datePaid,
    String? note,
    String? categoryName,
    String? categoryType,
  }) {
    return Transaction(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      datePaid: datePaid ?? this.datePaid,
      note: note ?? this.note,
      categoryName: categoryName ?? this.categoryName,
      categoryType: categoryType ?? this.categoryType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'amount': amount,
      'date_paid': datePaid,
      'note': note,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      datePaid: map['date_paid'] as String,
      note: map['note'] as String?,
      categoryName: map['category_name'] as String?,
      categoryType: map['category_type'] as String?,
    );
  }
}