import 'package:fatora/models/debtor_model.dart';
import 'package:fatora/models/debts_model.dart';
import 'package:fatora/models/payment_model.dart';
import 'package:fatora/services/isar_service.dart';
import 'package:isar/isar.dart';

class TransactionService {
  late Future<Isar> db;

  TransactionService() {
    db = IsarService().db;
  }

  // ================== DEBTS ==================

  /// Adds a debt and updates the Debtor's totals
  Future<void> addDebt(int debtorId, DebtTransaction debt) async {
    final isar = await db;

    await isar.writeTxn(() async {
      final debtor = await isar.debtors.get(debtorId);
      if (debtor == null) throw Exception("Debtor not found");

      // 1. Save the debt record first
      await isar.debtTransactions.put(debt);

      // 2. Link it to the debtor
      debt.debtor.value = debtor;
      await debt.debtor.save();

      // 3. Update Debtor Totals
      debtor.totalBorrowed += debt.total;
      debtor.currentDebt += debt.total;
      debtor.updatedAt = DateTime.now();
      debtor.totalTransactions += 1;

      // 4. Save Debtor updates
      await isar.debtors.put(debtor);
    });
  }

  /// Delete a debt and revert the Debtor's totals
  Future<void> deleteDebt(int debtId) async {
    final isar = await db;

    await isar.writeTxn(() async {
      final debt = await isar.debtTransactions.get(debtId);
      if (debt == null) return;

      // Load linked debtor
      await debt.debtor.load();
      final debtor = debt.debtor.value;

      if (debtor != null) {
        // Revert totals
        debtor.totalBorrowed -= debt.total;
        debtor.currentDebt -= debt.total;
        debtor.updatedAt = DateTime.now();
        debtor.totalTransactions = (debtor.totalTransactions > 0) 
            ? debtor.totalTransactions - 1 
            : 0;
        
        await isar.debtors.put(debtor);
      }

      // Delete the debt record
      await isar.debtTransactions.delete(debtId);
    });
  }

  // ================== PAYMENTS ==================

  /// Adds a payment and updates the Debtor's totals
  Future<void> addPayment(int debtorId, PaymentTransaction payment) async {
    final isar = await db;

    await isar.writeTxn(() async {
      final debtor = await isar.debtors.get(debtorId);
      if (debtor == null) throw Exception("Debtor not found");

      // 1. Save payment
      await isar.paymentTransactions.put(payment);

      // 2. Link to debtor
      payment.debtor.value = debtor;
      await payment.debtor.save();

      // 3. Update Debtor Totals
      debtor.totalPaid += payment.amount;
      debtor.currentDebt -= payment.amount; // Debt decreases
      debtor.lastPaymentAt = payment.createdAt;
      debtor.updatedAt = DateTime.now();
      debtor.totalTransactions += 1;

      // 4. Save Debtor
      await isar.debtors.put(debtor);
    });
  }

  /// Delete a payment and revert the Debtor's totals
  Future<void> deletePayment(int paymentId) async {
    final isar = await db;

    await isar.writeTxn(() async {
      final payment = await isar.paymentTransactions.get(paymentId);
      if (payment == null) return;

      await payment.debtor.load();
      final debtor = payment.debtor.value;

      if (debtor != null) {
        // Revert totals
        debtor.totalPaid -= payment.amount;
        debtor.currentDebt += payment.amount; // Debt increases back
        debtor.updatedAt = DateTime.now();
        debtor.totalTransactions = (debtor.totalTransactions > 0) 
            ? debtor.totalTransactions - 1 
            : 0;
        
        // Note: Reverting lastPaymentAt accurately is complex without query history, 
        // we leave it as is or find the previous payment.
        // For simplicity in this phase, we update timestamp but not revert lastPaymentAt date specifically.
        
        await isar.debtors.put(debtor);
      }

      await isar.paymentTransactions.delete(paymentId);
    });
  }

  // ================== FETCHING ==================

  /// Get all debts for a debtor
  Future<List<DebtTransaction>> getDebtsForDebtor(int debtorId) async {
    final isar = await db;
    // We can filter by the link's ID
    return await isar.debtTransactions
        .filter()
        .debtor((q) => q.idEqualTo(debtorId))
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Get all payments for a debtor
  Future<List<PaymentTransaction>> getPaymentsForDebtor(int debtorId) async {
    final isar = await db;
    return await isar.paymentTransactions
        .filter()
        .debtor((q) => q.idEqualTo(debtorId))
        .sortByCreatedAtDesc()
        .findAll();
  }
}
