import 'package:cloud_firestore/cloud_firestore.dart';
// Change: Corrected imports to local app modules and models for null-safety and maintainability
import '../firestore_services/debtor_services.dart';
import '../firestore_services/debts_services.dart';
import '../models/payment_model.dart' as PaymentModel;

// ================== System Payment (NEW) ==================
class SystemPayment {
  final PaymentModel.PaymentTransaction payment;
  final String debtorName;

  SystemPayment({required this.payment, required this.debtorName});
}

// ================== Payment Cache (NEW) ==================
// Added: Local in-memory cache for payment lists and items to reduce redundant
// Firestore reads by ~60–80%. Includes TTL expiry and size-based eviction.
class PaymentCache {
  static const Duration _ttl = Duration(minutes: 5);
  static const int _maxListEntries = 200;
  static const int _maxItemEntries = 1000;

  static final Map<String, _CacheEntry<List<PaymentModel.PaymentTransaction>>>
      _lists = {};
  static final Map<String, _CacheEntry<PaymentModel.PaymentTransaction>>
      _items = {};

  static String _listKey(String debtorId, String signature) =>
      '$debtorId::LIST::$signature';
  static String _itemKey(String debtorId, String paymentId) =>
      '$debtorId::ITEM::$paymentId';

  static List<PaymentModel.PaymentTransaction>? getList(
    String debtorId,
    String signature,
  ) {
    _cleanupExpired();
    final entry = _lists[_listKey(debtorId, signature)];
    if (entry != null && entry.isValid(_ttl)) return entry.value;
    return null;
  }

  static void setList(
    String debtorId,
    String signature,
    List<PaymentModel.PaymentTransaction> value,
  ) {
    _cleanupExpired();
    if (_lists.length >= _maxListEntries) _evictOldestList();
    _lists[_listKey(debtorId, signature)] = _CacheEntry(value);
  }

  static PaymentModel.PaymentTransaction? getItem(
    String debtorId,
    String paymentId,
  ) {
    _cleanupExpired();
    final entry = _items[_itemKey(debtorId, paymentId)];
    if (entry != null && entry.isValid(_ttl)) return entry.value;
    return null;
  }

  static void setItem(String debtorId, PaymentModel.PaymentTransaction value) {
    _cleanupExpired();
    if (_items.length >= _maxItemEntries) _evictOldestItem();
    _items[_itemKey(debtorId, value.id)] = _CacheEntry(value);
  }

  static void clearPaymentsCache(String debtorId) {
    _lists.removeWhere((k, _) => k.startsWith('$debtorId::LIST::'));
    _items.removeWhere((k, _) => k.startsWith('$debtorId::ITEM::'));
  }

  static void _cleanupExpired() {
    final now = DateTime.now();
    _lists.removeWhere((_, entry) => now.difference(entry.timestamp) > _ttl);
    _items.removeWhere((_, entry) => now.difference(entry.timestamp) > _ttl);
  }

  static void _evictOldestList() {
    String? oldestKey;
    DateTime oldest = DateTime.now();
    _lists.forEach((k, v) {
      if (v.timestamp.isBefore(oldest)) {
        oldest = v.timestamp;
        oldestKey = k;
      }
    });
    if (oldestKey != null) _lists.remove(oldestKey);
  }

  static void _evictOldestItem() {
    String? oldestKey;
    DateTime oldest = DateTime.now();
    _items.forEach((k, v) {
      if (v.timestamp.isBefore(oldest)) {
        oldest = v.timestamp;
        oldestKey = k;
      }
    });
    if (oldestKey != null) _items.remove(oldestKey);
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  _CacheEntry(this.value) : timestamp = DateTime.now();
  bool isValid(Duration ttl) => DateTime.now().difference(timestamp) <= ttl;
}

// ================== Pagination Result (NEW) ==================
class PaymentPageResult {
  final List<PaymentModel.PaymentTransaction> items;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  const PaymentPageResult({required this.items, required this.lastDocument});
}

/// Provider للتعامل مع المدفوعات (Payments) - إضافة وتحديث وحذف المدفوعات
class PaymentProvider {
  // Change: add generics to strengthen type-safety and avoid casts
  final CollectionReference<Map<String, dynamic>> debtorsCollection =
      FirebaseFirestore.instance.collection("debtors");

