import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
// استيراد الكلاسات المشتركة من ملف debtor.dart
// ignore: unused_import
import 'debtor_services.dart';

// ================== الكلاسات المساعدة المفقودة ==================

/// كلاس للتحقق من صحة البيانات
class DebtsDataValidator {
  /// التحقق من صحة قائمة الأصناف
  static String? validateItems(List<Map<String, dynamic>>? items) {
    if (items == null || items.isEmpty) {
      return 'قائمة الأصناف فارغة';
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      // التحقق من وجود الحقول المطلوبة
      if (item['name'] == null || item['name'].toString().trim().isEmpty) {
        return 'اسم الصنف مطلوب في العنصر رقم ${i + 1}';
      }

      if (item['quantity'] == null || item['quantity'] <= 0) {
        return 'كمية صحيحة مطلوبة في العنصر رقم ${i + 1}';
      }

      if (item['price'] == null || item['price'] <= 0) {
        return 'سعر صحيح مطلوب في العنصر رقم ${i + 1}';
      }
    }

    return null;
  }

  /// التحقق من صحة المبلغ
  static String? validateAmount(int? amount) {
    if (amount == null || amount <= 0) {
      return 'المبلغ يجب أن يكون أكبر من صفر';
    }

    if (amount > 1000000000) {
      return 'المبلغ كبير جداً';
    }

    return null;
  }

  /// التحقق من صحة معرف العميل
  static String? validateDebtorId(String? debtorId) {
    if (debtorId == null || debtorId.trim().isEmpty) {
      return 'معرف العميل مطلوب';
    }

    return null;
  }
}

/// كلاس لإدارة الcache
class DebtsDebtorCache {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTTL = Duration(minutes: 5);

  /// الحصول على بيانات العميل من الcache
  static Future<Map<String, dynamic>?> getDebtorWithCache(
      String debtorId,
      ) async {
    final now = DateTime.now();
    final timestamp = _cacheTimestamps[debtorId];

    // التحقق من صلاحية الcache
    if (timestamp != null && now.difference(timestamp) < _cacheTTL) {
      return _cache[debtorId];
    }

    // جلب البيانات من Firestore
    try {
      final doc =
      await FirebaseFirestore.instance
          .collection('debtors')
          .doc(debtorId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // حفظ في الcache
        _cache[debtorId] = data;
        _cacheTimestamps[debtorId] = now;

        return data;
      }
    } catch (e) {
      // Error fetching debtor, return null
    }

    return null;
  }

  /// مسح الcache لعميل معين
  static void clearDebtorCache(String debtorId) {
    _cache.remove(debtorId);
    _cacheTimestamps.remove(debtorId);
  }

  /// مسح جميع الcache
  static void clearAllCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// تنظيف الcache المنتهي الصلاحية
  static void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) >= _cacheTTL) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }
}

/// كلاس للتعامل مع أخطاء Firestore
class DebtsFirestoreErrorHandler {
  /// الحصول على رسالة خطأ مفهومة
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'خطأ غير معروف';

    final errorMessage = error.toString().toLowerCase();

    // أخطاء الشبكة
    if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return 'خطأ في الاتصال، تأكد من الإنترنت';
    }

    // أخطاء الصلاحيات
    if (errorMessage.contains('permission') ||
        errorMessage.contains('denied')) {
      return 'ليس لديك صلاحية للوصول لهذه البيانات';
    }

    // أخطاء البيانات غير الموجودة
    if (errorMessage.contains('not found') ||
        errorMessage.contains('no document')) {
      return 'البيانات المطلوبة غير موجودة';
    }

    // أخطاء التحقق من البيانات
    if (errorMessage.contains('invalid') ||
        errorMessage.contains('validation')) {
      return 'البيانات المدخلة غير صحيحة';
    }

    // أخطاء الحد الأقصى للعمليات
    if (errorMessage.contains('quota') || errorMessage.contains('limit')) {
      return 'تم تجاوز الحد المسموح به، حاول لاحقاً';
    }

    // أخطاء المعاملات
    if (errorMessage.contains('transaction') ||
        errorMessage.contains('conflict')) {
      return 'حدث تضارب في البيانات، حاول مرة أخرى';
    }

    // إرجاع رسالة الخطأ كما هي إذا لم تطابق أي نمط
    return error.toString();
  }

  /// التحقق من نوع الخطأ
  static ErrorType getErrorType(dynamic error) {
    if (error == null) return ErrorType.unknown;

    final errorMessage = error.toString().toLowerCase();

    if (errorMessage.contains('network') ||
        errorMessage.contains('connection')) {
      return ErrorType.network;
    }

    if (errorMessage.contains('permission') ||
        errorMessage.contains('denied')) {
      return ErrorType.permission;
    }

    if (errorMessage.contains('not found')) {
      return ErrorType.notFound;
    }

    if (errorMessage.contains('invalid') ||
        errorMessage.contains('validation')) {
      return ErrorType.validation;
    }

    if (errorMessage.contains('quota') || errorMessage.contains('limit')) {
      return ErrorType.quota;
    }

    if (errorMessage.contains('transaction')) {
      return ErrorType.transaction;
    }

    return ErrorType.unknown;
  }
}

/// أنواع الأخطاء
enum ErrorType {
  network,
  permission,
  notFound,
  validation,
  quota,
  transaction,
  unknown,
}

/// كلاس لتسجيل العمليات والأداء
class DebtsFirestoreLogger {
  /// تسجيل أداء العملية
  static void logPerformance(String operation, Duration duration) {
    if (kReleaseMode) return;
    debugPrint('[PERFORMANCE] $operation took ${duration.inMilliseconds}ms');

    if (duration.inSeconds > 5) {
      debugPrint('[WARNING] Slow operation detected: $operation');
    }
  }

  /// تسجيل العملية
  static void logOperation(
      String operation,
      String message, {
        bool isError = false,
      }) {
    if (kReleaseMode && !isError) return;

    final timestamp = DateTime.now().toIso8601String();
    final logLevel = isError ? 'ERROR' : 'INFO';

    debugPrint('[$logLevel] [$timestamp] [$operation] $message');

    if (isError) {
      _logErrorToService(operation, message);
    }
  }

  static void _logErrorToService(String operation, String message) {
    // In a real app, log to a service like Crashlytics or Sentry
    debugPrint('[ERROR SERVICE] $operation: $message');
  }
}

