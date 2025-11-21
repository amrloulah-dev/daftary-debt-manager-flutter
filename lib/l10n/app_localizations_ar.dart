// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'فاتورة';

  @override
  String get home => 'الرئيسية';

  @override
  String get debtor => 'مدين';

  @override
  String get debtors => 'المدينون';

  @override
  String get debts => 'الديون';

  @override
  String get payments => 'المدفوعات';

  @override
  String get statistics => 'الإحصائيات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get addDebt => 'إضافة دين';

  @override
  String get addPayment => 'إضافة دفعة';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get search => 'بحث';

  @override
  String get name => 'الاسم';

  @override
  String get phone => 'الهاتف';

  @override
  String get amount => 'المبلغ';

  @override
  String get date => 'التاريخ';

  @override
  String get description => 'الوصف';

  @override
  String get notes => 'ملاحظات';

  @override
  String get paid => 'مدفوع';

  @override
  String get unpaid => 'غير مدفوع';

  @override
  String get summary => 'ملخص';

  @override
  String get borrowed => 'مقترض';

  @override
  String get outstanding => 'متبقي';

  @override
  String get totalDebtors => 'إجمالي المدينين';

  @override
  String get activeDebtors => 'المدينون النشطون';

  @override
  String get totalDebt => 'إجمالي الدين';

  @override
  String get totalPaid => 'إجمالي المدفوع';

  @override
  String get addDebtor => 'إضافة مدين';

  @override
  String get editDebtor => 'تعديل مدين';

  @override
  String get deleteDebtor => 'حذف مدين';

  @override
  String get deleteDebtorConfirmation =>
      'هل أنت متأكد أنك تريد حذف هذا المدين وجميع سجلاته المرتبطة به؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get debtorNameRequired => 'اسم المدين مطلوب.';

  @override
  String get addEditDebtScreenTitle => 'إضافة/تعديل دين';

  @override
  String get addEditPaymentScreenTitle => 'إضافة/تعديل دفعة';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get recordPayment => 'تسجيل دفعة';

  @override
  String get deletePayment => 'حذف الدفعة';

  @override
  String get deletePaymentConfirmation =>
      'هل أنت متأكد أنك تريد حذف هذه الدفعة؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteDebtConfirmation =>
      'هل أنت متأكد أنك تريد حذف هذا الدين؟ لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get signInWithGoogle => 'تسجيل الدخول باستخدام جوجل';

  @override
  String get signInWithFacebook => 'تسجيل الدخول باستخدام فيسبوك';

  @override
  String get welcomeBack => 'مرحبا بعودتك!';

  @override
  String get hello => 'مرحباً';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get recordPaymentTitle => 'تسجيل دفعة';

  @override
  String get sendReminder => 'إرسال تذكير';

  @override
  String get recentTransactions => 'المعاملات الأخيرة';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get byName => 'بالاسم';

  @override
  String get byDebtAmount => 'بمبلغ الدين';

  @override
  String get byLastPayment => 'بآخر دفعة';

  @override
  String get noDebtorsFound => 'لم يتم العثور على مدينين';

  @override
  String get noDebtorsFoundHint => 'اضغط على زر \'+\' لإضافة مدين جديد.';

  @override
  String get searchDebtorsHint => 'ابحث عن المدينين...';

  @override
  String get debtDetails => 'تفاصيل الدين';

  @override
  String get paymentDetails => 'تفاصيل الدفعة';

  @override
  String get paidOff => 'مدفوع بالكامل';

  @override
  String get active => 'نشط';

  @override
  String get lastPayment => 'آخر دفعة';

  @override
  String get noPaymentsYet => 'لا توجد مدفوعات حتى الآن';

  @override
  String get selectDateRange => 'اختر نطاق التاريخ';

  @override
  String get weekly => 'أسبوعي';

  @override
  String get monthly => 'شهري';

  @override
  String get yearly => 'سنوي';

  @override
  String get avgDebtPerDebtor => 'متوسط الدين لكل مدين';

  @override
  String get paymentRate => 'معدل الدفع';

  @override
  String get totalOutstanding => 'إجمالي المتبقي';

  @override
  String get monthlyPaymentAvg => 'متوسط الدفع الشهري';

  @override
  String get debtDistribution => 'توزيع الديون';

  @override
  String get paymentTrends => 'اتجاهات الدفع';

  @override
  String get monthlyComparison => 'مقارنة شهرية';

  @override
  String get appSubtitle => 'إدارة ديونك ومدفوعاتك بكفاءة';

  @override
  String get signInFailed => 'تم إلغاء تسجيل الدخول أو فشل';

  @override
  String get couldNotLoadStats => 'تعذر تحميل الإحصائيات.';

  @override
  String get couldNotLoadTransactions => 'تعذر تحميل المعاملات.';

  @override
  String get noRecentTransactions => 'لا توجد معاملات حديثة';

  @override
  String get tryAdjustingSearch => 'حاول تعديل بحثك.';

  @override
  String get transactions => 'المعاملات';

  @override
  String get percentPaid => '% مدفوع';

  @override
  String get errorLoadingDebts => 'خطأ في تحميل الديون.';

  @override
  String get errorLoadingPayments => 'خطأ في تحميل المدفوعات.';

  @override
  String get noPaymentsFound => 'لم يتم العثور على مدفوعات.';

  @override
  String get debtorSavedSuccess => 'تم حفظ المدين بنجاح!';

  @override
  String errorSavingDebtor(Object error) {
    return 'خطأ في حفظ المدين: $error';
  }

  @override
  String get debtorDeletedSuccess => 'تم حذف المدين بنجاح!';

  @override
  String errorDeletingDebtor(Object error) {
    return 'خطأ في حذف المدين: $error';
  }

  @override
  String get emailAddress => 'البريد الإلكتروني';

  @override
  String get invalidEmailAddress => 'يرجى إدخال عنوان بريد إلكتروني صالح.';

  @override
  String get debtSavedSuccess => 'تم حفظ الدين بنجاح!';

  @override
  String errorSavingDebt(Object error) {
    return 'خطأ في حفظ الدين: $error';
  }

  @override
  String get debtDeletedSuccess => 'تم حذف الدين بنجاح!';

  @override
  String errorDeletingDebt(Object error) {
    return 'خطأ في حذف الدين: $error';
  }

  @override
  String get amountRequired => 'يرجى إدخال مبلغ';

  @override
  String get invalidNumber => 'يرجى إدخال رقم صالح';

  @override
  String get isDebtPaid => 'هل هذا الدين مدفوع؟';

  @override
  String get paymentSavedSuccess => 'تم حفظ الدفعة بنجاح!';

  @override
  String errorSavingPayment(Object error) {
    return 'خطأ في حفظ الدفعة: $error';
  }

  @override
  String get paymentDeletedSuccess => 'تم حذف الدفعة بنجاح!';

  @override
  String errorDeletingPayment(Object error) {
    return 'خطأ في حذف الدفعة: $error';
  }

  @override
  String get cash => 'نقداً';

  @override
  String get bankTransfer => 'تحويل بنكي';

  @override
  String get check => 'شيك';

  @override
  String get other => 'أخرى';

  @override
  String get currentDebt => 'الدين الحالي';

  @override
  String get newBalance => 'الرصيد الجديد';

  @override
  String forDebtor(Object name) {
    return 'لـ: $name';
  }

  @override
  String toDebtor(Object name) {
    return 'إلى: $name';
  }

  @override
  String get editDebt => 'تعديل الدين';

  @override
  String get editPayment => 'تعديل الدفعة';

  @override
  String get debtorName => 'اسم المدين';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get descriptionOptional => 'الوصف (اختياري)';

  @override
  String errorOccurred(Object error) {
    return 'حدث خطأ: $error';
  }

  @override
  String get chartPlaceholder => 'عنصر نائب للرسم البياني';
}
