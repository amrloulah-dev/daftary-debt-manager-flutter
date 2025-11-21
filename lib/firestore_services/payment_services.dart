import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'debtor_services.dart';

/*
ملاحظة الفهارس المركبة (Firestore Composite Indexes):
يرجى إنشاء الفهارس التالية عبر لوحة تحكم Firestore لتحسين الأداء:

1) collectionGroup("payments"): debtorId ASC, createdAt DESC
2) collectionGroup("payments"): paymentMethod ASC, referenceNumber ASC
3) collectionGroup("payments"): isPartialPayment ASC, createdAt DESC

ستظهر لك روابط الإنشاء التلقائية في سجلات الأخطاء إذا كان فهرس ناقصاً.
*/

// ========== أدوات مساعدة: تصنيف الأخطاء، Cache بمدة صلاحية، Rate Limit، Retry/Backoff، مراقبة الأداء ==========

class PaymentError implements Exception {
  final String message;
  PaymentError(this.message);
  @override
  String toString() => 'PaymentError: $message';
}

class ValidationError extends PaymentError {
  ValidationError(String message) : super(message);
}

class DuplicateReferenceError extends PaymentError {
  DuplicateReferenceError(String message) : super(message);
}

class RateLimitError extends PaymentError {
  RateLimitError(String message) : super(message);
}

class NotFoundError extends PaymentError {
  NotFoundError(String message) : super(message);
}

class FirestoreOperationError extends PaymentError {
  FirestoreOperationError(String message) : super(message);
}

enum ErrorCategory {
  validation,
  duplicate,
  rateLimit,
  notFound,
  firestore,
  unknown,
}

class _TtlEntry<T> {
  final T value;
  final DateTime expiresAt;
  _TtlEntry(this.value, this.expiresAt);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class PaymentMemoryCache {
  static final Map<String, _TtlEntry<Map<String, dynamic>>> _systemStats = {};
  static final Map<String, _TtlEntry<List<Map<String, dynamic>>>> _refSearch =
  {};

  static Duration systemStatsTtl = const Duration(minutes: 5);
  static Duration referenceSearchTtl = const Duration(seconds: 60);

  static Map<String, dynamic>? getSystemStats() {
    final e = _systemStats['system'];
    if (e == null || e.isExpired) return null;
    return e.value;
  }

  static void setSystemStats(Map<String, dynamic> stats) {
    _systemStats['system'] = _TtlEntry(
      stats,
      DateTime.now().add(systemStatsTtl),
    );
  }

  static List<Map<String, dynamic>>? getReferenceSearch(String ref) {
    final e = _refSearch[ref];
    if (e == null || e.isExpired) return null;
    return e.value;
  }

  static void setReferenceSearch(
      String ref,
      List<Map<String, dynamic>> results,
      ) {
    _refSearch[ref] = _TtlEntry(
      results,
      DateTime.now().add(referenceSearchTtl),
    );
  }

  static void clearReference(String ref) {
    _refSearch.remove(ref);
  }
}

class RateLimiter {
  static final Map<String, List<DateTime>> _ops = {};

  static void checkAndConsume(
      String key, {
        int maxOps = 20,
        Duration per = const Duration(minutes: 1),
      }) {
    final now = DateTime.now();
    final windowStart = now.subtract(per);
    final recent =
    (_ops[key] ?? []).where((t) => t.isAfter(windowStart)).toList();
    if (recent.length >= maxOps) {
      throw RateLimitError('تم تجاوز الحد المسموح للعمليات. حاول لاحقاً');
    }
    recent.add(now);
    _ops[key] = recent;
  }
}

class Retry {
  static Future<T> withRetry<T>(
      Future<T> Function() fn, {
        int maxAttempts = 3,
        Duration initialDelay = const Duration(milliseconds: 200),
      }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    late Object lastError;
    while (attempt < maxAttempts) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        attempt++;
        if (attempt >= maxAttempts) break;
        await Future.delayed(delay);
        delay *= 2;
      }
    }
    throw lastError;
  }
}

class PerformanceMonitor {
  static const Duration slowThreshold = Duration(seconds: 2);
  static void track(String name, Stopwatch sw) {
    sw.stop();
    DebtorsFirestoreLogger.logPerformance(name, sw.elapsed);
    if (sw.elapsed > slowThreshold) {
      DebtorsFirestoreLogger.logOperation(
        'PERF_ALERT',
        'Operation $name is slow: ${sw.elapsed}',
        isError: true,
      );
    }
  }
}

