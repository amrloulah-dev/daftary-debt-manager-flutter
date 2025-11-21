import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
// إصلاح: استخدام المسارات المحلية الصحيحة بدلاً من مسارات package غير الموجودة
import '../models/debtor_model.dart' as DebtorModel;
import '../firestore_services/debtor_services.dart';
import '../models/payment_model.dart';

/*
فهرسة مركبة مقترحة (Composite Indexes) لتحسين الاستعلامات الشائعة:
- debtors: isActive ASC, currentDebt DESC
- debtors: isActive ASC, name ASC (للبحث والترتيب بالاسم)
- debtors: isActive ASC, lastPaymentAt ASC
- debtors: phone ASC, isActive ASC (للبحث بالهاتف)
- debtors: searchKeywords ARRAY_CONTAINS, name ASC (قد يتطلب فهرس)
ملاحظة: راقب أخطاء Firestore التي تقترح إنشاء فهارس تلقائياً.
*/

// إعدادات عامة للأداء/الاعتمادية
const Duration _readTimeout = Duration(seconds: 10);
const Duration _writeTimeout = Duration(seconds: 30);
const List<int> _retryDelaysSeconds = [1, 2, 4, 8];

enum _ErrorCategory {
  network,
  permission,
  validation,
  notFound,
  quota,
  timeout,
  unknown,
}

_ErrorCategory _classifyError(Object e) {
  if (e is FirebaseException) {
    switch (e.code) {
      case 'unavailable':
      case 'network-request-failed':
        return _ErrorCategory.network;
      case 'permission-denied':
        return _ErrorCategory.permission;
      case 'not-found':
        return _ErrorCategory.notFound;
      case 'resource-exhausted':
        return _ErrorCategory.quota;
      case 'deadline-exceeded':
        return _ErrorCategory.timeout;
      default:
        return _ErrorCategory.unknown;
    }
  }
  return _ErrorCategory.unknown;
}

// بسيط: قاطع الدارة (Circuit Breaker) لكل عملية باسم مفتاح
class _CircuitBreaker {
  final int failureThreshold;
  final Duration cooldown;
  int _failures = 0;
  bool _open = false;
  DateTime? _openedAt;

  _CircuitBreaker({
    this.failureThreshold = 4,
    this.cooldown = const Duration(seconds: 20),
  });

  bool get isOpen {
    if (!_open) return false;
    if (_openedAt == null) return true;
    // انتقل إلى نصف-مفتوح بعد فترة التهدئة
    if (DateTime.now().difference(_openedAt!) > cooldown) {
      _open = false;
      _failures = 0;
      return false;
    }
    return true;
  }

  void recordSuccess() {
    _failures = 0;
    _open = false;
    _openedAt = null;
  }

  void recordFailure() {
    _failures++;
    if (_failures >= failureThreshold) {
      _open = true;
      _openedAt = DateTime.now();
    }
  }
}

final Map<String, _CircuitBreaker> _cbRegistry = {};
_CircuitBreaker _getBreaker(String key) =>
    _cbRegistry.putIfAbsent(key, () => _CircuitBreaker());

// تنفيذ إعادة المحاولة مع backoff أسي + jitter
Future<T> _executeWithRetry<T>({
  required String opKey,
  required Future<T> Function() action,
  required Duration timeout,
  int maxAttempts = 4,
}) async {
  final breaker = _getBreaker(opKey);
  if (breaker.isOpen) {
    throw FirebaseException(
      plugin: 'firestore',
      code: 'unavailable',
      message: 'Circuit breaker open for $opKey',
    );
  }

  int attempt = 0;
  while (true) {
    try {
      final result = await action().timeout(timeout);
      breaker.recordSuccess();
      return result;
    } catch (e) {
      attempt++;
      breaker.recordFailure();
      if (attempt >= maxAttempts) rethrow;
      final base =
      _retryDelaysSeconds[math.min(
        attempt - 1,
        _retryDelaysSeconds.length - 1,
      )];
      final jitterMs = math.Random().nextInt(250);
      await Future.delayed(Duration(seconds: base, milliseconds: jitterMs));
    }
  }
}

// LRU بسيط داخل الذاكرة للمزود (مكمل للـ EnhancedCacheManager)
class _InMemoryLruCache<K, V> {
  final int capacity;
  final _map = <K, V>{};
  final _queue = <K>[]; // يحفظ الترتيب حسب الاستخدام
  _InMemoryLruCache(this.capacity);

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    _queue.remove(key);
    _queue.add(key);
    return _map[key];
  }

  void set(K key, V value) {
    if (_map.containsKey(key)) {
      _queue.remove(key);
    } else if (_map.length >= capacity && _queue.isNotEmpty) {
      final oldest = _queue.removeAt(0);
      _map.remove(oldest);
    }
    _map[key] = value;
    _queue.add(key);
  }

  void clear() {
    _map.clear();
    _queue.clear();
  }
}

