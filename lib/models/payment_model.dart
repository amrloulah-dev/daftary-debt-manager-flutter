import 'package:isar/isar.dart';
import 'package:fatora/models/debtor_model.dart';

part 'payment_model.g.dart';

@collection
class PaymentTransaction {
  Id id = Isar.autoIncrement;

  late int amount;
  late DateTime createdAt;
  DateTime? updatedAt;
  late DateTime addedAt;
  String? notes;
  
  @Index()
  String paymentMethod = 'Cash'; 

  // Store enum as index or string. String is safer for migrations.
  // Or handle in service. Let's store as String for simplicity in prototype.
  String status = 'completed'; // 'pending', 'completed', 'cancelled'

  final debtor = IsarLink<Debtor>();

  PaymentTransaction({
    this.id = Isar.autoIncrement,
    required this.amount,
    required this.createdAt,
    this.updatedAt,
    required this.addedAt,
    this.notes,
    this.paymentMethod = 'Cash',
    this.status = 'completed',
  });

  bool get isCompleted => status == 'completed';
}