class PageResult<T> {
  final List<T> items;
  final DocumentSnapshot? nextCursor;
  final bool hasMore;
  PageResult({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}

abstract class NotificationHandler {
  Future<void> sendDuePaymentNotification({
    required String debtorId,
    required int amount,
    required DateTime dueAt,
  });
}

class PaymentRepository {
  static CollectionReference<Map<String, dynamic>> debtorPayments(
      String debtorId,
      ) => DebtorsCollection.doc(debtorId).collection('payments');

  static CollectionReference<Map<String, dynamic>> get referenceClaims =>
      FirebaseFirestore.instance.collection('payment_references');

  static CollectionReference<Map<String, dynamic>> get scheduledPaymentsRoot =>
      FirebaseFirestore.instance.collection('scheduled_payments');

  static CollectionReference<Map<String, dynamic>> get auditLogs =>
      FirebaseFirestore.instance.collection('auditLogs');

  static Future<PageResult<Map<String, dynamic>>> fetchDebtorPaymentsPage({
    required String debtorId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = debtorPayments(
      debtorId,
    ).orderBy('createdAt', descending: true);
    if (startAfter != null) {
      query = (query as Query<Map<String, dynamic>>).startAfterDocument(
        startAfter,
      );
    }
    final snap = await query.limit(limit).get();
    final items =
    snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'amount': (data['amount'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'],
        'notes': data['notes'] as String? ?? '',
        'paymentMethod': data['paymentMethod'] as String? ?? 'نقداً',
        'referenceNumber': data['referenceNumber'] as String? ?? '',
        'debtAllocations': (data['debtAllocations'] as List?) ?? const [],
        'isPartialPayment': data['isPartialPayment'] as bool? ?? false,
        'addedAt': data['addedAt'],
        'updatedAt': data['updatedAt'],
      };
    }).toList();
    final last = snap.docs.isNotEmpty ? snap.docs.last : null;
    return PageResult(
      items: items,
      nextCursor: last,
      hasMore: last != null && snap.docs.length == limit,
    );
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamDebtorPayments(
      String debtorId, {
        int limit = 50,
      }) {
    return debtorPayments(
      debtorId,
    ).orderBy('createdAt', descending: true).limit(limit).snapshots();
  }
}

class PaymentService {
  static NotificationHandler? _notifications;
  static void configure({NotificationHandler? notifications}) {
    _notifications = notifications;
  }

  static Future<Map<String, dynamic>> getSystemStatsCached(
      Future<Map<String, dynamic>> Function() loader,
      ) async {
    final cached = PaymentMemoryCache.getSystemStats();
    if (cached != null && cached.isNotEmpty) return cached;
    final stats = await loader();
    if (stats.isNotEmpty) PaymentMemoryCache.setSystemStats(stats);
    return stats;
  }

  static Future<List<Map<String, dynamic>>> searchByReferenceCached(
      String referenceNumber,
      Future<List<Map<String, dynamic>>> Function() loader,
      ) async {
    final trimmed = referenceNumber.trim();
    if (trimmed.isEmpty) return [];
    final cached = PaymentMemoryCache.getReferenceSearch(trimmed);
    if (cached != null) return cached;
    final results = await loader();
    PaymentMemoryCache.setReferenceSearch(trimmed, results);
    return results;
  }

  static Future<void> writeAudit({
    required String action,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await PaymentRepository.auditLogs.add({
        'action': action,
        'description': description,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<String?> schedulePayment({
    required String debtorId,
    required int amount,
    required DateTime scheduledFor,
    String? notes,
    String? paymentMethod,
    String? paymentSource,
    String? referenceNumber,
    String? invoiceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (amount <= 0) throw ValidationError('قيمة المبلغ غير صحيحة');
      if (scheduledFor.isBefore(
        DateTime.now().subtract(const Duration(minutes: 1)),
      )) {
        throw ValidationError('تاريخ الجدولة يجب أن يكون مستقبلياً');
      }
      final doc = await PaymentRepository.scheduledPaymentsRoot.add({
        'debtorId': debtorId,
        'amount': amount,
        'scheduledAt': Timestamp.fromDate(scheduledFor),
        'status': 'pending',
        'notes': notes ?? '',
        'paymentMethod': paymentMethod ?? 'نقداً',
        'paymentSource': paymentSource ?? 'app',
        'referenceNumber': referenceNumber?.trim(),
        'invoiceId': invoiceId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await writeAudit(
        action: 'SCHEDULE_PAYMENT',
        description: 'Scheduled payment for $debtorId on $scheduledFor',
        metadata: {'scheduledPaymentId': doc.id},
      );
      return doc.id;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        'SCHEDULE_PAYMENT',
        'Error: $e',
        isError: true,
      );
      return null;
    } finally {
      PerformanceMonitor.track('SCHEDULE_PAYMENT', stopwatch);
    }
  }

  static Future<int> processDueScheduledPayments({int limit = 20}) async {
    final stopwatch = Stopwatch()..start();
    int processed = 0;
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final q =
      await PaymentRepository.scheduledPaymentsRoot
          .where('status', isEqualTo: 'pending')
          .where('scheduledAt', isLessThanOrEqualTo: now)
          .orderBy('scheduledAt')
          .limit(limit)
          .get();
      for (final doc in q.docs) {
        final data = doc.data();
        final debtorId = data['debtorId'] as String?;
        final int amount = (data['amount'] as num?)?.toInt() ?? 0;
        final String? notes = data['notes'] as String?;
        final String? paymentMethod = data['paymentMethod'] as String?;
        final String? paymentSource = data['paymentSource'] as String?;
        final String? referenceNumber = data['referenceNumber'] as String?;
        final String? invoiceId = data['invoiceId'] as String?;
        if (debtorId == null || amount <= 0) continue;
        try {
          final ok = await Retry.withRetry(
                () => addPayment(
              debtorId: debtorId,
              amount: amount,
              date: DateTime.now(),
              notes: notes,
              paymentMethod: paymentMethod,
              referenceNumber: referenceNumber,
              paymentSource: paymentSource,
              invoiceId: invoiceId,
            ),
          );
          if (ok) {
            await doc.reference.update({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
            });
            processed++;
            if (_notifications != null) {
              try {
                await _notifications!.sendDuePaymentNotification(
                  debtorId: debtorId,
                  amount: amount,
                  dueAt: (data['scheduledAt'] as Timestamp).toDate(),
                );
              } catch (_) {}
            }
          }
        } catch (e) {
          await doc.reference.update({
            'status': 'failed',
            'failureReason': e.toString(),
            'failedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        'PROCESS_DUE_SCHEDULED_PAYMENTS',
        'Error: $e',
        isError: true,
      );
    } finally {
      PerformanceMonitor.track('PROCESS_DUE_SCHEDULED_PAYMENTS', stopwatch);
    }
    return processed;
  }
}

// ================== دوال إدارة المدفوعات ==================

/// إضافة دفعة محسن
Future<bool> addPayment({
  required String debtorId,
  required int amount,
  required DateTime date,
  String? notes,
  String? paymentMethod,
  String? referenceNumber,
  String? paymentSource,
  String? invoiceId,
}) async {
  final stopwatch = Stopwatch()..start();

  try {
    // Rate limiting + تحقق أساسي
    try {
      RateLimiter.checkAndConsume(
        'addPayment:$debtorId',
        maxOps: 30,
        per: const Duration(minutes: 1),
      );
    } catch (e) {
      throw RateLimitError(e.toString());
    }
    final amountError = DebtorsDataValidator.validateAmount(amount);
    if (amountError != null) throw Exception(amountError);
    if (amount <= 0) throw ValidationError('قيمة المبلغ غير صحيحة');

    final debtorRef = DebtorsCollection.doc(debtorId);
    final paymentsRef = debtorRef.collection('payments');

    await Retry.withRetry(
          () => FirebaseFirestore.instance.runTransaction((transaction) async {
        // التحقق من وجود العميل
        final debtorSnapshot = await transaction.get(debtorRef);
        if (!debtorSnapshot.exists) {
          throw Exception('العميل غير موجود');
        }

        final debtorData = debtorSnapshot.data() as Map<String, dynamic>;
        final currentDebt = (debtorData['currentDebt'] as int?) ?? 0;
        // تحسين: تخزين معلومات العميل مع الدفعة لتسهيل الاستعلامات لاحقاً
        // هذا يساعدنا على استخدام collectionGroup بدون جلب مستند العميل لكل دفعة
        final debtorName = debtorData['name'] as String?;
        final debtorPhone = debtorData['phone'] as String?;

        if (amount > currentDebt) {
          throw Exception(
            'المبلغ المدفوع أكبر من الدين المتبقي ($currentDebt جنيه)',
          );
        }

        // إعداد بيانات الدفعة
        final paymentData = {
          'amount': amount,
          'createdAt': Timestamp.fromDate(date),
          'notes': notes ?? '',
          'paymentMethod': paymentMethod ?? 'نقداً',
          'addedAt': FieldValue.serverTimestamp(),
          // تغيير رئيسي: إضافة معرف العميل ومعلوماته لتسريع الاستعلامات الشاملة
          'debtorId': debtorId,
          'paymentSource': paymentSource ?? 'app',
          if (invoiceId != null) 'invoiceId': invoiceId,
          if (debtorName != null) 'debtorName': debtorName,
          if (debtorPhone != null) 'debtorPhone': debtorPhone,
        };

        // إضافة الرقم المرجعي إذا تم تحديده
        if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
          final ref = referenceNumber.trim();
          paymentData['referenceNumber'] = ref;
          // منع التكرار عبر حجز الرقم المرجعي
          final claimRef = PaymentRepository.referenceClaims.doc(ref);
          final claimSnap = await transaction.get(claimRef);
          if (claimSnap.exists) {
            throw DuplicateReferenceError('هذا الرقم المرجعي مستخدم بالفعل');
          }
          final paymentDocRef = paymentsRef.doc();
          transaction.set(claimRef, {
            'debtorId': debtorId,
            'claimedAt': FieldValue.serverTimestamp(),
            'paymentPath': paymentDocRef.path,
          });
          transaction.set(paymentDocRef, paymentData);
        } else {
          // إضافة الدفعة بدون رقم مرجعي
          transaction.set(paymentsRef.doc(), paymentData);
        }

        // تحديث إجماليات العميل
        transaction.update(debtorRef, {
          'totalPaid': FieldValue.increment(amount),
          'currentDebt': FieldValue.increment(-amount),
          'lastPaymentAt': Timestamp.fromDate(date),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(1),
        });

        // مسح الcache (تغيير: استخدام EnhancedCacheManager بدلاً من DebtorCache)
        EnhancedCacheManager.clearDebtorCache(debtorId);
      }),
    );

    PerformanceMonitor.track("ADD_PAYMENT", stopwatch);
    DebtorsFirestoreLogger.logOperation(
      "ADD_PAYMENT",
      "Successfully added payment: $amount for $debtorId",
    );

    // ربط الفاتورة إن وجدت (non-critical)
    if (invoiceId != null && invoiceId.trim().isNotEmpty) {
      try {
        final invoiceRef = FirebaseFirestore.instance
            .collection('invoices')
            .doc(invoiceId);
        await invoiceRef.update({
          'amountPaid': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    // سجل تدقيق
    unawaited(
      PaymentService.writeAudit(
        action: 'ADD_PAYMENT',
        description: 'Add payment $amount for $debtorId',
        metadata: {
          'debtorId': debtorId,
          'amount': amount,
          'referenceNumber': referenceNumber,
          'invoiceId': invoiceId,
        },
      ),
    );

    return true;
  } catch (e) {
    stopwatch.stop();
    final category =
    e is ValidationError
        ? ErrorCategory.validation
        : e is DuplicateReferenceError
        ? ErrorCategory.duplicate
        : e is RateLimitError
        ? ErrorCategory.rateLimit
        : ErrorCategory.firestore;
    DebtorsFirestoreLogger.logOperation(
      "ADD_PAYMENT",
      "${category.toString()}: $e",
      isError: true,
    );
    return false;
  }
}

/// إضافة دفعة جزئية مع ربطها بديون محددة
Future<bool> addPartialPayment({
  required String debtorId,
  required int amount,
  required DateTime date,
  required List<Map<String, dynamic>>
  debtAllocations, // [{'debtId': 'id', 'amount': 100}]
  String? notes,
  String? paymentMethod,
  String? referenceNumber,
  String? paymentSource,
  String? invoiceId,
}) async {
  final stopwatch = Stopwatch()..start();

  try {
    try {
      RateLimiter.checkAndConsume(
        'addPartialPayment:$debtorId',
        maxOps: 30,
        per: const Duration(minutes: 1),
      );
    } catch (e) {
      throw RateLimitError(e.toString());
    }
    final amountError = DebtorsDataValidator.validateAmount(amount);
    if (amountError != null) throw Exception(amountError);

    // التحقق من أن مجموع التخصيصات يساوي المبلغ المدفوع
    final allocatedTotal = debtAllocations.fold<int>(
      0,
          (sum, allocation) => sum + (allocation['amount'] as int),
    );

    if (allocatedTotal != amount) {
      throw Exception(
        'مجموع التخصيصات ($allocatedTotal) لا يساوي المبلغ المدفوع ($amount)',
      );
    }

    final debtorRef = DebtorsCollection.doc(debtorId);
    final paymentsRef = debtorRef.collection('payments');

    await Retry.withRetry(
          () => FirebaseFirestore.instance.runTransaction((transaction) async {
        // التحقق من وجود العميل
        final debtorSnapshot = await transaction.get(debtorRef);
        if (!debtorSnapshot.exists) {
          throw Exception('العميل غير موجود');
        }

        // تحسين: الحصول على معلومات العميل لتخزينها مع الدفعة لتسريع الاستعلامات لاحقاً
        final debtorData = debtorSnapshot.data() as Map<String, dynamic>;
        final debtorName = debtorData['name'] as String?;
        final debtorPhone = debtorData['phone'] as String?;

        // التحقق من وجود الديون المحددة
        for (final allocation in debtAllocations) {
          final debtId = allocation['debtId'] as String;
          final debtRef = debtorRef.collection('debts').doc(debtId);
          final debtSnapshot = await transaction.get(debtRef);

          if (!debtSnapshot.exists) {
            throw Exception('الدين $debtId غير موجود');
          }
        }

        final Map<String, dynamic> partialData = {
          'amount': amount,
          'createdAt': Timestamp.fromDate(date),
          'notes': notes ?? '',
          'paymentMethod': paymentMethod ?? 'نقداً',
          'debtAllocations': debtAllocations,
          'isPartialPayment': true,
          'addedAt': FieldValue.serverTimestamp(),
          // تغيير رئيسي: إضافة معرف العميل ومعلوماته لتسريع الاستعلامات الشاملة
          'debtorId': debtorId,
          'paymentSource': paymentSource ?? 'app',
          if (invoiceId != null) 'invoiceId': invoiceId,
          if (debtorName != null) 'debtorName': debtorName,
          if (debtorPhone != null) 'debtorPhone': debtorPhone,
        };

        if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
          final ref = referenceNumber.trim();
          partialData['referenceNumber'] = ref;
          final claimRef = PaymentRepository.referenceClaims.doc(ref);
          final claimSnap = await transaction.get(claimRef);
          if (claimSnap.exists) {
            throw DuplicateReferenceError('هذا الرقم المرجعي مستخدم بالفعل');
          }
          final paymentDocRef = paymentsRef.doc();
          transaction.set(claimRef, {
            'debtorId': debtorId,
            'claimedAt': FieldValue.serverTimestamp(),
            'paymentPath': paymentDocRef.path,
          });
          transaction.set(paymentDocRef, partialData);
        } else {
          transaction.set(paymentsRef.doc(), partialData);
        }

        // تحديث إجماليات العميل
        transaction.update(debtorRef, {
          'totalPaid': FieldValue.increment(amount),
          'currentDebt': FieldValue.increment(-amount),
          'lastPaymentAt': Timestamp.fromDate(date),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(1),
        });

        // مسح الcache (تغيير: استخدام EnhancedCacheManager)
        EnhancedCacheManager.clearDebtorCache(debtorId);
      }),
    );

    PerformanceMonitor.track("ADD_PARTIAL_PAYMENT", stopwatch);
    DebtorsFirestoreLogger.logOperation(
      "ADD_PARTIAL_PAYMENT",
      "Successfully added partial payment: $amount for $debtorId",
    );

    unawaited(
      PaymentService.writeAudit(
        action: 'ADD_PARTIAL_PAYMENT',
        description: 'Partial payment $amount for $debtorId',
        metadata: {
          'debtorId': debtorId,
          'amount': amount,
          'referenceNumber': referenceNumber,
          'invoiceId': invoiceId,
        },
      ),
    );

    return true;
  } catch (e) {
    stopwatch.stop();
    // إصلاح: استخدام e.toString() بدلاً من دالة غير موجودة getErrorMessage
    DebtorsFirestoreLogger.logOperation(
      "ADD_PARTIAL_PAYMENT",
      "${e is DuplicateReferenceError ? 'duplicate' : 'error'}: $e",
      isError: true,
    );
    return false;
  }
}

/// تحديث دفعة معينة
Future<void> updatePayment({
  required String debtorId,
  required String paymentId,
  int? newAmount,
  DateTime? newDate,
  String? notes,
  String? paymentMethod,
}) async {
  final debtorRef = DebtorsCollection.doc(debtorId);
  final paymentRef = debtorRef.collection('payments').doc(paymentId);

  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // جلب الدفعة الحالية
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists) {
        throw Exception('الدفعة غير موجودة');
      }

      final currentPaymentData = paymentSnapshot.data() as Map<String, dynamic>;
      final oldAmount = currentPaymentData['amount'] as int;

      final Map<String, dynamic> paymentUpdates = {};

      if (newAmount != null) {
        final amountError = DebtorsDataValidator.validateAmount(newAmount);
        if (amountError != null) throw Exception(amountError);
        paymentUpdates['amount'] = newAmount;
      }

      if (newDate != null) {
        paymentUpdates['createdAt'] = Timestamp.fromDate(newDate);
      }

      if (notes != null) {
        paymentUpdates['notes'] = notes;
      }

      if (paymentMethod != null) {
        paymentUpdates['paymentMethod'] = paymentMethod;
      }

      if (paymentUpdates.isEmpty) {
        throw Exception('لم يتم تحديد أي بيانات للتحديث');
      }

      paymentUpdates['updatedAt'] = FieldValue.serverTimestamp();

      // تحديث الدفعة
      transaction.update(paymentRef, paymentUpdates);

      // تحديث إجماليات العميل (إذا تغير المبلغ)
      if (newAmount != null && newAmount != oldAmount) {
        final difference = newAmount - oldAmount;

        transaction.update(debtorRef, {
          'totalPaid': FieldValue.increment(difference),
          'currentDebt': FieldValue.increment(-difference),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // مسح الcache (تغيير: استخدام EnhancedCacheManager)
      EnhancedCacheManager.clearDebtorCache(debtorId);
    });

    DebtorsFirestoreLogger.logOperation(
      "UPDATE_PAYMENT",
      "Successfully updated payment: $paymentId",
    );
  } catch (e) {
    // إصلاح: استخدام e.toString()
    DebtorsFirestoreLogger.logOperation("UPDATE_PAYMENT", "Error: $e", isError: true);
    rethrow;
  }
}

/// حذف دفعة معينة
Future<void> deletePayment({
  required String debtorId,
  required String paymentId,
}) async {
  final debtorRef = DebtorsCollection.doc(debtorId);
  final paymentRef = debtorRef.collection('payments').doc(paymentId);

  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // جلب بيانات الدفعة قبل الحذف
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists) {
        throw Exception('الدفعة غير موجودة');
      }

      final paymentData = paymentSnapshot.data() as Map<String, dynamic>;
      final paymentAmount = paymentData['amount'] as int;
      final refNum = (paymentData['referenceNumber'] as String?)?.trim();

      // حذف الدفعة
      transaction.delete(paymentRef);

      // إزالة حجز الرقم المرجعي إن وجد
      if (refNum != null && refNum.isNotEmpty) {
        final claimRef = PaymentRepository.referenceClaims.doc(refNum);
        transaction.delete(claimRef);
        PaymentMemoryCache.clearReference(refNum);
      }

      // تحديث إجماليات العميل
      transaction.update(debtorRef, {
        'totalPaid': FieldValue.increment(-paymentAmount),
        'currentDebt': FieldValue.increment(paymentAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // مسح الcache (تغيير: استخدام EnhancedCacheManager)
      EnhancedCacheManager.clearDebtorCache(debtorId);
    });

    DebtorsFirestoreLogger.logOperation(
      "DELETE_PAYMENT",
      "Successfully deleted payment: $paymentId",
    );
    unawaited(
      PaymentService.writeAudit(
        action: 'DELETE_PAYMENT',
        description: 'Delete payment $paymentId for $debtorId',
        metadata: {'debtorId': debtorId, 'paymentId': paymentId},
      ),
    );
  } catch (e) {
    DebtorsFirestoreLogger.logOperation("DELETE_PAYMENT", "Error: $e", isError: true);
    rethrow;
  }
}

/// جلب مدفوعات عميل معين
Future<List<Map<String, dynamic>>> fetchDebtorPayments(String debtorId) async {
  try {
    // استخدام ترحيل داخلي لتجنّب جلب ضخم مرة واحدة
    final List<Map<String, dynamic>> all = [];
    DocumentSnapshot? cursor;
    const int pageSize = 200;
    while (true) {
      final page = await PaymentRepository.fetchDebtorPaymentsPage(
        debtorId: debtorId,
        limit: pageSize,
        startAfter: cursor,
      );
      all.addAll(page.items);
      if (!page.hasMore) break;
      cursor = page.nextCursor;
    }
    return all;
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "FETCH_DEBTOR_PAYMENTS",
      "Error: $e",
      isError: true,
    );
    return [];
  }
}

/// جلب مدفوعات عميل مع فلترة
Future<List<Map<String, dynamic>>> fetchDebtorPaymentsFiltered({
  required String debtorId,
  DateTime? startDate,
  DateTime? endDate,
  int? minAmount,
  int? maxAmount,
  String? paymentMethod,
  bool? isPartialPayment,
  int limit = 50,
}) async {
  try {
    Query query = DebtorsCollection.doc(
      debtorId,
    ).collection('payments').orderBy('createdAt', descending: true);

    // ملاحظة مهمة (تغيير رئيسي): Firestore لا يسمح باستخدام عوامل مقارنة (range) على أكثر من حقل واحد في نفس الاستعلام.
    // لذلك إذا تم تحديد نطاق للتاريخ، سنطبّق فلاتر المبلغ على جهة العميل بعد الجلب.
    final bool hasDateRange = startDate != null || endDate != null;
    final bool hasAmountRange = minAmount != null || maxAmount != null;
    final bool filterAmountClientSide = hasDateRange && hasAmountRange;

    // فلتر التاريخ (خادمياً)
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

    // فلتر المبلغ (خادمياً فقط إذا لم يكن هناك فلتر تاريخ)
    if (!hasDateRange) {
      if (minAmount != null) {
        query = query.where('amount', isGreaterThanOrEqualTo: minAmount);
      }
      if (maxAmount != null) {
        query = query.where('amount', isLessThanOrEqualTo: maxAmount);
      }
    }

    // فلتر طريقة الدفع
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      query = query.where('paymentMethod', isEqualTo: paymentMethod);
    }

    // فلتر نوع الدفعة
    if (isPartialPayment != null) {
      query = query.where('isPartialPayment', isEqualTo: isPartialPayment);
    }

    // إذا كنا سنفلتر المبلغ على جهة العميل، زدنا حد الجلب قليلاً لتحسين النتائج بعد الفلترة
    final int serverLimit = filterAmountClientSide ? (limit * 3) : limit;
    final snapshot = await query.limit(serverLimit).get();

    final mapped =
    snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'amount': (data['amount'] as num?)?.toInt() ?? 0,
        'createdAt': data['createdAt'],
        'notes': data['notes'] as String? ?? '',
        'paymentMethod': data['paymentMethod'] as String? ?? 'نقداً',
        'referenceNumber': data['referenceNumber'] as String? ?? '',
        'debtAllocations': (data['debtAllocations'] as List?) ?? const [],
        'isPartialPayment': data['isPartialPayment'] as bool? ?? false,
      };
    }).toList();

    // فلتر المبلغ (عميل)
    final filtered =
    filterAmountClientSide
        ? mapped.where((m) {
      final amt = (m['amount'] as int);
      if (minAmount != null && amt < minAmount) return false;
      if (maxAmount != null && amt > maxAmount) return false;
      return true;
    }).toList()
        : mapped;

    return filtered.take(limit).toList();
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "FETCH_DEBTOR_PAYMENTS_FILTERED",
      "Error: $e",
      isError: true,
    );
    return [];
  }
}

/// جلب تفاصيل دفعة معينة
Future<Map<String, dynamic>?> getPaymentDetails({
  required String debtorId,
  required String paymentId,
}) async {
  try {
    final paymentDoc =
    await DebtorsCollection.doc(
      debtorId,
    ).collection('payments').doc(paymentId).get();

    if (!paymentDoc.exists) {
      return null;
    }

    final data = paymentDoc.data() as Map<String, dynamic>;
    return {
      'id': paymentDoc.id,
      'amount': data['amount'] ?? 0,
      'createdAt': data['createdAt'],
      'notes': data['notes'] ?? '',
      'paymentMethod': data['paymentMethod'] ?? 'نقداً',
      'referenceNumber': data['referenceNumber'] ?? '',
      'debtAllocations': data['debtAllocations'] ?? [],
      'isPartialPayment': data['isPartialPayment'] ?? false,
      'addedAt': data['addedAt'],
      'updatedAt': data['updatedAt'],
    };
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "GET_PAYMENT_DETAILS",
      "Error: $e",
      isError: true,
    );
    return null;
  }
}

/// جلب إحصائيات المدفوعات لعميل معين
Future<Map<String, dynamic>> getDebtorPaymentStatistics(String debtorId) async {
  try {
    final paymentsSnapshot =
    await DebtorsCollection.doc(debtorId).collection('payments').get();

    int totalPayments = 0;
    int totalAmount = 0;
    int totalPartialPayments = 0;
    int totalRegularPayments = 0;

    DateTime? firstPayment;
    DateTime? lastPayment;
    int maxPaymentAmount = 0;
    int minPaymentAmount = 0;

    final Map<String, int> paymentMethods = {};
    final Map<String, int> monthlyPayments = {};

    for (var doc in paymentsSnapshot.docs) {
      final data = doc.data();
      // إصلاح: تحويلات آمنة لتجنب أخطاء النوع مع null
      final amount = (data['amount'] as num?)?.toInt() ?? 0;
      final isPartial = data['isPartialPayment'] as bool? ?? false;
      final paymentMethod = data['paymentMethod'] as String? ?? 'نقداً';
      final createdAt = data['createdAt'] as Timestamp?;

      totalPayments++;
      totalAmount += amount;

      if (isPartial) {
        totalPartialPayments++;
      } else {
        totalRegularPayments++;
      }

      // تتبع أعلى وأقل مبلغ
      if (maxPaymentAmount == 0 || amount > maxPaymentAmount) {
        maxPaymentAmount = amount;
      }
      if (minPaymentAmount == 0 || amount < minPaymentAmount) {
        minPaymentAmount = amount;
      }

      // إحصائيات طرق الدفع
      paymentMethods[paymentMethod] = (paymentMethods[paymentMethod] ?? 0) + 1;

      // تتبع التواريخ
      if (createdAt != null) {
        final paymentDate = createdAt.toDate();
        if (firstPayment == null || paymentDate.isBefore(firstPayment)) {
          firstPayment = paymentDate;
        }
        if (lastPayment == null || paymentDate.isAfter(lastPayment)) {
          lastPayment = paymentDate;
        }

        // إحصائيات شهرية
        final monthKey =
            "${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}";
        monthlyPayments[monthKey] = (monthlyPayments[monthKey] ?? 0) + amount;
      }
    }

    return {
      'totalPayments': totalPayments,
      'totalAmount': totalAmount,
      'totalPartialPayments': totalPartialPayments,
      'totalRegularPayments': totalRegularPayments,
      'averagePaymentAmount':
      totalPayments > 0 ? (totalAmount / totalPayments).round() : 0,
      'maxPaymentAmount': maxPaymentAmount,
      'minPaymentAmount': totalPayments > 0 ? minPaymentAmount : 0,
      'paymentMethodsBreakdown': paymentMethods,
      'monthlyBreakdown': monthlyPayments,
      'firstPayment': firstPayment?.toIso8601String(),
      'lastPayment': lastPayment?.toIso8601String(),
      'paymentFrequency': _calculatePaymentFrequency(
        firstPayment,
        lastPayment,
        totalPayments,
      ),
    };
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "GET_DEBTOR_PAYMENT_STATISTICS",
      "Error: $e",
      isError: true,
    );
    return {};
  }
}

/// البحث في المدفوعات بالرقم المرجعي
Future<List<Map<String, dynamic>>> searchPaymentsByReference(
    String referenceNumber,
    ) async {
  try {
    // Rate limit + Cache نتائج البحث القصير
    try {
      RateLimiter.checkAndConsume(
        'searchRef:${referenceNumber.trim()}',
        maxOps: 60,
        per: const Duration(minutes: 1),
      );
    } catch (e) {
      throw RateLimitError(e.toString());
    }
    final results = await PaymentService.searchByReferenceCached(
      referenceNumber,
          () async {
        final q =
        await FirebaseFirestore.instance
            .collectionGroup('payments')
            .where('referenceNumber', isEqualTo: referenceNumber.trim())
            .get();

        final List<Map<String, dynamic>> out = [];
        final Map<String, Map<String, dynamic>> debtorInfoCache = {};
        for (final paymentDoc in q.docs) {
          final paymentData = paymentDoc.data();
          String? debtorId = paymentData['debtorId'] as String?;
          String? debtorName = paymentData['debtorName'] as String?;
          String? debtorPhone = paymentData['debtorPhone'] as String?;

          debtorId ??= paymentDoc.reference.parent.parent?.id;

          if ((debtorName == null || debtorPhone == null) && debtorId != null) {
            var cached = debtorInfoCache[debtorId];
            if (cached == null) {
              try {
                final debtorRef = DebtorsCollection.doc(debtorId);
                final debtorSnap = await debtorRef.get();
                if (debtorSnap.exists) {
                  cached = (debtorSnap.data() as Map<String, dynamic>);
                  debtorInfoCache[debtorId] = cached;
                }
              } catch (_) {}
            }
            debtorName ??= cached?['name'] as String?;
            debtorPhone ??= cached?['phone'] as String?;
          }

          out.add({
            'paymentId': paymentDoc.id,
            'debtorId': debtorId,
            'debtorName': debtorName,
            'debtorPhone': debtorPhone,
            'amount': paymentData['amount'] ?? 0,
            'createdAt': paymentData['createdAt'],
            'paymentMethod': paymentData['paymentMethod'] ?? 'نقداً',
            'referenceNumber': paymentData['referenceNumber'],
            'notes': paymentData['notes'] ?? '',
          });
        }
        return out;
      },
    );
    return results;
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "SEARCH_PAYMENTS_BY_REFERENCE",
      "Error: $e",
      isError: true,
    );
    return [];
  }
}

/// إضافة عدة مدفوعات لعملاء مختلفين
Future<bool> addMultiplePayments(List<Map<String, dynamic>> payments) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    // تحسين الأداء: تخزين Snapshot لكل عميل لتجنب جلبه مراراً
    final Map<String, Map<String, dynamic>?> debtorSnapshotCache = {};

