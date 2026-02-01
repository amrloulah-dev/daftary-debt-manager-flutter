import 'package:fatora/providers/payment_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

class AddEditPaymentScreen extends StatefulWidget {
  final int debtorId;

  const AddEditPaymentScreen({super.key, required this.debtorId});

  @override
  State<AddEditPaymentScreen> createState() => _AddEditPaymentScreenState();
}

class _AddEditPaymentScreenState extends State<AddEditPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  String _paymentMethod = 'Cash'; // Default

  bool _isLoading = false;

  final List<String> _paymentMethods = ['Cash', 'Bank Transfer', 'Check', 'Other'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    
    // Parse amount
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    
    if (amount <= 0) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.amountRequired)),
      );
      return;
    }

    final success = await context.read<PaymentProvider>().addPayment(
      debtorId: widget.debtorId,
      amount: amount.round(), // Using int as per model
      date: _selectedDate,
      notes: _notesController.text.trim(),
      paymentMethod: _paymentMethod,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.paymentSavedSuccess)),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorSavingPayment('Unknown'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addPayment),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Amount Field
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.amount, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppThemes.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                prefixText: '', // Currency symbol if needed
                                hintText: '0.00',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.amountRequired;
                                }
                                if (double.tryParse(value) == null) {
                                  return l10n.invalidNumber;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date Picker
                    ListTile(
                      title: Text(l10n.date),
                      subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      tileColor: theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Dropdown
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: InputDecoration(
                        labelText: l10n.paymentMethod,
                        prefixIcon: const Icon(Icons.credit_card),
                      ),
                      items: _paymentMethods.map((String method) {
                        return DropdownMenuItem<String>(
                          value: method,
                          child: Text(method), // Should translate these in real app
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _paymentMethod = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: l10n.notesOptional,
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _savePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemes.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}