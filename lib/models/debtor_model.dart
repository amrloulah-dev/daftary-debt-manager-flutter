import 'package:cloud_firestore/cloud_firestore.dart';

// ================== ENUMS ==================
enum SortBy { name, debt, lastPayment, createdDate }

enum SortOrder { ascending, descending }

enum DebtorStatus { active, inactive, zeroDebt }

// ================== DEBTOR MODEL ==================

/// نموذج العميل الأساسي
class Debtor {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final int totalBorrowed;
  final int totalPaid;
  final int currentDebt;
  final List<String> searchKeywords;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final DateTime? lastPaymentAt;
  final int totalTransactions;

  const Debtor({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    required this.totalBorrowed,
    required this.totalPaid,
    required this.currentDebt,
    required this.searchKeywords,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.lastPaymentAt,
    this.totalTransactions = 0,
  });

  /// إنشاء من Firestore Document
  factory Debtor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Debtor(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] as String?,
      notes: data['notes'] as String?,
      totalBorrowed: data['totalBorrowed'] ?? 0,
      totalPaid: data['totalPaid'] ?? 0,
      currentDebt: data['currentDebt'] ?? 0,
      searchKeywords: List<String>.from(data['searchKeywords'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      lastPaymentAt: (data['lastPaymentAt'] as Timestamp?)?.toDate(),
      totalTransactions: data['totalTransactions'] ?? 0,
    );
  }

