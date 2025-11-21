import 'package:cloud_firestore/cloud_firestore.dart';

// ================== ENUMS ==================
enum PaymentStatus { pending, completed, cancelled }

// ================== PAYMENT MODEL ==================

/// معاملة الدفع
class PaymentTransaction {
  final String id;
  final String debtorId;
  final int amount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime addedAt;
  final String notes;
  final String paymentMethod;
  final PaymentStatus status;

  const PaymentTransaction({
    required this.id,
    required this.debtorId,
    required this.amount,
    required this.createdAt,
    this.updatedAt,
    required this.addedAt,
    this.notes = '',
    this.paymentMethod = 'Cash',
    this.status = PaymentStatus.completed,
  });

  factory PaymentTransaction.fromFirestore(DocumentSnapshot doc, String debtorId) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentTransaction(
      id: doc.id,
      debtorId: debtorId,
      amount: data['amount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'Cash',
      status: PaymentStatus.values.firstWhere(
            (s) => s.name == data['status'],
        orElse: () => PaymentStatus.completed,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'addedAt': Timestamp.fromDate(addedAt),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'status': status.name,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtorId': debtorId,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'addedAt': addedAt.toIso8601String(),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'status': status.name,
    };
  }

  PaymentTransaction copyWith({
    int? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    String? paymentMethod,
    PaymentStatus? status,
  }) {
    return PaymentTransaction(
      id: id,
      debtorId: debtorId,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      addedAt: addedAt,
      notes: notes ?? this.notes,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
    );
  }

  @override
  String toString() => 'PaymentTransaction(id: $id, amount: $amount, createdAt: $createdAt)';
}

// ================== RESPONSE MODELS ==================

/// نموذج الاستجابة العامة
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? errorCode;
  final DateTime timestamp;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.errorCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiResponse.success(T data) {
    return ApiResponse<T>(
      success: true,
      data: data,
    );
  }

  factory ApiResponse.error(String error, {String? errorCode}) {
    return ApiResponse<T>(
      success: false,
      error: error,
      errorCode: errorCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'data': data,
      'error': error,
      'errorCode': errorCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// نموذج البيانات المقسمة على صفحات
class PaginatedResponse<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int currentPage;
  final int pageSize;
  final int? totalCount;

  const PaginatedResponse({
    required this.items,
    this.lastDocument,
    required this.hasMore,
    required this.currentPage,
    required this.pageSize,
    this.totalCount,
  });

  /// صفحة فارغة
  factory PaginatedResponse.empty(int pageSize) {
    return PaginatedResponse<T>(
      items: [],
      hasMore: false,
      currentPage: 0,
      pageSize: pageSize,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items,
      'hasMore': hasMore,
      'currentPage': currentPage,
      'pageSize': pageSize,
      'itemsCount': items.length,
      'totalCount': totalCount,
    };
  }

  /// هل يوجد صفحة تالية
  bool get hasNext => hasMore;

  /// هل يوجد صفحة سابقة
  bool get hasPrevious => currentPage > 0;

  /// رقم الصفحة التالية
  int get nextPage => hasMore ? currentPage + 1 : currentPage;

  /// رقم الصفحة السابقة
  int get previousPage => currentPage > 0 ? currentPage - 1 : 0;
}

/// نموذج الإحصائيات الشاملة
class StatisticsResponse {
  final GeneralStatistics general;
  final List<PaymentTransaction> recentPayments;
  final Map<String, dynamic> trends;

  const StatisticsResponse({
    required this.general,
    required this.recentPayments,
    required this.trends,
  });

  Map<String, dynamic> toMap() {
    return {
      'general': general.toMap(),
      'recentPayments': recentPayments.map((payment) => payment.toMap()).toList(),
      'trends': trends,
    };
  }
}

/// الإحصائيات العامة
class GeneralStatistics {
  final int totalDebtors;
  final int activeDebtors;
  final int inactiveDebtors;
  final int totalBorrowed;
  final int totalPaid;
  final int totalCurrentDebt;
  final int zeroDebtDebtors;
  final int debtorsWithDebt;
  final int averageDebt;
  final int paymentRate;

  const GeneralStatistics({
    required this.totalDebtors,
    required this.activeDebtors,
    required this.inactiveDebtors,
    required this.totalBorrowed,
    required this.totalPaid,
    required this.totalCurrentDebt,
    required this.zeroDebtDebtors,
    required this.debtorsWithDebt,
    required this.averageDebt,
    required this.paymentRate,
  });

  factory GeneralStatistics.fromMap(Map<String, dynamic> map) {
    return GeneralStatistics(
      totalDebtors: map['totalDebtors'] ?? 0,
      activeDebtors: map['activeDebtors'] ?? 0,
      inactiveDebtors: map['inactiveDebtors'] ?? 0,
      totalBorrowed: map['totalBorrowed'] ?? 0,
      totalPaid: map['totalPaid'] ?? 0,
      totalCurrentDebt: map['totalCurrentDebt'] ?? 0,
      zeroDebtDebtors: map['zeroDebtDebtors'] ?? 0,
      debtorsWithDebt: map['debtorsWithDebt'] ?? 0,
      averageDebt: map['averageDebt'] ?? 0,
      paymentRate: map['paymentRate'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalDebtors': totalDebtors,
      'activeDebtors': activeDebtors,
      'inactiveDebtors': inactiveDebtors,
      'totalBorrowed': totalBorrowed,
      'totalPaid': totalPaid,
      'totalCurrentDebt': totalCurrentDebt,
      'zeroDebtDebtors': zeroDebtDebtors,
      'debtorsWithDebt': debtorsWithDebt,
      'averageDebt': averageDebt,
      'paymentRate': paymentRate,
    };
  }
}

// ================== EXTENSION METHODS ==================

/// امتدادات للمدفوعات
extension PaymentExtensions on PaymentTransaction {
  /// هل الدفعة حديثة
  bool isRecent({Duration period = const Duration(days: 7)}) {
    return DateTime.now().difference(createdAt) <= period;
  }

  /// تصنيف المدفوعة حسب المبلغ
  String get amountCategory {
    if (amount < 50) return 'قليل';
    if (amount < 200) return 'متوسط';
    if (amount < 500) return 'جيد';
    return 'ممتاز';
  }

  /// هل الدفعة مكتملة
  bool get isCompleted => status == PaymentStatus.completed;

  /// هل الدفعة معلقة
  bool get isPending => status == PaymentStatus.pending;

  /// هل الدفعة ملغاة
  bool get isCancelled => status == PaymentStatus.cancelled;

  /// لون حالة الدفعة
  String get statusColor {
    switch (status) {
      case PaymentStatus.completed: return 'green';
      case PaymentStatus.pending: return 'orange';
      case PaymentStatus.cancelled: return 'red';
    }
  }

  /// نص حالة الدفعة
  String get statusText {
    switch (status) {
      case PaymentStatus.completed: return 'مكتمل';
      case PaymentStatus.pending: return 'معلق';
      case PaymentStatus.cancelled: return 'ملغي';
    }
  }
}

/// امتدادات للتواريخ
extension DateTimeExtensions on DateTime {
  /// تنسيق التاريخ بالعربية
  String get arabicFormat {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '$day ${months[month - 1]} $year';
  }

  /// هل التاريخ اليوم
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// هل التاريخ بالأمس
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// هل التاريخ هذا الأسبوع
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek) && isBefore(endOfWeek) ||
        isAtSameMomentAs(startOfWeek) || isAtSameMomentAs(endOfWeek);
  }

  /// التاريخ النسبي
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inDays > 0) {
      if (isYesterday) return 'أمس';
      if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';
      if (difference.inDays < 30) return 'منذ ${(difference.inDays / 7).round()} أسابيع';
      if (difference.inDays < 365) return 'منذ ${(difference.inDays / 30).round()} شهور';
      return 'منذ ${(difference.inDays / 365).round()} سنوات';
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعات';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقائق';
    } else {
      return 'الآن';
    }
  }
}

