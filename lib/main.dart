// ===========================================================================
// FAROOQ STARS — mobile app (iOS + Android + web-ready)
// Western & Vedic astrology, zodiac signs and compatibility — for curiosity
// and fun. Companion app to farooqstars.com (same Supabase backend).
//
// Phase 1 (this file): brand foundation, 4 languages with RTL (English,
// Urdu, Hindi, Arabic), Today screen, all 12 zodiac/rashi profiles,
// compatibility (match) tool, More/About — fully responsive from day one
// (phones portrait+landscape, tablets). Live daily readings from Supabase
// switch on in Phase 2 once the anon key + table names are wired in.
// ===========================================================================
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ---- Brand palette (same family as farooqstars.com & Farooq Music) ----
const kBg      = Color(0xFF1a0e22);
const kCard    = Color(0xFF23172b);
const kPrimary = Color(0xFF9d4edd);
const kLight   = Color(0xFFc77dff);
const kOn      = Color(0xFFefe7f5);
const kMuted   = Color(0xFFb39fc4);
const kBorder  = Color(0x33c77dff);
const kGold    = Color(0xFFf0c75e);

// ---- Backend (same Supabase project as farooqstars.com) ----
const kSupabaseUrl = 'https://yxrntgugocmhphkoibnp.supabase.co';
// TODO (Phase 2): paste the website's anon/public key here to switch on the
// live daily readings. With the key empty the app runs fully offline.
const kSupabaseAnonKey = '';
bool get supabaseReady => kSupabaseAnonKey.isNotEmpty;

const kWebsite = 'https://www.farooqstars.com';

late SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  // Restore saved choices
  final l = prefs.getString('lang');
  if (l != null) {
    currentLang.value =
      AppLang.values.firstWhere((e) => e.name == l, orElse: () => AppLang.en);
  }
  mySignIdx.value = prefs.getInt('mySign') ?? -1;
  useVedic.value = prefs.getBool('useVedic') ?? false;
  if (supabaseReady) {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  }
  runApp(const FarooqStarsApp());
}

// ===========================================================================
// Languages — English, Urdu (RTL), Hindi, Arabic (RTL)
// ===========================================================================
enum AppLang { en, ur, hi, ar }

final currentLang = ValueNotifier<AppLang>(AppLang.en);
final mySignIdx   = ValueNotifier<int>(-1);      // -1 = not chosen yet
final useVedic    = ValueNotifier<bool>(false);  // Western <-> Vedic

bool get rtl => currentLang.value == AppLang.ur || currentLang.value == AppLang.ar;

String langLabel(AppLang l) {
  switch (l) {
    case AppLang.en: return 'English';
    case AppLang.ur: return 'اردو';
    case AppLang.hi: return 'हिंदी';
    case AppLang.ar: return 'العربية';
  }
}

// Urdu text looks best in Nastaliq where the platform has it (iOS ships it;
// Android falls back gracefully to its default Urdu-capable font).
String? get urduFont =>
  currentLang.value == AppLang.ur ? 'Noto Nastaliq Urdu' : null;