  /// إنشاء من Map
  factory Debtor.fromMap(Map<String, dynamic> map, String id) {
    return Debtor(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      totalBorrowed: map['totalBorrowed'] ?? 0,
      totalPaid: map['totalPaid'] ?? 0,
      currentDebt: map['currentDebt'] ?? 0,
      searchKeywords: List<String>.from(map['searchKeywords'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      lastPaymentAt: (map['lastPaymentAt'] as Timestamp?)?.toDate(),
      totalTransactions: map['totalTransactions'] ?? 0,
    );
  }

  /// تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'totalBorrowed': totalBorrowed,
      'totalPaid': totalPaid,
      'currentDebt': currentDebt,
      'searchKeywords': searchKeywords,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'lastPaymentAt':
      lastPaymentAt != null ? Timestamp.fromDate(lastPaymentAt!) : null,
      'totalTransactions': totalTransactions,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'notes': notes,
      'totalBorrowed': totalBorrowed,
      'totalPaid': totalPaid,
      'currentDebt': currentDebt,
      'isActive': isActive,
      'lastPaymentAt': lastPaymentAt?.toIso8601String(),
      'totalTransactions': totalTransactions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// نسخة معدلة من العميل
  Debtor copyWith({
    String? name,
    String? phone,
    String? email,
    String? notes,
    int? totalBorrowed,
    int? totalPaid,
    int? currentDebt,
    List<String>? searchKeywords,
    DateTime? updatedAt,
    bool? isActive,
    DateTime? lastPaymentAt,
    int? totalTransactions,
  }) {
    return Debtor(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      totalBorrowed: totalBorrowed ?? this.totalBorrowed,
      totalPaid: totalPaid ?? this.totalPaid,
      currentDebt: currentDebt ?? this.currentDebt,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      lastPaymentAt: lastPaymentAt ?? this.lastPaymentAt,
      totalTransactions: totalTransactions ?? this.totalTransactions,
    );
  }

  /// الحصول على حالة العميل
  DebtorStatus get status {
    if (!isActive) return DebtorStatus.inactive;
    if (currentDebt == 0) return DebtorStatus.zeroDebt;
    return DebtorStatus.active;
  }

  /// هل العميل نشط ولديه ديون
  bool get hasActiveDebt => isActive && currentDebt > 0;

  /// معدل الدفع كنسبة مئوية
  double get paymentRate =>
      totalBorrowed > 0 ? (totalPaid / totalBorrowed) * 100 : 0;

  @override
  String toString() =>
      'Debtor(id: $id, name: $name, currentDebt: $currentDebt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Debtor && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ================== DEBTOR STATISTICS MODELS ==================

/// إحصائيات مفصلة لعميل واحد
class DebtorDetailedStatistics {
  final Debtor debtor;
  final DebtorTotals totals;
  final DebtorAverages averages;
  final DebtorRates rates;
  final DebtorDates dates;
  final DebtorPatterns patterns;

  const DebtorDetailedStatistics({
    required this.debtor,
    required this.totals,
    required this.averages,
    required this.rates,
    required this.dates,
    required this.patterns,
  });

  factory DebtorDetailedStatistics.fromMap(Map<String, dynamic> map) {
    return DebtorDetailedStatistics(
      debtor: Debtor.fromMap(map['debtorInfo'], map['debtorInfo']['id']),
      totals: DebtorTotals.fromMap(map['totals']),
      averages: DebtorAverages.fromMap(map['averages']),
      rates: DebtorRates.fromMap(map['rates']),
      dates: DebtorDates.fromMap(map['dates']),
      patterns: DebtorPatterns.fromMap(map['patterns']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'debtor': debtor.toMap(),
      'totals': totals.toMap(),
      'averages': averages.toMap(),
      'rates': rates.toMap(),
      'dates': dates.toMap(),
      'patterns': patterns.toMap(),
    };
  }
}

class DebtorTotals {
  final int totalBorrowed;
  final int totalPaid;
  final int totalDebtsCount;
  final int totalPaymentsCount;

  const DebtorTotals({
    required this.totalBorrowed,
    required this.totalPaid,
    required this.totalDebtsCount,
    required this.totalPaymentsCount,
  });

  factory DebtorTotals.fromMap(Map<String, dynamic> map) {
    return DebtorTotals(
      totalBorrowed: map['totalBorrowed'] ?? 0,
      totalPaid: map['totalPaid'] ?? 0,
      totalDebtsCount: map['totalDebtsCount'] ?? 0,
      totalPaymentsCount: map['totalPaymentsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalBorrowed': totalBorrowed,
      'totalPaid': totalPaid,
      'totalDebtsCount': totalDebtsCount,
      'totalPaymentsCount': totalPaymentsCount,
    };
  }
}

class DebtorAverages {
  final int averageDebtAmount;
  final int averagePaymentAmount;

  const DebtorAverages({
    required this.averageDebtAmount,
    required this.averagePaymentAmount,
  });

  factory DebtorAverages.fromMap(Map<String, dynamic> map) {
    return DebtorAverages(
      averageDebtAmount: map['averageDebtAmount'] ?? 0,
      averagePaymentAmount: map['averagePaymentAmount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageDebtAmount': averageDebtAmount,
      'averagePaymentAmount': averagePaymentAmount,
    };
  }
}

class DebtorRates {
  final int paymentRate;

  const DebtorRates({required this.paymentRate});

  factory DebtorRates.fromMap(Map<String, dynamic> map) {
    return DebtorRates(paymentRate: map['paymentRate'] ?? 0);
  }

  Map<String, dynamic> toMap() {
    return {'paymentRate': paymentRate};
  }
}

class DebtorDates {
  final DateTime? firstDebt;
  final DateTime? lastDebt;
  final DateTime? firstPayment;
  final DateTime? lastPayment;

  const DebtorDates({
    this.firstDebt,
    this.lastDebt,
    this.firstPayment,
    this.lastPayment,
  });

  factory DebtorDates.fromMap(Map<String, dynamic> map) {
    return DebtorDates(
      firstDebt:
      map['firstDebt'] != null ? DateTime.parse(map['firstDebt']) : null,
      lastDebt:
      map['lastDebt'] != null ? DateTime.parse(map['lastDebt']) : null,
      firstPayment:
      map['firstPayment'] != null
          ? DateTime.parse(map['firstPayment'])
          : null,
      lastPayment:
      map['lastPayment'] != null
          ? DateTime.parse(map['lastPayment'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstDebt': firstDebt?.toIso8601String(),
      'lastDebt': lastDebt?.toIso8601String(),
      'firstPayment': firstPayment?.toIso8601String(),
      'lastPayment': lastPayment?.toIso8601String(),
    };
  }
}

class DebtorPatterns {
  final int? daysSinceLastPayment;
  final double? averageDaysBetweenPayments;
  final String? paymentFrequency;

  const DebtorPatterns({
    this.daysSinceLastPayment,
    this.averageDaysBetweenPayments,
    this.paymentFrequency,
  });

  factory DebtorPatterns.fromMap(Map<String, dynamic> map) {
    return DebtorPatterns(
      daysSinceLastPayment: map['daysSinceLastPayment'],
      averageDaysBetweenPayments: map['averageDaysBetweenPayments']?.toDouble(),
      paymentFrequency: map['paymentFrequency'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'daysSinceLastPayment': daysSinceLastPayment,
      'averageDaysBetweenPayments': averageDaysBetweenPayments,
      'paymentFrequency': paymentFrequency,
    };
  }
}

// ================== CONFIGURATION MODELS ==================

/// إعدادات الترتيب
class SortConfiguration {
  final SortBy sortBy;
  final SortOrder sortOrder;

  const SortConfiguration({
    this.sortBy = SortBy.debt,
    this.sortOrder = SortOrder.descending,
  });

  SortConfiguration copyWith({SortBy? sortBy, SortOrder? sortOrder}) {
    return SortConfiguration(
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {'sortBy': sortBy.name, 'sortOrder': sortOrder.name};
  }

  factory SortConfiguration.fromMap(Map<String, dynamic> map) {
    return SortConfiguration(
      sortBy: SortBy.values.firstWhere(
            (e) => e.name == map['sortBy'],
        orElse: () => SortBy.debt,
      ),
      sortOrder: SortOrder.values.firstWhere(
            (e) => e.name == map['sortOrder'],
        orElse: () => SortOrder.descending,
      ),
    );
  }
}

/// إعدادات الفلترة
class FilterConfiguration {
  final bool activeOnly;
  final AmountRange? debtRange;
  final DateRange? dateRange;
  final DebtorStatus? status;

  const FilterConfiguration({
    this.activeOnly = true,
    this.debtRange,
    this.dateRange,
    this.status,
  });

  FilterConfiguration copyWith({
    bool? activeOnly,
    AmountRange? debtRange,
    DateRange? dateRange,
    DebtorStatus? status,
  }) {
    return FilterConfiguration(
      activeOnly: activeOnly ?? this.activeOnly,
      debtRange: debtRange ?? this.debtRange,
      dateRange: dateRange ?? this.dateRange,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activeOnly': activeOnly,
      'debtRange': debtRange?.toMap(),
      'dateRange': dateRange?.toMap(),
      'status': status?.name,
    };
  }
}

/// إعدادات البحث
class SearchConfiguration {
  final String? query;
  final bool searchInName;
  final bool searchInPhone;
  final bool caseSensitive;

  const SearchConfiguration({
    this.query,
    this.searchInName = true,
    this.searchInPhone = true,
    this.caseSensitive = false,
  });

  SearchConfiguration copyWith({
    String? query,
    bool? searchInName,
    bool? searchInPhone,
    bool? caseSensitive,
  }) {
    return SearchConfiguration(
      query: query ?? this.query,
      searchInName: searchInName ?? this.searchInName,
      searchInPhone: searchInPhone ?? this.searchInPhone,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'query': query,
      'searchInName': searchInName,
      'searchInPhone': searchInPhone,
      'caseSensitive': caseSensitive,
    };
  }

  /// هل البحث فعال
  bool get isActive => query != null && query!.trim().isNotEmpty;

  /// الاستعلام المنظف
  String get cleanQuery => query?.trim().toLowerCase() ?? '';
}

// ================== UTILITY CLASSES ==================

/// نطاق التواريخ
class DateRange {
  final DateTime startDate;
  final DateTime endDate;

  const DateRange({required this.startDate, required this.endDate});

  /// نطاق تاريخ لهذا الشهر
  factory DateRange.thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateRange(startDate: start, endDate: end);
  }

  /// نطاق تاريخ لهذا الأسبوع
  factory DateRange.thisWeek() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
    return DateRange(
      startDate: DateTime(start.year, start.month, start.day),
      endDate: end,
    );
  }

  /// نطاق تاريخ لآخر 30 يوم
  factory DateRange.last30Days() {
    final now = DateTime.now();
    return DateRange(
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
    );
  }

  /// نطاق تاريخ لآخر 7 أيام
  factory DateRange.last7Days() {
    final now = DateTime.now();
    return DateRange(
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory DateRange.fromMap(Map<String, dynamic> map) {
    return DateRange(
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }

  /// مدة النطاق بالأيام
  int get durationInDays => endDate.difference(startDate).inDays;

  /// هل التاريخ ضمن النطاق
  bool contains(DateTime date) {
    return date.isAfter(startDate) && date.isBefore(endDate) ||
        date.isAtSameMomentAs(startDate) ||
        date.isAtSameMomentAs(endDate);
  }

  @override
  String toString() =>
      'DateRange(${startDate.toLocal()} - ${endDate.toLocal()})';
}

/// نطاق المبالغ
class AmountRange {
  final int? minAmount;
  final int? maxAmount;

  const AmountRange({this.minAmount, this.maxAmount});

  /// نطاق للديون المرتفعة
  factory AmountRange.highDebts({int threshold = 1000}) {
    return AmountRange(minAmount: threshold);
  }

  /// نطاق للديون المنخفضة
  factory AmountRange.lowDebts({int threshold = 100}) {
    return AmountRange(maxAmount: threshold);
  }

  /// نطاق للديون المتوسطة
  factory AmountRange.mediumDebts({int min = 100, int max = 1000}) {
    return AmountRange(minAmount: min, maxAmount: max);
  }

  /// نطاق الديون الصفرية
  factory AmountRange.zeroDebts() {
    return const AmountRange(minAmount: 0, maxAmount: 0);
  }

  Map<String, dynamic> toMap() {
    return {'minAmount': minAmount, 'maxAmount': maxAmount};
  }

  factory AmountRange.fromMap(Map<String, dynamic> map) {
    return AmountRange(
      minAmount: map['minAmount'],
      maxAmount: map['maxAmount'],
    );
  }

  /// هل المبلغ ضمن النطاق
  bool contains(int amount) {
    if (minAmount != null && amount < minAmount!) return false;
    if (maxAmount != null && amount > maxAmount!) return false;
    return true;
  }

  /// هل النطاق صحيح
  bool get isValid {
    if (minAmount != null && minAmount! < 0) return false;
    if (maxAmount != null && maxAmount! < 0) return false;
    if (minAmount != null && maxAmount != null && minAmount! > maxAmount!)
      return false;
    return true;
  }

  @override
  String toString() {
    if (minAmount != null && maxAmount != null) {
      return 'AmountRange($minAmount - $maxAmount)';
    } else if (minAmount != null) {
      return 'AmountRange(≥ $minAmount)';
    } else if (maxAmount != null) {
      return 'AmountRange(≤ $maxAmount)';
    }
    return 'AmountRange(unlimited)';
  }
}

// ================== EXTENSION METHODS ==================

/// امتدادات للعميل
extension DebtorExtensions on Debtor {
  /// هل العميل متأخر في الدفع
  bool isOverdue({Duration period = const Duration(days: 30)}) {
    if (currentDebt <= 0) return false;
    if (lastPaymentAt == null) return true;
    return DateTime.now().difference(lastPaymentAt!) > period;
  }

  /// تصنيف العميل حسب مخاطر الدين
  String get riskLevel {
    if (currentDebt == 0) return 'آمن';
    if (currentDebt < 100) return 'منخفض';
    if (currentDebt < 500) return 'متوسط';
    if (currentDebt < 1000) return 'مرتفع';
    return 'خطر عالي';
  }

  /// لون المخاطر
  String get riskColor {
    switch (riskLevel) {
      case 'آمن':
        return 'green';
      case 'منخفض':
        return 'blue';
      case 'متوسط':
        return 'orange';
      case 'مرتفع':
        return 'red';
      case 'خطر عالي':
        return 'darkred';
      default:
        return 'gray';
    }
  }

  /// عدد الأيام منذ آخر دفعة
  int? get daysSinceLastPayment {
    if (lastPaymentAt == null) return null;
    return DateTime.now().difference(lastPaymentAt!).inDays;
  }

  /// تحويل إلى Map مع إضافات
  Map<String, dynamic> toDetailedMap() {
    return {
      ...toMap(),
      'riskLevel': riskLevel,
      'riskColor': riskColor,
      'daysSinceLastPayment': daysSinceLastPayment,
      'paymentRate': paymentRate.toStringAsFixed(1),
      'status': status.name,
    };
  }
}

/// امتدادات للقوائم
extension DebtorListExtensions on List<Debtor> {
  /// فلترة العملاء النشطين
  List<Debtor> get activeOnly => where((d) => d.isActive).toList();

  /// فلترة العملاء الذين لديهم ديون
  List<Debtor> get withDebts => where((d) => d.currentDebt > 0).toList();

  /// العملاء عاليين المخاطر
  List<Debtor> get highRisk => where((d) => d.riskLevel == 'خطر عالي').toList();

  /// إجمالي الديون
  int get totalDebt => fold(0, (sum, debtor) => sum + debtor.currentDebt);

  /// إجمالي المدفوعات
  int get totalPaid => fold(0, (sum, debtor) => sum + debtor.totalPaid);

  /// متوسط الدين
  double get averageDebt => isEmpty ? 0 : totalDebt / length;

  /// ترتيب حسب الدين (تنازلي)
  List<Debtor> get sortedByDebt =>
      [...this]..sort((a, b) => b.currentDebt.compareTo(a.currentDebt));

  /// ترتيب حسب الاسم (تصاعدي)
  List<Debtor> get sortedByName =>
      [...this]..sort((a, b) => a.name.compareTo(b.name));
}