/// أكواد أخطاء الديون بشكل منظم
enum DebtError {
  debtorNotFound,
  invalidAmount,
  networkError,
  permissionDenied,
  notFound,
  quotaExceeded,
  transactionConflict,
  unknown,
}

/// استثناء منظم لأخطاء الديون
class DebtException implements Exception {
  final DebtError code;
  final String message;

  DebtException(this.code, this.message);

  @override
  String toString() => 'DebtException(${code.name}): $message';
}

/// كاش عام بمدة انتهاء (TTL)
class TTLCache<K, V> {
  final Duration ttl;
  final Map<K, _TTLCacheEntry<V>> _store = {};

  TTLCache({this.ttl = const Duration(minutes: 5)});

  void set(K key, V value) {
    _store[key] = _TTLCacheEntry(value, DateTime.now());
  }

  V? get(K key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.insertedAt) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  void remove(K key) => _store.remove(key);

  void clear() => _store.clear();

  void cleanExpired() {
    final now = DateTime.now();
    final keysToRemove = <K>[];
    _store.forEach((key, entry) {
      if (now.difference(entry.insertedAt) > ttl) keysToRemove.add(key);
    });
    for (final key in keysToRemove) {
      _store.remove(key);
    }
  }
}

class _TTLCacheEntry<V> {
  final V value;
  final DateTime insertedAt;
  _TTLCacheEntry(this.value, this.insertedAt);
}

/// قاطع دوائر بسيط لحماية عمليات الديون
class DebtsCircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration openTimeout;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;

  DebtsCircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.openTimeout = const Duration(seconds: 30),
  });

  static final DebtsCircuitBreaker instance = DebtsCircuitBreaker(
    name: 'debts_operations',
  );

  bool get isOpen {
    if (_openedAt == null) return false;
    final isTimeoutPassed =
        DateTime.now().difference(_openedAt!) >= openTimeout;
    if (isTimeoutPassed) {
      _openedAt = null;
      _consecutiveFailures = 0;
      return false;
    }
    return true;
  }

  Future<T> execute<T>(
      String operationName,
      Future<T> Function() operation,
      ) async {
    if (isOpen) {
      throw DebtException(
        DebtError.networkError,
        'Circuit breaker is OPEN for $name, operation $operationName blocked temporarily',
      );
    }

    try {
      final result = await operation();
      _consecutiveFailures = 0;
      return result;
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= failureThreshold) {
        _openedAt = DateTime.now();
        DebtsFirestoreLogger.logOperation(
          'CIRCUIT_BREAKER_OPEN',
          'Opened due to repeated failures in $name (last op: $operationName)',
          isError: true,
        );
      }
      rethrow;
    }
  }
}

/// تنفيذ عملية مع إعادة المحاولة بتأخير أسّي
Future<T> retryOperation<T>(
    Future<T> Function() operation, {
      String operationName = 'UNKNOWN',
      int maxAttempts = 3,
      Duration initialDelay = const Duration(milliseconds: 400),
    }) async {
  int attempt = 0;
  Duration delay = initialDelay;
  while (true) {
    attempt++;
    try {
      return await operation();
    } catch (e) {
      final isRetriable =
          e is FirebaseException ||
              e is SocketException ||
              e is TimeoutException;
      if (!isRetriable || attempt >= maxAttempts) {
        DebtsFirestoreLogger.logOperation(
          operationName,
          'Failed after $attempt attempts: $e',
          isError: true,
        );
        rethrow;
      }

      DebtsFirestoreLogger.logOperation(
        operationName,
        'Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms... ',
        isError: false,
      );
      await Future.delayed(delay + Duration(milliseconds: 100 * attempt));
      delay *= 2;
    }
  }
}

/// غلاف مرونة يجمع بين القاطع وإعادة المحاولة
class DebtsResilience {
  static Future<T> run<T>({
    required String operationName,
    required Future<T> Function() operation,
  }) async {
    return await DebtsCircuitBreaker.instance.execute(operationName, () {
      return retryOperation<T>(operation, operationName: operationName);
    });
  }
}

/// ضغط البيانات باستخدام gzip + base64
String compressData(Map<String, dynamic> data) {
  final jsonString = jsonEncode(data);
  final utf8Bytes = utf8.encode(jsonString);
  final gzipped = gzip.encode(utf8Bytes);
  return base64Encode(gzipped);
}

/// فك ضغط البيانات gzip + base64
Map<String, dynamic> decompressData(String compressed) {
  final gzipped = base64Decode(compressed);
  final decompressed = gzip.decode(gzipped);
  final jsonString = utf8.decode(decompressed);
  final decoded = jsonDecode(jsonString);
  return Map<String, dynamic>.from(decoded as Map);
}

/// فهارس مركبة مقترحة لتحسين أداء استعلامات الديون
const List<Map<String, dynamic>> debtsCompositeIndexes = [
  {
    'collectionGroup': 'debts',
    'queryScope': 'COLLECTION',
    'fields': [
      {'fieldPath': 'isPaid', 'order': 'ASCENDING'},
      {'fieldPath': 'createdAt', 'order': 'DESCENDING'},
      {'fieldPath': 'total', 'order': 'DESCENDING'},
    ],
  },
];

/// مرجع مجموعة العملاء
final CollectionReference DebtorsCollection = FirebaseFirestore.instance
    .collection('debtors');

/// كاش تفصيلي للديون لتقليل قراءات الشبكة
final TTLCache<String, Map<String, dynamic>> _debtDetailsCache = TTLCache(
  ttl: const Duration(minutes: 2),
);

/// تنفيذ آمن لالتزام دفعة كتابية (WriteBatch)
Future<void> commitBatch(
    WriteBatch batch, {
      String operationName = 'BATCH_COMMIT',
    }) {
  return DebtsResilience.run<void>(
    operationName: operationName,
    operation: () => batch.commit(),
  );
}

// ================== دوال إدارة الديون ==================

