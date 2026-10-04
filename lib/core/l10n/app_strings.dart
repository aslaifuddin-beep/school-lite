/// نصوص التطبيق باللغة العربية.
///
/// جميع الشاشات تشتق نصوصها من هنا لضمان اتساق المصطلحات التعليمية
/// وإمكانية استبدالها لاحقاً بـ ARB/Intl دون تعديل الواجهات.
abstract final class AppStrings {
  // عام
  static const appName = 'مدرستي';
  static const appTagline = 'رفيقك التعليمي — يعمل حتى بدون إنترنت';
  static const ok = 'موافق';
  static const cancel = 'إلغاء';
  static const confirm = 'تأكيد';
  static const save = 'حفظ';
  static const delete = 'حذف';
  static const edit = 'تعديل';
  static const retry = 'إعادة المحاولة';
  static const close = 'إغلاق';
  static const loading = 'جارٍ التحميل…';
  static const error = 'حدث خطأ';
  static const noResults = 'لا توجد نتائج';
  static const comingSoon = 'قيد التطوير — قريباً';
  static const requiredField = 'هذا الحقل مطلوب';
  static const continueLabel = 'متابعة';
  static const back = 'رجوع';

  // تسجيل الدخول والحسابات
  static const loginTitle = 'تسجيل الدخول';
  static const loginSubtitle = 'أضف حساب الطالب للبدء';
  static const serverUrl = 'رابط المنصة';
  static const serverUrlHint = 'مثال: https://moodle.unrwa.org';
  static const username = 'اسم المستخدم';
  static const password = 'كلمة المرور';
  static const signIn = 'دخول';
  static const signingIn = 'جارٍ تسجيل الدخول…';
  static const invalidCredentials = 'اسم المستخدم أو كلمة المرور غير صحيحة';
  static const invalidServerUrl = 'تحقق من صيغة الرابط (يبدأ بـ https://)';
  static const demoMode = 'الوضع التجريبي';
  static const demoModeHint = 'استعرض التطبيق ببيانات تجريبية دون خادم';
  static const demoAccountName = 'طالب تجريبي';
  static const networkError = 'تعذّر الاتصال بالخادم — تحقق من الإنترنت';
  static const serviceDisabled = 'خدمات الويب (Web Services) غير مفعّلة على الخادم';
  static const sslError =
      'فشل التحقق من شهادة الخادم (SSL) — تحقق من إعدادات الشبكة وتاريخ الجهاز';
  static const httpError = 'رد غير متوقع من الخادم — حاول مرة أخرى لاحقاً';
  static const badEndpoint =
      'تعذّر العثور على خدمة Moodle على هذا الرابط — تحقق من عنوان المنصة';

  // إدارة الحسابات المتعددة
  static const accounts = 'الحسابات';
  static const accountsManager = 'إدارة الحسابات';
  static const addAccount = 'إضافة حساب';
  static const switchAccount = 'تبديل الحساب';
  static const activeAccount = 'الحساب الحالي';
  static const accountsLimitReached = 'الحد الأقصى 10 حسابات في الجهاز';
  static const deleteAccount = 'حذف الحساب';
  static const deleteAccountWarning =
      'سيتم حذف الحساب وكل بياناته المحفوظة محلياً من هذا الجهاز.';
  static const noAccountsYet = 'لا توجد حسابات بعد — أضف حساب طالب للبدء';
  static const lastSync = 'آخر مزامنة';
  static const neverSynced = 'لم تتم المزامنة بعد';
  static const signOut = 'تسجيل الخروج';

  // القفل والأمان
  static const lockTitle = 'التطبيق مقفل';
  static const unlockWithBiometric = 'الدخول بالبصمة';
  static const unlockWithPin = 'الدخول برمز PIN';
  static const enterPin = 'أدخل رمز PIN';
  static const wrongPin = 'رمز غير صحيح — حاول مجدداً';
  static const biometricReason = 'سجّل دخولك للوصول إلى حسابات أبنائك';
  static const biometricUnavailable = 'المصادقة البيومترية غير متاحة';
  static const pinNotSet = 'لم يتم تعيين رمز بعد';
  static const setPin = 'تعيين رمز PIN';
  static const changePin = 'تغيير رمز PIN';
  static const confirmPin = 'تأكيد الرمز';
  static const pinMismatch = 'الرمزان غير متطابقين';
  static const pinSaved = 'تم حفظ رمز PIN بنجاح';
  static const security = 'الأمان';
  static const biometricLogin = 'الدخول بالبصمة';
  static const pinLock = 'قفل برمز PIN';