    for (final payment in payments) {
      final debtorId = payment['debtorId'] as String;
      final amount = payment['amount'] as int;
      final date = payment['date'] as DateTime;

      final debtorRef = DebtorsCollection.doc(debtorId);
      final paymentRef = debtorRef.collection('payments').doc();

      // تحسين: جلب معلومات العميل مرة واحدة لكل عميل في هذه المجموعة باستخدام Cache محلي
      Map<String, dynamic>? debtorData = debtorSnapshotCache[debtorId];
      if (!debtorSnapshotCache.containsKey(debtorId)) {
        final debtorSnapshot = await debtorRef.get();
        debtorData =
        debtorSnapshot.exists
            ? debtorSnapshot.data() as Map<String, dynamic>
            : null;
        debtorSnapshotCache[debtorId] = debtorData;
      }
      final debtorName = debtorData?['name'] as String?;
      final debtorPhone = debtorData?['phone'] as String?;

      // إضافة المدفوعة
      batch.set(paymentRef, {
        'amount': amount,
        'createdAt': Timestamp.fromDate(date),
        'notes': payment['notes'] ?? '',
        'paymentMethod': payment['paymentMethod'] ?? 'نقداً',
        'referenceNumber': payment['referenceNumber'] ?? '',
        'addedAt': FieldValue.serverTimestamp(),
        // تغيير رئيسي: إضافة معرف العميل ومعلوماته لتسريع الاستعلامات الشاملة
        'debtorId': debtorId,
        if (debtorName != null) 'debtorName': debtorName,
        if (debtorPhone != null) 'debtorPhone': debtorPhone,
      });

      // تحديث إجماليات العميل
      batch.update(debtorRef, {
        'totalPaid': FieldValue.increment(amount),
        'currentDebt': FieldValue.increment(-amount),
        'lastPaymentAt': Timestamp.fromDate(date),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // مسح الcache (تغيير: استخدام EnhancedCacheManager)
      EnhancedCacheManager.clearDebtorCache(debtorId);
    }

    await batch.commit();
    DebtorsFirestoreLogger.logOperation(
      "ADD_MULTIPLE_PAYMENTS",
      "Successfully added ${payments.length} payments",
    );
    return true;
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "ADD_MULTIPLE_PAYMENTS",
      "Error: $e",
      isError: true,
    );
    return false;
  }
}