/// إضافة دين محسن
Future<bool> addDebts({
  required String debtorId,
  required List<Map<String, dynamic>> items,
  required int total,
}) async {
  final stopwatch = Stopwatch()..start();

  try {
    // التحقق من البيانات
    final itemsError = DebtsDataValidator.validateItems(items);
    if (itemsError != null)
      throw DebtException(DebtError.invalidAmount, itemsError);

    final amountError = DebtsDataValidator.validateAmount(total);
    if (amountError != null)
      throw DebtException(DebtError.invalidAmount, amountError);

    final debtorRef = DebtorsCollection.doc(debtorId);
    final debtsRef = debtorRef.collection('debts');

    await DebtsResilience.run<void>(
      operationName: 'ADD_DEBT',
      operation: () async {
        // استخدام WriteBatch للوضع البسيط بدون قراءات
        final batch = FirebaseFirestore.instance.batch();

        // لا بد من وجود debtor مسبقاً، إن أردت ضمان ذلك بقراءة، استعمل transaction كما في addDebtWithDetails
        final debtDocRef = debtsRef.doc();
        batch.set(debtDocRef, {
          'items': items,
          'total': total,
          'createdAt': FieldValue.serverTimestamp(),
          'isPaid': false,
          'notes': '',
          'deleted': false,
        });

        batch.update(debtorRef, {
          'totalBorrowed': FieldValue.increment(total),
          'currentDebt': FieldValue.increment(total),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(1),
        });

        await commitBatch(batch, operationName: 'ADD_DEBT_BATCH');
      },
    );

    // مسح الcache بعد نجاح العملية
    DebtsDebtorCache.clearDebtorCache(debtorId);

    stopwatch.stop();
    DebtsFirestoreLogger.logPerformance("ADD_DEBT", stopwatch.elapsed);
    DebtsFirestoreLogger.logOperation(
      "ADD_DEBT",
      "Successfully added debt: $total for $debtorId",
    );

    return true;
  } catch (e) {
    stopwatch.stop();
    DebtsFirestoreLogger.logOperation(
      "ADD_DEBT",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return false;
  }
}

/// إضافة دين مع تفاصيل إضافية
Future<bool> addDebtWithDetails({
  required String debtorId,
  required List<Map<String, dynamic>> items,
  required int total,
  String? notes,
  DateTime? customDate,
  String? referenceNumber,
}) async {
  final stopwatch = Stopwatch()..start();

  try {
    // التحقق من البيانات
    final itemsError = DebtsDataValidator.validateItems(items);
    if (itemsError != null) throw Exception(itemsError);

    final amountError = DebtsDataValidator.validateAmount(total);
    if (amountError != null) throw Exception(amountError);

    final debtorRef = DebtorsCollection.doc(debtorId);
    final debtsRef = debtorRef.collection('debts');

    await DebtsResilience.run<void>(
      operationName: 'ADD_DEBT_WITH_DETAILS',
      operation: () async {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // التحقق من وجود العميل
          final debtorSnapshot = await transaction.get(debtorRef);
          if (!debtorSnapshot.exists) {
            throw DebtException(DebtError.debtorNotFound, 'العميل غير موجود');
          }

          // إعداد بيانات الدين
          final debtData = {
            'items': items,
            'total': total,
            'createdAt':
            customDate != null
                ? Timestamp.fromDate(customDate)
                : FieldValue.serverTimestamp(),
            'isPaid': false,
            'notes': notes ?? '',
            'addedAt': FieldValue.serverTimestamp(),
          };

          // إضافة رقم مرجعي إذا تم تحديده
          if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
            debtData['referenceNumber'] = referenceNumber.trim();
          }

          // إضافة الدين
          transaction.set(debtsRef.doc(), {...debtData, 'deleted': false});

          // تحديث إجماليات العميل
          transaction.update(debtorRef, {
            'totalBorrowed': FieldValue.increment(total),
            'currentDebt': FieldValue.increment(total),
            'updatedAt': FieldValue.serverTimestamp(),
            'totalTransactions': FieldValue.increment(1),
          });
        });
      },
    );

    // مسح الcache
    DebtsDebtorCache.clearDebtorCache(debtorId);

    stopwatch.stop();
    DebtsFirestoreLogger.logPerformance("ADD_DEBT_WITH_DETAILS", stopwatch.elapsed);
    DebtsFirestoreLogger.logOperation(
      "ADD_DEBT_WITH_DETAILS",
      "Successfully added detailed debt: $total for $debtorId",
    );

    return true;
  } catch (e) {
    stopwatch.stop();
    DebtsFirestoreLogger.logOperation(
      "ADD_DEBT_WITH_DETAILS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return false;
  }
}

