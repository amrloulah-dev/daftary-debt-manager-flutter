import 'package:cloud_firestore/cloud_firestore.dart';

// ================== ENUMS ==================
enum TransactionType { debt, payment }

// ================== DEBT MODELS ==================

/// صنف في الدين
class DebtItem {
  final String name;
  final double price;
  final int quantity;
  final double total;
  final String? description;

  const DebtItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.description,
  }) : total = price * quantity;

  factory DebtItem.fromMap(Map<String, dynamic> map) {
    return DebtItem(
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'total': total,
      'description': description,
    };
  }

  DebtItem copyWith({
    String? name,
    double? price,
    int? quantity,
    String? description,
  }) {
    return DebtItem(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
    );
  }

  @override
  String toString() =>
      'DebtItem(name: $name, price: $price, quantity: $quantity)';
}

/// معاملة الدين
class DebtTransaction {
  final String id;
  final String debtorId;
  final List<DebtItem> items;
  final int total;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPaid;
  final String notes;

  const DebtTransaction({
    required this.id,
    required this.debtorId,
    required this.items,
    required this.total,
    required this.createdAt,
    this.updatedAt,
    this.isPaid = false,
    this.notes = '',
  });

  factory DebtTransaction.fromFirestore(DocumentSnapshot doc, String debtorId) {
    final data = doc.data() as Map<String, dynamic>;
    return DebtTransaction(
      id: doc.id,
      debtorId: debtorId,
      items:
      (data['items'] as List<dynamic>?)
          ?.map((item) => DebtItem.fromMap(item as Map<String, dynamic>))
          .toList() ??
          [],
      total: data['total'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isPaid: data['isPaid'] ?? false,
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isPaid': isPaid,
      'notes': notes,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtorId': debtorId,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isPaid': isPaid,
      'notes': notes,
    };
  }

  DebtTransaction copyWith({
    List<DebtItem>? items,
    int? total,
    DateTime? updatedAt,
    bool? isPaid,
    String? notes,
  }) {
    return DebtTransaction(
      id: id,
      debtorId: debtorId,
      items: items ?? this.items,
      total: total ?? this.total,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
    );
  }

  /// عدد الأصناف
  int get itemsCount => items.length;

  /// متوسط سعر الصنف
  double get averageItemPrice =>
      items.isNotEmpty
          ? items.map((item) => item.price).reduce((a, b) => a + b) /
          items.length
          : 0;

  @override
  String toString() =>
      'DebtTransaction(id: $id, total: $total, itemsCount: $itemsCount)';
}

// ================== UTILITY CLASSES ==================

/// نتيجة التحقق من البيانات
class ValidationResult {
  final bool isValid;
  final String? error;
  final String? fieldName;

  const ValidationResult({required this.isValid, this.error, this.fieldName});

  factory ValidationResult.valid() {
    return const ValidationResult(isValid: true);
  }

  factory ValidationResult.invalid(String error, {String? fieldName}) {
    return ValidationResult(isValid: false, error: error, fieldName: fieldName);
  }

  Map<String, dynamic> toMap() {
    return {'isValid': isValid, 'error': error, 'fieldName': fieldName};
  }

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $error';
}

/// معلومات العملية
class OperationInfo {
  final String operation;
  final String description;
  final DateTime timestamp;
  final Duration? duration;
  final bool success;
  final String? error;

  const OperationInfo({
    required this.operation,
    required this.description,
    required this.timestamp,
    this.duration,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'operation': operation,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'success': success,
      'error': error,
    };
  }

  @override
  String toString() =>
      '$operation: $description (${success ? 'Success' : 'Failed'})';
}

/// معلومات Batch Operation
class BatchOperationResult {
  final int totalItems;
  final int successfulItems;
  final int failedItems;
  final List<String> errors;
  final Duration totalDuration;

  const BatchOperationResult({
    required this.totalItems,
    required this.successfulItems,
    required this.failedItems,
    required this.errors,
    required this.totalDuration,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalItems': totalItems,
      'successfulItems': successfulItems,
      'failedItems': failedItems,
      'errors': errors,
      'totalDuration': totalDuration.inMilliseconds,
      'successRate': successRate,
    };
  }

  /// معدل النجاح كنسبة مئوية
  double get successRate =>
      totalItems > 0 ? (successfulItems / totalItems) * 100 : 0;

  /// هل العملية نجحت بالكامل
  bool get isCompletelySuccessful => failedItems == 0;

  /// هل العملية فشلت بالكامل
  bool get isCompletelyFailed => successfulItems == 0;

  @override
  String toString() =>
      'BatchOperation: $successfulItems/$totalItems successful (${successRate.toStringAsFixed(1)}%)';
}

// ================== EXTENSION METHODS ==================

/// امتدادات للمعاملات
extension TransactionExtensions on DebtTransaction {
  /// هل المعاملة قديمة
  bool isOld({Duration period = const Duration(days: 90)}) {
    return DateTime.now().difference(createdAt) > period;
  }

  /// تصنيف المعاملة حسب الحجم
  String get sizeCategory {
    if (total < 50) return 'صغير';
    if (total < 200) return 'متوسط';
    if (total < 500) return 'كبير';
    return 'ضخم';
  }
}

// ================== CONSTANTS ==================

/// ثوابت التطبيق المتعلقة بالديون
class DebtConstants {
  // ثوابت Firestore
  static const String debtsSubCollection = 'debts';

  // ثوابت التحقق
  static const int minAmount = 0;
  static const int maxAmount = 999999999;

  // ثوابت التصنيف
  static const int smallDebtThreshold = 50;
  static const int mediumDebtThreshold = 200;
  static const int largeDebtThreshold = 500;

  // رسائل الأخطاء
  static const String invalidAmountError = 'المبلغ غير صحيح';
  static const String emptyItemsError = 'لا يمكن إنشاء دين بدون أصناف';
  static const String invalidItemError = 'صنف غير صحيح في الدين';
}