const Map<String, Map<AppLang, String>> _tr = {
  'today':      {AppLang.en: 'Today', AppLang.ur: 'آج', AppLang.hi: 'आज', AppLang.ar: 'اليوم'},
  'zodiac':     {AppLang.en: 'Zodiac', AppLang.ur: 'برج', AppLang.hi: 'राशियाँ', AppLang.ar: 'الأبراج'},
  'match':      {AppLang.en: 'Match', AppLang.ur: 'جوڑ', AppLang.hi: 'मिलान', AppLang.ar: 'التوافق'},
  'more':       {AppLang.en: 'More', AppLang.ur: 'مزید', AppLang.hi: 'और', AppLang.ar: 'المزيد'},
  'western':    {AppLang.en: 'Western', AppLang.ur: 'مغربی', AppLang.hi: 'पश्चिमी', AppLang.ar: 'غربي'},
  'vedic':      {AppLang.en: 'Vedic', AppLang.ur: 'ویدک', AppLang.hi: 'वैदिक', AppLang.ar: 'فيدي'},
  'chooseSign': {AppLang.en: 'Choose your sign', AppLang.ur: 'اپنا برج چنیں', AppLang.hi: 'अपनी राशि चुनें', AppLang.ar: 'اختر برجك'},
  'yourSign':   {AppLang.en: 'Your sign', AppLang.ur: 'آپ کا برج', AppLang.hi: 'आपकी राशि', AppLang.ar: 'برجك'},
  'element':    {AppLang.en: 'Element', AppLang.ur: 'عنصر', AppLang.hi: 'तत्व', AppLang.ar: 'العنصر'},
  'planet':     {AppLang.en: 'Planet', AppLang.ur: 'سیارہ', AppLang.hi: 'ग्रह', AppLang.ar: 'الكوكب'},
  'dates':      {AppLang.en: 'Dates', AppLang.ur: 'تاریخیں', AppLang.hi: 'तिथियाँ', AppLang.ar: 'التواريخ'},
  'dailyReading': {AppLang.en: 'Daily reading', AppLang.ur: 'آج کی reading', AppLang.hi: 'आज का फल', AppLang.ar: 'قراءة اليوم'},
  'comingLive': {
    AppLang.en: 'Live daily readings arrive in the next update — until then, read today\'s post on the website.',
    AppLang.ur: 'روزانہ کی live readings اگلے update میں آ رہی ہیں — تب تک آج کی post website پر پڑھیں۔',
    AppLang.hi: 'रोज़ाना की live readings अगले update में आ रही हैं — तब तक आज की post website पर पढ़ें।',
    AppLang.ar: 'القراءات اليومية المباشرة قادمة في التحديث القادم — حتى ذلك الحين اقرأ منشور اليوم على الموقع.',
  },
  'readOnWebsite': {AppLang.en: 'Read on website', AppLang.ur: 'Website پر پڑھیں', AppLang.hi: 'Website पर पढ़ें', AppLang.ar: 'اقرأ على الموقع'},
  'fullProfile': {AppLang.en: 'Full profile on website', AppLang.ur: 'مکمل profile website پر', AppLang.hi: 'पूरी profile website पर', AppLang.ar: 'الملف الكامل على الموقع'},
  'pickTwo':    {AppLang.en: 'Pick two signs and see how they get along', AppLang.ur: 'دو برج چنیں اور دیکھیں ان کی کیسی بنتی ہے', AppLang.hi: 'दो राशियाँ चुनें और देखें उनकी कैसी बनती है', AppLang.ar: 'اختر برجين وشاهد مدى انسجامهما'},
  'firstSign':  {AppLang.en: 'First sign', AppLang.ur: 'پہلا برج', AppLang.hi: 'पहली राशि', AppLang.ar: 'البرج الأول'},
  'secondSign': {AppLang.en: 'Second sign', AppLang.ur: 'دوسرا برج', AppLang.hi: 'दूसरी राशि', AppLang.ar: 'البرج الثاني'},
  'share':      {AppLang.en: 'Share', AppLang.ur: 'Share کریں', AppLang.hi: 'Share करें', AppLang.ar: 'مشاركة'},
  'language':   {AppLang.en: 'Language', AppLang.ur: 'زبان', AppLang.hi: 'भाषा', AppLang.ar: 'اللغة'},
  'website':    {AppLang.en: 'Website — farooqstars.com', AppLang.ur: 'Website — farooqstars.com', AppLang.hi: 'Website — farooqstars.com', AppLang.ar: 'الموقع — farooqstars.com'},
  'dailyEmail': {AppLang.en: 'Daily email — subscribe', AppLang.ur: 'روزانہ email — subscribe کریں', AppLang.hi: 'रोज़ाना email — subscribe करें', AppLang.ar: 'البريد اليومي — اشترك'},
  'contact':    {AppLang.en: 'Contact us', AppLang.ur: 'ہم سے رابطہ', AppLang.hi: 'संपर्क करें', AppLang.ar: 'اتصل بنا'},
  'musicApp':   {AppLang.en: 'Farooq Music — our music app', AppLang.ur: 'Farooq Music — ہماری music app', AppLang.hi: 'Farooq Music — हमारी music app', AppLang.ar: 'Farooq Music — تطبيق الموسيقى'},
  'about':      {AppLang.en: 'About', AppLang.ur: 'تعارف', AppLang.hi: 'परिचय', AppLang.ar: 'حول'},
  'aboutText': {
    AppLang.en: 'Western & Vedic astrology charts, zodiac signs and compatibility — for curiosity and fun.',
    AppLang.ur: 'مغربی اور ویدک astrology، برج اور جوڑ کی مطابقت — تجسس اور تفریح کے لیے۔',
    AppLang.hi: 'पश्चिमी और वैदिक ज्योतिष, राशियाँ और मिलान — जिज्ञासा और मनोरंजन के लिए।',
    AppLang.ar: 'الأبراج الغربية والفيدية والتوافق — للفضول والمتعة.',
  },
  'disclaimer': {
    AppLang.en: 'For curiosity and fun — not professional advice.',
    AppLang.ur: 'صرف تجسس اور تفریح کے لیے — کوئی پیشہ ورانہ مشورہ نہیں۔',
    AppLang.hi: 'केवल जिज्ञासा और मनोरंजन के लिए — कोई पेशेवर सलाह नहीं।',
    AppLang.ar: 'للفضول والمتعة فقط — ليست نصيحة مهنية.',
  },
  'greatMatch': {AppLang.en: 'Written in the stars!', AppLang.ur: 'ستاروں میں لکھا جوڑ!', AppLang.hi: 'सितारों में लिखा जोड़!', AppLang.ar: 'مكتوب في النجوم!'},
  'goodMatch':  {AppLang.en: 'A warm, promising pair', AppLang.ur: 'گرم جوشی والا امید بھرا جوڑ', AppLang.hi: 'गर्मजोशी भरा, उम्मीद वाला जोड़', AppLang.ar: 'ثنائي دافئ وواعد'},
  'okMatch':    {AppLang.en: 'Sparks with some work', AppLang.ur: 'تھوڑی محنت سے چنگاری', AppLang.hi: 'थोड़ी मेहनत से चिंगारी', AppLang.ar: 'شرارة مع بعض الجهد'},
  'hardMatch':  {AppLang.en: 'Opposites — handle with care', AppLang.ur: 'الٹ مزاج — ذرا سنبھل کے', AppLang.hi: 'उल्टे मिज़ाज — ज़रा संभल के', AppLang.ar: 'أضداد — بحذر ولطف'},
  'fire':  {AppLang.en: 'Fire', AppLang.ur: 'آگ', AppLang.hi: 'अग्नि', AppLang.ar: 'نار'},
  'earth': {AppLang.en: 'Earth', AppLang.ur: 'مٹی', AppLang.hi: 'पृथ्वी', AppLang.ar: 'أرض'},
  'air':   {AppLang.en: 'Air', AppLang.ur: 'ہوا', AppLang.hi: 'वायु', AppLang.ar: 'هواء'},
  'water': {AppLang.en: 'Water', AppLang.ur: 'پانی', AppLang.hi: 'जल', AppLang.ar: 'ماء'},
};