/// تحديث دين معين
Future<void> updateDebt({
  required String debtorId,
  required String debtId,
  List<Map<String, dynamic>>? items,
  int? newTotal,
  String? notes,
  bool? isPaid,
}) async {
  final debtorRef = DebtorsCollection.doc(debtorId);
  final debtRef = debtorRef.collection('debts').doc(debtId);

  try {
    await DebtsResilience.run<void>(
      operationName: 'UPDATE_DEBT',
      operation: () async {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // جلب الدين الحالي
          final debtSnapshot = await transaction.get(debtRef);
          if (!debtSnapshot.exists) {
            throw DebtException(DebtError.notFound, 'الدين غير موجود');
          }

          final currentDebtData = debtSnapshot.data() as Map<String, dynamic>;
          final oldTotal = (currentDebtData['total'] as num).toInt();

          final Map<String, dynamic> debtUpdates = {};

          if (items != null) {
            final itemsError = DebtsDataValidator.validateItems(items);
            if (itemsError != null)
              throw DebtException(DebtError.invalidAmount, itemsError);
            debtUpdates['items'] = items;
          }

          if (newTotal != null) {
            final amountError = DebtsDataValidator.validateAmount(newTotal);
            if (amountError != null)
              throw DebtException(DebtError.invalidAmount, amountError);
            debtUpdates['total'] = newTotal;
          }

          if (notes != null) {
            debtUpdates['notes'] = notes;
          }

          if (isPaid != null) {
            debtUpdates['isPaid'] = isPaid;
          }

          if (debtUpdates.isEmpty) {
            throw DebtException(
              DebtError.unknown,
              'لم يتم تحديد أي بيانات للتحديث',
            );
          }

          debtUpdates['updatedAt'] = FieldValue.serverTimestamp();

          // تحديث الدين
          transaction.update(debtRef, debtUpdates);

          // تحديث إجماليات العميل (إذا تغير المجموع)
          if (newTotal != null && newTotal != oldTotal) {
            final difference = newTotal - oldTotal;

            transaction.update(debtorRef, {
              'totalBorrowed': FieldValue.increment(difference),
              'currentDebt': FieldValue.increment(difference),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          DebtsDebtorCache.clearDebtorCache(debtorId);
        });
      },
    );

    DebtsFirestoreLogger.logOperation(
      "UPDATE_DEBT",
      "Successfully updated debt: $debtId",
    );
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "UPDATE_DEBT",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    rethrow;
  }
}

/// حذف دين معين
Future<void> deleteDebt({
  required String debtorId,
  required String debtId,
}) async {
  final debtorRef = DebtorsCollection.doc(debtorId);
  final debtRef = debtorRef.collection('debts').doc(debtId);

  try {
    await DebtsResilience.run<void>(
      operationName: 'DELETE_DEBT',
      operation: () async {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // جلب بيانات الدين قبل الحذف
          final debtSnapshot = await transaction.get(debtRef);
          if (!debtSnapshot.exists) {
            throw DebtException(DebtError.notFound, 'الدين غير موجود');
          }

          final debtData = debtSnapshot.data() as Map<String, dynamic>;
          final debtTotal = (debtData['total'] as num).toInt();

          // حذف ناعم: تحديد الحقل deleted بدلاً من حذف المستند نهائياً
          transaction.update(debtRef, {
            'deleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
          });

          // تحديث إجماليات العميل
          transaction.update(debtorRef, {
            'totalBorrowed': FieldValue.increment(-debtTotal),
            'currentDebt': FieldValue.increment(-debtTotal),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          DebtsDebtorCache.clearDebtorCache(debtorId);
        });
      },
    );

    DebtsFirestoreLogger.logOperation(
      "DELETE_DEBT",
      "Successfully deleted debt: $debtId",
    );
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "DELETE_DEBT",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    rethrow;
  }
}

/// جلب ديون عميل معين
Future<List<Map<String, dynamic>>> fetchDebtorDebts(String debtorId) async {
  try {
    final snapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'FETCH_DEBTOR_DEBTS',
      operation: () {
        return DebtorsCollection.doc(debtorId)
            .collection('debts')
            .where('deleted', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .get();
      },
    );

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'items': data['items'] ?? [],
        'total': (data['total'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'],
        'isPaid': data['isPaid'] ?? false,
        'notes': data['notes'] ?? '',
        'referenceNumber': data['referenceNumber'] ?? '',
        'addedAt': data['addedAt'],
        'updatedAt': data['updatedAt'],
      };
    }).toList();
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "FETCH_DEBTOR_DEBTS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return [];
  }
}

/// جلب ديون عميل مع فلترة
Future<List<Map<String, dynamic>>> fetchDebtorDebtsFiltered({
  required String debtorId,
  bool? isPaid,
  DateTime? startDate,
  DateTime? endDate,
  int? minAmount,
  int? maxAmount,
  int limit = 50,
}) async {
  try {
    Query query = DebtorsCollection.doc(
      debtorId,
    ).collection('debts').orderBy('createdAt', descending: true);
    query = query.where('deleted', isEqualTo: false);

    // فلتر حالة الدفع
    if (isPaid != null) {
      query = query.where('isPaid', isEqualTo: isPaid);
    }

    // فلتر التاريخ
    if (startDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    // فلتر المبلغ
    if (minAmount != null) {
      query = query.where('total', isGreaterThanOrEqualTo: minAmount);
    }

    if (maxAmount != null) {
      query = query.where('total', isLessThanOrEqualTo: maxAmount);
    }

    // ملاحظة: لضمان دعم ترتيب/فلترة متعددة الحقول يفضل إعداد فهرس مركب مسبقاً
    final snapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'FETCH_DEBTOR_DEBTS_FILTERED',
      operation: () => query.limit(limit).get(),
    );

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'items': data['items'] ?? [],
        'total': (data['total'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'],
        'isPaid': data['isPaid'] ?? false,
        'notes': data['notes'] ?? '',
        'referenceNumber': data['referenceNumber'] ?? '',
      };
    }).toList();
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "FETCH_DEBTOR_DEBTS_FILTERED",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return [];
  }
}

/// جلب دين معين بالتفصيل
Future<Map<String, dynamic>?> getDebtDetails({
  required String debtorId,
  required String debtId,
}) async {
  try {
    // كاش تفاصيل الدين
    final cacheKey = '$debtorId::$debtId';
    final cached = _debtDetailsCache.get(cacheKey);
    if (cached != null) return cached;

    final debtDoc = await DebtsResilience.run<DocumentSnapshot>(
      operationName: 'GET_DEBT_DETAILS',
      operation: () {
        return DebtorsCollection.doc(
          debtorId,
        ).collection('debts').doc(debtId).get();
      },
    );

    if (!debtDoc.exists) {
      return null;
    }

    final data = debtDoc.data() as Map<String, dynamic>;
    if ((data['deleted'] as bool?) == true) return null;
    final result = {
      'id': debtDoc.id,
      'items': data['items'] ?? [],
      'total': (data['total'] as num?)?.toInt() ?? 0,
      'createdAt': data['createdAt'],
      'isPaid': data['isPaid'] ?? false,
      'notes': data['notes'] ?? '',
      'referenceNumber': data['referenceNumber'] ?? '',
      'addedAt': data['addedAt'],
      'updatedAt': data['updatedAt'],
    };

    _debtDetailsCache.set(cacheKey, result);
    return result;
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "GET_DEBT_DETAILS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return null;
  }
}

