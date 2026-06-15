class Category {
  final int? id;
  final String name;
  final String type; // 'fixed_bill' or 'variable_expense'
  final double? expectedMonthlyAmount;
  final bool enabled;

  const Category({
    this.id,
    required this.name,
    required this.type,
    this.expectedMonthlyAmount,
    this.enabled = true,
  });

  Category copyWith({
    int? id,
    String? name,
    String? type,
    double? expectedMonthlyAmount,
    bool? enabled,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      expectedMonthlyAmount: expectedMonthlyAmount ?? this.expectedMonthlyAmount,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'expected_monthly_amount': expectedMonthlyAmount,
      'enabled': enabled ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      expectedMonthlyAmount: map['expected_monthly_amount'] as double?,
      enabled: (map['enabled'] as int?) == 1,
    );
  }

  bool get isFixedBill => type == 'fixed_bill';
  bool get isVariableExpense => type == 'variable_expense';
}