String tr(String key) =>
  _tr[key]?[currentLang.value] ?? _tr[key]?[AppLang.en] ?? key;

// Localized month + weekday names (index 1..12 / 1..7)
const _months = {
  AppLang.en: ['', 'January','February','March','April','May','June','July','August','September','October','November','December'],
  AppLang.ur: ['', 'جنوری','فروری','مارچ','اپریل','مئی','جون','جولائی','اگست','ستمبر','اکتوبر','نومبر','دسمبر'],
  AppLang.hi: ['', 'जनवरी','फ़रवरी','मार्च','अप्रैल','मई','जून','जुलाई','अगस्त','सितंबर','अक्टूबर','नवंबर','दिसंबर'],
  AppLang.ar: ['', 'يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'],
};
const _weekdays = {
  AppLang.en: ['', 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'],
  AppLang.ur: ['', 'پیر','منگل','بدھ','جمعرات','جمعہ','ہفتہ','اتوار'],
  AppLang.hi: ['', 'सोमवार','मंगलवार','बुधवार','गुरुवार','शुक्रवार','शनिवार','रविवार'],
  AppLang.ar: ['', 'الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'],
};

String todayLine() {
  final now = DateTime.now();
  final l = currentLang.value;
  final wd = _weekdays[l]![now.weekday];
  final mo = _months[l]![now.month];
  return '$wd، ${now.day} $mo ${now.year}'.replaceAll('،', l == AppLang.en ? ',' : '،');
}

// ===========================================================================
// Zodiac data — 12 signs, Western (tropical) + Vedic (sidereal)
// ===========================================================================
class ZSign {
  final String key, symbol, westDates, vedicDates, element;
  final Map<AppLang, String> name;   // Western name
  final Map<AppLang, String> vname;  // Vedic (rashi) name
  final Map<AppLang, String> planet;
  final Map<AppLang, String> trait;
  const ZSign(this.key, this.symbol, this.westDates, this.vedicDates,
    this.element, this.name, this.vname, this.planet, this.trait);
}

const _mars    = {AppLang.en: 'Mars', AppLang.ur: 'مریخ', AppLang.hi: 'मंगल', AppLang.ar: 'المريخ'};
const _venus   = {AppLang.en: 'Venus', AppLang.ur: 'زہرہ', AppLang.hi: 'शुक्र', AppLang.ar: 'الزهرة'};
const _mercury = {AppLang.en: 'Mercury', AppLang.ur: 'عطارد', AppLang.hi: 'बुध', AppLang.ar: 'عطارد'};
const _moon    = {AppLang.en: 'Moon', AppLang.ur: 'چاند', AppLang.hi: 'चंद्र', AppLang.ar: 'القمر'};
const _sun     = {AppLang.en: 'Sun', AppLang.ur: 'سورج', AppLang.hi: 'सूर्य', AppLang.ar: 'الشمس'};
const _jupiter = {AppLang.en: 'Jupiter', AppLang.ur: 'مشتری', AppLang.hi: 'बृहस्पति', AppLang.ar: 'المشتري'};
const _saturn  = {AppLang.en: 'Saturn', AppLang.ur: 'زحل', AppLang.hi: 'शनि', AppLang.ar: 'زحل'};

const List<ZSign> signs = [
  ZSign('aries', '♈', 'Mar 21 – Apr 19', 'Apr 14 – May 14', 'fire',
    {AppLang.en: 'Aries', AppLang.ur: 'حمل', AppLang.hi: 'मेष', AppLang.ar: 'الحمل'},
    {AppLang.en: 'Mesha', AppLang.ur: 'میش', AppLang.hi: 'मेष', AppLang.ar: 'ميشا'},
    _mars,
    {AppLang.en: 'Bold first steps and a spark that lights the room.',
     AppLang.ur: 'پہلا قدم اٹھانے والا، ہر محفل کی چنگاری۔',
     AppLang.hi: 'पहला क़दम उठाने वाला, हर महफ़िल की चिंगारी।',
     AppLang.ar: 'خطوة أولى جريئة وشرارة تضيء المكان.'}),
  ZSign('taurus', '♉', 'Apr 20 – May 20', 'May 15 – Jun 14', 'earth',
    {AppLang.en: 'Taurus', AppLang.ur: 'ثور', AppLang.hi: 'वृषभ', AppLang.ar: 'الثور'},
    {AppLang.en: 'Vrishabha', AppLang.ur: 'ورشبھ', AppLang.hi: 'वृषभ', AppLang.ar: 'فريشابا'},
    _venus,
    {AppLang.en: 'Steady hands, warm heart, and taste for the finer things.',
     AppLang.ur: 'مضبوط ہاتھ، گرم دل، اور نفاست کا ذوق۔',
     AppLang.hi: 'मज़बूत हाथ, गर्म दिल, और नफ़ासत का शौक़।',
     AppLang.ar: 'يدٌ ثابتة وقلبٌ دافئ وذوقٌ رفيع.'}),
  ZSign('gemini', '♊', 'May 21 – Jun 20', 'Jun 15 – Jul 14', 'air',
    {AppLang.en: 'Gemini', AppLang.ur: 'جوزا', AppLang.hi: 'मिथुन', AppLang.ar: 'الجوزاء'},
    {AppLang.en: 'Mithuna', AppLang.ur: 'متھن', AppLang.hi: 'मिथुन', AppLang.ar: 'ميثونا'},
    _mercury,
    {AppLang.en: 'Quick wit, twin moods, endless curiosity.',
     AppLang.ur: 'تیز ذہن، دو رنگ مزاج، بے انت تجسس۔',
     AppLang.hi: 'तेज़ दिमाग़, दो रंग मिज़ाज, बेअंत जिज्ञासा।',
     AppLang.ar: 'بديهة سريعة ومزاجان وفضول لا ينتهي.'}),
  ZSign('cancer', '♋', 'Jun 21 – Jul 22', 'Jul 15 – Aug 14', 'water',
    {AppLang.en: 'Cancer', AppLang.ur: 'سرطان', AppLang.hi: 'कर्क', AppLang.ar: 'السرطان'},
    {AppLang.en: 'Karka', AppLang.ur: 'کرک', AppLang.hi: 'कर्क', AppLang.ar: 'كاركا'},
    _moon,
    {AppLang.en: 'Moon-led feelings and a home wherever they love.',
     AppLang.ur: 'چاند سے جڑے جذبے، جہاں محبت وہیں گھر۔',
     AppLang.hi: 'चाँद से जुड़े जज़्बात, जहाँ मोहब्बत वहीं घर।',
     AppLang.ar: 'مشاعر يقودها القمر وبيتٌ حيث يحبّون.'}),
  ZSign('leo', '♌', 'Jul 23 – Aug 22', 'Aug 15 – Sep 15', 'fire',
    {AppLang.en: 'Leo', AppLang.ur: 'اسد', AppLang.hi: 'सिंह', AppLang.ar: 'الأسد'},
    {AppLang.en: 'Simha', AppLang.ur: 'سنگھ', AppLang.hi: 'सिंह', AppLang.ar: 'سيمها'},
    _sun,
    {AppLang.en: 'Sunlit pride, big heart, born for the stage.',
     AppLang.ur: 'دھوپ جیسا وقار، بڑا دل، سٹیج کے لیے پیدا۔',
     AppLang.hi: 'धूप जैसा गौरव, बड़ा दिल, स्टेज के लिए पैदा।',
     AppLang.ar: 'كبرياء مشمس وقلب كبير وُلد للمسرح.'}),
  ZSign('virgo', '♍', 'Aug 23 – Sep 22', 'Sep 16 – Oct 15', 'earth',
    {AppLang.en: 'Virgo', AppLang.ur: 'سنبلہ', AppLang.hi: 'कन्या', AppLang.ar: 'العذراء'},
    {AppLang.en: 'Kanya', AppLang.ur: 'کنیا', AppLang.hi: 'कन्या', AppLang.ar: 'كانيا'},
    _mercury,
    {AppLang.en: 'Sharp eyes for detail, quiet acts of care.',
     AppLang.ur: 'باریکی پر گہری نظر، خاموش خدمت گزار۔',
     AppLang.hi: 'बारीकी पर गहरी नज़र, ख़ामोश सेवा।',
     AppLang.ar: 'عين دقيقة للتفاصيل ورعاية بصمت.'}),
  ZSign('libra', '♎', 'Sep 23 – Oct 22', 'Oct 16 – Nov 14', 'air',
    {AppLang.en: 'Libra', AppLang.ur: 'میزان', AppLang.hi: 'तुला', AppLang.ar: 'الميزان'},
    {AppLang.en: 'Tula', AppLang.ur: 'تلا', AppLang.hi: 'तुला', AppLang.ar: 'تولا'},
    _venus,
    {AppLang.en: 'Balance, beauty, and a gift for bringing peace.',
     AppLang.ur: 'توازن، خوبصورتی، اور صلح کرانے کا ہنر۔',
     AppLang.hi: 'संतुलन, सुंदरता, और सुलह कराने का हुनर।',
     AppLang.ar: 'توازن وجمال وموهبة صنع السلام.'}),
  ZSign('scorpio', '♏', 'Oct 23 – Nov 21', 'Nov 15 – Dec 14', 'water',
    {AppLang.en: 'Scorpio', AppLang.ur: 'عقرب', AppLang.hi: 'वृश्चिक', AppLang.ar: 'العقرب'},
    {AppLang.en: 'Vrishchika', AppLang.ur: 'ورشچک', AppLang.hi: 'वृश्चिक', AppLang.ar: 'فريشيكا'},
    _mars,
    {AppLang.en: 'Deep waters, fierce loyalty, x-ray intuition.',
     AppLang.ur: 'گہرا پانی، شدید وفاداری، پار دیکھتی نگاہ۔',
     AppLang.hi: 'गहरा पानी, ज़बरदस्त वफ़ादारी, पार देखती नज़र।',
     AppLang.ar: 'مياه عميقة وولاء شديد وحدس نافذ.'}),
  ZSign('sagittarius', '♐', 'Nov 22 – Dec 21', 'Dec 15 – Jan 13', 'fire',
    {AppLang.en: 'Sagittarius', AppLang.ur: 'قوس', AppLang.hi: 'धनु', AppLang.ar: 'القوس'},
    {AppLang.en: 'Dhanu', AppLang.ur: 'دھنو', AppLang.hi: 'धनु', AppLang.ar: 'دانو'},
    _jupiter,
    {AppLang.en: 'Arrows aimed at far horizons and honest laughter.',
     AppLang.ur: 'دور افق پر تیر، کھلکھلاتا سچا قہقہہ۔',
     AppLang.hi: 'दूर क्षितिज पर तीर, खिलखिलाती सच्ची हँसी।',
     AppLang.ar: 'سهام نحو آفاق بعيدة وضحكة صادقة.'}),
  ZSign('capricorn', '♑', 'Dec 22 – Jan 19', 'Jan 14 – Feb 11', 'earth',
    {AppLang.en: 'Capricorn', AppLang.ur: 'جدی', AppLang.hi: 'मकर', AppLang.ar: 'الجدي'},
    {AppLang.en: 'Makara', AppLang.ur: 'مکر', AppLang.hi: 'मकर', AppLang.ar: 'ماكارا'},
    _saturn,
    {AppLang.en: 'Mountain patience — they climb, and they arrive.',
     AppLang.ur: 'پہاڑ جیسا صبر — چڑھتے ہیں اور پہنچ کر رہتے ہیں۔',
     AppLang.hi: 'पहाड़ जैसा सब्र — चढ़ते हैं और पहुँच कर रहते हैं।',
     AppLang.ar: 'صبر الجبال — يتسلّقون ويصلون.'}),
  ZSign('aquarius', '♒', 'Jan 20 – Feb 18', 'Feb 12 – Mar 13', 'air',
    {AppLang.en: 'Aquarius', AppLang.ur: 'دلو', AppLang.hi: 'कुंभ', AppLang.ar: 'الدلو'},
    {AppLang.en: 'Kumbha', AppLang.ur: 'کمبھ', AppLang.hi: 'कुंभ', AppLang.ar: 'كومبا'},
    _saturn,
    {AppLang.en: 'Tomorrow\'s ideas, a friend to the whole sky.',
     AppLang.ur: 'کل کے خیالات، سارے آسمان کا دوست۔',
     AppLang.hi: 'कल के विचार, सारे आसमान का दोस्त।',
     AppLang.ar: 'أفكار الغد وصديق للسماء كلها.'}),
  ZSign('pisces', '♓', 'Feb 19 – Mar 20', 'Mar 14 – Apr 13', 'water',
    {AppLang.en: 'Pisces', AppLang.ur: 'حوت', AppLang.hi: 'मीन', AppLang.ar: 'الحوت'},
    {AppLang.en: 'Meena', AppLang.ur: 'مین', AppLang.hi: 'मीन', AppLang.ar: 'مينا'},
    _jupiter,
    {AppLang.en: 'Dream-deep empathy that swims between worlds.',
     AppLang.ur: 'خواب جیسی گہری ہمدردی، دو جہانوں کی تیراک۔',
     AppLang.hi: 'ख़्वाब जैसी गहरी हमदर्दी, दो जहानों की तैराक।',
     AppLang.ar: 'تعاطف عميق كالحلم يسبح بين العوالم.'}),
];

String elementEmoji(String e) {
  switch (e) {
    case 'fire': return '🔥';
    case 'earth': return '🌱';
    case 'air': return '🌬️';
    default: return '💧';
  }
}

// ---- Compatibility (element harmony + a stable per-pair flavour) ----
int matchScore(int a, int b) {
  const good = {'fire': 'air', 'air': 'fire', 'earth': 'water', 'water': 'earth'};
  final ea = signs[a].element, eb = signs[b].element;
  int base;
  if (a == b) {
    base = 82;
  } else if (ea == eb) {
    base = 84;
  } else if (good[ea] == eb) {
    base = 88;
  } else if ((ea == 'fire' && eb == 'water') || (ea == 'water' && eb == 'fire') ||
             (ea == 'earth' && eb == 'air') || (ea == 'air' && eb == 'earth')) {
    base = 58;
  } else {
    base = 70;
  }
  final wiggle = ((a * 7 + b * 7 + a * b) % 11) - 5; // symmetric, stable
  return (base + wiggle).clamp(42, 99);
}

String matchVerdictKey(int score) {
  if (score >= 85) return 'greatMatch';
  if (score >= 70) return 'goodMatch';
  if (score >= 55) return 'okMatch';
  return 'hardMatch';
}

// ---- Small helpers ----
Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String signName(ZSign s) => useVedic.value
  ? s.vname[currentLang.value] ?? s.vname[AppLang.en]!
  : s.name[currentLang.value] ?? s.name[AppLang.en]!;

String signDates(ZSign s) => useVedic.value ? s.vedicDates : s.westDates;

// ===========================================================================
// App root
// ===========================================================================
class FarooqStarsApp extends StatelessWidget {
  const FarooqStarsApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLang>(
    valueListenable: currentLang,
    builder: (_, lang, __) => MaterialApp(
      title: 'Farooq Stars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary, secondary: kLight,
          surface: kCard, onSurface: kOn),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: kCard,
          indicatorColor: kPrimary.withOpacity(0.35),
          iconTheme: const WidgetStatePropertyAll(IconThemeData(color: kOn)),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: const RootShell()),
    ));
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: kBg, elevation: 0, centerTitle: true,
      title: const Text('FAROOQ STARS ✦',
        style: TextStyle(color: kOn, fontWeight: FontWeight.w900,
          fontSize: 18, letterSpacing: 3)),
    ),
    body: IndexedStack(index: _tab, children: const [
      TodayTab(), ZodiacTab(), MatchTab(), MoreTab(),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: [
        NavigationDestination(icon: const Icon(Icons.auto_awesome), label: tr('today')),
        NavigationDestination(icon: const Icon(Icons.brightness_3), label: tr('zodiac')),
        NavigationDestination(icon: const Icon(Icons.favorite_outline), label: tr('match')),
        NavigationDestination(icon: const Icon(Icons.menu), label: tr('more')),
      ]),
  );
}