/// جلب آخر المدفوعات المضافة عبر النظام
Future<List<Map<String, dynamic>>> getRecentPayments({int limit = 20}) async {
  try {
    // تغيير رئيسي: استخدام collectionGroup للعثور على أحدث المدفوعات على مستوى النظام بكفاءة
    final q =
    await FirebaseFirestore.instance
        .collectionGroup('payments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    // الحفاظ على التوافق: تعويض أي بيانات عميل مفقودة من المسار أو من الوثيقة الأصلية
    final List<Map<String, dynamic>> recentPayments = [];
    final Map<String, Map<String, dynamic>> debtorInfoCache = {};

    for (final doc in q.docs) {
      final data = doc.data();
      String? debtorId =
          data['debtorId'] as String? ?? doc.reference.parent.parent?.id;
      String? debtorName = data['debtorName'] as String?;
      String? debtorPhone = data['debtorPhone'] as String?;

      if ((debtorName == null || debtorPhone == null) && debtorId != null) {
        var cached = debtorInfoCache[debtorId];
        if (cached == null) {
          try {
            final debtorSnap = await DebtorsCollection.doc(debtorId).get();
            if (debtorSnap.exists) {
              cached = (debtorSnap.data() as Map<String, dynamic>);
              debtorInfoCache[debtorId] = cached;
            }
          } catch (_) {}
        }
        debtorName ??= cached?['name'] as String?;
        debtorPhone ??= cached?['phone'] as String?;
      }

      recentPayments.add({
        'paymentId': doc.id,
        'debtorId': debtorId,
        'debtorName': debtorName,
        'debtorPhone': debtorPhone,
        'amount': data['amount'] ?? 0,
        'createdAt': data['createdAt'],
        'paymentMethod': data['paymentMethod'] ?? 'نقداً',
        'notes': data['notes'] ?? '',
      });
    }

    return recentPayments;
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "GET_RECENT_PAYMENTS",
      "Error: $e",
      isError: true,
    );
    return [];
  }
}