  // الشريط السريع للتبديل
  static const quickSwitchHint = 'اضغط للتبديل بين حسابات الأبناء';

  // التنقل السفلي
  static const navHome = 'الرئيسية';
  static const navCourses = 'المقررات';
  static const navAssignments = 'الواجبات';
  static const navNotifications = 'الإشعارات';
  static const navSettings = 'الإعدادات';

  // لوحة التحكم
  static const dashboard = 'لوحة التحكم';
  static const welcomeBack = 'أهلاً بك';
  static const upcomingAssignments = 'واجبات قادمة';
  static const todayMaterials = 'دروس اليوم';
  static const latestNotifications = 'أحدث الإشعارات';
  static const viewAll = 'عرض الكل';
  static const noUpcomingAssignments = 'لا توجد واجبات قادمة — أحسنت!';
  static const offlineBanner = 'أنت الآن بدون إنترنت — المحتوى المحفوظ متاح';
  static const syncedNow = 'تمت المزامنة الآن';
  static const syncPending = 'بانتظار المزامنة';

  // المقررات
  static const courses = 'المقررات';
  static const myCourses = 'مقرراتي';
  static const courseSections = 'الأقسام';
  static const lessons = 'الدروس';
  static const files = 'الملفات';
  static const noCourses = 'لا توجد مقررات محفوظة بعد';

  // الواجبات
  static const assignments = 'الواجبات';
  static const dueDate = 'موعد التسليم';
  static const submitAssignment = 'تسليم الواجب';
  static const attachFile = 'إرفاق ملف';
  static const answer = 'إجابة الطالب';
  static const submitOffline = 'حفظ في طابور المزامنة';
  static const submitted = 'تم التسليم';
  static const pendingSync = 'بانتظار الإرسال';
  static const noAssignments = 'لا توجد واجبات حالياً';
  static const timeLeft = 'المتبقي';
  static const overdue = 'متأخر';
  static const draftAnswer = 'اكتب إجابتك هنا…';
  static const todaysTasks = 'مهام اليوم';
  static const dueSoonLabel = 'يستحق خلال 24 ساعة';
  static const notSubmitted = 'لم يُسلَّم';
  static const graded = 'مُقيَّم';
  static const noDueDate = 'بلا موعد محدد';
  static const allTasks = 'الكل';
  static const dueSoonTasks = 'قريبة';
  static const upcomingTasks = 'قادمة';
  static const gradeLabel = 'الدرجة';
  static const answerRequired = 'اكتب إجابة أو أرفق ملفاً أولاً';
  static const pickFileFailed = 'تعذّر اختيار الملفات';
  static const cameraCaptureFailed = 'تعذّر التقاط الصورة';
  static const removeAttachment = 'إزالة المرفق';

  // المحتوى المحلي (التنزيل والعرض دون إنترنت)
  static const savedOffline = 'محفوظ محلياً';
  static const downloadFile = 'تنزيل للعرض دون إنترنت';
  static const downloading = 'جارٍ التنزيل…';
  static const downloadFailed = 'فشل التنزيل — حاول عند توفر الشبكة';
  static const openFile = 'فتح الملف';
  static const offlineReady = 'الملفات المحفوظة متاحة دون إنترنت';

  // الإشعارات
  static const notifications = 'الإشعارات';
  static const noNotifications = 'لا توجد إشعارات جديدة';
  static const markAllRead = 'تحديد الكل كمقروء';

  // الإعدادات
  static const settings = 'الإعدادات';
  static const appearance = 'المظهر';
  static const darkMode = 'الوضع الداكن';
  static const syncSettings = 'المزامنة';
  static const autoSync = 'المزامنة التلقائية';
  static const platform = 'المنصة التعليمية';
  static const about = 'حول التطبيق';

  // أخطاء المزامنة
  static const syncFailed = 'فشلت المزامنة — سيُعاد تلقائياً عند توفر الاتصال';
  static const queuedForSync = 'تم الحفظ في طابور المزامنة وسيُرسل عند الاتصال';
}