// Content column that stays a pleasant width on tablets / landscape
class CenteredList extends StatelessWidget {
  final List<Widget> children;
  const CenteredList({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 680),
    child: ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20,
        24 + MediaQuery.of(context).viewPadding.bottom),
      children: children)));
}

Widget card({required Widget child, EdgeInsets? padding}) => Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: padding ?? const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: kCard,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: kBorder)),
  child: child);

// Western <-> Vedic pill toggle
class SystemToggle extends StatelessWidget {
  const SystemToggle({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useVedic,
    builder: (_, vedic, __) {
      Widget half(String label, bool sel, VoidCallback tap) => Expanded(
        child: GestureDetector(onTap: tap, child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? kPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(99)),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: sel ? Colors.white : kMuted,
              fontWeight: FontWeight.w700, fontSize: 13.5)))));
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: kCard,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kBorder)),
        child: Row(children: [
          half(tr('western'), !vedic, () {
            useVedic.value = false;
            prefs.setBool('useVedic', false);
          }),
          half(tr('vedic'), vedic, () {
            useVedic.value = true;
            prefs.setBool('useVedic', true);
          }),
        ]));
    });
}

// ===========================================================================
// TODAY tab
// ===========================================================================
class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useVedic,
    builder: (_, __, ___) => ValueListenableBuilder<int>(
      valueListenable: mySignIdx,
      builder: (_, myIdx, __) {
        final sign = myIdx >= 0 ? signs[myIdx] : null;
        return CenteredList(children: [
          // Date header
          Padding(padding: const EdgeInsets.only(bottom: 14),
            child: Text(todayLine(), textAlign: TextAlign.center,
              style: TextStyle(color: kGold, fontSize: 15,
                fontWeight: FontWeight.w700, fontFamily: urduFont))),
          const SystemToggle(),
          // Sign chips
          Text(sign == null ? tr('chooseSign') : tr('yourSign'),
            style: TextStyle(color: kMuted, fontSize: 13,
              fontWeight: FontWeight.w600, fontFamily: urduFont)),
          const SizedBox(height: 10),
          SizedBox(height: 44, child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: signs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == myIdx;
              return GestureDetector(
                onTap: () {
                  mySignIdx.value = i;
                  prefs.setInt('mySign', i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: sel ? kPrimary : kCard,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: sel ? kPrimary : kBorder)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(signs[i].symbol,
                      style: TextStyle(fontSize: 18,
                        color: sel ? Colors.white : kGold)),
                    const SizedBox(width: 6),
                    Text(signName(signs[i]),
                      style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : kOn)),
                  ])));
            })),
          const SizedBox(height: 18),
          if (sign != null) ...[
            SignCard(sign: sign),
            DailyReadingCard(sign: sign),
          ] else
            card(child: Column(children: [
              const Text('✨', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(tr('chooseSign'), textAlign: TextAlign.center,
                style: TextStyle(color: kOn, fontSize: 16,
                  fontWeight: FontWeight.w700, fontFamily: urduFont)),
            ])),
        ]);
      }));
}