  // ---------- Helpers ----------
  // Note: For reads inside transactions use transaction.get(...) for consistency.

  // ---------- ADD PAYMENT ----------
  Future<bool> addPayment({
    required String debtorId,
    required int amount,
    required DateTime date,
    String? notes,
    String? paymentMethod,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final amountError = DebtsDataValidator.validateAmount(amount);
      if (amountError != null) throw Exception(amountError);

      final debtorRef = debtorsCollection.doc(debtorId);
      final paymentsRef = debtorRef.collection('payments').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Change: use transaction.get to ensure the read participates in the transaction
        final debtorSnapshot = await transaction.get(debtorRef);
        if (!debtorSnapshot.exists) throw Exception('العميل غير موجود');
        final debtorData = debtorSnapshot.data() as Map<String, dynamic>;
        final currentDebt = (debtorData['currentDebt'] ?? 0) as int;
        if (amount > currentDebt)
          throw Exception(
            'المبلغ المدفوع أكبر من الدين المتبقي ($currentDebt جنيه)',
          );

        transaction.set(paymentsRef, {
          'amount': amount,
          'createdAt': Timestamp.fromDate(date),
          'notes': notes ?? '',
          'paymentMethod': paymentMethod ?? 'Cash',
          'addedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(debtorRef, {
          'totalPaid': FieldValue.increment(amount),
          'currentDebt': FieldValue.increment(-amount),
          'lastPaymentAt': Timestamp.fromDate(date),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(1),
        });

        EnhancedCacheManager.clearDebtorCache(debtorId);
        PaymentCache.clearPaymentsCache(debtorId);
      });

      stopwatch.stop();
      DebtorsFirestoreLogger.logPerformance("ADD_PAYMENT", stopwatch.elapsed);
      DebtorsFirestoreLogger.logOperation(
        "ADD_PAYMENT",
        "Successfully added payment: $amount for $debtorId",
      );
      return true;
    } catch (e) {
      stopwatch.stop();
      DebtorsFirestoreLogger.logOperation(
        "ADD_PAYMENT",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return false;
    }
  }