/// جلب إحصائيات شاملة لجميع المدفوعات في النظام
Future<Map<String, dynamic>> getSystemPaymentStatistics() async {
  try {
    // Cache: إرجاع الإحصائيات من الذاكرة إذا كانت متاحة
    return await PaymentService.getSystemStatsCached(() async {
      int totalPayments = 0;
      int totalAmount = 0;
      int totalPartialPayments = 0;
      int totalRegularPayments = 0;

      final Map<String, int> paymentMethods = {};
      final Map<String, int> monthlyPayments = {};
      int maxPaymentAmount = 0;
      int minPaymentAmount = 0;

      final paymentsSnapshot =
      await FirebaseFirestore.instance.collectionGroup('payments').get();

      for (var paymentDoc in paymentsSnapshot.docs) {
        final paymentData = paymentDoc.data();
        final amount = (paymentData['amount'] as num?)?.toInt() ?? 0;
        final isPartial = paymentData['isPartialPayment'] as bool? ?? false;
        final paymentMethod =
            paymentData['paymentMethod'] as String? ?? 'نقداً';
        final createdAt = paymentData['createdAt'] as Timestamp?;

        totalPayments++;
        totalAmount += amount;

        if (isPartial) {
          totalPartialPayments++;
        } else {
          totalRegularPayments++;
        }

        if (maxPaymentAmount == 0 || amount > maxPaymentAmount) {
          maxPaymentAmount = amount;
        }
        if (minPaymentAmount == 0 || amount < minPaymentAmount) {
          minPaymentAmount = amount;
        }

        paymentMethods[paymentMethod] =
            (paymentMethods[paymentMethod] ?? 0) + 1;

        if (createdAt != null) {
          final monthKey =
              "${createdAt.toDate().year}-${createdAt.toDate().month.toString().padLeft(2, '0')}";
          monthlyPayments[monthKey] = (monthlyPayments[monthKey] ?? 0) + amount;
        }
      }

      return {
        'totalPayments': totalPayments,
        'totalAmount': totalAmount,
        'totalPartialPayments': totalPartialPayments,
        'totalRegularPayments': totalRegularPayments,
        'averagePaymentAmount':
        totalPayments > 0 ? (totalAmount / totalPayments).round() : 0,
        'maxPaymentAmount': maxPaymentAmount,
        'minPaymentAmount': totalPayments > 0 ? minPaymentAmount : 0,
        'paymentMethodsBreakdown': paymentMethods,
        'monthlyBreakdown': monthlyPayments,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    });
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "GET_SYSTEM_PAYMENT_STATISTICS",
      "Error: $e",
      isError: true,
    );
    return {};
  }
}