/// جلب إحصائيات الديون لعميل معين
Future<Map<String, dynamic>> getDebtorDebtStatistics(String debtorId) async {
  try {
    final debtsSnapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'GET_DEBTOR_DEBT_STATISTICS_DEBTS_QUERY',
      operation:
          () => DebtorsCollection.doc(debtorId).collection('debts').get(),
    );

    int totalDebts = 0;
    int totalPaidDebts = 0;
    int totalUnpaidDebts = 0;
    int totalAmount = 0;
    int totalPaidAmount = 0;
    int totalUnpaidAmount = 0;

    DateTime? firstDebt;
    DateTime? lastDebt;
    int maxDebtAmount = 0;
    int minDebtAmount = 0;

    for (var doc in debtsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['total'] as num?)?.toInt() ?? 0;
      final isPaid = (data['isPaid'] as bool?) ?? false;
      final createdAt = data['createdAt'] as Timestamp?;

      totalDebts++;
      totalAmount += amount;

      if (isPaid) {
        totalPaidDebts++;
        totalPaidAmount += amount;
      } else {
        totalUnpaidDebts++;
        totalUnpaidAmount += amount;
      }

      // تتبع أعلى وأقل مبلغ
      if (maxDebtAmount == 0 || amount > maxDebtAmount) {
        maxDebtAmount = amount;
      }
      if (minDebtAmount == 0 || amount < minDebtAmount) {
        minDebtAmount = amount;
      }

      // تتبع التواريخ
      if (createdAt != null) {
        final debtDate = createdAt.toDate();
        if (firstDebt == null || debtDate.isBefore(firstDebt)) {
          firstDebt = debtDate;
        }
        if (lastDebt == null || debtDate.isAfter(lastDebt)) {
          lastDebt = debtDate;
        }
      }
    }

    return {
      'totalDebts': totalDebts,
      'totalPaidDebts': totalPaidDebts,
      'totalUnpaidDebts': totalUnpaidDebts,
      'totalAmount': totalAmount,
      'totalPaidAmount': totalPaidAmount,
      'totalUnpaidAmount': totalUnpaidAmount,
      'averageDebtAmount':
      totalDebts > 0 ? (totalAmount / totalDebts).round() : 0,
      'maxDebtAmount': maxDebtAmount,
      'minDebtAmount': totalDebts > 0 ? minDebtAmount : 0,
      'paymentRate':
      totalAmount > 0 ? ((totalPaidAmount / totalAmount) * 100).round() : 0,
      'firstDebt': firstDebt?.toIso8601String(),
      'lastDebt': lastDebt?.toIso8601String(),
    };
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "GET_DEBTOR_DEBT_STATISTICS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return {};
  }
}

/// البحث في الديون بالرقم المرجعي
Future<List<Map<String, dynamic>>> searchDebtsByReference(
    String referenceNumber,
    ) async {
  try {
    final List<Map<String, dynamic>> results = [];

    // البحث في جميع العملاء (هذا قد يكون بطيئاً مع كثرة البيانات)
    final debtorsSnapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'SEARCH_DEBTS_BY_REFERENCE_DEBTORS_QUERY',
      operation: () => DebtorsCollection.get(),
    );

    for (var debtorDoc in debtorsSnapshot.docs) {
      final debtsSnapshot = await DebtsResilience.run<QuerySnapshot>(
        operationName: 'SEARCH_DEBTS_BY_REFERENCE_DEBTS_QUERY',
        operation:
            () =>
            debtorDoc.reference
                .collection('debts')
                .where('deleted', isEqualTo: false)
                .where('referenceNumber', isEqualTo: referenceNumber.trim())
                .get(),
      );

      for (var debtDoc in debtsSnapshot.docs) {
        final debtData = debtDoc.data() as Map<String, dynamic>;
        final debtorData = debtorDoc.data() as Map<String, dynamic>;

        results.add({
          'debtId': debtDoc.id,
          'debtorId': debtorDoc.id,
          'debtorName': debtorData['name'],
          'debtorPhone': debtorData['phone'],
          'total': (debtData['total'] as num?)?.toInt() ?? 0,
          'createdAt': debtData['createdAt'],
          'isPaid': debtData['isPaid'] ?? false,
          'referenceNumber': debtData['referenceNumber'],
          'notes': debtData['notes'] ?? '',
        });
      }
    }

    return results;
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "SEARCH_DEBTS_BY_REFERENCE",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return [];
  }
}

/// تحديث حالة دين (مدفوع/غير مدفوع)
Future<bool> updateDebtPaymentStatus({
  required String debtorId,
  required String debtId,
  required bool isPaid,
}) async {
  try {
    await DebtsResilience.run<void>(
      operationName: 'UPDATE_DEBT_PAYMENT_STATUS',
      operation:
          () => updateDebt(debtorId: debtorId, debtId: debtId, isPaid: isPaid),
    );

    final statusText = isPaid ? "مدفوع" : "غير مدفوع";
    DebtsFirestoreLogger.logOperation(
      "UPDATE_DEBT_PAYMENT_STATUS",
      "Successfully updated debt $debtId to $statusText",
    );

    return true;
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "UPDATE_DEBT_PAYMENT_STATUS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return false;
  }
}

/// إضافة عدة ديون لعميل واحد في batch
Future<bool> addMultipleDebts({
  required String debtorId,
  required List<Map<String, dynamic>> debts,
}) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    final debtorRef = DebtorsCollection.doc(debtorId);
    final debtsRef = debtorRef.collection('debts');

    int totalAmount = 0;

    for (final debtData in debts) {
      final items = debtData['items'] as List<Map<String, dynamic>>;
      final total = (debtData['total'] as num).toInt();

      // التحقق من صحة البيانات
      final itemsError = DebtsDataValidator.validateItems(items);
      if (itemsError != null) throw Exception(itemsError);

      final amountError = DebtsDataValidator.validateAmount(total);
      if (amountError != null) throw Exception(amountError);

      totalAmount += total;

      // إضافة الدين إلى الbatch
      final debtRef = debtsRef.doc();
      batch.set(debtRef, {
        'items': items,
        'total': total,
        'createdAt':
        debtData['createdAt'] != null
            ? Timestamp.fromDate(debtData['createdAt'] as DateTime)
            : FieldValue.serverTimestamp(),
        'isPaid': false,
        'notes': debtData['notes'] ?? '',
        'referenceNumber': debtData['referenceNumber'] ?? '',
        'addedAt': FieldValue.serverTimestamp(),
        'deleted': false,
      });
    }

    // تحديث إجماليات العميل
    batch.update(debtorRef, {
      'totalBorrowed': FieldValue.increment(totalAmount),
      'currentDebt': FieldValue.increment(totalAmount),
      'updatedAt': FieldValue.serverTimestamp(),
      'totalTransactions': FieldValue.increment(debts.length),
    });

    await commitBatch(batch, operationName: 'ADD_MULTIPLE_DEBTS_BATCH');
    DebtsDebtorCache.clearDebtorCache(debtorId);

    DebtsFirestoreLogger.logOperation(
      "ADD_MULTIPLE_DEBTS",
      "Successfully added ${debts.length} debts for debtor: $debtorId",
    );
    return true;
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "ADD_MULTIPLE_DEBTS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return false;
  }
}

