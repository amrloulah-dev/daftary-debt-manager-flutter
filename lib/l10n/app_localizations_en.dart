// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fatora';

  @override
  String get home => 'Home';

  @override
  String get debtor => 'Debtor';

  @override
  String get debtors => 'Debtors';

  @override
  String get debts => 'Debts';

  @override
  String get payments => 'Payments';

  @override
  String get statistics => 'Statistics';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get addDebt => 'Add Debt';

  @override
  String get addPayment => 'Add Payment';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get search => 'Search';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get description => 'Description';

  @override
  String get notes => 'Notes';

  @override
  String get paid => 'Paid';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get summary => 'Summary';

  @override
  String get borrowed => 'Borrowed';

  @override
  String get outstanding => 'Outstanding';

  @override
  String get totalDebtors => 'Total Debtors';

  @override
  String get activeDebtors => 'Active Debtors';

  @override
  String get totalDebt => 'Total Debt';

  @override
  String get totalPaid => 'Total Paid';

  @override
  String get addDebtor => 'Add Debtor';

  @override
  String get editDebtor => 'Edit Debtor';

  @override
  String get deleteDebtor => 'Delete Debtor';

  @override
  String get deleteDebtorConfirmation =>
      'Are you sure you want to delete this debtor and all their associated records? This action cannot be undone.';

  @override
  String get debtorNameRequired => 'Debtor name is required.';

  @override
  String get addEditDebtScreenTitle => 'Add/Edit Debt';

  @override
  String get addEditPaymentScreenTitle => 'Add/Edit Payment';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get recordPayment => 'Record Payment';

  @override
  String get deletePayment => 'Delete Payment';

  @override
  String get deletePaymentConfirmation =>
      'Are you sure you want to delete this payment? This action cannot be undone.';

  @override
  String get deleteDebtConfirmation =>
      'Are you sure you want to delete this debt? This action cannot be undone.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithFacebook => 'Sign in with Facebook';

  @override
  String get welcomeBack => 'Welcome back!';

  @override
  String get hello => 'Hello';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get recordPaymentTitle => 'Record Payment';

  @override
  String get sendReminder => 'Send Reminder';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get viewAll => 'View All';

  @override
  String get byName => 'By Name';

  @override
  String get byDebtAmount => 'By Debt Amount';

  @override
  String get byLastPayment => 'By Last Payment';

  @override
  String get noDebtorsFound => 'No debtors found';

  @override
  String get noDebtorsFoundHint => 'Tap the \'+\' button to add a new debtor.';

  @override
  String get searchDebtorsHint => 'Search debtors...';

  @override
  String get debtDetails => 'Debt Details';

  @override
  String get paymentDetails => 'Payment Details';

  @override
  String get paidOff => 'Paid Off';

  @override
  String get active => 'Active';

  @override
  String get lastPayment => 'Last payment';

  @override
  String get noPaymentsYet => 'No payments yet';

  @override
  String get selectDateRange => 'Select Date Range';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get avgDebtPerDebtor => 'Avg. Debt per Debtor';

  @override
  String get paymentRate => 'Payment Rate';

  @override
  String get totalOutstanding => 'Total Outstanding';

  @override
  String get monthlyPaymentAvg => 'Monthly Payment Avg';

  @override
  String get debtDistribution => 'Debt Distribution';

  @override
  String get paymentTrends => 'Payment Trends';

  @override
  String get monthlyComparison => 'Monthly Comparison';

  @override
  String get appSubtitle => 'Manage your debts and payments efficiently';

  @override
  String get signInFailed => 'Sign-In cancelled or failed';

  @override
  String get couldNotLoadStats => 'Could not load stats.';

  @override
  String get couldNotLoadTransactions => 'Could not load transactions.';

  @override
  String get noRecentTransactions => 'No recent transactions';

  @override
  String get tryAdjustingSearch => 'Try adjusting your search.';

  @override
  String get transactions => 'Transactions';

  @override
  String get percentPaid => '% Paid';

  @override
  String get errorLoadingDebts => 'Error loading debts.';

  @override
  String get errorLoadingPayments => 'Error loading payments.';

  @override
  String get noPaymentsFound => 'No payments found.';

  @override
  String get debtorSavedSuccess => 'Debtor saved successfully!';

  @override
  String errorSavingDebtor(Object error) {
    return 'Error saving debtor: $error';
  }

  @override
  String get debtorDeletedSuccess => 'Debtor deleted successfully!';

  @override
  String errorDeletingDebtor(Object error) {
    return 'Error deleting debtor: $error';
  }

  @override
  String get emailAddress => 'Email Address';

  @override
  String get invalidEmailAddress => 'Please enter a valid email address.';

  @override
  String get debtSavedSuccess => 'Debt saved successfully!';

  @override
  String errorSavingDebt(Object error) {
    return 'Error saving debt: $error';
  }

  @override
  String get debtDeletedSuccess => 'Debt deleted successfully!';

  @override
  String errorDeletingDebt(Object error) {
    return 'Error deleting debt: $error';
  }

  @override
  String get amountRequired => 'Please enter an amount';

  @override
  String get invalidNumber => 'Please enter a valid number';

  @override
  String get isDebtPaid => 'Is this debt paid?';

  @override
  String get paymentSavedSuccess => 'Payment saved successfully!';

  @override
  String errorSavingPayment(Object error) {
    return 'Error saving payment: $error';
  }

  @override
  String get paymentDeletedSuccess => 'Payment deleted successfully!';

  @override
  String errorDeletingPayment(Object error) {
    return 'Error deleting payment: $error';
  }

  @override
  String get cash => 'Cash';

  @override
  String get bankTransfer => 'Bank Transfer';

  @override
  String get check => 'Check';

  @override
  String get other => 'Other';

  @override
  String get currentDebt => 'Current Debt';

  @override
  String get newBalance => 'New Balance';

  @override
  String forDebtor(Object name) {
    return 'For: $name';
  }

  @override
  String toDebtor(Object name) {
    return 'To: $name';
  }

  @override
  String get editDebt => 'Edit Debt';

  @override
  String get editPayment => 'Edit Payment';

  @override
  String get debtorName => 'Debtor Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String errorOccurred(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get chartPlaceholder => 'Chart placeholder';
}