/// تصدير مدفوعات عميل معين إلى قائمة للمعالجة الخارجية
Future<List<Map<String, dynamic>>> exportDebtorPayments(String debtorId) async {
  try {
    final payments = await fetchDebtorPayments(debtorId);
    // تغيير: استخدام EnhancedCacheManager + DebtorsCollection بدلاً من DebtorCache غير المعرف هنا
    Map<String, dynamic>? debtorInfo = EnhancedCacheManager.getDebtor(debtorId);
    if (debtorInfo == null) {
      final debtorSnap = await DebtorsCollection.doc(debtorId).get();
      if (debtorSnap.exists) {
        debtorInfo = Map<String, dynamic>.from(
          debtorSnap.data() as Map<String, dynamic>,
        );
        debtorInfo['id'] = debtorId; // إزالة ! غير الضرورية
        EnhancedCacheManager.cacheDebtor(debtorId, debtorInfo);
      }
    }

    return payments.map((payment) {
      // تحويل الTimestamp إلى تاريخ قابل للقراءة
      final createdAt = payment['createdAt'] as Timestamp?;
      final addedAt = payment['addedAt'] as Timestamp?;

      return {
        'معرف_الدفعة': payment['id'],
        'معرف_العميل': debtorId,
        'اسم_العميل': debtorInfo?['name'] ?? '',
        'هاتف_العميل': debtorInfo?['phone'] ?? '',
        'المبلغ': payment['amount'],
        'تاريخ_الدفع': createdAt?.toDate().toString() ?? '',
        'تاريخ_الإضافة': addedAt?.toDate().toString() ?? '',
        'طريقة_الدفع': payment['paymentMethod'],
        'الملاحظات': payment['notes'],
        'الرقم_المرجعي': payment['referenceNumber'],
        'دفعة_جزئية': payment['isPartialPayment'] ? 'نعم' : 'لا',
        'تخصيصات_الديون': payment['debtAllocations'],
      };
    }).toList();
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "EXPORT_DEBTOR_PAYMENTS",
      "Error: $e",
      isError: true,
    );
    return [];
  }
}