/// جلب آخر الديون المضافة عبر النظام
Future<List<Map<String, dynamic>>> getRecentDebts({int limit = 20}) async {
  try {
    final List<Map<String, dynamic>> recentDebts = [];

    // جلب جميع العملاء النشطين
    final debtorsSnapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'GET_RECENT_DEBTS_DEBTORS_QUERY',
      operation:
          () => DebtorsCollection.where('isActive', isEqualTo: true).get(),
    );

    // جلب أحدث الديون لكل عميل
    for (var debtorDoc in debtorsSnapshot.docs) {
      final debtorData = debtorDoc.data() as Map<String, dynamic>;

      final debtsSnapshot = await DebtsResilience.run<QuerySnapshot>(
        operationName: 'GET_RECENT_DEBTS_DEBTS_QUERY',
        operation:
            () =>
            debtorDoc.reference
                .collection('debts')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .get(),
      );

      for (var debtDoc in debtsSnapshot.docs) {
        final debtData = debtDoc.data() as Map<String, dynamic>;

        recentDebts.add({
          'debtId': debtDoc.id,
          'debtorId': debtorDoc.id,
          'debtorName': debtorData['name'],
          'debtorPhone': debtorData['phone'],
          'items': debtData['items'] ?? [],
          'total': (debtData['total'] as num?)?.toInt() ?? 0,
          'createdAt': debtData['createdAt'],
          'isPaid': debtData['isPaid'] ?? false,
          'notes': debtData['notes'] ?? '',
        });
      }
    }

    // ترتيب النتائج حسب التاريخ وتحديد العدد المطلوب
    recentDebts.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    return recentDebts.take(limit).toList();
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "GET_RECENT_DEBTS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return [];
  }
}

/// الحصول على الديون المتأخرة (غير المدفوعة لفترة طويلة)
Future<List<Map<String, dynamic>>> getOverdueDebts({
  Duration overduePeriod = const Duration(days: 30),
  int limit = 50,
}) async {
  try {
    final cutoffDate = DateTime.now().subtract(overduePeriod);
    final List<Map<String, dynamic>> overdueDebts = [];

    // البحث في جميع العملاء النشطين
    final debtorsSnapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'GET_OVERDUE_DEBTS_DEBTORS_QUERY',
      operation:
          () =>
          DebtorsCollection.where(
            'isActive',
            isEqualTo: true,
          ).where('currentDebt', isGreaterThan: 0).get(),
    );

    for (var debtorDoc in debtorsSnapshot.docs) {
      final debtorData = debtorDoc.data() as Map<String, dynamic>;

      final debtsSnapshot = await DebtsResilience.run<QuerySnapshot>(
        operationName: 'GET_OVERDUE_DEBTS_DEBTS_QUERY',
        operation:
            () =>
            debtorDoc.reference
                .collection('debts')
                .where('isPaid', isEqualTo: false)
                .where(
              'createdAt',
              isLessThan: Timestamp.fromDate(cutoffDate),
            )
                .orderBy('createdAt')
                .get(),
      );

      for (var debtDoc in debtsSnapshot.docs) {
        final debtData = debtDoc.data() as Map<String, dynamic>;
        final createdAt = debtData['createdAt'] as Timestamp?;

        if (createdAt != null) {
          final daysPastDue =
              DateTime.now().difference(createdAt.toDate()).inDays;

          overdueDebts.add({
            'debtId': debtDoc.id,
            'debtorId': debtorDoc.id,
            'debtorName': debtorData['name'],
            'debtorPhone': debtorData['phone'],
            'total': (debtData['total'] as num?)?.toInt() ?? 0,
            'createdAt': createdAt,
            'daysPastDue': daysPastDue,
            'notes': debtData['notes'] ?? '',
          });
        }
      }
    }

    // ترتيب حسب عدد الأيام المتأخرة (الأطول أولاً)
    overdueDebts.sort(
          (a, b) => (b['daysPastDue'] as int).compareTo(a['daysPastDue'] as int),
    );

    return overdueDebts.take(limit).toList();
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "GET_OVERDUE_DEBTS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return [];
  }
}

/// إحضار الديون بصفحات
Future<PaginatedDebtsResult> getDebtsPaginated({
  required String debtorId,
  int pageSize = 20,
  DocumentSnapshot? startAfter,
  bool onlyUnDeleted = true,
  bool? isPaid,
}) async {
  return await DebtsResilience.run<PaginatedDebtsResult>(
    operationName: 'GET_DEBTS_PAGINATED',
    operation: () async {
      Query query = DebtorsCollection.doc(debtorId)
          .collection('debts')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (onlyUnDeleted) {
        query = query.where('deleted', isEqualTo: false);
      }

      if (isPaid != null) {
        query = query.where('isPaid', isEqualTo: isPaid);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final items =
      snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'items': data['items'] ?? [],
          'total': (data['total'] as num?)?.toInt() ?? 0,
          'createdAt': data['createdAt'],
          'isPaid': data['isPaid'] ?? false,
          'notes': data['notes'] ?? '',
          'referenceNumber': data['referenceNumber'] ?? '',
        };
      }).toList();

      return PaginatedDebtsResult(
        items: items,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
        pageSize: pageSize,
      );
    },
  );
}

class PaginatedDebtsResult {
  final List<Map<String, dynamic>> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  final int pageSize;

  PaginatedDebtsResult({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
    required this.pageSize,
  });
}

/// تدفق لحظي للديون الخاصة بعميل
Stream<List<Map<String, dynamic>>> getDebtsStream({
  required String debtorId,
  bool onlyUnDeleted = true,
}) {
  Query query = DebtorsCollection.doc(
    debtorId,
  ).collection('debts').orderBy('createdAt', descending: true);

  if (onlyUnDeleted) {
    query = query.where('deleted', isEqualTo: false);
  }

  return query.snapshots().map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'items': data['items'] ?? [],
        'total': (data['total'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'],
        'isPaid': data['isPaid'] ?? false,
        'notes': data['notes'] ?? '',
        'referenceNumber': data['referenceNumber'] ?? '',
      };
    }).toList();
  });
}

