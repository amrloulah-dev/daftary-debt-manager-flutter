import 'package:flutter/foundation.dart';
import 'package:fatora/models/payment_model.dart';
import 'package:fatora/services/transaction_service.dart';

class PaymentProvider with ChangeNotifier {
  final TransactionService _service = TransactionService();

  List<PaymentTransaction> _payments = [];
  List<PaymentTransaction> get payments => _payments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadPayments(int debtorId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _payments = await _service.getPaymentsForDebtor(debtorId);
    } catch (e) {
      if (kDebugMode) print("Error loading payments: $e");
      _payments = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addPayment({
    required int debtorId,
    required int amount,
    required DateTime date,
    String? notes,
    String? paymentMethod,
  }) async {
    try {
      final newPayment = PaymentTransaction(
        amount: amount,
        createdAt: date,
        addedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        notes: notes,
        paymentMethod: paymentMethod ?? 'Cash',
        status: 'completed',
      );

      await _service.addPayment(debtorId, newPayment);
      
      await loadPayments(debtorId);
      return true;
    } catch (e) {
      if (kDebugMode) print("Error adding payment: $e");
      return false;
    }
  }

  Future<bool> deletePayment(int debtorId, int paymentId) async {
    try {
      await _service.deletePayment(paymentId);
      await loadPayments(debtorId);
      return true;
    } catch (e) {
      if (kDebugMode) print("Error deleting payment: $e");
      return false;
    }
  }
}