// طبقة Cache متعددة المستويات: ذاكرة ثم Cache محسن ثم الشبكة
class _MultiLevelCache {
  static final _InMemoryLruCache<String, Object> _memory = _InMemoryLruCache(
    200,
  );

  static T? getMemory<T>(String key) {
    final v = _memory.get(key);
    if (v is T) return v;
    return null;
  }

  static void setMemory(String key, Object value) {
    _memory.set(key, value);
  }

  // المستوى الثاني: EnhancedCacheManager
  static Map<String, dynamic>? getStats(String key) {
    try {
      return EnhancedCacheManager.getStats(key);
    } catch (_) {
      return null;
    }
  }

  static void setStats(String key, Map<String, dynamic> value) {
    try {
      EnhancedCacheManager.cacheStats(key, value);
    } catch (_) {}
  }
}

// مفاتيح ذكية: FNV-1a 32-bit
String _fnv1aHash(String input) {
  const int fnvPrime = 0x01000193;
  int hash = 0x811C9DC5;
  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

// Cache warming: تحميل بيانات متوقعة الاستخدام مسبقاً
Future<void> warmDebtorCaches() async {
  try {
    final provider = DebtorProvider();
    // إحصائيات عامة + أول صفحة مدينين + أفضل 10
    unawaited(provider.getGeneralStatistics());
    unawaited(provider.getDebtorsPaginated(pageSize: 20));
    unawaited(provider.getTop10Debtors());
  } catch (_) {}
}



// تحسين: Cache بسيط لإحصائيات عامة مع مدة صلاحية لتقليل قراءات Firestore المكلفة
class _DebtorStatsCache {
  static GeneralStatistics? _general;
  static DateTime? _expiresAt;
  static const Duration _ttl = Duration(minutes: 5);

  static GeneralStatistics? getValid() {
    if (_general == null || _expiresAt == null) return null;
    if (DateTime.now().isAfter(_expiresAt!)) return null;
    return _general;
  }

  static void set(GeneralStatistics stats) {
    _general = stats;
    _expiresAt = DateTime.now().add(_ttl);
  }

// ملاحظة: وظيفة المسح غير مستخدمة حالياً ويمكن إعادة تفعيلها عند الحاجة
}

/// Provider للتعامل مع العملاء (Debtors) - العمليات الأساسية والبحث والإحصائيات
class DebtorProvider {
  final CollectionReference debtorsCollection = FirebaseFirestore.instance
      .collection("debtors");

  // ---------- Helpers (DRY) ----------
  /// يولّد keywords للبحث (محفوظ كما عندك). يحافظ على التفريغ والصغيرة.
  List<String> _generateSearchKeywords(String name) {
    final keywords = <String>[];
    final cleanName = name.trim().toLowerCase();
    if (cleanName.isEmpty) return keywords;
    keywords.add(cleanName);
    final words = cleanName.split(RegExp(r'\s+'));
    keywords.addAll(words);
    for (String word in words) {
      for (int i = 1; i <= word.length; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    return keywords.toSet().toList();
  }

  /// يحول SortBy الى حقل في الـ Firestore
  String _getSortField(DebtorModel.SortBy sortBy) {
    switch (sortBy) {
      case DebtorModel.SortBy.name:
        return 'name';
      case DebtorModel.SortBy.debt:
        return 'currentDebt';
      case DebtorModel.SortBy.lastPayment:
        return 'lastPaymentAt';
      case DebtorModel.SortBy.createdDate:
        return 'createdAt';
    }
  }

  

  // ---------- ADD DEBTOR ----------
  /// نتحقق من صحة البيانات ونتجنب race condition بمحاولة التحقق داخل transaction إذا أمكن.
  Future<String?> addDebtor({
    required String name,
    required String phone,
    required int totalBorrowed,
    required int totalPaid,
    String? email,
    String? notes,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final nameError = DebtorsDataValidator.validateName(name);
      if (nameError != null) throw Exception(nameError);
      final phoneError = DebtorsDataValidator.validatePhone(phone);
      if (phoneError != null) throw Exception(phoneError);
      final borrowedError = DebtorsDataValidator.validateAmount(totalBorrowed);
      if (borrowedError != null) throw Exception(borrowedError);
      final paidError = DebtorsDataValidator.validateAmount(totalPaid);
      if (paidError != null) throw Exception(paidError);
      if (totalPaid > totalBorrowed)
        throw Exception(
          'المبلغ المدفوع لا يمكن أن يكون أكبر من المبلغ المطلوب',
        );

      final String cleanPhone = phone.trim();
      final int currentDebt = totalBorrowed - totalPaid;
      final searchKeywords = _generateSearchKeywords(name);
      final newDocRef = debtorsCollection.doc();

      await _executeWithRetry(
        opKey: 'ADD_DEBTOR',
        timeout: _writeTimeout,
        action:
            () => FirebaseFirestore.instance.runTransaction((tx) async {
          if (cleanPhone.isNotEmpty) {
            final phoneClaimRef = FirebaseFirestore.instance
                .collection('debtor_phones')
                .doc(cleanPhone);
            final existingClaim = await tx.get(phoneClaimRef);
            if (existingClaim.exists) {
              throw Exception('رقم الهاتف موجود مسبقاً');
            }
            tx.set(phoneClaimRef, {
              'debtorId': newDocRef.id,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          tx.set(newDocRef, {
            'name': name.trim(),
            'phone': cleanPhone,
            'email': email,
            'notes': notes,
            'totalBorrowed': totalBorrowed,
            'totalPaid': totalPaid,
            'currentDebt': currentDebt,
            'searchKeywords': searchKeywords,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'lastPaymentAt': null,
            'totalTransactions': 0,
          });
        }),
      );

      stopwatch.stop();
      DebtorsFirestoreLogger.logPerformance("ADD_DEBTOR", stopwatch.elapsed);
      DebtorsFirestoreLogger.logOperation(
        "ADD_DEBTOR",
        "Successfully added: ${name.trim()}",
      );
      return newDocRef.id;
    } catch (e) {
      stopwatch.stop();
      // توحيد معالجة الأخطاء وفق المتاح في FirestoreErrorHandler
      DebtorsFirestoreLogger.logOperation("ADD_DEBTOR", "Error: $e", isError: true);
      return null;
    }
  }

  // ---------- UPDATE DEBTOR INFO ----------
  Future<void> updateDebtorInfo({
    required String debtorId,
    String? name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null && name.trim().isNotEmpty) {
        final nameError = DebtorsDataValidator.validateName(name);
        if (nameError != null) throw Exception(nameError);
        updates['name'] = name.trim();
        updates['searchKeywords'] = _generateSearchKeywords(name);
      }
      if (phone != null) {
        final phoneTrimmed = phone.trim();
        if (phoneTrimmed.isNotEmpty) {
          final phoneError = DebtorsDataValidator.validatePhone(phone);
          if (phoneError != null) throw Exception(phoneError);

          // تحقق من عدم وجود الهاتف لعميل آخر
          final existing = await debtorsCollection
              .where('phone', isEqualTo: phoneTrimmed)
              .limit(1)
              .get();
          if (existing.docs.isNotEmpty && existing.docs.first.id != debtorId) {
            throw Exception('رقم الهاتف موجود لعميل آخر');
          }
        }
        updates['phone'] = phoneTrimmed;
      }
      if (email != null) {
        updates['email'] = email;
      }
      if (notes != null) {
        updates['notes'] = notes;
      }
      if (updates.isEmpty) throw Exception('لم يتم تحديد أي بيانات للتحديث');
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await debtorsCollection.doc(debtorId).update(updates);
      // مسح كاش العميل إن توفر مدير كاش محسن
      try {
        EnhancedCacheManager.clearDebtorCache(debtorId);
      } catch (_) {}
      DebtorsFirestoreLogger.logOperation(
        "UPDATE_DEBTOR_INFO",
        "Successfully updated debtor: $debtorId",
      );
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "UPDATE_DEBTOR_INFO",
        "Error: $e",
        isError: true,
      );
      rethrow;
    }
  }

  // ---------- DELETE DEBTOR (with batched pagination for child collections) ----------
  /// حذف العميل مع كل الديون والمدفوعات بشكل آمن (Batch delete مع pagination)
  Future<void> deleteDebtor(String debtorId) async {
    final debtorRef = debtorsCollection.doc(debtorId);
    try {
      // خطوة: تأكد أن المستند موجود
      final snapshot = await debtorRef.get();
      if (!snapshot.exists) throw Exception('العميل غير موجود');

      // حذف المجموعات الفرعية بطريقة batch وبحجم معقول (لتجنب تجاوز حدود transaction)
      // دالة داخلية تساعد على حذف كل الدوكس من مجموعة محددة بالصفحات
      Future<void> _deleteCollectionPaginated(
          CollectionReference coll, {
            int batchSize = 500,
          }) async {
        while (true) {
          final snap = await coll.limit(batchSize).get();
          if (snap.docs.isEmpty) break;
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // أولاً حذف الديون والمدفوعات (قد تكون كبيرة)
      await _deleteCollectionPaginated(debtorRef.collection('debts'));
      await _deleteCollectionPaginated(debtorRef.collection('payments'));

      // ثم حذف المستند الرئيسي
      await debtorRef.delete();
      try {
        EnhancedCacheManager.clearDebtorCache(debtorId);
      } catch (_) {}

      DebtorsFirestoreLogger.logOperation(
        "DELETE_DEBTOR",
        "Successfully deleted debtor with all related data: $debtorId",
      );
    } catch (e) {
      DebtorsFirestoreLogger.logOperation("DELETE_DEBTOR", "Error: $e", isError: true);
      rethrow;
    }
  }

  // ---------- FETCH / SEARCH ----------
  Future<List<DebtorModel.Debtor>> fetchDebtorMainData() async {
    final stopwatch = Stopwatch()..start();
    try {
      // Cache memory level + retry + timeout
      final cacheKey = 'main_${_fnv1aHash('active:true|order:debt_desc')}';
      final mem = _MultiLevelCache.getMemory<List<DebtorModel.Debtor>>(
        cacheKey,
      );
      if (mem != null) {
        stopwatch.stop();
        return mem;
      }
      final snapshot = await _executeWithRetry(
        opKey: 'FETCH_DEBTOR_MAIN_DATA',
        timeout: _readTimeout,
        action:
            () =>
            debtorsCollection
                .where('isActive', isEqualTo: true)
                .orderBy('currentDebt', descending: true)
                .get(),
      );
      final result =
      snapshot.docs
          .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
          .toList();
      _MultiLevelCache.setMemory(cacheKey, result);
      stopwatch.stop();
      DebtorsFirestoreLogger.logPerformance(
        "FETCH_DEBTOR_MAIN_DATA",
        stopwatch.elapsed,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      DebtorsFirestoreLogger.logOperation(
        "FETCH_DEBTOR_MAIN_DATA",
        "Error: $e",
        isError: true,
      );
      return [];
    }
  }

  Future<List<DebtorModel.Debtor>> searchDebtorsByName(String query) async {
    try {
      if (query.trim().isEmpty) return await fetchDebtorMainData();
      final searchQuery = query.trim().toLowerCase();
      final cacheKey = 'search_${_fnv1aHash(searchQuery)}';
      final mem = _MultiLevelCache.getMemory<List<DebtorModel.Debtor>>(
        cacheKey,
      );
      if (mem != null) return mem;
      final snapshot = await _executeWithRetry(
        opKey: 'SEARCH_DEBTORS_BY_NAME',
        timeout: _readTimeout,
        action:
            () =>
            debtorsCollection
                .where('searchKeywords', arrayContains: searchQuery)
                .where('isActive', isEqualTo: true)
                .orderBy('name')
                .get(),
      );
      return snapshot.docs
          .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
          .toList();
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "SEARCH_DEBTORS_BY_NAME",
        "Error: $e",
        isError: true,
      );
      return [];
    }
  }

  Future<DebtorModel.Debtor?> searchDebtorByPhone(String phone) async {
    try {
      final cleanPhone = phone.trim();
      final snapshot = await _executeWithRetry(
        opKey: 'SEARCH_DEBTOR_BY_PHONE',
        timeout: _readTimeout,
        action:
            () =>
            debtorsCollection
                .where('phone', isEqualTo: cleanPhone)
                .where('isActive', isEqualTo: true)
                .limit(1)
                .get(),
      );
      if (snapshot.docs.isEmpty) return null;
      return DebtorModel.Debtor.fromFirestore(snapshot.docs.first);
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "SEARCH_DEBTOR_BY_PHONE",
        "Error: $e",
        isError: true,
      );
      return null;
    }
  }

  // ---------- FILTERING & PAGINATION ----------
  Future<List<DebtorModel.Debtor>> getDebtorsByDebtRange({
    int? minDebt,
    int? maxDebt,
    int limit = 50,
  }) async {
    try {
      Query query = debtorsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('currentDebt', descending: true);
      if (minDebt != null)
        query = query.where('currentDebt', isGreaterThanOrEqualTo: minDebt);
      if (maxDebt != null)
        query = query.where('currentDebt', isLessThanOrEqualTo: maxDebt);
      final snapshot = await _executeWithRetry(
        opKey: 'GET_DEBTORS_BY_DEBT_RANGE',
        timeout: _readTimeout,
        action: () => query.limit(limit).get(),
      );
      return snapshot.docs
          .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
          .toList();
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_DEBTORS_BY_DEBT_RANGE",
        "Error: $e",
        isError: true,
      );
      return [];
    }
  }

  Stream<List<DebtorModel.Debtor>> getDebtorsStream({
    String? searchQuery,
    DebtorModel.SortBy sortBy = DebtorModel.SortBy.debt,
    DebtorModel.SortOrder sortOrder = DebtorModel.SortOrder.descending,
    bool activeOnly = true,
  }) {
    Query query = debtorsCollection;
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: searchQuery.trim().toLowerCase(),
      );
    }
    final orderByField = _getSortField(sortBy);
    final descending = sortOrder == DebtorModel.SortOrder.descending;
    query = query.orderBy(orderByField, descending: descending);

    return query.snapshots().map((snapshot) {
      try {
        return snapshot.docs
            .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
            .toList();
      } catch (e) {
        DebtorsFirestoreLogger.logOperation(
          "DebtorsStreamMap",
          "Error mapping debtors stream: $e",
          isError: true,
        );
        return [];
      }
    });
  }

  Future<PaginatedResult<DebtorModel.Debtor>> getDebtorsPaginated({
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
    String? searchQuery,
    DebtorModel.SortBy sortBy = DebtorModel.SortBy.debt,
    DebtorModel.SortOrder sortOrder = DebtorModel.SortOrder.descending,
    bool activeOnly = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      Query query = debtorsCollection;
      if (activeOnly) query = query.where('isActive', isEqualTo: true);
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        query = query.where(
          'searchKeywords',
          arrayContains: searchQuery.trim().toLowerCase(),
        );
      }
      final orderByField = _getSortField(sortBy);
      final descending = sortOrder == DebtorModel.SortOrder.descending;
      query = query.orderBy(orderByField, descending: descending);
      if (lastDocument != null) query = query.startAfterDocument(lastDocument);
      query = query.limit(pageSize);

      final snapshot = await _executeWithRetry(
        opKey: 'GET_DEBTORS_PAGINATED',
        timeout: _readTimeout,
        action: () => query.get(),
      );
      final items =
      snapshot.docs
          .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
          .toList();

      stopwatch.stop();
      DebtorsFirestoreLogger.logPerformance(
        "GET_DEBTORS_PAGINATED",
        stopwatch.elapsed,
      );
      return PaginatedResult<DebtorModel.Debtor>(
        items: items,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
        currentPage: items.length,
      );
    } catch (e) {
      stopwatch.stop();
      DebtorsFirestoreLogger.logOperation(
        "GET_DEBTORS_PAGINATED",
        "Error: $e",
        isError: true,
      );
      return PaginatedResult<DebtorModel.Debtor>(
        items: [],
        lastDocument: null,
        hasMore: false,
        currentPage: 0,
      );
    }
  }

  // ---------- STATISTICS ----------
  Stream<GeneralStatistics> getGeneralStatisticsStream() {
    return debtorsCollection.snapshots().map((snapshot) {
      int totalDebtors = 0;
      int activeDebtors = 0;
      int totalBorrowed = 0;
      int totalPaid = 0;
      int totalCurrentDebt = 0;
      int zeroDebtDebtors = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalDebtors++;
        final isActive = data['isActive'] as bool? ?? true;
        if (isActive) activeDebtors++;
        final borrowed = (data['totalBorrowed'] as num?)?.toInt() ?? 0;
        final paid = (data['totalPaid'] as num?)?.toInt() ?? 0;
        final currentDebt = (data['currentDebt'] as num?)?.toInt() ?? 0;
        totalBorrowed += borrowed;
        totalPaid += paid;
        totalCurrentDebt += currentDebt;
        if (currentDebt == 0) zeroDebtDebtors++;
      }

      final stats = GeneralStatistics(
        totalDebtors: totalDebtors,
        activeDebtors: activeDebtors,
        inactiveDebtors: totalDebtors - activeDebtors,
        totalBorrowed: totalBorrowed,
        totalPaid: totalPaid,
        totalCurrentDebt: totalCurrentDebt,
        zeroDebtDebtors: zeroDebtDebtors,
        debtorsWithDebt: totalDebtors - zeroDebtDebtors,
        averageDebt:
        totalDebtors > 0 ? (totalCurrentDebt / totalDebtors).round() : 0,
        paymentRate:
        totalBorrowed > 0 ? ((totalPaid / totalBorrowed) * 100).round() : 0,
      );
      _DebtorStatsCache.set(stats); // Still update cache for other potential uses
      return stats;
    });
  }

  Future<GeneralStatistics> getGeneralStatistics() async {
    try {
      // تحسين: إرجاع من الكاش إن كان صالحاً
      final cached = _DebtorStatsCache.getValid();
      if (cached != null) return cached;

      // ملاحظة: هذه الدالة تعمل get() لكل الوثائق — مناسب للمجموعات الصغيرة.
      // لو الداتا كبيرة: الأفضل عمل doc منفصل للكاش وتحديثه عند كل تغيير.
      final snapshot = await _executeWithRetry(
        opKey: 'GET_GENERAL_STATISTICS',
        timeout: _readTimeout,
        action: () => debtorsCollection.get(),
      );
      int totalDebtors = 0;
      int activeDebtors = 0;
      int totalBorrowed = 0;
      int totalPaid = 0;
      int totalCurrentDebt = 0;
      int zeroDebtDebtors = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalDebtors++;
        final isActive = data['isActive'] as bool? ?? true;
        if (isActive) activeDebtors++;
        final borrowed = (data['totalBorrowed'] as num?)?.toInt() ?? 0;
        final paid = (data['totalPaid'] as num?)?.toInt() ?? 0;
        final currentDebt = (data['currentDebt'] as num?)?.toInt() ?? 0;
        totalBorrowed += borrowed;
        totalPaid += paid;
        totalCurrentDebt += currentDebt;
        if (currentDebt == 0) zeroDebtDebtors++;
      }

      final stats = GeneralStatistics(
        totalDebtors: totalDebtors,
        activeDebtors: activeDebtors,
        inactiveDebtors: totalDebtors - activeDebtors,
        totalBorrowed: totalBorrowed,
        totalPaid: totalPaid,
        totalCurrentDebt: totalCurrentDebt,
        zeroDebtDebtors: zeroDebtDebtors,
        debtorsWithDebt: totalDebtors - zeroDebtDebtors,
        averageDebt:
        totalDebtors > 0 ? (totalCurrentDebt / totalDebtors).round() : 0,
        paymentRate:
        totalBorrowed > 0 ? ((totalPaid / totalBorrowed) * 100).round() : 0,
      );
      _DebtorStatsCache.set(stats);
      return stats;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_GENERAL_STATISTICS",
        "Error: $e",
        isError: true,
      );
      return GeneralStatistics(
        totalDebtors: 0,
        activeDebtors: 0,
        inactiveDebtors: 0,
        totalBorrowed: 0,
        totalPaid: 0,
        totalCurrentDebt: 0,
        zeroDebtDebtors: 0,
        debtorsWithDebt: 0,
        averageDebt: 0,
        paymentRate: 0,
      );
    }
  }

  Future<List<DebtorModel.Debtor>> getTop10Debtors() async {
    try {
      final snapshot = await _executeWithRetry(
        opKey: 'GET_TOP_10_DEBTORS',
        timeout: _readTimeout,
        action:
            () =>
            debtorsCollection
                .where('isActive', isEqualTo: true)
                .orderBy('currentDebt', descending: true)
                .limit(20)
                .get(),
      );
      final list =
      snapshot.docs
          .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
          .where((d) => d.currentDebt > 0)
          .take(10)
          .toList();
      return list;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_TOP_10_DEBTORS",
        "Error: $e",
        isError: true,
      );
      return [];
    }
  }

  Future<DebtorModel.DebtorDetailedStatistics> getDebtorDetailedStats(
      String debtorId,
      ) async {
    try {
      final debtorDoc = await debtorsCollection.doc(debtorId).get();
      if (!debtorDoc.exists) throw Exception('العميل غير موجود');
      final debtor = DebtorModel.Debtor.fromFirestore(debtorDoc);

      // تحسين: عد تجميعي + استعلامات محدودة لأول/آخر بدلاً من جلب كامل المجموعات
      int totalDebtsCount = 0;
      int totalPaymentsCount = 0;
      try {
        final c = await debtorDoc.reference.collection('debts').count().get();
        totalDebtsCount = c.count ?? 0;
      } catch (_) {
        final snap = await debtorDoc.reference.collection('debts').get();
        totalDebtsCount = snap.docs.length;
      }
      try {
        final c =
        await debtorDoc.reference.collection('payments').count().get();
        totalPaymentsCount = c.count ?? 0;
      } catch (_) {
        final snap = await debtorDoc.reference.collection('payments').get();
        totalPaymentsCount = snap.docs.length;
      }

      DateTime? firstDebt, lastDebt, firstPayment, lastPayment;
      final debtsAsc =
      await debtorDoc.reference
          .collection('debts')
          .orderBy('createdAt')
          .limit(1)
          .get();
      if (debtsAsc.docs.isNotEmpty) {
        final ts = (debtsAsc.docs.first.data())['createdAt'] as Timestamp?;
        firstDebt = ts?.toDate();
      }
      final debtsDesc =
      await debtorDoc.reference
          .collection('debts')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (debtsDesc.docs.isNotEmpty) {
        final ts = (debtsDesc.docs.first.data())['createdAt'] as Timestamp?;
        lastDebt = ts?.toDate();
      }

      final paymentsAsc =
      await debtorDoc.reference
          .collection('payments')
          .orderBy('createdAt')
          .limit(1)
          .get();
      if (paymentsAsc.docs.isNotEmpty) {
        final ts = (paymentsAsc.docs.first.data())['createdAt'] as Timestamp?;
        firstPayment = ts?.toDate();
      }
      final paymentsDesc =
      await debtorDoc.reference
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (paymentsDesc.docs.isNotEmpty) {
        final ts = (paymentsDesc.docs.first.data())['createdAt'] as Timestamp?;
        lastPayment = ts?.toDate();
      }

      final totalBorrowed = debtor.totalBorrowed;
      final totalPaid = debtor.totalPaid;
      final averageDebtAmount =
      totalDebtsCount > 0 ? (totalBorrowed / totalDebtsCount).round() : 0;
      final averagePaymentAmount =
      totalPaymentsCount > 0 ? (totalPaid / totalPaymentsCount).round() : 0;
      final paymentRate =
      totalBorrowed > 0 ? ((totalPaid / totalBorrowed) * 100).round() : 0;

      return DebtorModel.DebtorDetailedStatistics(
        debtor: debtor,
        totals: DebtorModel.DebtorTotals(
          totalBorrowed: totalBorrowed,
          totalPaid: totalPaid,
          totalDebtsCount: totalDebtsCount,
          totalPaymentsCount: totalPaymentsCount,
        ),
        averages: DebtorModel.DebtorAverages(
          averageDebtAmount: averageDebtAmount,
          averagePaymentAmount: averagePaymentAmount,
        ),
        rates: DebtorModel.DebtorRates(paymentRate: paymentRate),
        dates: DebtorModel.DebtorDates(
          firstDebt: firstDebt,
          lastDebt: lastDebt,
          firstPayment: firstPayment,
          lastPayment: lastPayment,
        ),
        patterns: DebtorModel.DebtorPatterns(
          daysSinceLastPayment:
          lastPayment != null
              ? DateTime.now().difference(lastPayment).inDays
              : null,
        ),
      );
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_DEBTOR_DETAILED_STATS",
        "Error: $e",
        isError: true,
      );
      return DebtorModel.DebtorDetailedStatistics(
        debtor: DebtorModel.Debtor(
          id: debtorId,
          name: '',
          phone: '',
          totalBorrowed: 0,
          totalPaid: 0,
          currentDebt: 0,
          searchKeywords: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        totals: DebtorModel.DebtorTotals(
          totalBorrowed: 0,
          totalPaid: 0,
          totalDebtsCount: 0,
          totalPaymentsCount: 0,
        ),
        averages: DebtorModel.DebtorAverages(
          averageDebtAmount: 0,
          averagePaymentAmount: 0,
        ),
        rates: DebtorModel.DebtorRates(paymentRate: 0),
        dates: DebtorModel.DebtorDates(),
        patterns: DebtorModel.DebtorPatterns(),
      );
    }
  }

  // ---------- BATCH / MULTI UPDATES ----------
  Future<bool> updateMultipleDebtors(List<Map<String, dynamic>> updates) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final update in updates) {
        final debtorId = update['id'] as String;
        final debtorRef = debtorsCollection.doc(debtorId);
        final updateData = Map<String, dynamic>.from(update);
        updateData.remove('id');
        updateData['updatedAt'] = FieldValue.serverTimestamp();
        batch.update(debtorRef, updateData);
        try {
          EnhancedCacheManager.clearDebtorCache(debtorId);
        } catch (_) {}
      }
      await batch.commit();
      DebtorsFirestoreLogger.logOperation(
        "UPDATE_MULTIPLE_DEBTORS",
        "Successfully updated ${updates.length} debtors",
      );
      return true;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "UPDATE_MULTIPLE_DEBTORS",
        "Error: $e",
        isError: true,
      );
      return false;
    }
  }

  // ---------- QUICK FILTERS ----------
  Future<List<DebtorModel.Debtor>> getHighDebtors({
    int threshold = 1000,
  }) async {
    return getDebtorsByDebtRange(minDebt: threshold);
  }

  Future<List<DebtorModel.Debtor>> getLowDebtors({int threshold = 100}) async {
    return getDebtorsByDebtRange(maxDebt: threshold);
  }

  Future<List<DebtorModel.Debtor>> getZeroDebtors() async {
    return getDebtorsByDebtRange(minDebt: 0, maxDebt: 0);
  }

  Future<List<DebtorModel.Debtor>> getInactiveDebtors({
    Duration inactivePeriod = const Duration(days: 30),
    int limit = 20,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(inactivePeriod);
      // إصلاح: إزالة نطاقين على حقول مختلفة. فلتر currentDebt يتم على جهة العميل.
      final snapshot = await _executeWithRetry(
        opKey: 'GET_INACTIVE_DEBTORS',
        timeout: _readTimeout,
        action:
            () =>
            debtorsCollection
                .where('isActive', isEqualTo: true)
                .where(
              'lastPaymentAt',
              isLessThan: Timestamp.fromDate(cutoffDate),
            )
                .orderBy('lastPaymentAt')
                .limit(limit * 3)
                .get(),
      );
      final items =
      snapshot.docs
          .map((doc) => DebtorModel.Debtor.fromFirestore(doc))
          .where((d) => d.currentDebt > 0)
          .take(limit)
          .toList();
      return items;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_INACTIVE_DEBTORS",
        "Error: $e",
        isError: true,
      );
      return [];
    }
  }

  // ---------- RECALCULATE TOTALS ----------
  Future<bool> recalculateDebtorTotals(String debtorId) async {
    try {
      final debtorRef = debtorsCollection.doc(debtorId);
      // تحسين: تجنّب الاستعلام داخل Transaction، اقرأ ثم حدّث مرة واحدة + مهلات + إعادة محاولة
      final debtsSnapshot = await _executeWithRetry(
        opKey: 'RECALC_DEBTS',
        timeout: _readTimeout,
        action: () => debtorRef.collection('debts').get(),
      );
      int totalBorrowed = 0;
      for (final doc in debtsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalBorrowed += (data['total'] as num?)?.toInt() ?? 0;
      }

      final paymentsSnapshot = await _executeWithRetry(
        opKey: 'RECALC_PAYMENTS',
        timeout: _readTimeout,
        action: () => debtorRef.collection('payments').get(),
      );
      int totalPaid = 0;
      DateTime? lastPayment;
      for (final doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalPaid += (data['amount'] as num?)?.toInt() ?? 0;
        final ts = data['createdAt'] as Timestamp?;
        final dt = ts?.toDate();
        if (dt != null && (lastPayment == null || dt.isAfter(lastPayment))) {
          lastPayment = dt;
        }
      }

      await _executeWithRetry(
        opKey: 'RECALC_UPDATE',
        timeout: _writeTimeout,
        action:
            () => debtorRef.update({
          'totalBorrowed': totalBorrowed,
          'totalPaid': totalPaid,
          'currentDebt': totalBorrowed - totalPaid,
          'lastPaymentAt':
          lastPayment != null ? Timestamp.fromDate(lastPayment) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
      try {
        EnhancedCacheManager.clearDebtorCache(debtorId);
      } catch (_) {}
      DebtorsFirestoreLogger.logOperation(
        "RECALCULATE_DEBTOR_TOTALS",
        "Successfully recalculated totals for: $debtorId",
      );
      return true;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "RECALCULATE_DEBTOR_TOTALS",
        "Error: $e",
        isError: true,
      );
      return false;
    }
  }

  // ---------- CLEANUP & REINDEX ----------
  Future<bool> cleanupAndReindex() async {
    try {
      final snapshot = await debtorsCollection.get();
      var batch = FirebaseFirestore.instance.batch();
      int updatedCount = 0;
      int ops = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          final searchKeywords = _generateSearchKeywords(name);
          final currentKeywords =
          (data['searchKeywords'] as List<dynamic>?)?.cast<String>();
          if (currentKeywords == null ||
              currentKeywords.toSet() != searchKeywords.toSet()) {
            batch.update(doc.reference, {
              'searchKeywords': searchKeywords,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            updatedCount++;
            ops++;
            // تحسين: نفّذ commit كل 300 عملية ثم أعد إنشاء batch جديد
            if (ops >= 300) {
              await batch.commit();
              batch = FirebaseFirestore.instance.batch();
              ops = 0;
            }
          }
        }
      }

      // commit any remaining operations
      if (ops > 0) {
        await batch.commit();
      }
      try {
        EnhancedCacheManager.clearAllCaches();
      } catch (_) {}
      DebtorsFirestoreLogger.logOperation(
        "CLEANUP_AND_REINDEX",
        "Successfully updated $updatedCount documents",
      );
      return true;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "CLEANUP_AND_REINDEX",
        "Error: $e",
        isError: true,
      );
      return false;
    }
  }

  // ---------- COMPATIBILITY / ALIASES ----------
  Future<String?> addDebtorWithValidation({
    required String name,
    required String phone,
    required int totalBorrowed,
    required int totalPaid,
  }) async {
    return await addDebtor(
      name: name,
      phone: phone,
      totalBorrowed: totalBorrowed,
      totalPaid: totalPaid,
    );
  }

  Future<DebtorModel.Debtor?> getDebtorById(String debtorId) async {
    try {
      final doc = await debtorsCollection.doc(debtorId).get();
      if (doc.exists) {
        return DebtorModel.Debtor.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_DEBTOR_BY_ID",
        "Error: $e",
        isError: true,
      );
      return null;
    }
  }
}