/// حذف عدة مدفوعات في batch واحد
Future<bool> deleteMultiplePayments(
    List<Map<String, String>> paymentsToDelete,
    ) async {
  try {
    final batch = FirebaseFirestore.instance.batch();
    final Map<String, int> debtorTotals = {};

    for (final paymentInfo in paymentsToDelete) {
      final debtorId = paymentInfo['debtorId']!;
      final paymentId = paymentInfo['paymentId']!;

      final debtorRef = DebtorsCollection.doc(debtorId);
      final paymentRef = debtorRef.collection('payments').doc(paymentId);

      // جلب بيانات الدفعة لحساب المجموع
      final paymentDoc = await paymentRef.get();
      if (paymentDoc.exists) {
        final paymentData = paymentDoc.data() as Map<String, dynamic>;
        final paymentAmount = paymentData['amount'] as int;
        final refNum = (paymentData['referenceNumber'] as String?)?.trim();

        // إضافة إلى المجموع الخاص بالعميل
        debtorTotals[debtorId] = (debtorTotals[debtorId] ?? 0) + paymentAmount;

        // إضافة عملية الحذف إلى الbatch
        batch.delete(paymentRef);

        // إزالة الرقم المرجعي المحجوز إن وجد
        if (refNum != null && refNum.isNotEmpty) {
          batch.delete(PaymentRepository.referenceClaims.doc(refNum));
          PaymentMemoryCache.clearReference(refNum);
        }
      }
    }

    // تحديث إجماليات العملاء
    debtorTotals.forEach((debtorId, totalToAdd) {
      final debtorRef = DebtorsCollection.doc(debtorId);
      batch.update(debtorRef, {
        'totalPaid': FieldValue.increment(-totalToAdd),
        'currentDebt': FieldValue.increment(totalToAdd),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // مسح الcache (تغيير: استخدام EnhancedCacheManager)
      EnhancedCacheManager.clearDebtorCache(debtorId);
    });

    await batch.commit();

    DebtorsFirestoreLogger.logOperation(
      "DELETE_MULTIPLE_PAYMENTS",
      "Successfully deleted ${paymentsToDelete.length} payments",
    );
    unawaited(
      PaymentService.writeAudit(
        action: 'DELETE_MULTIPLE_PAYMENTS',
        description: 'Batch delete payments',
        metadata: {'count': paymentsToDelete.length},
      ),
    );
    return true;
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "DELETE_MULTIPLE_PAYMENTS",
      "Error: $e",
      isError: true,
    );
    return false;
  }
}

// ========== دعم البيانات الضخمة: ترحيل، بث، أرشفة ==========

Future<PageResult<Map<String, dynamic>>> fetchDebtorPaymentsPaginated({
  required String debtorId,
  int limit = 20,
  DocumentSnapshot? startAfter,
}) {
  return PaymentRepository.fetchDebtorPaymentsPage(
    debtorId: debtorId,
    limit: limit,
    startAfter: startAfter,
  );
}

Stream<QuerySnapshot<Map<String, dynamic>>> streamDebtorPayments(
    String debtorId, {
      int limit = 50,
    }) {
  return PaymentRepository.streamDebtorPayments(debtorId, limit: limit);
}

Future<Map<String, dynamic>> getSystemPaymentStatisticsLazy({
  int pageSize = 1000,
  DocumentSnapshot? startAfter,
}) async {
  try {
    int totalPayments = 0;
    int totalAmount = 0;
    int totalPartialPayments = 0;
    int totalRegularPayments = 0;
    final Map<String, int> paymentMethods = {};
    final Map<String, int> monthlyPayments = {};

    Query query = FirebaseFirestore.instance
        .collectionGroup('payments')
        .orderBy('createdAt');
    if (startAfter != null) {
      query = (query as Query<Map<String, dynamic>>).startAfterDocument(
        startAfter,
      );
    }
    final snap = await query.limit(pageSize).get();
    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final amount = (d['amount'] as num?)?.toInt() ?? 0;
      final isPartial = d['isPartialPayment'] as bool? ?? false;
      final method = d['paymentMethod'] as String? ?? 'نقداً';
      final ts = d['createdAt'] as Timestamp?;
      totalPayments++;
      totalAmount += amount;
      if (isPartial)
        totalPartialPayments++;
      else
        totalRegularPayments++;
      paymentMethods[method] = (paymentMethods[method] ?? 0) + 1;
      if (ts != null) {
        final m =
            "${ts.toDate().year}-${ts.toDate().month.toString().padLeft(2, '0')}";
        monthlyPayments[m] = (monthlyPayments[m] ?? 0) + amount;
      }
    }
    return {
      'pageSize': pageSize,
      'pageCount': snap.docs.length,
      'hasMore': snap.docs.length == pageSize,
      'nextCursor': snap.docs.isNotEmpty ? snap.docs.last : null,
      'partialStats': {
        'totalPayments': totalPayments,
        'totalAmount': totalAmount,
        'totalPartialPayments': totalPartialPayments,
        'totalRegularPayments': totalRegularPayments,
        'paymentMethodsBreakdown': paymentMethods,
        'monthlyBreakdown': monthlyPayments,
      },
    };
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      'GET_SYSTEM_PAYMENT_STATISTICS_LAZY',
      'Error: $e',
      isError: true,
    );
    return {};
  }
}

