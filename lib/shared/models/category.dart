class Category {
  final int? id;
  final String name;
  final String type; // 'fixed_bill' or 'variable_expense'
  final double? expectedMonthlyAmount;
  final int dueDay;
  final bool enabled;
  final bool archived;
  final bool reminderEnabled;

  const Category({
    this.id,
    required this.name,
    required this.type,
    this.expectedMonthlyAmount,
    this.dueDay = 1,
    this.enabled = true,
    this.archived = false,
    this.reminderEnabled = true,
  });

  Category copyWith({
    int? id,
    String? name,
    String? type,
    double? expectedMonthlyAmount,
    int? dueDay,
    bool? enabled,
    bool? archived,
    bool? reminderEnabled,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      expectedMonthlyAmount:
          expectedMonthlyAmount ?? this.expectedMonthlyAmount,
      dueDay: dueDay ?? this.dueDay,
      enabled: enabled ?? this.enabled,
      archived: archived ?? this.archived,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type,
      'expected_monthly_amount': expectedMonthlyAmount,
      'due_day': dueDay,
      'enabled': enabled ? 1 : 0,
      'archived': archived ? 1 : 0,
      'reminder_enabled': reminderEnabled ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      expectedMonthlyAmount: (map['expected_monthly_amount'] as num?)
          ?.toDouble(),
      dueDay: (map['due_day'] as num?)?.toInt() ?? 1,
      enabled: (map['enabled'] as int?) == 1,
      archived: (map['archived'] as int?) == 1,
      reminderEnabled: (map['reminder_enabled'] as int?) != 0,
    );
  }

  bool get isFixedBill => type == 'fixed_bill';
  bool get isVariableExpense => type == 'variable_expense';
}