class SignCard extends StatelessWidget {
  final ZSign sign;
  const SignCard({super.key, required this.sign});

  Widget chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: kBg,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: kBorder)),
    child: Text('$label: $value',
      style: const TextStyle(color: kMuted, fontSize: 12.5,
        fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    final lang = currentLang.value;
    return card(child: Column(children: [
      Text(sign.symbol, style: const TextStyle(fontSize: 54, color: kGold)),
      const SizedBox(height: 6),
      Text(signName(sign),
        style: TextStyle(color: kOn, fontSize: 24,
          fontWeight: FontWeight.w800, fontFamily: urduFont)),
      const SizedBox(height: 4),
      Text(signDates(sign),
        style: const TextStyle(color: kMuted, fontSize: 13)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
        children: [
          chip(tr('element'), '${elementEmoji(sign.element)} ${tr(sign.element)}'),
          chip(tr('planet'), sign.planet[lang] ?? sign.planet[AppLang.en]!),
        ]),
      const SizedBox(height: 14),
      Text(sign.trait[lang] ?? sign.trait[AppLang.en]!,
        textAlign: TextAlign.center,
        style: TextStyle(color: kLight, fontSize: 15, height: 1.9,
          fontWeight: FontWeight.w500, fontFamily: urduFont)),
    ]));
  }
}

