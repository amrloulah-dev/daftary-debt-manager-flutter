import 'package:flutter/foundation.dart';
import 'package:fatora/models/debtor_model.dart';
import 'package:fatora/services/debtor_service.dart';

class DebtorProvider with ChangeNotifier {
  final DebtorService _service = DebtorService();

  List<Debtor> _debtors = [];
  List<Debtor> get debtors => _debtors;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Cache for statistics
  GeneralStatistics _stats = const GeneralStatistics(
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
  GeneralStatistics get statistics => _stats;

  // ---------- LOAD & SEARCH ----------

  Future<void> loadDebtors() async {
    _isLoading = true;
    notifyListeners();

    try {
      _debtors = await _service.getAllDebtors();
      _calculateStatistics();
    } catch (e) {
      if (kDebugMode) print("Error loading debtors: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchDebtors(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      _debtors = await _service.searchDebtors(query);
    } catch (e) {
      if (kDebugMode) print("Error searching debtors: $e");
      _debtors = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------- CRUD OPERATIONS ----------

  Future<bool> addDebtor({
    required String name,
    required String phone,
    String? email,
    String? notes,
  }) async {
    try {
      final newDebtor = Debtor(
        name: name,
        phone: phone,
        email: email,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _service.saveDebtor(newDebtor);
      
      // Efficient update: add to top of list and notify, or reload
      // Reloading ensures sorting is correct based on Service logic
      await loadDebtors(); 
      return true;
    } catch (e) {
      if (kDebugMode) print("Error adding debtor: $e");
      return false;
    }
  }

  Future<bool> updateDebtorInfo({
    required int id,
    String? name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    try {
      final existing = await _service.getDebtorById(id);
      if (existing == null) return false;

      // Update fields
      if (name != null) existing.name = name;
      if (phone != null) existing.phone = phone;
      if (email != null) existing.email = email;
      if (notes != null) existing.notes = notes;
      existing.updatedAt = DateTime.now();

      await _service.saveDebtor(existing);
      await loadDebtors();
      return true;
    } catch (e) {
      if (kDebugMode) print("Error updating debtor: $e");
      return false;
    }
  }

  Future<bool> deleteDebtor(int id) async {
    try {
      await _service.deleteDebtor(id);
      _debtors.removeWhere((d) => d.id == id);
      _calculateStatistics();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print("Error deleting debtor: $e");
      return false;
    }
  }

  // ---------- STATISTICS LOGIC ----------

  void _calculateStatistics() {
    int totalDebtors = _debtors.length;
    int activeDebtors = 0;
    int totalBorrowed = 0;
    int totalPaid = 0;
    int totalCurrentDebt = 0;
    int zeroDebtDebtors = 0;

    for (var d in _debtors) {
      if (d.isActive) activeDebtors++;
      totalBorrowed += d.totalBorrowed;
      totalPaid += d.totalPaid;
      totalCurrentDebt += d.currentDebt;
      if (d.currentDebt == 0) zeroDebtDebtors++;
    }

    _stats = GeneralStatistics(
      totalDebtors: totalDebtors,
      activeDebtors: activeDebtors,
      inactiveDebtors: totalDebtors - activeDebtors,
      totalBorrowed: totalBorrowed,
      totalPaid: totalPaid,
      totalCurrentDebt: totalCurrentDebt,
      zeroDebtDebtors: zeroDebtDebtors,
      debtorsWithDebt: totalDebtors - zeroDebtDebtors,
      averageDebt: totalDebtors > 0 ? (totalCurrentDebt / totalDebtors).round() : 0,
      paymentRate: totalBorrowed > 0 ? ((totalPaid / totalBorrowed) * 100).round() : 0,
    );
  }
}

// Keep the model class here for UI compatibility or move to separate file if desired
class GeneralStatistics {
  final int totalDebtors;
  final int activeDebtors;
  final int inactiveDebtors;
  final int totalBorrowed;
  final int totalPaid;
  final int totalCurrentDebt;
  final int zeroDebtDebtors;
  final int debtorsWithDebt;
  final int averageDebt;
  final int paymentRate;

  const GeneralStatistics({
    required this.totalDebtors,
    required this.activeDebtors,
    required this.inactiveDebtors,
    required this.totalBorrowed,
    required this.totalPaid,
    required this.totalCurrentDebt,
    required this.zeroDebtDebtors,
    required this.debtorsWithDebt,
    required this.averageDebt,
    required this.paymentRate,
  });
}