/// امتدادات للأرقام
extension IntExtensions on int {
  /// تنسيق الرقم بالفواصل
  String get formatted {
    return toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  /// تحويل إلى نص بالعربية
  String get arabicText {
    if (this == 0) return 'صفر';
    if (this < 0) return 'سالب ${(-this).arabicText}';

    final ones = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    final tens = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
    final hundreds = ['', 'مائة', 'مائتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة', 'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'];

    // تنفيذ مبسط للأرقام الصغيرة
    if (this < 10) return ones[this];
    if (this < 100) {
      final ten = this ~/ 10;
      final one = this % 10;
      if (this < 20) {
        const teens = ['عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر', 'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'];
        return teens[this - 10];
      }
      return one == 0 ? tens[ten] : '${ones[one]} و${tens[ten]}';
    }

    // للأرقام الأكبر، عرض مبسط
    return formatted;
  }

  /// تحويل إلى عملة
  String get currency => '${formatted} جنيه';
}

// ================== CONSTANTS ==================

/// ثوابت التطبيق المتعلقة بالمدفوعات
class PaymentConstants {
  static const String appName = 'إدارة الديون';
  static const String appVersion = '1.0.0';

  // ثوابت Firestore
  static const String paymentsSubCollection = 'payments';

  // ثوابت التحقق
  static const int minAmount = 0;
  static const int maxAmount = 999999999;

  // ثوابت الصفحات
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ثوابت Cache
  static const Duration cacheExpiry = Duration(minutes: 5);
  static const int maxCacheSize = 100;

  // ثوابت التصنيف
  static const int smallPaymentThreshold = 50;
  static const int mediumPaymentThreshold = 200;
  static const int goodPaymentThreshold = 500;

  // رسائل الأخطاء
  static const String networkError = 'مشكلة في الاتصال بالإنترنت';
  static const String permissionError = 'ليس لديك صلاحية للوصول';
  static const String notFoundError = 'البيانات غير موجودة';
  static const String invalidDataError = 'البيانات غير صحيحة';
  static const String quotaExceededError = 'تم تجاوز الحد المسموح';
  static const String unknownError = 'حدث خطأ غير متوقع';
  static const String invalidAmountError = 'المبلغ غير صحيح';
  static const String negativePaymentError = 'لا يمكن إدخال دفعة بمبلغ سالب';

  // رسائل النجاح
  static const String addSuccessMessage = 'تم إضافة الدفعة بنجاح';
  static const String updateSuccessMessage = 'تم تحديث الدفعة بنجاح';
  static const String deleteSuccessMessage = 'تم حذف الدفعة بنجاح';
  static const String cancelSuccessMessage = 'تم إلغاء الدفعة بنجاح';
}

/// قيم افتراضية للمدفوعات
class DefaultPaymentValues {
  static const int defaultPageSize = PaymentConstants.defaultPageSize;
  static const PaymentStatus defaultStatus = PaymentStatus.completed;
  static const String defaultNotes = '';
}