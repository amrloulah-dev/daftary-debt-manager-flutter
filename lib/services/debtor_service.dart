import 'package:fatora/models/debtor_model.dart';
import 'package:fatora/models/debts_model.dart';
import 'package:fatora/models/payment_model.dart';
import 'package:fatora/services/isar_service.dart';
import 'package:isar/isar.dart';

class DebtorService {
  late Future<Isar> db;

  DebtorService() {
    db = IsarService().db;
  }

  // --- READ ---

  /// Get all debtors, sorted by latest update
  Future<List<Debtor>> getAllDebtors() async {
    final isar = await db;
    return await isar.debtors.where().sortByUpdatedAtDesc().findAll();
  }

  /// Get specific debtor by ID with links loaded
  Future<Debtor?> getDebtorById(int id) async {
    final isar = await db;
    final debtor = await isar.debtors.get(id);
    if (debtor != null) {
      // Ensure links are loaded if not eager loaded
      // In Isar 3.x, accessing the link property usually loads it lazily or requires explicit load
      // For IsarLinks, they are lazy.
      await debtor.debts.load();
      await debtor.payments.load();
    }
    return debtor;
  }

  /// Search debtors by name or phone
  Future<List<Debtor>> searchDebtors(String query) async {
    final isar = await db;
    if (query.isEmpty) return getAllDebtors();

    return await isar.debtors
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .phoneContains(query)
        .findAll();
  }

  // --- WRITE ---

  /// Add or Update a debtor
  Future<int> saveDebtor(Debtor debtor) async {
    final isar = await db;
    return await isar.writeTxn(() async {
      return await isar.debtors.put(debtor);
    });
  }

  // --- DELETE ---

  /// Cascade delete: Deletes debtor AND all associated debts/payments
  Future<void> deleteDebtor(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      final debtor = await isar.debtors.get(id);
      if (debtor == null) return;

      // 1. Load links to get IDs
      await debtor.debts.load();
      await debtor.payments.load();

      // 2. Delete linked debts
      final debtIds = debtor.debts.map((e) => e.id).toList();
      if (debtIds.isNotEmpty) {
        await isar.debtTransactions.deleteAll(debtIds);
      }

      // 3. Delete linked payments
      final paymentIds = debtor.payments.map((e) => e.id).toList();
      if (paymentIds.isNotEmpty) {
        await isar.paymentTransactions.deleteAll(paymentIds);
      }

      // 4. Delete the debtor itself
      await isar.debtors.delete(id);
    });
  }
}
