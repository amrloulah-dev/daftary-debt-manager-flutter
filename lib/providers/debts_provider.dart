import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_services/debtor_services.dart';
import '../firestore_services/debts_services.dart';
import '../models/debts_model.dart' as DebtsModel;

class DebtsCache {
  static const Duration _ttl = Duration(minutes: 5);
  static const int _maxListEntries = 200;
  static const int _maxItemEntries = 1000;

  static final Map<String, _CacheEntry<List<DebtsModel.DebtTransaction>>>
  _lists = {};
  static final Map<String, _CacheEntry<DebtsModel.DebtTransaction>> _items = {};

  static String _listKey(String debtorId, String signature) =>
      '$debtorId::LIST::$signature';
  static String _itemKey(String debtorId, String debtId) =>
      '$debtorId::ITEM::$debtId';

  static List<DebtsModel.DebtTransaction>? getList(
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
      List<DebtsModel.DebtTransaction> value,
      ) {
    _cleanupExpired();
    if (_lists.length >= _maxListEntries) _evictOldestList();
    _lists[_listKey(debtorId, signature)] = _CacheEntry(value);
  }

  static DebtsModel.DebtTransaction? getItem(String debtorId, String debtId) {
    _cleanupExpired();
    final entry = _items[_itemKey(debtorId, debtId)];
    if (entry != null && entry.isValid(_ttl)) return entry.value;
    return null;
  }

  static void setItem(String debtorId, DebtsModel.DebtTransaction value) {
    _cleanupExpired();
    if (_items.length >= _maxItemEntries) _evictOldestItem();
    _items[_itemKey(debtorId, value.id)] = _CacheEntry(value);
  }