/// مستودع الديون - واجهة عامة
abstract class DebtRepository {
  Future<bool> createDebt({
    required String debtorId,
    required List<Map<String, dynamic>> items,
    required int total,
  });
  Future<bool> createDebtWithDetails({
    required String debtorId,
    required List<Map<String, dynamic>> items,
    required int total,
    String? notes,
    DateTime? customDate,
    String? referenceNumber,
  });
  Future<void> modifyDebt({
    required String debtorId,
    required String debtId,
    List<Map<String, dynamic>>? items,
    int? newTotal,
    String? notes,
    bool? isPaid,
  });
  Future<void> removeDebt({required String debtorId, required String debtId});
  Future<List<Map<String, dynamic>>> listDebtorDebts(String debtorId);
  Future<List<Map<String, dynamic>>> listDebtorDebtsFiltered({
    required String debtorId,
    bool? isPaid,
    DateTime? startDate,
    DateTime? endDate,
    int? minAmount,
    int? maxAmount,
    int limit,
  });
  Future<Map<String, dynamic>?> fetchDebtDetailsById({
    required String debtorId,
    required String debtId,
  });
  Future<PaginatedDebtsResult> paginateDebts({
    required String debtorId,
    int pageSize,
    DocumentSnapshot? startAfter,
    bool onlyUnDeleted,
    bool? isPaid,
  });
  Stream<List<Map<String, dynamic>>> watchDebts({
    required String debtorId,
    bool onlyUnDeleted,
  });
}

/// تنفيذ Firestore لمستودع الديون
class FirestoreDebtRepository implements DebtRepository {
  @override
  Future<bool> createDebt({
    required String debtorId,
    required List<Map<String, dynamic>> items,
    required int total,
  }) {
    return addDebts(debtorId: debtorId, items: items, total: total);
  }

  @override
  Future<bool> createDebtWithDetails({
    required String debtorId,
    required List<Map<String, dynamic>> items,
    required int total,
    String? notes,
    DateTime? customDate,
    String? referenceNumber,
  }) {
    return addDebtWithDetails(
      debtorId: debtorId,
      items: items,
      total: total,
      notes: notes,
      customDate: customDate,
      referenceNumber: referenceNumber,
    );
  }

  @override
  Future<void> removeDebt({required String debtorId, required String debtId}) {
    return deleteDebt(debtorId: debtorId, debtId: debtId);
  }

  @override
  Future<List<Map<String, dynamic>>> listDebtorDebts(String debtorId) {
    return fetchDebtorDebts(debtorId);
  }

  @override
  Future<List<Map<String, dynamic>>> listDebtorDebtsFiltered({
    required String debtorId,
    bool? isPaid,
    DateTime? startDate,
    DateTime? endDate,
    int? minAmount,
    int? maxAmount,
    int limit = 50,
  }) {
    return fetchDebtorDebtsFiltered(
      debtorId: debtorId,
      isPaid: isPaid,
      startDate: startDate,
      endDate: endDate,
      minAmount: minAmount,
      maxAmount: maxAmount,
      limit: limit,
    );
  }

  @override
  Future<Map<String, dynamic>?> fetchDebtDetailsById({
    required String debtorId,
    required String debtId,
  }) {
    return getDebtDetails(debtorId: debtorId, debtId: debtId);
  }

  @override
  Future<PaginatedDebtsResult> paginateDebts({
    required String debtorId,
    int pageSize = 20,
    DocumentSnapshot? startAfter,
    bool onlyUnDeleted = true,
    bool? isPaid,
  }) {
    return getDebtsPaginated(
      debtorId: debtorId,
      pageSize: pageSize,
      startAfter: startAfter,
      onlyUnDeleted: onlyUnDeleted,
      isPaid: isPaid,
    );
  }

  @override
  Stream<List<Map<String, dynamic>>> watchDebts({
    required String debtorId,
    bool onlyUnDeleted = true,
  }) {
    return getDebtsStream(debtorId: debtorId, onlyUnDeleted: onlyUnDeleted);
  }

  @override
  Future<void> modifyDebt({
    required String debtorId,
    required String debtId,
    List<Map<String, dynamic>>? items,
    int? newTotal,
    String? notes,
    bool? isPaid,
  }) {
    return updateDebt(
      debtorId: debtorId,
      debtId: debtId,
      items: items,
      newTotal: newTotal,
      notes: notes,
      isPaid: isPaid,
    );
  }
}