class DailyReadingCard extends StatelessWidget {
  final ZSign sign;
  const DailyReadingCard({super.key, required this.sign});

  @override
  Widget build(BuildContext context) {
    final vedic = useVedic.value;
    final url = vedic
      ? '$kWebsite/farooq-now-vedic.html'
      : '$kWebsite/farooq-now-western.html';
    return card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Icon(Icons.auto_awesome, color: kGold, size: 20),
          const SizedBox(width: 8),
          Text(tr('dailyReading'),
            style: TextStyle(color: kOn, fontSize: 16,
              fontWeight: FontWeight.w800, fontFamily: urduFont)),
        ]),
        const SizedBox(height: 10),
        Text(tr('comingLive'),
          style: TextStyle(color: kMuted, fontSize: 13.5, height: 1.8,
            fontFamily: urduFont)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: kPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12)),
          onPressed: () => openUrl(url),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(tr('readOnWebsite'),
            style: TextStyle(fontWeight: FontWeight.w700,
              fontFamily: urduFont))),
      ]));
  }
}

// ===========================================================================
// ZODIAC tab — all 12 signs
// ===========================================================================
class ZodiacTab extends StatelessWidget {
  const ZodiacTab({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useVedic,
    builder: (_, vedic, __) => Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SystemToggle()),
        Expanded(child: LayoutBuilder(builder: (_, box) {
          final cols = (box.maxWidth / 170).floor().clamp(2, 5);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(20, 4, 20,
              24 + MediaQuery.of(context).viewPadding.bottom),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols, mainAxisSpacing: 12,
              crossAxisSpacing: 12, childAspectRatio: 1.02),
            itemCount: signs.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => showSignSheet(ctx, signs[i]),
              child: Container(
                decoration: BoxDecoration(color: kCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kBorder)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(signs[i].symbol,
                      style: const TextStyle(fontSize: 34, color: kGold)),
                    const SizedBox(height: 6),
                    Text(signName(signs[i]),
                      style: TextStyle(color: kOn, fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: urduFont)),
                    const SizedBox(height: 2),
                    Text(signDates(signs[i]),
                      style: const TextStyle(color: kMuted, fontSize: 11)),
                  ]))));
        })),
      ]))));
}

