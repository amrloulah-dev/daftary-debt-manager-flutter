import 'package:fatora/models/debtor_model.dart' as debtor_model;
import 'package:fatora/models/payment_model.dart' as payment_model;
import 'package:fatora/providers/payment_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

class AddEditPaymentScreen extends StatefulWidget {
  final debtor_model.Debtor debtor;
  final payment_model.PaymentTransaction? payment;

  const AddEditPaymentScreen({super.key, required this.debtor, this.payment});

  @override
  State<AddEditPaymentScreen> createState() => _AddEditPaymentScreenState();
}

class _AddEditPaymentScreenState extends State<AddEditPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentProvider = PaymentProvider();

  late TextEditingController _amountController;
  late TextEditingController _notesController;
  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  int _paymentAmount = 0;

  bool get _isEditMode => widget.payment != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: _isEditMode ? widget.payment!.amount.toString() : '');
    _notesController =
        TextEditingController(text: _isEditMode ? widget.payment!.notes : '');

    if (_isEditMode) {
      _selectedDate = widget.payment!.createdAt;
      _paymentAmount = widget.payment!.amount;
      _paymentMethod = widget.payment!.paymentMethod;
    }

    _amountController.addListener(() {
      setState(() {
        _paymentAmount = int.tryParse(_amountController.text) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final l10n = AppLocalizations.of(context)!;

      try {
        if (_isEditMode) {
          await _paymentProvider.updatePayment(
            debtorId: widget.debtor.id,
            paymentId: widget.payment!.id,
            newAmount: _paymentAmount,
            newDate: _selectedDate,
            notes: _notesController.text,
            paymentMethod: _paymentMethod,
          );
        } else {
          await _paymentProvider.addPayment(
            debtorId: widget.debtor.id,
            amount: _paymentAmount,
            date: _selectedDate,
            notes: _notesController.text,
            paymentMethod: _paymentMethod,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.paymentSavedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorSavingPayment(e.toString())),
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

  Future<void> _deletePayment() async {
    if (!_isEditMode) return;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePayment),
        content: Text(l10n.deletePaymentConfirmation),
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
        await _paymentProvider.deletePayment(
          debtorId: widget.debtor.id,
          paymentId: widget.payment!.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.paymentDeletedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorDeletingPayment(e.toString())),
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
    final newBalance = widget.debtor.currentDebt - _paymentAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addEditPaymentScreenTitle),
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
              Text(l10n.toDebtor(widget.debtor.name), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('${l10n.currentDebt}: ${NumberFormat.currency(symbol: '').format(widget.debtor.currentDebt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppThemes.debtColor)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                style: const TextStyle(fontSize: 24, color: AppThemes.successColor),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  prefixStyle: const TextStyle(fontSize: 24, color: AppThemes.successColor),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.amountRequired;
                  }
                  if (int.tryParse(value) == null) {
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
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                onChanged: (String? newValue) {
                  setState(() {
                    _paymentMethod = newValue!;
                  });
                },
                items: <String>['Cash', 'Bank Transfer', 'Check', 'Other']
                    .map<DropdownMenuItem<String>>((String value) {
                  String text;
                  switch (value) {
                    case 'Bank Transfer':
                      text = l10n.bankTransfer;
                      break;
                    case 'Check':
                      text = l10n.check;
                      break;
                    case 'Other':
                      text = l10n.other;
                      break;
                    case 'Cash':
                    default:
                      text = l10n.cash;
                      break;
                  }
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(text),
                  );
                }).toList(),
                decoration: InputDecoration(labelText: l10n.paymentMethod),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.notesOptional,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildBalanceSummary(newBalance, theme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildActionButtons(theme),
    );
  }

  Widget _buildBalanceSummary(int newBalance, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppThemes.radiusMedium),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.currentDebt),
              Text(NumberFormat.currency(symbol: '').format(widget.debtor.currentDebt)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.payments, style: const TextStyle(color: AppThemes.successColor)),
              Text(
                '-${NumberFormat.currency(symbol: '').format(_paymentAmount)}',
                style: const TextStyle(color: AppThemes.successColor),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.newBalance, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                NumberFormat.currency(symbol: '').format(newBalance),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppThemes.debtColor),
              ),
            ],
          ),
        ],
      ),
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
            onPressed: _isLoading ? null : _savePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemes.successColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(l10n.recordPayment),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (_isEditMode)
            TextButton(
              onPressed: _isLoading ? null : _deletePayment,
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
              child: Text(l10n.deletePayment),
            ),
        ],
      ),
    );
  }
}