/// جلب إحصائيات شاملة لجميع الديون في النظام
Future<Map<String, dynamic>> getSystemDebtStatistics() async {
  try {
    int totalDebts = 0;
    int totalPaidDebts = 0;
    int totalUnpaidDebts = 0;
    int totalAmount = 0;
    int totalPaidAmount = 0;
    int totalUnpaidAmount = 0;

    final Map<String, int> monthlyDebts = {};
    int maxDebtAmount = 0;
    int minDebtAmount = 0;

    // جلب جميع العملاء
    final debtorsSnapshot = await DebtsResilience.run<QuerySnapshot>(
      operationName: 'GET_SYSTEM_DEBT_STATISTICS_DEBTORS_QUERY',
      operation: () => DebtorsCollection.get(),
    );

    for (var debtorDoc in debtorsSnapshot.docs) {
      final debtsSnapshot = await DebtsResilience.run<QuerySnapshot>(
        operationName: 'GET_SYSTEM_DEBT_STATISTICS_DEBTS_QUERY',
        operation: () => debtorDoc.reference.collection('debts').get(),
      );

      for (var debtDoc in debtsSnapshot.docs) {
        final debtData = debtDoc.data() as Map<String, dynamic>;
        final amount = (debtData['total'] as num?)?.toInt() ?? 0;
        final isPaid = (debtData['isPaid'] as bool?) ?? false;
        final createdAt = debtData['createdAt'] as Timestamp?;

        totalDebts++;
        totalAmount += amount;

        if (isPaid) {
          totalPaidDebts++;
          totalPaidAmount += amount;
        } else {
          totalUnpaidDebts++;
          totalUnpaidAmount += amount;
        }

        // تتبع أعلى وأقل مبلغ
        if (maxDebtAmount == 0 || amount > maxDebtAmount) {
          maxDebtAmount = amount;
        }
        if (minDebtAmount == 0 || amount < minDebtAmount) {
          minDebtAmount = amount;
        }

        // إحصائيات شهرية
        if (createdAt != null) {
          final monthKey =
              "${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}";
          monthlyDebts[monthKey] = (monthlyDebts[monthKey] ?? 0) + 1;
        }
      }
    }

    return {
      'totalDebts': totalDebts,
      'totalPaidDebts': totalPaidDebts,
      'totalUnpaidDebts': totalUnpaidDebts,
      'totalAmount': totalAmount,
      'totalPaidAmount': totalPaidAmount,
      'totalUnpaidAmount': totalUnpaidAmount,
      'averageDebtAmount':
      totalDebts > 0 ? (totalAmount / totalDebts).round() : 0,
      'maxDebtAmount': maxDebtAmount,
      'minDebtAmount': totalDebts > 0 ? minDebtAmount : 0,
      'paymentRate':
      totalAmount > 0 ? ((totalPaidAmount / totalAmount) * 100).round() : 0,
      'monthlyBreakdown': monthlyDebts,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "GET_SYSTEM_DEBT_STATISTICS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return {};
  }
}

/// حذف عدة ديون في batch واحد
Future<bool> deleteMultipleDebts(
    List<Map<String, String>> debtsToDelete,
    ) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    final Map<String, int> debtorTotals = {};

    for (final debtInfo in debtsToDelete) {
      final debtorId = debtInfo['debtorId']!;
      final debtId = debtInfo['debtId']!;

      final debtorRef = DebtorsCollection.doc(debtorId);
      final debtRef = debtorRef.collection('debts').doc(debtId);

      // جلب بيانات الدين لحساب المجموع
      final debtDoc = await debtRef.get();
      if (debtDoc.exists) {
        final debtData = debtDoc.data() as Map<String, dynamic>;
        final debtTotal = (debtData['total'] as num).toInt();

        // إضافة إلى المجموع الخاص بالعميل
        debtorTotals[debtorId] = (debtorTotals[debtorId] ?? 0) + debtTotal;

        // إضافة عملية الحذف إلى الbatch
        batch.delete(debtRef);
      }
    }

    // تحديث إجماليات العملاء + حذف ناعم لكل دين محذوف
    debtorTotals.forEach((debtorId, totalToSubtract) {
      final debtorRef = DebtorsCollection.doc(debtorId);
      batch.update(debtorRef, {
        'totalBorrowed': FieldValue.increment(-totalToSubtract),
        'currentDebt': FieldValue.increment(-totalToSubtract),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      DebtsDebtorCache.clearDebtorCache(debtorId);
    });

    await commitBatch(batch, operationName: 'DELETE_MULTIPLE_DEBTS_BATCH');

    DebtsFirestoreLogger.logOperation(
      "DELETE_MULTIPLE_DEBTS",
      "Successfully deleted ${debtsToDelete.length} debts",
    );
    return true;
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "DELETE_MULTIPLE_DEBTS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return false;
  }
}

/// نسخ دين إلى عميل آخر
Future<bool> copyDebtToAnotherDebtor({
  required String sourceDebtorId,
  required String sourceDebtId,
  required String targetDebtorId,
  bool copyNotes = true,
  String? additionalNotes,
}) async {
  try {
    // جلب بيانات الدين المصدر
    final sourceDebtDoc = await DebtsResilience.run<DocumentSnapshot>(
      operationName: 'COPY_DEBT_FETCH_SOURCE',
      operation:
          () =>
          DebtorsCollection.doc(
            sourceDebtorId,
          ).collection('debts').doc(sourceDebtId).get(),
    );

    if (!sourceDebtDoc.exists) {
      throw Exception('الدين المصدر غير موجود');
    }

    final sourceDebtData = sourceDebtDoc.data() as Map<String, dynamic>;

    // إعداد بيانات الدين الجديد
    final newDebtData = {
      'items': sourceDebtData['items'],
      'total': sourceDebtData['total'],
      'createdAt': FieldValue.serverTimestamp(),
      'isPaid': false,
      'notes': copyNotes ? (sourceDebtData['notes'] ?? '') : '',
      'referenceNumber': sourceDebtData['referenceNumber'] ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    };

    // إضافة ملاحظات إضافية
    if (additionalNotes != null && additionalNotes.trim().isNotEmpty) {
      final existingNotes = newDebtData['notes'] as String;
      newDebtData['notes'] =
      existingNotes.isEmpty
          ? additionalNotes.trim()
          : '$existingNotes\n${additionalNotes.trim()}';
    }

    // إضافة الدين الجديد
    final result = await DebtsResilience.run<bool>(
      operationName: 'COPY_DEBT_ADD_TARGET',
      operation:
          () => addDebtWithDetails(
        debtorId: targetDebtorId,
        items: List<Map<String, dynamic>>.from(newDebtData['items']),
        total: (newDebtData['total'] as num).toInt(),
        notes: newDebtData['notes'] as String?,
        referenceNumber: newDebtData['referenceNumber'] as String?,
      ),
    );

    if (result) {
      DebtsFirestoreLogger.logOperation(
        "COPY_DEBT",
        "Successfully copied debt from $sourceDebtorId to $targetDebtorId",
      );
    }

    return result;
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "COPY_DEBT",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return false;
  }
}

/// تصدير ديون عميل معين إلى قائمة للمعالجة الخارجية
Future<List<Map<String, dynamic>>> exportDebtorDebts(String debtorId) async {
  try {
    final debts = await fetchDebtorDebts(debtorId);
    final debtorInfo = await DebtsDebtorCache.getDebtorWithCache(debtorId);

    return debts.map((debt) {
      // تحويل الTimestamp إلى تاريخ قابل للقراءة
      final createdAt = debt['createdAt'] as Timestamp?;
      final addedAt = debt['addedAt'] as Timestamp?;

      return {
        'معرف_الدين': debt['id'],
        'معرف_العميل': debtorId,
        'اسم_العميل': debtorInfo?['name'] ?? '',
        'هاتف_العميل': debtorInfo?['phone'] ?? '',
        'الأصناف': debt['items'],
        'المجموع': debt['total'],
        'تاريخ_الإنشاء': createdAt?.toDate().toString() ?? '',
        'تاريخ_الإضافة': addedAt?.toDate().toString() ?? '',
        'حالة_الدفع': debt['isPaid'] ? 'مدفوع' : 'غير مدفوع',
        'الملاحظات': debt['notes'],
        'الرقم_المرجعي': debt['referenceNumber'],
      };
    }).toList();
  } catch (e) {
    DebtsFirestoreLogger.logOperation(
      "EXPORT_DEBTOR_DEBTS",
      "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
      isError: true,
    );
    return [];
  }
}