void showSignSheet(BuildContext context, ZSign sign) {
  final lang = currentLang.value;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: DraggableScrollableSheet(
        initialChildSize: 0.62, maxChildSize: 0.92, minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(controller: ctrl,
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kBorder,
                  borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              Center(child: Text(sign.symbol,
                style: const TextStyle(fontSize: 60, color: kGold))),
              const SizedBox(height: 6),
              Center(child: Text(
                '${sign.name[lang] ?? sign.name[AppLang.en]!}  ·  ${sign.vname[lang] ?? sign.vname[AppLang.en]!}',
                style: TextStyle(color: kOn, fontSize: 22,
                  fontWeight: FontWeight.w800, fontFamily: urduFont))),
              const SizedBox(height: 14),
              _sheetRow(tr('western'), sign.westDates),
              _sheetRow(tr('vedic'), sign.vedicDates),
              _sheetRow(tr('element'),
                '${elementEmoji(sign.element)} ${tr(sign.element)}'),
              _sheetRow(tr('planet'),
                sign.planet[lang] ?? sign.planet[AppLang.en]!),
              const SizedBox(height: 14),
              Text(sign.trait[lang] ?? sign.trait[AppLang.en]!,
                textAlign: TextAlign.center,
                style: TextStyle(color: kLight, fontSize: 15.5, height: 1.9,
                  fontFamily: urduFont)),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => openUrl(useVedic.value
                  ? '$kWebsite/farooq-rashis.html'
                  : '$kWebsite/farooq-zodiac.html'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(tr('fullProfile'),
                  style: TextStyle(fontWeight: FontWeight.w700,
                    fontFamily: urduFont))),
            ])))));
}

Widget _sheetRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(children: [
    Expanded(child: Text(label,
      style: const TextStyle(color: kMuted, fontSize: 13.5))),
    Text(value, style: const TextStyle(color: kOn, fontSize: 13.5,
      fontWeight: FontWeight.w600)),
  ]));