Future<int> archiveOldPayments({
  required DateTime olderThan,
  int batchSize = 200,
}) async {
  int archived = 0;
  DocumentSnapshot? cursor;
  try {
    while (true) {
      Query query = FirebaseFirestore.instance
          .collectionGroup('payments')
          .where('createdAt', isLessThan: Timestamp.fromDate(olderThan))
          .orderBy('createdAt')
          .limit(batchSize);
      if (cursor != null) {
        query = (query as Query<Map<String, dynamic>>).startAfterDocument(
          cursor,
        );
      }
      final snap = await query.get();
      if (snap.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final debtorId =
            data['debtorId'] as String? ??
                doc.reference.parent.parent?.id ??
                'unknown';
        final archiveRef = FirebaseFirestore.instance
            .collection('archived_payments')
            .doc('${debtorId}_${doc.id}');
        batch.set(archiveRef, {
          ...data,
          'archivedAt': FieldValue.serverTimestamp(),
          'originalPath': doc.reference.path,
        });
        batch.delete(doc.reference);
        archived++;
      }
      await batch.commit();
      cursor = snap.docs.last;
      if (snap.docs.length < batchSize) break;
    }
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      'ARCHIVE_OLD_PAYMENTS',
      'Error: $e',
      isError: true,
    );
  }
  return archived;
}

/// جلب المدفوعات حسب طريقة الدفع
Future<List<Map<String, dynamic>>> getPaymentsByMethod({
  required String paymentMethod,
  DateTime? startDate,
  DateTime? endDate,
  int limit = 50,
}) async {
  try {
    // تغيير رئيسي: استخدام collectionGroup مع فلتر طريقة الدفع لتجنب N+1
    Query query = FirebaseFirestore.instance
        .collectionGroup('payments')
        .where('paymentMethod', isEqualTo: paymentMethod)
        .orderBy('createdAt', descending: true);

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

    final paymentsSnapshot = await query.limit(limit).get();

    // الحفاظ على التوافق: تعويض بيانات العميل المفقودة
    final List<Map<String, dynamic>> results = [];
    final Map<String, Map<String, dynamic>> debtorInfoCache = {};

    for (final paymentDoc in paymentsSnapshot.docs) {
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      String? debtorId =
          paymentData['debtorId'] as String? ??
              paymentDoc.reference.parent.parent?.id;
      String? debtorName = paymentData['debtorName'] as String?;
      String? debtorPhone = paymentData['debtorPhone'] as String?;

      if ((debtorName == null || debtorPhone == null) && debtorId != null) {
        var cached = debtorInfoCache[debtorId];
        if (cached == null) {
          try {
            final debtorSnap = await DebtorsCollection.doc(debtorId).get();
            if (debtorSnap.exists) {
              cached = (debtorSnap.data() as Map<String, dynamic>);
              debtorInfoCache[debtorId] = cached;
            }
          } catch (_) {}
        }
        debtorName ??= cached?['name'] as String?;
        debtorPhone ??= cached?['phone'] as String?;
      }

      results.add({
        'paymentId': paymentDoc.id,
        'debtorId': debtorId,
        'debtorName': debtorName,
        'debtorPhone': debtorPhone,
        'amount': paymentData['amount'] ?? 0,
        'createdAt': paymentData['createdAt'],
        'notes': paymentData['notes'] ?? '',
      });
    }

    return results;
  } catch (e) {
    DebtorsFirestoreLogger.logOperation(
      "GET_PAYMENTS_BY_METHOD",
      "Error: $e",
      isError: true,
    );
    return [];
  }
}

// ================== دوال مساعدة ==================

/// حساب تكرار المدفوعات
Map<String, dynamic> _calculatePaymentFrequency(
    DateTime? firstPayment,
    DateTime? lastPayment,
    int totalPayments,
    ) {
  if (firstPayment == null || lastPayment == null || totalPayments <= 1) {
    return {
      'frequency': 'غير محدد',
      'averageDaysBetweenPayments': 0,
      'paymentPattern': 'غير منتظم',
    };
  }

  final totalDays = lastPayment.difference(firstPayment).inDays;
  final averageDaysBetweenPayments =
  totalPayments > 1 ? (totalDays / (totalPayments - 1)).round() : 0;

  String frequency;
  String pattern;

  if (averageDaysBetweenPayments <= 7) {
    frequency = 'أسبوعي';
    pattern = 'منتظم جداً';
  } else if (averageDaysBetweenPayments <= 15) {
    frequency = 'نصف شهري';
    pattern = 'منتظم';
  } else if (averageDaysBetweenPayments <= 35) {
    frequency = 'شهري';
    pattern = 'منتظم نسبياً';
  } else if (averageDaysBetweenPayments <= 95) {
    frequency = 'فصلي';
    pattern = 'متباعد';
  } else {
    frequency = 'سنوي';
    pattern = 'نادر';
  }

  return {
    'frequency': frequency,
    'averageDaysBetweenPayments': averageDaysBetweenPayments,
    'paymentPattern': pattern,
  };
}

/// دالة مغلفة لجلب المدفوعات (للتوافق مع النسخة القديمة)
Future<List<Map<String, dynamic>>> fetchDebtorPayment(String debtorId) async {
  return await fetchDebtorPayments(debtorId);
}
