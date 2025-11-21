import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fatora'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @debtor.
  ///
  /// In en, this message translates to:
  /// **'Debtor'**
  String get debtor;

  /// No description provided for @debtors.
  ///
  /// In en, this message translates to:
  /// **'Debtors'**
  String get debtors;

  /// No description provided for @debts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debts;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @addDebt.
  ///
  /// In en, this message translates to:
  /// **'Add Debt'**
  String get addDebt;

  /// No description provided for @addPayment.
  ///
  /// In en, this message translates to:
  /// **'Add Payment'**
  String get addPayment;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaid;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @borrowed.
  ///
  /// In en, this message translates to:
  /// **'Borrowed'**
  String get borrowed;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get outstanding;

  /// No description provided for @totalDebtors.
  ///
  /// In en, this message translates to:
  /// **'Total Debtors'**
  String get totalDebtors;

  /// No description provided for @activeDebtors.
  ///
  /// In en, this message translates to:
  /// **'Active Debtors'**
  String get activeDebtors;

  /// No description provided for @totalDebt.
  ///
  /// In en, this message translates to:
  /// **'Total Debt'**
  String get totalDebt;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// No description provided for @addDebtor.
  ///
  /// In en, this message translates to:
  /// **'Add Debtor'**
  String get addDebtor;

  /// No description provided for @editDebtor.
  ///
  /// In en, this message translates to:
  /// **'Edit Debtor'**
  String get editDebtor;

  /// No description provided for @deleteDebtor.
  ///
  /// In en, this message translates to:
  /// **'Delete Debtor'**
  String get deleteDebtor;

  /// No description provided for @deleteDebtorConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this debtor and all their associated records? This action cannot be undone.'**
  String get deleteDebtorConfirmation;

  /// No description provided for @debtorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Debtor name is required.'**
  String get debtorNameRequired;

  /// No description provided for @addEditDebtScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add/Edit Debt'**
  String get addEditDebtScreenTitle;

  /// No description provided for @addEditPaymentScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add/Edit Payment'**
  String get addEditPaymentScreenTitle;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPayment;

  /// No description provided for @deletePayment.
  ///
  /// In en, this message translates to:
  /// **'Delete Payment'**
  String get deletePayment;

  /// No description provided for @deletePaymentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this payment? This action cannot be undone.'**
  String get deletePaymentConfirmation;

  /// No description provided for @deleteDebtConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this debt? This action cannot be undone.'**
  String get deleteDebtConfirmation;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithFacebook.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Facebook'**
  String get signInWithFacebook;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get welcomeBack;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @recordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get recordPaymentTitle;

  /// No description provided for @sendReminder.
  ///
  /// In en, this message translates to:
  /// **'Send Reminder'**
  String get sendReminder;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @byName.
  ///
  /// In en, this message translates to:
  /// **'By Name'**
  String get byName;

  /// No description provided for @byDebtAmount.
  ///
  /// In en, this message translates to:
  /// **'By Debt Amount'**
  String get byDebtAmount;

  /// No description provided for @byLastPayment.
  ///
  /// In en, this message translates to:
  /// **'By Last Payment'**
  String get byLastPayment;

  /// No description provided for @noDebtorsFound.
  ///
  /// In en, this message translates to:
  /// **'No debtors found'**
  String get noDebtorsFound;

  /// No description provided for @noDebtorsFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the \'+\' button to add a new debtor.'**
  String get noDebtorsFoundHint;

  /// No description provided for @searchDebtorsHint.
  ///
  /// In en, this message translates to:
  /// **'Search debtors...'**
  String get searchDebtorsHint;

  /// No description provided for @debtDetails.
  ///
  /// In en, this message translates to:
  /// **'Debt Details'**
  String get debtDetails;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// No description provided for @paidOff.
  ///
  /// In en, this message translates to:
  /// **'Paid Off'**
  String get paidOff;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @lastPayment.
  ///
  /// In en, this message translates to:
  /// **'Last payment'**
  String get lastPayment;

  /// No description provided for @noPaymentsYet.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get noPaymentsYet;

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select Date Range'**
  String get selectDateRange;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @avgDebtPerDebtor.
  ///
  /// In en, this message translates to:
  /// **'Avg. Debt per Debtor'**
  String get avgDebtPerDebtor;

  /// No description provided for @paymentRate.
  ///
  /// In en, this message translates to:
  /// **'Payment Rate'**
  String get paymentRate;

  /// No description provided for @totalOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Total Outstanding'**
  String get totalOutstanding;

  /// No description provided for @monthlyPaymentAvg.
  ///
  /// In en, this message translates to:
  /// **'Monthly Payment Avg'**
  String get monthlyPaymentAvg;

  /// No description provided for @debtDistribution.
  ///
  /// In en, this message translates to:
  /// **'Debt Distribution'**
  String get debtDistribution;

  /// No description provided for @paymentTrends.
  ///
  /// In en, this message translates to:
  /// **'Payment Trends'**
  String get paymentTrends;

  /// No description provided for @monthlyComparison.
  ///
  /// In en, this message translates to:
  /// **'Monthly Comparison'**
  String get monthlyComparison;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your debts and payments efficiently'**
  String get appSubtitle;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-In cancelled or failed'**
  String get signInFailed;

  /// No description provided for @couldNotLoadStats.
  ///
  /// In en, this message translates to:
  /// **'Could not load stats.'**
  String get couldNotLoadStats;

  /// No description provided for @couldNotLoadTransactions.
  ///
  /// In en, this message translates to:
  /// **'Could not load transactions.'**
  String get couldNotLoadTransactions;

  /// No description provided for @noRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'No recent transactions'**
  String get noRecentTransactions;

  /// No description provided for @tryAdjustingSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search.'**
  String get tryAdjustingSearch;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @percentPaid.
  ///
  /// In en, this message translates to:
  /// **'% Paid'**
  String get percentPaid;

  /// No description provided for @errorLoadingDebts.
  ///
  /// In en, this message translates to:
  /// **'Error loading debts.'**
  String get errorLoadingDebts;

  /// No description provided for @errorLoadingPayments.
  ///
  /// In en, this message translates to:
  /// **'Error loading payments.'**
  String get errorLoadingPayments;

  /// No description provided for @noPaymentsFound.
  ///
  /// In en, this message translates to:
  /// **'No payments found.'**
  String get noPaymentsFound;

  /// No description provided for @debtorSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Debtor saved successfully!'**
  String get debtorSavedSuccess;

  /// No description provided for @errorSavingDebtor.
  ///
  /// In en, this message translates to:
  /// **'Error saving debtor: {error}'**
  String errorSavingDebtor(Object error);

  /// No description provided for @debtorDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Debtor deleted successfully!'**
  String get debtorDeletedSuccess;

  /// No description provided for @errorDeletingDebtor.
  ///
  /// In en, this message translates to:
  /// **'Error deleting debtor: {error}'**
  String errorDeletingDebtor(Object error);

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @invalidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get invalidEmailAddress;

  /// No description provided for @debtSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Debt saved successfully!'**
  String get debtSavedSuccess;

  /// No description provided for @errorSavingDebt.
  ///
  /// In en, this message translates to:
  /// **'Error saving debt: {error}'**
  String errorSavingDebt(Object error);

  /// No description provided for @debtDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Debt deleted successfully!'**
  String get debtDeletedSuccess;

  /// No description provided for @errorDeletingDebt.
  ///
  /// In en, this message translates to:
  /// **'Error deleting debt: {error}'**
  String errorDeletingDebt(Object error);

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get amountRequired;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get invalidNumber;

  /// No description provided for @isDebtPaid.
  ///
  /// In en, this message translates to:
  /// **'Is this debt paid?'**
  String get isDebtPaid;

  /// No description provided for @paymentSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment saved successfully!'**
  String get paymentSavedSuccess;

  /// No description provided for @errorSavingPayment.
  ///
  /// In en, this message translates to:
  /// **'Error saving payment: {error}'**
  String errorSavingPayment(Object error);

  /// No description provided for @paymentDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment deleted successfully!'**
  String get paymentDeletedSuccess;

  /// No description provided for @errorDeletingPayment.
  ///
  /// In en, this message translates to:
  /// **'Error deleting payment: {error}'**
  String errorDeletingPayment(Object error);

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @currentDebt.
  ///
  /// In en, this message translates to:
  /// **'Current Debt'**
  String get currentDebt;

  /// No description provided for @newBalance.
  ///
  /// In en, this message translates to:
  /// **'New Balance'**
  String get newBalance;

  /// No description provided for @forDebtor.
  ///
  /// In en, this message translates to:
  /// **'For: {name}'**
  String forDebtor(Object name);

  /// No description provided for @toDebtor.
  ///
  /// In en, this message translates to:
  /// **'To: {name}'**
  String toDebtor(Object name);

  /// No description provided for @editDebt.
  ///
  /// In en, this message translates to:
  /// **'Edit Debt'**
  String get editDebt;

  /// No description provided for @editPayment.
  ///
  /// In en, this message translates to:
  /// **'Edit Payment'**
  String get editPayment;

  /// No description provided for @debtorName.
  ///
  /// In en, this message translates to:
  /// **'Debtor Name'**
  String get debtorName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String errorOccurred(Object error);

  /// No description provided for @chartPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Chart placeholder'**
  String get chartPlaceholder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