// ===========================================================================
// MATCH tab — compatibility
// ===========================================================================
class MatchTab extends StatefulWidget {
  const MatchTab({super.key});
  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab> {
  int? _a, _b;

  Future<void> _pick(bool first) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: signs.length,
          itemBuilder: (ctx, i) => GestureDetector(
            onTap: () => Navigator.pop(ctx, i),
            child: Container(
              decoration: BoxDecoration(color: kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(signs[i].symbol,
                    style: const TextStyle(fontSize: 24, color: kGold)),
                  const SizedBox(height: 4),
                  Text(signName(signs[i]),
                    style: TextStyle(color: kOn, fontSize: 11,
                      fontWeight: FontWeight.w600, fontFamily: urduFont),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ]))))));
    if (picked != null) setState(() => first ? _a = picked : _b = picked);
  }

  Widget _slot(String label, int? idx, VoidCallback tap) => Expanded(
    child: GestureDetector(onTap: tap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: idx != null ? kPrimary : kBorder, width: 1.4)),
      child: Column(children: [
        Text(idx != null ? signs[idx].symbol : '＋',
          style: TextStyle(fontSize: 40,
            color: idx != null ? kGold : kMuted)),
        const SizedBox(height: 6),
        Text(idx != null ? signName(signs[idx]) : label,
          style: TextStyle(color: idx != null ? kOn : kMuted,
            fontSize: 13.5, fontWeight: FontWeight.w700,
            fontFamily: urduFont)),
      ]))));

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useVedic,
    builder: (_, __, ___) {
      final ready = _a != null && _b != null;
      final score = ready ? matchScore(_a!, _b!) : 0;
      return CenteredList(children: [
        const SizedBox(height: 4),
        Text(tr('pickTwo'), textAlign: TextAlign.center,
          style: TextStyle(color: kMuted, fontSize: 14, height: 1.7,
            fontFamily: urduFont)),
        const SizedBox(height: 16),
        Row(children: [
          _slot(tr('firstSign'), _a, () => _pick(true)),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('♥', style: TextStyle(color: kPrimary, fontSize: 26))),
          _slot(tr('secondSign'), _b, () => _pick(false)),
        ]),
        const SizedBox(height: 20),
        if (ready) card(child: Column(children: [
          SizedBox(width: 150, height: 150, child: Stack(
            alignment: Alignment.center, children: [
              SizedBox(width: 150, height: 150,
                child: CircularProgressIndicator(
                  value: score / 100, strokeWidth: 10,
                  backgroundColor: kBg,
                  valueColor: const AlwaysStoppedAnimation(kPrimary))),
              Text('$score%', style: const TextStyle(color: kOn,
                fontSize: 34, fontWeight: FontWeight.w900)),
            ])),
          const SizedBox(height: 14),
          Text(tr(matchVerdictKey(score)), textAlign: TextAlign.center,
            style: TextStyle(color: kGold, fontSize: 17,
              fontWeight: FontWeight.w800, fontFamily: urduFont)),
          const SizedBox(height: 6),
          Text('${signName(signs[_a!])} ${signs[_a!].symbol}  +  ${signs[_b!].symbol} ${signName(signs[_b!])}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 13.5)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kLight,
                side: const BorderSide(color: kBorder),
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Share.share(
                '${signName(signs[_a!])} + ${signName(signs[_b!])} = $score% ✨ — Farooq Stars\n$kWebsite'),
              icon: const Icon(Icons.share, size: 18),
              label: Text(tr('share'),
                style: TextStyle(fontFamily: urduFont)))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => openUrl(useVedic.value
                ? '$kWebsite/farooq-match-vedic.html'
                : '$kWebsite/farooq-match-western.html'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(tr('readOnWebsite'),
                style: TextStyle(fontFamily: urduFont,
                  fontWeight: FontWeight.w700)))),
          ]),
        ])),
      ]);
    });
}

// ===========================================================================
// MORE tab
// ===========================================================================
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  Widget _link(IconData ic, String label, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(onTap: tap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder)),
        child: Row(children: [
          Icon(ic, color: kLight, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
            style: TextStyle(color: kOn, fontSize: 14.5,
              fontWeight: FontWeight.w600, fontFamily: urduFont))),
          const Icon(Icons.chevron_right, color: kMuted, size: 20),
        ]))));

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLang>(
    valueListenable: currentLang,
    builder: (_, lang, __) => CenteredList(children: [
      // Language picker
      Text(tr('language'), style: TextStyle(color: kMuted, fontSize: 13,
        fontWeight: FontWeight.w600, fontFamily: urduFont)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: AppLang.values.map((l) {
        final sel = l == lang;
        return GestureDetector(
          onTap: () {
            currentLang.value = l;
            prefs.setString('lang', l.name);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? kPrimary : kCard,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: sel ? kPrimary : kBorder)),
            child: Text(langLabel(l),
              style: TextStyle(color: sel ? Colors.white : kOn,
                fontSize: 14, fontWeight: FontWeight.w700))));
      }).toList()),
      const SizedBox(height: 22),
      // About
      card(child: Column(children: [
        const Text('✦', style: TextStyle(color: kGold, fontSize: 30)),
        const SizedBox(height: 8),
        Text('Farooq Stars', style: TextStyle(color: kOn, fontSize: 19,
          fontWeight: FontWeight.w800, fontFamily: urduFont)),
        const SizedBox(height: 8),
        Text(tr('aboutText'), textAlign: TextAlign.center,
          style: TextStyle(color: kMuted, fontSize: 13.5, height: 1.8,
            fontFamily: urduFont)),
      ])),
      // Links
      _link(Icons.public, tr('website'), () => openUrl(kWebsite)),
      _link(Icons.mail_outline, tr('dailyEmail'),
        () => openUrl('$kWebsite/farooq-subscribe.html')),
      _link(Icons.alternate_email, tr('contact'),
        () => openUrl('mailto:stars@farooqstars.com')),
      _link(Icons.music_note, tr('musicApp'),
        () => openUrl('https://www.farooqmusic.com')),
      const SizedBox(height: 8),
      // Disclaimer + version
      Text(tr('disclaimer'), textAlign: TextAlign.center,
        style: TextStyle(color: kMuted.withOpacity(0.8), fontSize: 12,
          height: 1.7, fontFamily: urduFont)),
      const SizedBox(height: 10),
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (_, snap) => Text(
          snap.hasData
            ? 'v${snap.data!.version} (${snap.data!.buildNumber})'
            : '',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kBorder, fontSize: 11.5))),
    ]));
}
