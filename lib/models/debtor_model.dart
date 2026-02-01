import 'package:isar/isar.dart';
import 'package:fatora/models/debts_model.dart';
import 'package:fatora/models/payment_model.dart';

part 'debtor_model.g.dart';

@collection
class Debtor {
  Id id = Isar.autoIncrement; // Auto-increment ID

  @Index(type: IndexType.value, caseSensitive: false)
  late String name;

  @Index(type: IndexType.value)
  late String phone;

  String? email;
  String? notes;

  int totalBorrowed = 0;
  int totalPaid = 0;
  int currentDebt = 0;

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  bool isActive = true;
  DateTime? lastPaymentAt;
  int totalTransactions = 0;

  @Backlink(to: 'debtor')
  final debts = IsarLinks<DebtTransaction>();

  @Backlink(to: 'debtor')
  final payments = IsarLinks<PaymentTransaction>();

  // Constructor
  Debtor({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    this.totalBorrowed = 0,
    this.totalPaid = 0,
    this.currentDebt = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.lastPaymentAt,
    this.totalTransactions = 0,
  });

  // --- Helper Getters (UI Logic) ---

  // Enum mapping for Status
  @ignore
  DebtorStatus get status {
    if (!isActive) return DebtorStatus.inactive;
    if (currentDebt == 0) return DebtorStatus.zeroDebt;
    return DebtorStatus.active;
  }

  @ignore
  bool get hasActiveDebt => isActive && currentDebt > 0;

  @ignore
  double get paymentRate =>
      totalBorrowed > 0 ? (totalPaid / totalBorrowed) * 100 : 0;

  @ignore
  String get riskLevel {
    if (currentDebt == 0) return 'آمن';
    if (currentDebt < 100) return 'منخفض';
    if (currentDebt < 500) return 'متوسط';
    if (currentDebt < 1000) return 'مرتفع';
    return 'خطر عالي';
  }

  @ignore
  String get riskColor {
    switch (riskLevel) {
      case 'آمن':
        return 'green';
      case 'منخفض':
        return 'blue';
      case 'متوسط':
        return 'orange';
      case 'مرتفع':
        return 'red';
      case 'خطر عالي':
        return 'darkred';
      default:
        return 'gray';
    }
  }

  @ignore
  int? get daysSinceLastPayment {
    if (lastPaymentAt == null) return null;
    return DateTime.now().difference(lastPaymentAt!).inDays;
  }
}

// Enums (kept for UI logic)
enum DebtorStatus { active, inactive, zeroDebt }