import 'package:isar/isar.dart';
import 'package:fatora/models/debtor_model.dart';

part 'debts_model.g.dart';

@collection
class DebtTransaction {
  Id id = Isar.autoIncrement;

  late int total;
  late DateTime createdAt;
  DateTime? updatedAt;
  bool isPaid = false;
  String? notes;

  // Embedded objects list
  List<DebtItem> items = [];

  final debtor = IsarLink<Debtor>();

  DebtTransaction({
    this.id = Isar.autoIncrement,
    required this.total,
    required this.createdAt,
    this.updatedAt,
    this.isPaid = false,
    this.notes,
    this.items = const [],
  });

  // --- Helper Methods ---
  int get itemsCount => items.length;
}

@embedded
class DebtItem {
  String? name;
  double? price;
  int? quantity;
  double? total;
  String? description;

  DebtItem({
    this.name,
    this.price,
    this.quantity,
    this.total, // Usually calculated
    this.description,
  });
}