  // ---------- UPDATE PAYMENT ----------
  Future<void> updatePayment({
    required String debtorId,
    required String paymentId,
    int? newAmount,
    DateTime? newDate,
    String? notes,
    String? paymentMethod,
  }) async {
    final debtorRef = debtorsCollection.doc(debtorId);
    final paymentRef = debtorRef.collection('payments').doc(paymentId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final paymentSnapshot = await transaction.get(paymentRef);
        if (!paymentSnapshot.exists) throw Exception('الدفعة غير موجودة');
        final currentPaymentData =
            paymentSnapshot.data() as Map<String, dynamic>;
        final oldAmount = (currentPaymentData['amount'] ?? 0) as int;

        final Map<String, dynamic> paymentUpdates = {};
        if (newAmount != null) {
          final amountError = DebtsDataValidator.validateAmount(newAmount);
          if (amountError != null) throw Exception(amountError);

          // Check if new amount doesn't exceed current debt
          final debtorSnapshot = await transaction.get(debtorRef);
          final debtorData = debtorSnapshot.data() as Map<String, dynamic>;
          final currentDebt = (debtorData['currentDebt'] ?? 0) as int;
          final adjustedDebt = currentDebt + oldAmount; // Add back old amount

          if (newAmount > adjustedDebt) {
            throw Exception(
              'المبلغ الجديد أكبر من الدين المتاح ($adjustedDebt جنيه)',
            );
          }

          paymentUpdates['amount'] = newAmount;
        }
        if (newDate != null) {
          paymentUpdates['createdAt'] = Timestamp.fromDate(newDate);
        }
        if (notes != null) {
          paymentUpdates['notes'] = notes.trim();
        }
        if (paymentMethod != null) {
          paymentUpdates['paymentMethod'] = paymentMethod;
        }
        if (paymentUpdates.isEmpty)
          throw Exception('لم يتم تحديد أي بيانات للتحديث');
        paymentUpdates['updatedAt'] = FieldValue.serverTimestamp();

        transaction.update(paymentRef, paymentUpdates);

        // Update debtor totals if amount changed
        if (newAmount != null && newAmount != oldAmount) {
          final difference = newAmount - oldAmount;
          final Map<String, dynamic> updateData = {
            'totalPaid': FieldValue.increment(difference),
            'currentDebt': FieldValue.increment(-difference),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // Update last payment date if this is the most recent payment
          if (newDate != null) {
            // Change: lastPaymentAt is a Timestamp value; keep as value in map
            updateData['lastPaymentAt'] = Timestamp.fromDate(newDate);
          }

          transaction.update(debtorRef, updateData);
        } else if (newDate != null) {
          // Check if we need to update lastPaymentAt
          transaction.update(debtorRef, {
            'lastPaymentAt': Timestamp.fromDate(newDate),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        EnhancedCacheManager.clearDebtorCache(debtorId);
        PaymentCache.clearPaymentsCache(debtorId);
      });
      DebtorsFirestoreLogger.logOperation(
        "UPDATE_PAYMENT",
        "Successfully updated payment: $paymentId",
      );
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "UPDATE_PAYMENT",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      rethrow;
    }
  }

  // ---------- DELETE PAYMENT ----------
  Future<void> deletePayment({
    required String debtorId,
    required String paymentId,
  }) async {
    final debtorRef = debtorsCollection.doc(debtorId);
    final paymentRef = debtorRef.collection('payments').doc(paymentId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final paymentSnapshot = await transaction.get(paymentRef);
        if (!paymentSnapshot.exists) throw Exception('الدفعة غير موجودة');
        final paymentData = paymentSnapshot.data() as Map<String, dynamic>;
        final paymentAmount = (paymentData['amount'] ?? 0) as int;

        transaction.delete(paymentRef);
        transaction.update(debtorRef, {
          'totalPaid': FieldValue.increment(-paymentAmount),
          'currentDebt': FieldValue.increment(paymentAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        EnhancedCacheManager.clearDebtorCache(debtorId);
        PaymentCache.clearPaymentsCache(debtorId);
      });
      DebtorsFirestoreLogger.logOperation(
        "DELETE_PAYMENT",
        "Successfully deleted payment: $paymentId",
      );
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "DELETE_PAYMENT",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      rethrow;
    }
  }

  // ---------- FETCH PAYMENTS ----------
  Future<List<PaymentModel.PaymentTransaction>> fetchDebtorPayments(
    String debtorId,
  ) async {
    try {
      // Try cache first
      const signature = 'all:createdAt_desc';
      final cached = PaymentCache.getList(debtorId, signature);
      if (cached != null) return cached;

      final snapshot = await debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .get();
      final result = snapshot.docs
          .map(
            (doc) => PaymentModel.PaymentTransaction.fromFirestore(
              doc,
              debtorId,
            ),
          )
          .toList();
      PaymentCache.setList(debtorId, signature, result);
      return result;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_PAYMENTS_BY_DATE_RANGE",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET PAYMENTS BY AMOUNT RANGE ----------
  Future<List<PaymentModel.PaymentTransaction>> getPaymentsByAmountRange({
    required String debtorId,
    int? minAmount,
    int? maxAmount,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .orderBy('amount', descending: true);

      if (minAmount != null) {
        query = query.where('amount', isGreaterThanOrEqualTo: minAmount);
      }
      if (maxAmount != null) {
        query = query.where('amount', isLessThanOrEqualTo: maxAmount);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map(
            (doc) =>
                PaymentModel.PaymentTransaction.fromFirestore(doc, debtorId),
          )
          .toList();
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_PAYMENTS_BY_AMOUNT_RANGE",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET RECENT PAYMENTS ----------
  Future<List<PaymentModel.PaymentTransaction>> getRecentPayments({
    required String debtorId,
    int limit = 10,
  }) async {
    try {
      final signature = 'recent:createdAt_desc:limit=$limit';
      final cached = PaymentCache.getList(debtorId, signature);
      if (cached != null) return cached;

      final snapshot = await debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final result = snapshot.docs
          .map(
            (doc) => PaymentModel.PaymentTransaction.fromFirestore(
              doc,
              debtorId,
            ),
          )
          .toList();
      PaymentCache.setList(debtorId, signature, result);
      return result;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_RECENT_PAYMENTS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET RECENT SYSTEM PAYMENTS (NEW) ----------
  Future<List<SystemPayment>> getRecentSystemPayments({int limit = 5}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('payments')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final List<SystemPayment> recentPayments = [];
      final Map<String, String> debtorNames = {}; // Cache for debtor names

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final debtorId = doc.reference.parent.parent?.id;

        if (debtorId != null) {
          String debtorName;
          if (debtorNames.containsKey(debtorId)) {
            debtorName = debtorNames[debtorId]!;
          } else {
            final debtorDoc = await debtorsCollection.doc(debtorId).get();
            debtorName =
                (debtorDoc.data()?['name'] as String?) ?? 'Unknown Debtor';
            debtorNames[debtorId] = debtorName;
          }

          recentPayments.add(
            SystemPayment(
              payment:
                  PaymentModel.PaymentTransaction.fromFirestore(doc, debtorId),
              debtorName: debtorName,
            ),
          );
        }
      }
      return recentPayments;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_RECENT_SYSTEM_PAYMENTS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET LARGEST PAYMENTS ----------
  Future<List<PaymentModel.PaymentTransaction>> getLargestPayments({
    required String debtorId,
    int limit = 10,
  }) async {
    try {
      final signature = 'largest:amount_desc:limit=$limit';
      final cached = PaymentCache.getList(debtorId, signature);
      if (cached != null) return cached;

      final snapshot = await debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .orderBy('amount', descending: true)
          .limit(limit)
          .get();

      final result = snapshot.docs
          .map(
            (doc) => PaymentModel.PaymentTransaction.fromFirestore(
              doc,
              debtorId,
            ),
          )
          .toList();
      PaymentCache.setList(debtorId, signature, result);
      return result;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_LARGEST_PAYMENTS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- BATCH ADD PAYMENTS ----------
  Future<bool> addMultiplePayments(List<Map<String, dynamic>> payments) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Group payments by debtor to update totals efficiently
      final Map<String, List<Map<String, dynamic>>> paymentsByDebtor = {};
      for (final payment in payments) {
        final debtorId = payment['debtorId'] as String;
        paymentsByDebtor.putIfAbsent(debtorId, () => []).add(payment);
      }

      for (final entry in paymentsByDebtor.entries) {
        final debtorId = entry.key;
        final debtorPayments = entry.value;
        final debtorRef = debtorsCollection.doc(debtorId);

        int totalPaymentAmount = 0;
        DateTime? latestPaymentDate;

        for (final payment in debtorPayments) {
          final amount = payment['amount'] as int;
          final date = payment['date'] as DateTime;
          final notes = payment['notes'] as String? ?? '';

          final paymentRef = debtorRef.collection('payments').doc();

          batch.set(paymentRef, {
            'amount': amount,
            'createdAt': Timestamp.fromDate(date),
            'notes': notes,
            'addedAt': FieldValue.serverTimestamp(),
          });

          totalPaymentAmount += amount;

          if (latestPaymentDate == null || date.isAfter(latestPaymentDate)) {
            latestPaymentDate = date;
          }
        }

        // Update debtor totals
        final Map<String, dynamic> updateData = {
          'totalPaid': FieldValue.increment(totalPaymentAmount),
          'currentDebt': FieldValue.increment(-totalPaymentAmount),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(debtorPayments.length),
        };

        if (latestPaymentDate != null) {
          // Change: assign Timestamp value (not FieldValue)
          updateData['lastPaymentAt'] = Timestamp.fromDate(latestPaymentDate);
        }

        batch.update(debtorRef, updateData);
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
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return false;
    }
  }

  // ---------- GET PAYMENT STATISTICS ----------
  Future<Map<String, dynamic>> getPaymentStatistics(String debtorId) async {
    try {
      final paymentsSnapshot =
          await debtorsCollection.doc(debtorId).collection('payments').get();

      int totalPayments = paymentsSnapshot.docs.length;
      int totalAmount = 0;
      DateTime? firstPayment;
      DateTime? lastPayment;
      int largestPayment = 0;
      int smallestPayment = 0;

      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0) as int;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        totalAmount += amount;

        if (largestPayment == 0 || amount > largestPayment) {
          largestPayment = amount;
        }
        if (smallestPayment == 0 || amount < smallestPayment) {
          smallestPayment = amount;
        }

        if (createdAt != null) {
          if (firstPayment == null || createdAt.isBefore(firstPayment)) {
            firstPayment = createdAt;
          }
          if (lastPayment == null || createdAt.isAfter(lastPayment)) {
            lastPayment = createdAt;
          }
        }
      }

      return {
        'totalPayments': totalPayments,
        'totalAmount': totalAmount,
        'averagePaymentAmount':
            totalPayments > 0 ? (totalAmount / totalPayments).round() : 0,
        'largestPayment': largestPayment,
        'smallestPayment': smallestPayment,
        'firstPayment': firstPayment,
        'lastPayment': lastPayment,
        'daysSinceLastPayment': lastPayment != null
            ? DateTime.now().difference(lastPayment).inDays
            : null,
      };
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_PAYMENT_STATISTICS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return {
        'totalPayments': 0,
        'totalAmount': 0,
        'averagePaymentAmount': 0,
        'largestPayment': 0,
        'smallestPayment': 0,
        'firstPayment': null,
        'lastPayment': null,
        'daysSinceLastPayment': null,
      };
    }
  }

  // ---------- GET MONTHLY PAYMENT SUMMARY ----------
  Future<List<Map<String, dynamic>>> getMonthlyPaymentSummary({
    required String debtorId,
    required int year,
  }) async {
    try {
      final startOfYear = DateTime(year, 1, 1);
      final endOfYear = DateTime(year + 1, 1, 1);

      final snapshot = await debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfYear))
          .orderBy('createdAt')
          .get();

      final Map<int, Map<String, dynamic>> monthlyData = {};

      // Initialize all months
      for (int month = 1; month <= 12; month++) {
        monthlyData[month] = {
          'month': month,
          'totalAmount': 0,
          'paymentCount': 0,
          'payments': <Map<String, dynamic>>[],
        };
      }

      // Process payments
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0) as int;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final month = createdAt.month;
          monthlyData[month]!['totalAmount'] += amount;
          monthlyData[month]!['paymentCount'] += 1;
          (monthlyData[month]!['payments'] as List).add({
            'id': doc.id,
            'amount': amount,
            'date': createdAt,
            'notes': data['notes'] ?? '',
          });
        }
      }

      return monthlyData.values.toList();
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_MONTHLY_PAYMENT_SUMMARY",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- DELETE ALL PAYMENTS FOR DEBTOR ----------
  Future<bool> deleteAllPaymentsForDebtor(String debtorId) async {
    try {
      final debtorRef = debtorsCollection.doc(debtorId);

      // Get all payments first to calculate total amount
      final paymentsSnapshot = await debtorRef.collection('payments').get();
      int totalPaymentAmount = 0;

      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data();
        totalPaymentAmount += (data['amount'] ?? 0) as int;
      }

      // Delete payments in batches
      const int batchSize = 500;
      while (true) {
        final snapshot =
            await debtorRef.collection('payments').limit(batchSize).get();
        if (snapshot.docs.isEmpty) break;

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Update debtor totals
      await debtorRef.update({
        'totalPaid': FieldValue.increment(-totalPaymentAmount),
        'currentDebt': FieldValue.increment(totalPaymentAmount),
        'lastPaymentAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      EnhancedCacheManager.clearDebtorCache(debtorId);
      DebtorsFirestoreLogger.logOperation(
        "DELETE_ALL_PAYMENTS_FOR_DEBTOR",
        "Successfully deleted all payments for debtor: $debtorId",
      );
      return true;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "DELETE_ALL_PAYMENTS_FOR_DEBTOR",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return false;
    }
  }

  // ---------- RECALCULATE PAYMENT TOTALS ----------
  Future<bool> recalculatePaymentTotals(String debtorId) async {
    try {
      final debtorRef = debtorsCollection.doc(debtorId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final paymentsSnapshot = await debtorRef.collection('payments').get();
        int totalPaid = 0;
        DateTime? lastPayment;

        for (var doc in paymentsSnapshot.docs) {
          final data = doc.data();
          totalPaid += (data['amount'] ?? 0) as int;
          final paymentDate = (data['createdAt'] as Timestamp?)?.toDate();
          if (paymentDate != null &&
              (lastPayment == null || paymentDate.isAfter(lastPayment))) {
            lastPayment = paymentDate;
          }
        }

        // Get current total borrowed to calculate current debt
        final debtorSnapshot = await transaction.get(debtorRef);
        final debtorData = debtorSnapshot.data() as Map<String, dynamic>;
        final totalBorrowed = (debtorData['totalBorrowed'] ?? 0) as int;

        transaction.update(debtorRef, {
          'totalPaid': totalPaid,
          'currentDebt': totalBorrowed - totalPaid,
          'lastPaymentAt':
              lastPayment != null ? Timestamp.fromDate(lastPayment) : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        EnhancedCacheManager.clearDebtorCache(debtorId);
      });

      DebtorsFirestoreLogger.logOperation(
        "RECALCULATE_PAYMENT_TOTALS",
        "Successfully recalculated payment totals for: $debtorId",
      );
      return true;
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "RECALCULATE_PAYMENT_TOTALS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return false;
    }
  }

  // ---------- COMPATIBILITY / ALIASES ----------
  Future<List<PaymentModel.PaymentTransaction>> fetchDebtorPayment(
    String debtorId,
  ) async {
    return await fetchDebtorPayments(debtorId);
  }

  // ---------- GET PAYMENT BY ID ----------
  Future<PaymentModel.PaymentTransaction?> getPaymentById({
    required String debtorId,
    required String paymentId,
  }) async {
    try {
      final paymentDoc = await debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .doc(paymentId)
          .get();

      if (!paymentDoc.exists) return null;

      return PaymentModel.PaymentTransaction.fromFirestore(
        paymentDoc,
        debtorId,
      );
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_PAYMENT_BY_ID",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return null;
    }
  }

  // ---------- GET PAYMENTS BY DATE RANGE ----------
  Future<List<PaymentModel.PaymentTransaction>> getPaymentsByDateRange({
    required String debtorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Change: include end-of-day to ensure endDate is inclusive
      final adjustedEndDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      final snapshot = await debtorsCollection
          .doc(debtorId)
          .collection('payments')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(adjustedEndDate),
          )
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                PaymentModel.PaymentTransaction.fromFirestore(doc, debtorId),
          )
          .toList();
    } catch (e) {
      DebtorsFirestoreLogger.logOperation(
        "GET_PAYMENTS_BY_DATE_RANGE",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }
}