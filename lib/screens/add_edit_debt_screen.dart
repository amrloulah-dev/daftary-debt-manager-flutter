import 'package:fatora/models/debtor_model.dart' as debtor_model;
import 'package:fatora/models/debts_model.dart' as debts_model;
import 'package:fatora/providers/debts_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class AddEditDebtScreen extends StatefulWidget {
  final debtor_model.Debtor debtor;
  final debts_model.DebtTransaction? debt;

  const AddEditDebtScreen({super.key, required this.debtor, this.debt});

  @override
  State<AddEditDebtScreen> createState() => _AddEditDebtScreenState();
}

class _AddEditDebtScreenState extends State<AddEditDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _debtsProvider = DebtProvider();

  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  DateTime _selectedDate = DateTime.now();
  bool _isPaid = false;
  bool _isLoading = false;

  bool get _isEditMode => widget.debt != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: _isEditMode ? widget.debt!.total.toString() : '');
    _descriptionController = TextEditingController(
        text: _isEditMode ? widget.debt!.notes : '');
    if (_isEditMode) {
      _selectedDate = widget.debt!.createdAt;
      _isPaid = widget.debt!.isPaid;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveDebt() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final l10n = AppLocalizations.of(context)!;

      final amount = int.tryParse(_amountController.text) ?? 0;
      final description = _descriptionController.text;

      try {
        if (_isEditMode) {
          await _debtsProvider.updateDebt(
            debtorId: widget.debtor.id,
            debtId: widget.debt!.id,
            newTotal: amount,
            notes: description,
          );
        } else {
          await _debtsProvider.addDebt(
            debtorId: widget.debtor.id,
            items: [
              {
                'name': l10n.debts,
                'quantity': 1,
                'price': amount,
              }
            ],
            total: amount,
            notes: description,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.debtSavedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorSavingDebt(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _deleteDebt() async {
    if (!_isEditMode) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteDebtor),
        content: Text(l10n.deleteDebtConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _debtsProvider.deleteDebt(
          debtorId: widget.debtor.id,
          debtId: widget.debt!.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.debtDeletedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorDeletingDebt(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addEditDebtScreenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.forDebtor(widget.debtor.name), style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                style: const TextStyle(fontSize: 24),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.amount,
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
              const SizedBox(height: 16),
              TextFormField(
                readOnly: true,
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null && pickedDate != _selectedDate) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: l10n.date,
                  suffixIcon: const Icon(Icons.calendar_today),
                  hintText: DateFormat.yMMMd().format(_selectedDate),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.descriptionOptional,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.isDebtPaid),
                value: _isPaid,
                onChanged: (bool value) {
                  setState(() {
                    _isPaid = value;
                  });
                },
                activeColor: AppThemes.successColor,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildActionButtons(theme),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _saveDebt,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemes.debtColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(l10n.save),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (_isEditMode)
            TextButton(
              onPressed: _isLoading ? null : _deleteDebt,
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(l10n.deleteDebtor),
            ),
        ],
      ),
    );
  }
}