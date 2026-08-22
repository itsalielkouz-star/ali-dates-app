/// Comprehensive Arabic Name Normalizer & Translator
/// Handles common transliteration variations from English/Franco-Arabic to proper Arabic,
/// with special rules for Jordanian and Arab names (e.g. elkouz -> الكوز, khaled -> خالد, etc.)
class NameTranslator {
  /// Known full or partial name mappings (case-insensitive)
  static final Map<String, String> _customExactMappings = {
    'elkouz': 'الكوز',
    'el kouz': 'الكوز',
    'al kouz': 'الكوز',
    'alkouz': 'الكوز',
    'kouz': 'كوز',
    'al-kouz': 'الكوز',
    'el-kouz': 'الكوز',
    'ali dates': 'تمور علي',
    'al-jawda almithaliya': 'الجودة المثالية',
    'al jawda al mithaliya': 'الجودة المثالية',
    'aljawda almithaliya': 'الجودة المثالية',
  };

  /// Token / word dictionary for translating romanized Arabic names to standard Arabic
  static final Map<String, String> _wordDictionary = {
    // Surnames / Family prefixes
    'elkouz': 'الكوز',
    'alkouz': 'الكوز',
    'kouz': 'كوز',
    'alkouz': 'الكوز',
    'el': 'ال',
    'al': 'ال',
    'abu': 'أبو',
    'abo': 'أبو',
    'ibn': 'ابن',
    'bin': 'بن',

    // First names
    'khaled': 'خالد',
    'khalid': 'خالد',
    'ali': 'علي',
    'aly': 'علي',
    'husam': 'حسام',
    'hossam': 'حسام',
    'ahmad': 'أحمد',
    'ahmed': 'أحمد',
    'mohammad': 'محمد',
    'mohammed': 'محمد',
    'mohamed': 'محمد',
    'muhammad': 'محمد',
    'mahmoud': 'محمود',
    'mahmood': 'محمود',
    'omar': 'عمر',
    'omer': 'عمر',
    'amr': 'عمرو',
    'tariq': 'طارق',
    'tareq': 'طارق',
    'tarek': 'طارق',
    'yousef': 'يوسف',
    'youssef': 'يوسف',
    'yousef': 'يوسف',
    'joseph': 'يوسف',
    'ibrahim': 'إبراهيم',
    'mustafa': 'مصطفى',
    'moustafa': 'مصطفى',
    'abdallah': 'عبدالله',
    'abdullah': 'عبدالله',
    'abdelrahman': 'عبدالرحمن',
    'abdulrahman': 'عبدالرحمن',
    'abdelaziz': 'عبدالعزيز',
    'abdulaziz': 'عبدالعزيز',
    'abdelrahim': 'عبدالرحيم',
    'abdulrahim': 'عبدالرحيم',
    'abdelkader': 'عبدالقادر',
    'abdelkarim': 'عبدالكريم',
    'abdulkarim': 'عبدالكريم',
    'abdelmajeed': 'عبدالمجيد',
    'hasan': 'حسن',
    'hassan': 'حسن',
    'hussein': 'حسين',
    'hussien': 'حسين',
    'hussain': 'حسين',
    'ziad': 'زياد',
    'zeyad': 'زياد',
    'zaid': 'زيد',
    'salem': 'سالم',
    'saleem': 'سليم',
    'salman': 'سلمان',
    'sulaiman': 'سليمان',
    'soliman': 'سليمان',
    'suleiman': 'سليمان',
    'saeed': 'سعيد',
    'said': 'سعيد',
    'samir': 'سمير',
    'sameer': 'سمير',
    'sami': 'سامي',
    'samy': 'سامي',
    'fadi': 'فادي',
    'fady': 'فادي',
    'firas': 'فراس',
    'feras': 'فراس',
    'faisal': 'فيصل',
    'faysal': 'فيصل',
    'ghassan': 'غسان',
    'hamza': 'حمزة',
    'hamzah': 'حمزة',
    'bilal': 'بلال',
    'belal': 'بلال',
    'anas': 'أنس',
    'ayman': 'أيمن',
    'amjad': 'أمجد',
    'akram': 'أكرم',
    'ashraf': 'أشرف',
    'adel': 'عادل',
    'adil': 'عادل',
    'adnan': 'عدنان',
    'emad': 'عماد',
    'imad': 'عماد',
    'issa': 'عيسى',
    'eisa': 'عيسى',
    'mousa': 'موسى',
    'musa': 'موسى',
    'naser': 'ناصر',
    'nasser': 'ناصر',
    'nasir': 'ناصر',
    'nabil': 'نبيل',
    'nadim': 'نديم',
    'radeed': 'رديد',
    'radwan': 'رضوان',
    'ramez': 'رامز',
    'rami': 'رامي',
    'ramy': 'رامي',
    'raed': 'رائد',
    'rashed': 'راشد',
    'rashid': 'راشد',
    'waleed': 'وليد',
    'walid': 'وليد',
    'waseem': 'وسيم',
    'wasim': 'وسيم',
    'yazan': 'يزن',
    'yahya': 'يحيى',
    'laith': 'ليث',
    'layth': 'ليث',
    'majd': 'مجد',
    'monther': 'منذر',
    'munther': 'منذر',
    'muthana': 'مثنى',
    'jafar': 'جعفر',
    'jaafar': 'جعفر',
    'jamal': 'جمال',
    'jihad': 'جهاد',
    'bassam': 'بسام',
    'bassem': 'باسم',
    'basim': 'باسم',
    'bahaa': 'بهاء',
    'baha': 'بهاء',
    'tamim': 'تميم',
    'tameem': 'تميم',
    'khalil': 'خليل',
    'khaleel': 'خليل',
    'shadi': 'شادي',
    'shady': 'شادي',
    'marwan': 'مروان',
    'motaz': 'معتز',
    'moataz': 'معتز',
    'mohannad': 'مهند',
    'muhannad': 'مهند',
    'osama': 'أسامة',
    'ousama': 'أسامة',
    'qasim': 'قاسم',
    'kasim': 'قاسم',
    'nidal': 'نضال',
    'nedal': 'نضال',
    'nour': 'نور',
    'noor': 'نور',
    'sultan': 'سلطان',
    'saad': 'سعد',
    'saud': 'سعود',
    'shaker': 'شاكر',
    'sabri': 'صبري',
    'salah': 'صلاح',
    'saleh': 'صالح',
    'suhaib': 'صهيب',
    'sohaib': 'صهيب',
    'diya': 'ضياء',
    'deyaa': 'ضياء',
    'taha': 'طه',
    'taher': 'طاهر',
    'talal': 'طلال',
    'atef': 'عاطف',
    'abed': 'عبد',
    'othman': 'عثمان',
    'osman': 'عثمان',
    'ezzat': 'عزت',
    'asla': 'عسلة',
    'ala': 'علاء',
    'alaa': 'علاء',
    'allam': 'علام',
    'awad': 'عوض',
    'ayesh': 'عايش',
    'faris': 'فارس',
    'fares': 'فارس',
    'farouq': 'فاروق',
    'farouk': 'فاروق',
    'fahad': 'فهد',
    'fahd': 'فهد',
    'fuad': 'فؤاد',
    'fouad': 'فؤاد',
    'karam': 'كرم',
    'kareem': 'كريم',
    'kamal': 'كمال',
    'kinan': 'كنان',
    'kenan': 'كنان',
    'luay': 'لؤي',
    'loai': 'لؤي',
    'maher': 'ماهر',
    'mamdouh': 'ممدوح',
    'mansour': 'منصور',
    'mounir': 'منير',
    'munir': 'منير',
    'muath': 'معاذ',
    'moath': 'معاذ',
    'naji': 'ناجي',
    'nagy': 'ناجي',
    'naseem': 'نسيم',
    'nasim': 'نسيم',
    'hadi': 'هادي',
    'hady': 'هادي',
    'hashem': 'هاشم',
    'hani': 'هاني',
    'hany': 'هاني',
    'haitham': 'هيثم',
    'haytham': 'هيثم',
    'wesam': 'وسام',
    'wisam': 'وسام',
    'waddah': 'وضاح',
  };

