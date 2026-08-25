/// Business constants, locations, sorting categories, and defaults
class AppConstants {
  // Brand Info
  static const String appNameAr = 'تمور علي';
  static const String appNameEn = 'Ali Dates';
  static const String appTagline = 'نظام إدارة المستودعات والفرز والإنتاج';
  static const String logoUrl = 'https://alidatesjo.com/wp-content/uploads/2026/04/logo.png';

  // Default Weights (in KG)
  static const double defaultEmptyPalletWeight = 16.0;
  static const double maxEmptyPalletWeight = 30.0;

  static const double defaultEmptyBoxWeight = 0.95;
  static const double maxEmptyBoxWeight = 1.5;

  static const int defaultBoxCount = 200;
  static const int maxBoxCount = 250;

  static const double maxGrossWeight = 1200.0;
  static const double autoSortBoxWeight = 5.0; // 5kg per box in auto-sort output

  // Warehouse Locations
  static const String locPreFridge = 'pre_fridge'; // ثلاجة التعقيم
  static const String locFirstFridge = 'first_fridge'; // التبريد الأولي
  static const String locMainFreezer1 = 'main_freezer_1'; // الفريزر 1
  static const String locMainFreezer2 = 'main_freezer_2'; // الفريزر 2
  static const String locSmallFreezer = 'small_freezer'; // الفريزر الصغير
  static const String locPreSort = 'presort'; // فرز أولي
  static const String locAutoSort = 'autosort'; // فرز آلي
  static const String locDelivered = 'delivered'; // تم التسليم

  static const Map<String, String> locationNamesAr = {
    locPreFridge: 'ثلاجة التعقيم',
    locFirstFridge: 'التبريد الأولي',
    locMainFreezer1: 'الفريزر الرئيسي 1',
    locMainFreezer2: 'الفريزر الرئيسي 2',
    locSmallFreezer: 'الفريزر الصغير',
    locPreSort: 'منطقة الفرز الأولي',
    locAutoSort: 'خط الفرز الآلي',
    locDelivered: 'تم التسليم للعميل',
  };

  // Freezer Rows & Columns Specs
  // Rows: A to P (16 rows)
  static const List<String> freezerRows = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'
  ];
  // Columns: 1 to 8 (Corridor in middle between col 4 and col 5)
  static const List<int> freezerCols = [1, 2, 3, 4, 5, 6, 7, 8];
  // Height Layers: 1 to 3
  static const List<int> freezerLayers = [1, 2, 3];

  // Auto-Sort Categories (تصنيفات الفرز الآلي)
  static const List<String> autoSortCategories = [
    'بريميوم',
    'ديلايت',
    'كلاسيك',
    'سوفت بريميوم',
    'احمر أ',
    'احمر ب',
    'بون بون',
  ];

  // Auto-Sort Sizes (أحجام الفرز الآلي)
  static const List<String> autoSortSizes = [
    'سوبر جمبو',
    'جمبو',
    'لارج',
    'ميديوم',
    'سمول',
    'سمول بيبي',
  ];

  // Daily Capacity Specs
  static const double preSortDailyCapacityKg = 30000.0; // 30 Tons / Day (طاقة مشغل الفرز الأولي)
  static const double autoSortDailyCapacityKg = 25000.0; // 25 Tons / Day

  // Pre-Sort Quality Categories (أصناف الفرز الأولي)
  static const List<String> preSortDefects = [
    'مفروز أولي',
    'تمر أصفر',
    'تمر مفعوص',
    'تمر ناشف',
    'نقرة عصفور',
    'رطب أول',
    'رطب أصفر',
    'رطب أسود',
  ];

  // Jordanian Governorates & Agricultural Farm Locations (المحافظات والمناطق الزراعية ومزارع الأغوار)
  static const List<String> jordanGovernorates = [
    'الشونة الشمالية',
    'وقّاص',
    'المنشية',
    'الكريمة',
    'الشيخ حسين',
    'طبقة فحل',
    'المشارع',
    'قليعات',
    'دير علا',
    'الشونة الجنوبية',
    'الكرامة',
    'الروضة',
    'الجوفة',
    'الرامة',
    'المغطس',
    'سويمة',
    'غور الصافي',
    'غور المزرعة',
    'غور الحديثة',
    'غور فيفا',
    'غور خنزيرة (الطيب)',
  ];
}
