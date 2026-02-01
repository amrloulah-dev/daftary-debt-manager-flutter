import 'package:flutter/foundation.dart';
import 'package:fatora/models/debts_model.dart';
import 'package:fatora/services/transaction_service.dart';

class DebtsProvider with ChangeNotifier {
  final TransactionService _service = TransactionService();

  List<DebtTransaction> _debts = [];
  List<DebtTransaction> get debts => _debts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadDebts(int debtorId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _debts = await _service.getDebtsForDebtor(debtorId);
    } catch (e) {
      if (kDebugMode) print("Error loading debts: $e");
      _debts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDebt({
    required int debtorId,
    required List<Map<String, dynamic>> items,
    required int total,
    String? notes,
    DateTime? date,
  }) async {
    try {
      // Map UI List<Map> to List<DebtItem>
      final debtItems = items.map((i) {
        return DebtItem(
          name: i['name'],
          price: (i['price'] as num).toDouble(),
          quantity: i['quantity'] as int,
          total: (i['total'] as num).toDouble(),
          description: i['description'],
        );
      }).toList();

      final newDebt = DebtTransaction(
        total: total,
        createdAt: date ?? DateTime.now(),
        updatedAt: DateTime.now(),
        notes: notes,
        items: debtItems,
        isPaid: false,
      );

      await _service.addDebt(debtorId, newDebt);
      
      // Refresh local list
      await loadDebts(debtorId);
      return true;
    } catch (e) {
      if (kDebugMode) print("Error adding debt: $e");
      return false;
    }
  }

  Future<bool> deleteDebt(int debtorId, int debtId) async {
    try {
      await _service.deleteDebt(debtId);
      await loadDebts(debtorId);
      return true;
    } catch (e) {
      if (kDebugMode) print("Error deleting debt: $e");
      return false;
    }
  }
}