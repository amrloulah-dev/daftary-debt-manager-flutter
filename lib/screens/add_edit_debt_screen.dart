import 'package:fatora/providers/debts_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

class AddEditDebtScreen extends StatefulWidget {
  final int debtorId;
  
  const AddEditDebtScreen({super.key, required this.debtorId});

  @override
  State<AddEditDebtScreen> createState() => _AddEditDebtScreenState();
}

class _AddEditDebtScreenState extends State<AddEditDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _selectedDate = DateTime.now();
    _addItem(); 
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add({
        'name': '',
        'price': 0.0,
        'quantity': 1,
        'total': 0.0,
        'description': '',
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, String field, dynamic value) {
    setState(() {
      _items[index][field] = value;
      if (field == 'price' || field == 'quantity') {
        final price = (_items[index]['price'] as num).toDouble();
        final qty = (_items[index]['quantity'] as int);
        _items[index]['total'] = price * qty;
      }
    });
  }

  double get _grandTotal {
    return _items.fold(0.0, (sum, item) => sum + (item['total'] as double));
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_grandTotal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total amount must be greater than 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    
    final success = await context.read<DebtsProvider>().addDebt(
      debtorId: widget.debtorId,
      items: _items,
      total: _grandTotal.round(),
      notes: _notesController.text,
      date: _selectedDate,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.debtSavedSuccess)),
      );
      Navigator.pop(context, true);
    } else {
      // Fix: Direct method call instead of replaceAll
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSavingDebt('Unknown'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addDebt),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.surface,
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _notesController,
                                decoration: InputDecoration(
                                  labelText: l10n.notesOptional,
                                  prefixIcon: const Icon(Icons.note),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                title: Text(l10n.date),
                                subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                                trailing: const Icon(Icons.calendar_today),
                                tileColor: theme.colorScheme.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onTap: () => _selectDate(context),
                              ),
                            ],
                          );
                        }
                        return _buildItemRow(index, theme, l10n);
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, -2),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.totalDebt, style: theme.textTheme.bodySmall),
                            Text(
                              NumberFormat.currency(symbol: '').format(_grandTotal),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppThemes.debtColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _saveDebt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemes.debtColor,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: Text(l10n.save),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildItemRow(int index, ThemeData theme, AppLocalizations l10n) {
    final item = _items[index];
    
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: item['name'],
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    onChanged: (val) => _updateItem(index, 'name', val),
                    validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: _items.length > 1 ? () => _removeItem(index) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item['price'] == 0.0 ? '' : item['price'].toString(),
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      final price = double.tryParse(val) ?? 0.0;
                      _updateItem(index, 'price', price);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: item['quantity'].toString(),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final qty = int.tryParse(val) ?? 1;
                      _updateItem(index, 'quantity', qty);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.centerRight,
                    child: Text(
                      NumberFormat.currency(symbol: '').format(item['total']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}