  /// Translates a given name string:
  /// - If already Arabic and contains 'elkouz' or variants, replaces with 'الكوز'.
  /// - If English / Franco-Arabic, translates each word token into standard Arabic.
  /// - Preserves already correct Arabic text while correcting misspellings like 'elkouz'.
  static String translate(String? rawName) {
    if (rawName == null || rawName.trim().isEmpty) return '';

    String cleaned = rawName.trim();

    // Check direct full phrase match
    final lower = cleaned.toLowerCase();
    if (_customExactMappings.containsKey(lower)) {
      return _customExactMappings[lower]!;
    }

    // Replace English tokens inside Arabic strings or mixed strings
    // (e.g. "خالد elkouz" -> "خالد الكوز")
    String result = cleaned;
    _customExactMappings.forEach((enKey, arVal) {
      final reg = RegExp(r'\b' + RegExp.escape(enKey) + r'\b', caseSensitive: false);
      result = result.replaceAll(reg, arVal);
    });

    // If string still contains English letters, attempt word-by-word transliteration
    if (RegExp(r'[a-zA-Z]').hasMatch(result)) {
      final words = result.split(RegExp(r'\s+'));
      final translatedWords = <String>[];

      for (var w in words) {
        final cleanWord = w.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '').toLowerCase();
        
        if (_wordDictionary.containsKey(cleanWord)) {
          translatedWords.add(_wordDictionary[cleanWord]!);
        } else if (_customExactMappings.containsKey(cleanWord)) {
          translatedWords.add(_customExactMappings[cleanWord]!);
        } else if (cleanWord.startsWith('el') && cleanWord.length > 2) {
          final rest = cleanWord.substring(2);
          if (_wordDictionary.containsKey(rest)) {
            translatedWords.add('ال' + _wordDictionary[rest]!);
          } else {
            translatedWords.add(w);
          }
        } else if (cleanWord.startsWith('al') && cleanWord.length > 2) {
          final rest = cleanWord.substring(2);
          if (_wordDictionary.containsKey(rest)) {
            translatedWords.add('ال' + _wordDictionary[rest]!);
          } else {
            translatedWords.add(w);
          }
        } else {
          // If not in dictionary and already has Arabic characters, keep as is
          translatedWords.add(w);
        }
      }
      result = translatedWords.join(' ');
    }

    // Final clean up for standard Arabic name formatting
    result = result.replaceAll('عبد ', 'عبد');
    result = result.replaceAll('ابو ', 'أبو ');
    result = result.replaceAll('أبو ', 'أبو ');

    return result.trim();
  }
}