  /// Clears all cached lists and items for a debtor — called after writes
  static void clearDebtsCache(String debtorId) {
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
class DebtPageResult {
  final List<DebtsModel.DebtTransaction> items;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDocument;
  const DebtPageResult({required this.items, required this.lastDocument});
}

/// Provider للتعامل مع الديون (Debts) - إضافة وتحديث وحذف الديون
class DebtProvider {
  // Fix: add generic type to strengthen null-safety and readability
  final CollectionReference<Map<String, dynamic>> debtorsCollection =
  FirebaseFirestore.instance.collection("debtors");

  // ---------- Helpers ----------
  // Note: reads inside transactions below use transaction.get for correctness.

  // ---------- ADD DEBT ----------
  Future<bool> addDebt({
    required String debtorId,
    required List<Map<String, dynamic>> items,
    required int total,
    String? notes,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final itemsError = DebtsDataValidator.validateItems(items);
      if (itemsError != null) throw Exception(itemsError);
      final amountError = DebtsDataValidator.validateAmount(total);
      if (amountError != null) throw Exception(amountError);

      final debtorRef = debtorsCollection.doc(debtorId);
      final debtsRef = debtorRef.collection('debts').doc(); // new doc

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Fix: perform existence read via transaction for Firestore transaction correctness
        final debtorSnapshot = await transaction.get(debtorRef);
        if (!debtorSnapshot.exists) throw Exception('العميل غير موجود');

        transaction.set(debtsRef, {
          'items': items,
          'total': total,
          'createdAt': FieldValue.serverTimestamp(),
          'isPaid': false,
          'notes': notes ?? '',
        });

        // Change: update aggregated O(1) stats alongside totals for faster stats reads
        final debtorData = debtorSnapshot.data();
        final Map<String, dynamic>? debtStats =
        (debtorData?['debtStats'] as Map<String, dynamic>?);
        final bool hasFirstDebt = (debtStats?['firstDebtAt'] != null);
        final Map<String, dynamic> statsUpdates = {
          'totalBorrowed': FieldValue.increment(total),
          'currentDebt': FieldValue.increment(total),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(1),
          'debtStats.totalDebts': FieldValue.increment(1),
          'debtStats.unpaidDebts': FieldValue.increment(1),
          'debtStats.totalAmount': FieldValue.increment(total),
          'debtStats.lastDebtAt': FieldValue.serverTimestamp(),
        };
        if (!hasFirstDebt) {
          statsUpdates['debtStats.firstDebtAt'] = FieldValue.serverTimestamp();
        }
        transaction.update(debtorRef, statsUpdates);

        EnhancedCacheManager.clearDebtorCache(debtorId);
        DebtsCache.clearDebtsCache(debtorId);
      });

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

  // ---------- UPDATE DEBT ----------
  Future<void> updateDebt({
    required String debtorId,
    required String debtId,
    List<Map<String, dynamic>>? items,
    int? newTotal,
    String? notes,
  }) async {
    final debtorRef = debtorsCollection.doc(debtorId);
    final debtRef = debtorRef.collection('debts').doc(debtId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final debtSnapshot = await transaction.get(debtRef);
        if (!debtSnapshot.exists) throw Exception('الدين غير موجود');
        final currentDebtData = debtSnapshot.data() as Map<String, dynamic>;
        final oldTotal = (currentDebtData['total'] ?? 0) as int;

        final Map<String, dynamic> debtUpdates = {};
        if (items != null) {
          final itemsError = DebtsDataValidator.validateItems(items);
          if (itemsError != null) throw Exception(itemsError);
          debtUpdates['items'] = items;
        }
        if (newTotal != null) {
          final amountError = DebtsDataValidator.validateAmount(newTotal);
          if (amountError != null) throw Exception(amountError);
          debtUpdates['total'] = newTotal;
        }
        if (notes != null) {
          debtUpdates['notes'] = notes.trim();
        }
        if (debtUpdates.isEmpty)
          throw Exception('لم يتم تحديد أي بيانات للتحديث');
        debtUpdates['updatedAt'] = FieldValue.serverTimestamp();

        transaction.update(debtRef, debtUpdates);

        // تحديث إجمالي الديون في حالة تغيير المبلغ
        if (newTotal != null && newTotal != oldTotal) {
          final difference = newTotal - oldTotal;
          transaction.update(debtorRef, {
            'totalBorrowed': FieldValue.increment(difference),
            'currentDebt': FieldValue.increment(difference),
            'updatedAt': FieldValue.serverTimestamp(),
            'debtStats.totalAmount': FieldValue.increment(difference),
            'debtStats.lastDebtAt': FieldValue.serverTimestamp(),
          });
        }
        EnhancedCacheManager.clearDebtorCache(debtorId);
      });
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

  // ---------- DELETE DEBT ----------
  Future<void> deleteDebt({
    required String debtorId,
    required String debtId,
  }) async {
    final debtorRef = debtorsCollection.doc(debtorId);
    final debtRef = debtorRef.collection('debts').doc(debtId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final debtSnapshot = await transaction.get(debtRef);
        if (!debtSnapshot.exists) throw Exception('الدين غير موجود');
        final debtData = debtSnapshot.data() as Map<String, dynamic>;
        final debtTotal = (debtData['total'] ?? 0) as int;
        final isPaid = (debtData['isPaid'] ?? false) as bool;

        transaction.delete(debtRef);
        transaction.update(debtorRef, {
          'totalBorrowed': FieldValue.increment(-debtTotal),
          'currentDebt': FieldValue.increment(-debtTotal),
          'updatedAt': FieldValue.serverTimestamp(),
          'debtStats.totalDebts': FieldValue.increment(-1),
          'debtStats.totalAmount': FieldValue.increment(-debtTotal),
          if (isPaid) 'debtStats.paidDebts': FieldValue.increment(-1),
          if (!isPaid) 'debtStats.unpaidDebts': FieldValue.increment(-1),
        });
        EnhancedCacheManager.clearDebtorCache(debtorId);
        DebtsCache.clearDebtsCache(debtorId);
      });
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

  // ---------- FETCH DEBTS ----------
  Future<List<DebtsModel.DebtTransaction>> fetchDebtorDebts(
      String debtorId,
      ) async {
    try {
      // Try cache first
      const signature = 'all:createdAt_desc';
      final cached = DebtsCache.getList(debtorId, signature);
      if (cached != null) return cached;

      final snapshot =
      await debtorsCollection
          .doc(debtorId)
          .collection('debts')
          .orderBy('createdAt', descending: true)
          .get();
      final result =
      snapshot.docs
          .map(
            (doc) =>
            DebtsModel.DebtTransaction.fromFirestore(doc, debtorId),
      )
          .toList();
      DebtsCache.setList(debtorId, signature, result);
      return result;
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "FETCH_DEBTOR_DEBTS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET DEBT BY ID ----------
  Future<DebtsModel.DebtTransaction?> getDebtById({
    required String debtorId,
    required String debtId,
  }) async {
    try {
      // Try cache first
      final cached = DebtsCache.getItem(debtorId, debtId);
      if (cached != null) return cached;

      final debtDoc =
      await debtorsCollection
          .doc(debtorId)
          .collection('debts')
          .doc(debtId)
          .get();

      if (!debtDoc.exists) return null;

      final item = DebtsModel.DebtTransaction.fromFirestore(debtDoc, debtorId);
      DebtsCache.setItem(debtorId, item);
      return item;
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "GET_DEBT_BY_ID",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return null;
    }
  }

  // ---------- GET DEBTS BY DATE RANGE ----------
  Future<List<DebtsModel.DebtTransaction>> getDebtsByDateRange({
    required String debtorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Fix: include full end day to avoid excluding records later in the endDate
      final adjustedEndDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      final snapshot =
      await debtorsCollection
          .doc(debtorId)
          .collection('debts')
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
          .map((doc) => DebtsModel.DebtTransaction.fromFirestore(doc, debtorId))
          .toList();
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "GET_DEBTS_BY_DATE_RANGE",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET DEBTS BY AMOUNT RANGE ----------
  Future<List<DebtsModel.DebtTransaction>> getDebtsByAmountRange({
    required String debtorId,
    int? minAmount,
    int? maxAmount,
    int limit = 50,
  }) async {
    try {
      Query query = debtorsCollection
          .doc(debtorId)
          .collection('debts')
          .orderBy('total', descending: true);

      if (minAmount != null) {
        query = query.where('total', isGreaterThanOrEqualTo: minAmount);
      }
      if (maxAmount != null) {
        query = query.where('total', isLessThanOrEqualTo: maxAmount);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs
          .map((doc) => DebtsModel.DebtTransaction.fromFirestore(doc, debtorId))
          .toList();
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "GET_DEBTS_BY_AMOUNT_RANGE",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- MARK DEBT AS PAID ----------
  Future<bool> markDebtAsPaid({
    required String debtorId,
    required String debtId,
    bool isPaid = true,
  }) async {
    try {
      final debtorRef = debtorsCollection.doc(debtorId);
      final debtRef = debtorRef.collection('debts').doc(debtId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(debtRef);
        if (!snapshot.exists) throw Exception('الدين غير موجود');
        final data = snapshot.data() as Map<String, dynamic>;
        final prevIsPaid = (data['isPaid'] ?? false) as bool;
        if (prevIsPaid == isPaid) return; // nothing to update

        transaction.update(debtRef, {
          'isPaid': isPaid,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(debtorRef, {
          if (isPaid) 'debtStats.paidDebts': FieldValue.increment(1),
          if (isPaid) 'debtStats.unpaidDebts': FieldValue.increment(-1),
          if (!isPaid) 'debtStats.paidDebts': FieldValue.increment(-1),
          if (!isPaid) 'debtStats.unpaidDebts': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      EnhancedCacheManager.clearDebtorCache(debtorId);
      DebtsCache.clearDebtsCache(debtorId);
      DebtsFirestoreLogger.logOperation(
        "MARK_DEBT_AS_PAID",
        "Successfully marked debt $debtId as ${isPaid ? 'paid' : 'unpaid'}",
      );
      return true;
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "MARK_DEBT_AS_PAID",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return false;
    }
  }

  // ---------- GET UNPAID DEBTS ----------
  Future<List<DebtsModel.DebtTransaction>> getUnpaidDebts(
      String debtorId,
      ) async {
    try {
      // Try cache first
      const signature = 'unpaid:createdAt_desc';
      final cached = DebtsCache.getList(debtorId, signature);
      if (cached != null) return cached;

      final snapshot =
      await debtorsCollection
          .doc(debtorId)
          .collection('debts')
          .where('isPaid', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      final result =
      snapshot.docs
          .map(
            (doc) =>
            DebtsModel.DebtTransaction.fromFirestore(doc, debtorId),
      )
          .toList();
      DebtsCache.setList(debtorId, signature, result);
      return result;
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "GET_UNPAID_DEBTS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- GET PAID DEBTS ----------
  Future<List<DebtsModel.DebtTransaction>> getPaidDebts(String debtorId) async {
    try {
      // Try cache first
      const signature = 'paid:createdAt_desc';
      final cached = DebtsCache.getList(debtorId, signature);
      if (cached != null) return cached;

      final snapshot =
      await debtorsCollection
          .doc(debtorId)
          .collection('debts')
          .where('isPaid', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      final result =
      snapshot.docs
          .map(
            (doc) =>
            DebtsModel.DebtTransaction.fromFirestore(doc, debtorId),
      )
          .toList();
      DebtsCache.setList(debtorId, signature, result);
      return result;
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "GET_PAID_DEBTS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return [];
    }
  }

  // ---------- BATCH ADD DEBTS ----------
  Future<bool> addMultipleDebts(List<Map<String, dynamic>> debts) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Group debts by debtor to update totals efficiently
      final Map<String, List<Map<String, dynamic>>> debtsByDebtor = {};
      for (final debt in debts) {
        final debtorId = debt['debtorId'] as String;
        debtsByDebtor.putIfAbsent(debtorId, () => []).add(debt);
      }

      for (final entry in debtsByDebtor.entries) {
        final debtorId = entry.key;
        final debtorDebts = entry.value;
        final debtorRef = debtorsCollection.doc(debtorId);

        int totalDebtAmount = 0;

        for (final debt in debtorDebts) {
          final items = debt['items'] as List<Map<String, dynamic>>;
          final total = debt['total'] as int;
          final notes = debt['notes'] as String? ?? '';

          final debtRef = debtorRef.collection('debts').doc();

          batch.set(debtRef, {
            'items': items,
            'total': total,
            'createdAt': FieldValue.serverTimestamp(),
            'isPaid': false,
            'notes': notes,
          });

          totalDebtAmount += total;
        }

        // Update debtor totals
        batch.update(debtorRef, {
          'totalBorrowed': FieldValue.increment(totalDebtAmount),
          'currentDebt': FieldValue.increment(totalDebtAmount),
          'updatedAt': FieldValue.serverTimestamp(),
          'totalTransactions': FieldValue.increment(debtorDebts.length),
        });

        EnhancedCacheManager.clearDebtorCache(debtorId);
      }

      await batch.commit();
      DebtsFirestoreLogger.logOperation(
        "ADD_MULTIPLE_DEBTS",
        "Successfully added ${debts.length} debts",
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

  // ---------- GET DEBT STATISTICS ----------
  Future<Map<String, dynamic>> getDebtStatistics(String debtorId) async {
    try {
      final debtsSnapshot =
      await debtorsCollection.doc(debtorId).collection('debts').get();

      int totalDebts = debtsSnapshot.docs.length;
      int totalAmount = 0;
      int paidDebts = 0;
      int unpaidDebts = 0;
      DateTime? firstDebt;
      DateTime? lastDebt;

      for (var doc in debtsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['total'] ?? 0) as int;
        final isPaid = (data['isPaid'] ?? false) as bool;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        totalAmount += amount;

        if (isPaid) {
          paidDebts++;
        } else {
          unpaidDebts++;
        }

        if (createdAt != null) {
          if (firstDebt == null || createdAt.isBefore(firstDebt)) {
            firstDebt = createdAt;
          }
          if (lastDebt == null || createdAt.isAfter(lastDebt)) {
            lastDebt = createdAt;
          }
        }
      }

      return {
        'totalDebts': totalDebts,
        'totalAmount': totalAmount,
        'paidDebts': paidDebts,
        'unpaidDebts': unpaidDebts,
        'averageDebtAmount':
        totalDebts > 0 ? (totalAmount / totalDebts).round() : 0,
        'firstDebt': firstDebt,
        'lastDebt': lastDebt,
      };
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "GET_DEBT_STATISTICS",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return {
        'totalDebts': 0,
        'totalAmount': 0,
        'paidDebts': 0,
        'unpaidDebts': 0,
        'averageDebtAmount': 0,
        'firstDebt': null,
        'lastDebt': null,
      };
    }
  }

  // ---------- DELETE ALL DEBTS FOR DEBTOR ----------
  Future<bool> deleteAllDebtsForDebtor(String debtorId) async {
    try {
      final debtorRef = debtorsCollection.doc(debtorId);

      // Get all debts first to calculate total amount
      final debtsSnapshot = await debtorRef.collection('debts').get();
      int totalDebtAmount = 0;

      for (var doc in debtsSnapshot.docs) {
        final data = doc.data();
        totalDebtAmount += (data['total'] ?? 0) as int;
      }

      // Delete debts in batches
      const int batchSize = 500;
      while (true) {
        final snapshot =
        await debtorRef.collection('debts').limit(batchSize).get();
        if (snapshot.docs.isEmpty) break;

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Update debtor totals
      await debtorRef.update({
        'totalBorrowed': FieldValue.increment(-totalDebtAmount),
        'currentDebt': FieldValue.increment(-totalDebtAmount),
        'updatedAt': FieldValue.serverTimestamp(),
        'totalTransactions': 0,
      });

      EnhancedCacheManager.clearDebtorCache(debtorId);
      DebtsFirestoreLogger.logOperation(
        "DELETE_ALL_DEBTS_FOR_DEBTOR",
        "Successfully deleted all debts for debtor: $debtorId",
      );
      return true;
    } catch (e) {
      DebtsFirestoreLogger.logOperation(
        "DELETE_ALL_DEBTS_FOR_DEBTOR",
        "Error: ${DebtsFirestoreErrorHandler.getErrorMessage(e)}",
        isError: true,
      );
      return false;
    }
  }
}
