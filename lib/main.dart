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
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
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
// Cloudflare Worker — live daily readings (same cache the website uses)
const kWorker = 'https://farooq-stars-ai.babaqatar.workers.dev';
// Build 5: full sign profiles — extracted from farooq-zodiac.html +
// farooq-rashis.html into ONE json on the site. Site stays the source of
// truth: update the json and every installed app shows the new text.
// STANDING RULE: app-only files live in the site's /app/ folder — never
// mixed with website files.
const kProfilesUrl = '$kWebsite/app/farooq-profiles.json';

Map<String, dynamic>? _profilesData;
Future<Map<String, dynamic>?> loadProfiles() async {
  if (_profilesData != null) return _profilesData;
  try {
    final r = await http.get(Uri.parse(kProfilesUrl))
      .timeout(const Duration(seconds: 30));
    _profilesData = jsonDecode(r.body) as Map<String, dynamic>;
  } catch (_) {}
  return _profilesData;
}


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
  'p_today': {AppLang.en: 'Today', AppLang.ur: 'آج', AppLang.hi: 'आज', AppLang.ar: 'اليوم'},
  'p_week': {AppLang.en: 'This week', AppLang.ur: 'یہ ہفتہ', AppLang.hi: 'यह सप्ताह', AppLang.ar: 'هذا الأسبوع'},
  'p_month': {AppLang.en: 'This month', AppLang.ur: 'یہ مہینہ', AppLang.hi: 'यह महीना', AppLang.ar: 'هذا الشهر'},
  'p_year': {AppLang.en: 'This year', AppLang.ur: 'یہ سال', AppLang.hi: 'यह वर्ष', AppLang.ar: 'هذه السنة'},
  'readingError': {AppLang.en: "Couldn't load today's reading — check your connection and tap ↻.", AppLang.ur: 'آج کی reading load نہیں ہو سکی — internet دیکھ کر ↻ دبائیں۔', AppLang.hi: 'आज का फल load नहीं हो सका — internet देखकर ↻ दबाएँ।', AppLang.ar: 'تعذّر تحميل قراءة اليوم — تحقق من الاتصال واضغط ↻.'},
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

// ===========================================================================
// v0.2 (Build 2): SITE IMAGE ICONS — the SAME PNGs farooqstars.com uses, so
// the look is identical on Android, iOS and web. Standing rule: NEVER
// text/emoji symbols (every platform draws those differently). Images are
// loaded from the site and cached on-device (cached_network_image); if the
// phone is offline before the first cache, the old text symbol appears as a
// quiet fallback so nothing ever looks broken.
//   • sign symbols  →  /icons/zsymbol1..12.png (Western) · hzsymbol1..12.png (Vedic)
//   • planets       →  /planet-icons-v2/<planet>.png
//   • big artwork   →  /signs/Z01..Z12.png (Western) · V01..V12.png (Vedic)
// ===========================================================================
// STANDING RULE: the app reads ONLY from the site's /app/ folder —
// farooq-app-sync.php keeps those copies fresh from the site originals.
String signSymbolUrl(int i, {required bool vedic}) =>
  '$kWebsite/app/icons/${vedic ? 'hz' : 'z'}symbol${i + 1}.png';

String signArtUrl(int i, {required bool vedic}) =>
  '$kWebsite/app/signs/${vedic ? 'V' : 'Z'}${(i + 1).toString().padLeft(2, '0')}.png';

/// The ORIGINAL large artwork in public_html root (Aries.png … 2–8 MB).
/// Used as the Today-card hero; the smaller card art shows instantly as a
/// placeholder while this downloads, then it stays cached on-device.
String signBigArtUrl(int i) => '$kWebsite/app/art/${signs[i].name[AppLang.en]!}.png';

String? planetIconUrl(ZSign s) {
  final p = (s.planet[AppLang.en] ?? '').toLowerCase();
  const known = {'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter',
    'saturn', 'uranus', 'neptune', 'pluto', 'rahu', 'ketu'};
  return known.contains(p) ? '$kWebsite/app/planet-icons-v2/$p.png' : null;
}

// The website's per-element accent colour (CSS --fire/--earth/--air/--water).
// Used to tint the dates line, trait chips and the Personality heading so the
// app matches the zodiac / rashi pages exactly.
Color elementColor(String element) {
  switch (element.toLowerCase()) {
    case 'fire':  return const Color(0xFFff6b6b);
    case 'earth': return const Color(0xFF57d39a);
    case 'air':   return const Color(0xFFffd56b);
    case 'water': return const Color(0xFF5aa9e6);
    default:      return kGold;
  }
}

/// Small sign symbol — vedic-aware (hzsymbol vs zsymbol).
class SignIcon extends StatelessWidget {
  final int index;
  final double size;
  const SignIcon(this.index, {super.key, required this.size});
  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: signSymbolUrl(index, vedic: useVedic.value),
    width: size, height: size, fit: BoxFit.contain,
    placeholder: (_, __) => SizedBox(width: size, height: size),
    errorWidget: (_, __, ___) => Text(signs[index].symbol,
      style: TextStyle(fontSize: size * 0.8, color: kGold)));
}

/// Big artistic sign banner. Square frame + BoxFit.contain = the WHOLE
/// image is always visible, nothing cut top/bottom (Build 3 fix).
/// hero:true (Today card) shows the ORIGINAL large root artwork, with the
/// smaller /signs/ card art appearing instantly while it downloads.
class SignArt extends StatelessWidget {
  final ZSign sign;
  final bool hero;
  const SignArt(this.sign, {super.key, this.hero = false});
  @override
  Widget build(BuildContext context) {
    final i = signs.indexOf(sign);
    final fallback = Center(child: Text(sign.symbol,
      style: const TextStyle(fontSize: 64, color: kGold)));
    final cardArt = CachedNetworkImage(
      imageUrl: signArtUrl(i, vedic: useVedic.value),
      fit: BoxFit.contain,
      // Decode at a sane size — the source signs art is ~700px, no need to
      // hold the full bitmap in memory.
      memCacheWidth: 720,
      placeholder: (_, __) => Container(color: kBg),
      errorWidget: (_, __, ___) => fallback);
    final img = hero
      ? CachedNetworkImage(
          imageUrl: signBigArtUrl(i),
          fit: BoxFit.contain,
          // The root artwork is 2816px wide (2–9 MB). Decoding it at full
          // resolution can exhaust memory on some phones and crash the app;
          // 1200px is plenty for a banner and keeps memory low.
          memCacheWidth: 1200,
          placeholder: (_, __) => cardArt,
          errorWidget: (_, __, ___) => cardArt)
      : cardArt;
    // hero (Today banner) uses the artwork's real 11:6 shape so there are no
    // empty bands top/bottom; the small square card art stays 1:1.
    return ClipRRect(borderRadius: BorderRadius.circular(18),
      child: AspectRatio(aspectRatio: hero ? (11 / 6) : 1, child: img));
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
                    SignIcon(i, size: 22),
                    const SizedBox(width: 6),
                    Text(signName(signs[i]),
                      style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : kOn)),
                  ])));
            })),
          const SizedBox(height: 18),
          if (sign != null) ...[
            // Build 7: website-style header — banner, left-aligned name,
            // element-coloured dates + info icon, trait chips, and the full
            // details table, all together at the top.
            SignHeaderCard(key: ValueKey('hdr-${sign.key}'), sign: sign),
            DailyReadingCard(
              key: ValueKey('read-${sign.key}-${currentLang.value.name}'),
              sign: sign),
            // Personality + the 8 sections, each a collapsible dropdown.
            SignReadings(key: ValueKey('rd-${sign.key}'), sign: sign),
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

// ===========================================================================
// Build 7: website-style header card. Banner, left-aligned name, dates in the
// element accent colour with an ⓘ that opens the Date Calculator, trait chips
// (accent-tinted) and the full details table — all in one panel at the top.
// ===========================================================================
class SignHeaderCard extends StatefulWidget {
  final ZSign sign;
  const SignHeaderCard({super.key, required this.sign});
  @override
  State<SignHeaderCard> createState() => _SignHeaderCardState();
}

class _SignHeaderCardState extends State<SignHeaderCard> {
  Map<String, dynamic>? _all;

  @override
  void initState() {
    super.initState();
    loadProfiles().then((d) {
      if (mounted) setState(() => _all = d);
    });
  }

  String lx(dynamic m) {
    if (m is Map) {
      return (m[currentLang.value.name] ?? m['en'] ?? '').toString();
    }
    return m == null ? '' : m.toString();
  }

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Text(label,
        style: TextStyle(color: kMuted, fontSize: 13.5, fontFamily: urduFont))),
      Expanded(flex: 3, child: Align(
        alignment: AlignmentDirectional.centerEnd, child: value)),
    ]));

  Widget _txt(String t) => Text(t, textAlign: TextAlign.end,
    style: TextStyle(color: kOn, fontSize: 13.5, fontWeight: FontWeight.w600,
      fontFamily: urduFont));

  @override
  Widget build(BuildContext context) {
    final sign = widget.sign;
    final vedic = useVedic.value;
    final lang = currentLang.value;
    final accent = elementColor(sign.element);
    final sys = _all?[vedic ? 'vedic' : 'western'] as Map<String, dynamic>?;
    final sg = sys?['signs']?[sign.key] as Map<String, dynamic>?;
    final rows = (sys?['rows'] ?? {}) as Map<String, dynamic>;

    // On the Vedic (rashi) side show the Sanskrit name transliterated in
    // English with the familiar Western name in brackets, e.g. "Kanya (Virgo)"
    // — nicer for the public. Western side just shows the sign name.
    final vName = sign.vname[lang] ?? sign.vname[AppLang.en]!;
    final wName = sign.name[lang] ?? sign.name[AppLang.en]!;
    final headerName = vedic
      ? (vName == wName ? vName : '$vName ($wName)')
      : signName(sign);

    final children = <Widget>[
      SignArt(sign, hero: true),
      const SizedBox(height: 14),
      // name — left aligned like the website
      Text(headerName,
        style: TextStyle(color: kOn, fontSize: 26,
          fontWeight: FontWeight.w800, fontFamily: urduFont)),
      const SizedBox(height: 5),
      // dates in the element accent colour + ⓘ opening the Date Calculator
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text(signDates(sign),
          style: TextStyle(color: accent, fontSize: 14,
            fontWeight: FontWeight.w700, fontFamily: urduFont)),
        const SizedBox(width: 6),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => DateCalculatorScreen(vedic: vedic))),
          borderRadius: BorderRadius.circular(99),
          child: Padding(padding: const EdgeInsets.all(2),
            child: Icon(Icons.info_outline, color: accent, size: 17))),
      ]),
      // the short one-liner tagline — restored (people liked it)
      const SizedBox(height: 12),
      Text(sign.trait[lang] ?? sign.trait[AppLang.en]!,
        style: TextStyle(color: Colors.white, fontSize: 14.5, height: 1.7,
          fontWeight: FontWeight.w500, fontFamily: urduFont)),
    ];

    if (sg != null) {
      // sg != null guarantees sys != null (sg came from sys?['signs']).
      // Using sys! here also promotes sys to non-null for the rows below.
      final order = ((sys!['order'] ?? const <dynamic>[]) as List)
        .cast<String>();
      final traits = lx(sg['traits']).split('·')
        .map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      if (traits.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerStart,
            child: Wrap(spacing: 8, runSpacing: 8,
              children: traits.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(accent.withOpacity(0.16), kCard),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: accent.withOpacity(0.40))),
                child: Text(t, style: TextStyle(color: kOn,
                  fontSize: 12.5, fontWeight: FontWeight.w700,
                  fontFamily: urduFont)))).toList())),
        ]);
      }
      children.addAll([
        const SizedBox(height: 14),
        Divider(color: kBorder, height: 1),
        const SizedBox(height: 6),
        _row(lx(rows['dates']), _txt(lx(sg['dates']))),
        _row(lx(rows['element']), _txt(lx(sys['el']?[sg['el']]))),
        _row(lx(rows['quality']), _txt(lx(sys['qu']?[sg['qu']]))),
        _row(lx(rows['ruler']), _txt(((sg['ruler'] ?? []) as List)
          .map((r) => lx(sys['pl']?[r])).join(' · '))),
        _row(lx(rows['day']), _txt(lx(sys['day']?[sg['day']]))),
        _row(lx(rows['numbers']), Wrap(spacing: 6, alignment: WrapAlignment.end,
          children: ((sg['nums'] ?? []) as List).map((n) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: kBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
            child: Text('$n', style: const TextStyle(color: kOn,
              fontSize: 13, fontWeight: FontWeight.w700)))).toList())),
        _row(lx(rows['colors']), Wrap(spacing: 10, runSpacing: 4,
          alignment: WrapAlignment.end,
          children: ((sg['colors'] ?? []) as List).map((ck) {
            final cm = sys['col']?[ck] as Map<String, dynamic>?;
            final hex = (cm?['h'] ?? '#888888') as String;
            final col = Color(int.tryParse(
              'ff${hex.replaceFirst('#', '')}', radix: 16) ?? 0xff888888);
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(lx(cm), style: TextStyle(color: kOn,
                fontSize: 13, fontWeight: FontWeight.w600,
                fontFamily: urduFont)),
            ]);
          }).toList())),
        _row(lx(rows['compat']), Wrap(spacing: 6, runSpacing: 6,
          alignment: WrapAlignment.end,
          children: ((sg['compat'] ?? []) as List).map((mk) {
            final mi = order.indexOf(mk as String);
            return GestureDetector(
              onTap: mi >= 0
                ? () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SignDetailScreen(sign: signs[mi])))
                : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: kBg,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kBorder)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (mi >= 0) ...[
                    SignIcon(mi, size: 16),
                    const SizedBox(width: 5),
                  ],
                  Text(lx(sys['sname']?[mk]),
                    style: TextStyle(color: kOn, fontSize: 12.5,
                      fontWeight: FontWeight.w700, fontFamily: urduFont)),
                  if (mi >= 0) ...[
                    const SizedBox(width: 3),
                    Icon(Icons.chevron_right, size: 14, color: kMuted),
                  ],
                ])));
          }).toList())),
      ]);
    }

    return card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }
}

class DailyReadingCard extends StatefulWidget {
  final ZSign sign;
  const DailyReadingCard({super.key, required this.sign});
  @override
  State<DailyReadingCard> createState() => _DailyReadingCardState();
}

class _DailyReadingCardState extends State<DailyReadingCard> {
  // One fetch per sign+language+period per session — after that it's instant.
  static final Map<String, String> _memCache = {};
  String? _text;
  bool _loading = true, _error = false;
  // Build 4: today | week | month | year — same worker cache the site uses.
  String _period = 'today';

  String get _cacheKey =>
    '${widget.sign.key}:${currentLang.value.name}:$_period';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final k = _cacheKey;
    if (_memCache.containsKey(k)) {
      setState(() { _text = _memCache[k]; _loading = false; _error = false; });
      return;
    }
    setState(() { _loading = true; _error = false; });
    try {
      // The SAME real AstrologyAPI reading the website shows — served from
      // the worker's morning cache, no new API cost. First hi/ar request of
      // the day translates once server-side, then that is cached too.
      final uri = Uri.parse('$kWorker/app/reading'
        '?s=${widget.sign.key}&period=$_period&lang=${currentLang.value.name}');
      final r = await http.get(uri).timeout(const Duration(seconds: 30));
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      // AstrologyAPI/translation text mein kabhi kabhi **markdown** ke
      // sitare aa jate hain — card par khaam ** acha nahi lagta, saaf karo.
      final t = d['ok'] == true
        ? (d['text'] ?? '').toString().replaceAll('**', '').trim()
        : '';
      if (t.isEmpty) throw Exception('empty');
      _memCache[k] = t;
      if (mounted) setState(() { _text = t; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

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
          const Spacer(),
          if (!_loading) IconButton(
            icon: const Icon(Icons.refresh, color: kMuted, size: 19),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Refresh',
            onPressed: () { _memCache.remove(_cacheKey); _load(); }),
        ]),
        const SizedBox(height: 8),
        // Period selector — Today / Week / Month / Year
        Wrap(spacing: 6, runSpacing: 6, children:
          ['today', 'week', 'month', 'year'].map((p) {
            final sel = p == _period;
            return GestureDetector(
              onTap: () {
                if (_period == p) return;
                setState(() => _period = p);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? kPrimary : kBg,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: sel ? kPrimary : kBorder)),
                child: Text(tr('p_$p'),
                  style: TextStyle(
                    color: sel ? Colors.white : kMuted, fontSize: 12.5,
                    fontWeight: FontWeight.w700, fontFamily: urduFont))));
          }).toList()),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: SizedBox(width: 26, height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 3, color: kPrimary))))
        else if (_error)
          Text(tr('readingError'),
            style: TextStyle(color: kMuted, fontSize: 13.5, height: 1.8,
              fontFamily: urduFont))
        else
          // Standing rule: reading text is WHITE in every language — the
          // background is purple, purple-on-purple is hard to read.
          Text(_text!,
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.95,
              fontWeight: FontWeight.w500, fontFamily: urduFont)),
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
// Build 5: FULL SIGN PROFILE — same content as the site's zodiac/rashi pages
// (traits, details table, personality, 8 tabbed sections, 4 languages).
// ===========================================================================
class ProfileScreen extends StatefulWidget {
  final ZSign sign;
  const ProfileScreen({super.key, required this.sign});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _all;
  bool _failed = false;
  String _tab = 'general';

  @override
  void initState() {
    super.initState();
    loadProfiles().then((d) {
      if (mounted) setState(() { _all = d; _failed = d == null; });
    });
  }

  // one language value out of a {en,ur,hi,ar} map
  String lx(dynamic m) {
    if (m is Map) {
      return (m[currentLang.value.name] ?? m['en'] ?? '').toString();
    }
    return m == null ? '' : m.toString();
  }

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: Text(label,
        style: TextStyle(color: kMuted, fontSize: 13.5,
          fontFamily: urduFont))),
      Expanded(flex: 3, child: Align(
        alignment: AlignmentDirectional.centerEnd, child: value)),
    ]));

  Widget _txt(String t, {Color c = kOn, double fs = 13.5,
      FontWeight w = FontWeight.w600}) =>
    Text(t, textAlign: TextAlign.end,
      style: TextStyle(color: c, fontSize: fs, fontWeight: w,
        fontFamily: urduFont));

  @override
  Widget build(BuildContext context) {
    final vedic = useVedic.value;
    final sys = _all?[vedic ? 'vedic' : 'western'] as Map<String, dynamic>?;
    final sk = widget.sign.key;
    final sg = sys?['signs']?[sk] as Map<String, dynamic>?;
    final rows = (sys?['rows'] ?? {}) as Map<String, dynamic>;
    final tabs = (sys?['tabs'] ?? {}) as Map<String, dynamic>;
    final lang = currentLang.value;

    Widget body;
    if (_failed) {
      body = Center(child: Padding(padding: const EdgeInsets.all(30),
        child: Text(tr('readingError'), textAlign: TextAlign.center,
          style: TextStyle(color: kMuted, fontSize: 14, height: 1.8,
            fontFamily: urduFont))));
    } else if (sg == null) {
      body = const Center(child: SizedBox(width: 30, height: 30,
        child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary)));
    } else {
      final order = (sys!['order'] as List).cast<String>();
      final traits = lx(sg['traits']).split('·')
        .map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      final details = (sg['details'] ?? {}) as Map<String, dynamic>;
      const tabOrder = ['general', 'career', 'love', 'health',
        'gems', 'dark', 'family', 'karma'];

      body = Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20,
            28 + MediaQuery.of(context).viewPadding.bottom),
          children: [
            SignArt(widget.sign, hero: true),
            const SizedBox(height: 14),
            Center(child: Text(signName(widget.sign),
              style: TextStyle(color: kOn, fontSize: 26,
                fontWeight: FontWeight.w800, fontFamily: urduFont))),
            const SizedBox(height: 4),
            Center(child: Text(lx(sg['dates']),
              style: const TextStyle(color: kMuted, fontSize: 13))),
            const SizedBox(height: 12),
            // trait chips
            Wrap(spacing: 8, runSpacing: 8,
              alignment: WrapAlignment.center,
              children: traits.map((t) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: kCard,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kBorder)),
                child: Text(t, style: TextStyle(color: kGold,
                  fontSize: 12.5, fontWeight: FontWeight.w700,
                  fontFamily: urduFont)))).toList()),
            const SizedBox(height: 16),
            // details table — same rows as the website
            card(child: Column(children: [
              _row(lx(rows['dates']), _txt(lx(sg['dates']))),
              _row(lx(rows['element']),
                _txt(lx(sys['el']?[sg['el']]))),
              _row(lx(rows['quality']),
                _txt(lx(sys['qu']?[sg['qu']]))),
              _row(lx(rows['ruler']), _txt(((sg['ruler'] ?? []) as List)
                .map((r) => lx(sys['pl']?[r])).join(' · '))),
              _row(lx(rows['day']),
                _txt(lx(sys['day']?[sg['day']]))),
              _row(lx(rows['numbers']), Wrap(spacing: 6,
                alignment: WrapAlignment.end,
                children: ((sg['nums'] ?? []) as List).map((n) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder)),
                  child: Text('$n', style: const TextStyle(color: kOn,
                    fontSize: 13, fontWeight: FontWeight.w700)))).toList())),
              _row(lx(rows['colors']), Wrap(spacing: 10, runSpacing: 4,
                alignment: WrapAlignment.end,
                children: ((sg['colors'] ?? []) as List).map((ck) {
                  final cm = sys['col']?[ck] as Map<String, dynamic>?;
                  final hex = (cm?['h'] ?? '#888888') as String;
                  final col = Color(int.parse(
                    'ff${hex.replaceFirst('#', '')}', radix: 16));
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 12, height: 12,
                      decoration: BoxDecoration(color: col,
                        shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(lx(cm), style: TextStyle(color: kOn,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      fontFamily: urduFont)),
                  ]);
                }).toList())),
              _row(lx(rows['compat']), Wrap(spacing: 6, runSpacing: 6,
                alignment: WrapAlignment.end,
                children: ((sg['compat'] ?? []) as List).map((mk) {
                  final mi = order.indexOf(mk as String);
                  return GestureDetector(
                    onTap: mi >= 0
                      ? () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SignDetailScreen(sign: signs[mi])))
                      : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: kBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: kBorder)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (mi >= 0) ...[
                          SignIcon(mi, size: 16),
                          const SizedBox(width: 5),
                        ],
                        Text(lx(sys['sname']?[mk]),
                          style: TextStyle(color: kOn, fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: urduFont)),
                        if (mi >= 0) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.chevron_right, size: 14, color: kMuted),
                        ],
                      ])));
                }).toList())),
            ])),
            const SizedBox(height: 16),
            Text(lx(rows['personality']).toUpperCase(),
              style: const TextStyle(color: kGold, fontSize: 13,
                fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(lx(sg['pers']),
              style: TextStyle(color: Colors.white, fontSize: 15,
                height: 1.9, fontFamily: urduFont)),
            const SizedBox(height: 18),
            // section tabs — same 8 as the website
            Wrap(spacing: 6, runSpacing: 6, children: tabOrder.map((t) {
              final sel = t == _tab;
              return GestureDetector(
                onTap: () => setState(() => _tab = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? kPrimary : kCard,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: sel ? kPrimary : kBorder)),
                  child: Text(lx(tabs[t]),
                    style: TextStyle(
                      color: sel ? Colors.white : kMuted,
                      fontSize: 12.5, fontWeight: FontWeight.w700,
                      fontFamily: urduFont))));
            }).toList()),
            const SizedBox(height: 14),
            Text(lx(details[_tab]),
              style: TextStyle(color: Colors.white, fontSize: 15,
                height: 1.95, fontFamily: urduFont)),
            const SizedBox(height: 6),
            // language switch reminder is not needed — app-wide language applies
          ])));
    }

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          iconTheme: const IconThemeData(color: kGold),
          title: Text(signName(widget.sign),
            style: TextStyle(color: kGold, fontSize: 18,
              fontWeight: FontWeight.w800, fontFamily: urduFont))),
        body: ValueListenableBuilder<AppLang>(
          valueListenable: currentLang,
          builder: (_, __, ___) => body)));
  }
}

// ===========================================================================
// Build 6: collapsible dropdown — used for Personality + the 8 sections so
// the whole profile fits compactly on the Today page.
// ===========================================================================
class DropSection extends StatefulWidget {
  final String title;
  final Widget child;
  final bool open;
  final Color titleColor;
  const DropSection({super.key, required this.title, required this.child,
    this.open = false, this.titleColor = kGold});
  @override
  State<DropSection> createState() => _DropSectionState();
}

class _DropSectionState extends State<DropSection> {
  late bool _open = widget.open;

  @override
  Widget build(BuildContext context) => card(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Expanded(child: Text(widget.title,
              style: TextStyle(color: widget.titleColor, fontSize: 14,
                fontWeight: FontWeight.w800, letterSpacing: 0.5,
                fontFamily: urduFont))),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.expand_more, color: kMuted, size: 22)),
          ]))),
      AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity, height: 0),
        secondChild: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: widget.child),
        crossFadeState:
          _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 180)),
    ]));
}

// ===========================================================================
// Build 7: Personality + the 8 sections, each a collapsible dropdown. Details
// table and trait chips now live in SignHeaderCard above; this starts at
// Personality. Personality's heading uses the element accent colour (like the
// website .pers h3); the 8 sections stay gold.
// ===========================================================================
class SignReadings extends StatefulWidget {
  final ZSign sign;
  const SignReadings({super.key, required this.sign});
  @override
  State<SignReadings> createState() => _SignReadingsState();
}

class _SignReadingsState extends State<SignReadings> {
  Map<String, dynamic>? _all;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    loadProfiles().then((d) {
      if (mounted) setState(() { _all = d; _failed = d == null; });
    });
  }

  String lx(dynamic m) {
    if (m is Map) {
      return (m[currentLang.value.name] ?? m['en'] ?? '').toString();
    }
    return m == null ? '' : m.toString();
  }

  @override
  Widget build(BuildContext context) {
    final vedic = useVedic.value;
    final accent = elementColor(widget.sign.element);
    final sys = _all?[vedic ? 'vedic' : 'western'] as Map<String, dynamic>?;
    final sg = sys?['signs']?[widget.sign.key] as Map<String, dynamic>?;
    final rows = (sys?['rows'] ?? {}) as Map<String, dynamic>;
    final tabs = (sys?['tabs'] ?? {}) as Map<String, dynamic>;

    if (_failed) {
      return card(child: Text(tr('readingError'), textAlign: TextAlign.center,
        style: TextStyle(color: kMuted, fontSize: 14, height: 1.8,
          fontFamily: urduFont)));
    }
    if (sg == null) {
      return card(child: const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: SizedBox(width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 3, color: kPrimary)))));
    }

    final details = (sg['details'] ?? {}) as Map<String, dynamic>;
    const tabOrder = ['general', 'career', 'love', 'health',
      'gems', 'dark', 'family', 'karma'];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Personality — collapsible dropdown, heading in the element accent
      DropSection(
        title: lx(rows['personality']).toUpperCase(),
        titleColor: accent,
        child: Text(lx(sg['pers']),
          style: TextStyle(color: Colors.white, fontSize: 15,
            height: 1.9, fontFamily: urduFont))),
      // the 8 sections — each its own collapsible dropdown, General first
      ...tabOrder.map((t) => DropSection(
        title: lx(tabs[t]),
        child: Text(lx(details[t]),
          style: TextStyle(color: Colors.white, fontSize: 15,
            height: 1.95, fontFamily: urduFont)))),
    ]);
  }
}

// ===========================================================================
// Build 9: full-screen view of ONE sign, using the same header + readings as
// the Today page (consistent look). Opened by tapping a "best match" chip.
// ===========================================================================
class SignDetailScreen extends StatelessWidget {
  final ZSign sign;
  const SignDetailScreen({super.key, required this.sign});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: useVedic,
    builder: (_, __, ___) => Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          iconTheme: const IconThemeData(color: kGold),
          title: Text(signName(sign),
            style: TextStyle(color: kGold, fontSize: 18,
              fontWeight: FontWeight.w800, fontFamily: urduFont))),
        body: CenteredList(children: [
          SignHeaderCard(key: ValueKey('dh-${sign.key}'), sign: sign),
          SignReadings(key: ValueKey('dr-${sign.key}'), sign: sign),
        ]))));
}

// ===========================================================================
// Build 7: Date Calculator (leap-year aware) — ported 1:1 from the website's
// Zodiac / Rashi date calculator. Opened by the ⓘ next to the dates.
// ===========================================================================
const List<String> _lcMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const List<Map<String, dynamic>> _lcWestern = [
  {'sym': '♈', 'name': {'en': 'Aries', 'ur': 'حمل', 'hi': 'मेष', 'ar': 'الحمل'}, 'm': 3, 'd': 20},
  {'sym': '♉', 'name': {'en': 'Taurus', 'ur': 'ثور', 'hi': 'वृषभ', 'ar': 'الثور'}, 'm': 4, 'd': 20},
  {'sym': '♊', 'name': {'en': 'Gemini', 'ur': 'جوزا', 'hi': 'मिथुन', 'ar': 'الجوزاء'}, 'm': 5, 'd': 21},
  {'sym': '♋', 'name': {'en': 'Cancer', 'ur': 'سرطان', 'hi': 'कर्क', 'ar': 'السرطان'}, 'm': 6, 'd': 21},
  {'sym': '♌', 'name': {'en': 'Leo', 'ur': 'اسد', 'hi': 'सिंह', 'ar': 'الأسد'}, 'm': 7, 'd': 23},
  {'sym': '♍', 'name': {'en': 'Virgo', 'ur': 'سنبلہ', 'hi': 'कन्या', 'ar': 'العذراء'}, 'm': 8, 'd': 23},
  {'sym': '♎', 'name': {'en': 'Libra', 'ur': 'میزان', 'hi': 'तुला', 'ar': 'الميزان'}, 'm': 9, 'd': 23},
  {'sym': '♏', 'name': {'en': 'Scorpio', 'ur': 'عقرب', 'hi': 'वृश्चिक', 'ar': 'العقرب'}, 'm': 10, 'd': 23},
  {'sym': '♐', 'name': {'en': 'Sagittarius', 'ur': 'قوس', 'hi': 'धनु', 'ar': 'القوس'}, 'm': 11, 'd': 22},
  {'sym': '♑', 'name': {'en': 'Capricorn', 'ur': 'جدی', 'hi': 'मकर', 'ar': 'الجدي'}, 'm': 12, 'd': 22},
  {'sym': '♒', 'name': {'en': 'Aquarius', 'ur': 'دلو', 'hi': 'कुम्भ', 'ar': 'الدلو'}, 'm': 1, 'd': 20},
  {'sym': '♓', 'name': {'en': 'Pisces', 'ur': 'حوت', 'hi': 'मीन', 'ar': 'الحوت'}, 'm': 2, 'd': 19},
];

const List<Map<String, dynamic>> _lcVedic = [
  {'sym': '♈', 'name': {'en': 'Mesha (Aries)', 'ur': 'میش', 'hi': 'मेष', 'ar': 'ميشا'}, 'm': 4, 'd': 13},
  {'sym': '♉', 'name': {'en': 'Vrishabha (Taurus)', 'ur': 'ورشبھ', 'hi': 'वृषभ', 'ar': 'فريشابها'}, 'm': 5, 'd': 14},
  {'sym': '♊', 'name': {'en': 'Mithuna (Gemini)', 'ur': 'متھن', 'hi': 'मिथुन', 'ar': 'ميثونا'}, 'm': 6, 'd': 15},
  {'sym': '♋', 'name': {'en': 'Karka (Cancer)', 'ur': 'کرک', 'hi': 'कर्क', 'ar': 'كاركا'}, 'm': 7, 'd': 16},
  {'sym': '♌', 'name': {'en': 'Simha (Leo)', 'ur': 'سنہ', 'hi': 'सिंह', 'ar': 'سيمها'}, 'm': 8, 'd': 17},
  {'sym': '♍', 'name': {'en': 'Kanya (Virgo)', 'ur': 'کنیا', 'hi': 'कन्या', 'ar': 'كانيا'}, 'm': 9, 'd': 17},
  {'sym': '♎', 'name': {'en': 'Tula (Libra)', 'ur': 'تلا', 'hi': 'तुला', 'ar': 'تولا'}, 'm': 10, 'd': 17},
  {'sym': '♏', 'name': {'en': 'Vrischika (Scorpio)', 'ur': 'ورشچک', 'hi': 'वृश्चिक', 'ar': 'فريشتشيكا'}, 'm': 11, 'd': 16},
  {'sym': '♐', 'name': {'en': 'Dhanu (Sagittarius)', 'ur': 'دھنو', 'hi': 'धनु', 'ar': 'دانو'}, 'm': 12, 'd': 16},
  {'sym': '♑', 'name': {'en': 'Makara (Capricorn)', 'ur': 'مکر', 'hi': 'मकर', 'ar': 'ماكارا'}, 'm': 1, 'd': 14},
  {'sym': '♒', 'name': {'en': 'Kumbha (Aquarius)', 'ur': 'کمبھ', 'hi': 'कुम्भ', 'ar': 'كومبها'}, 'm': 2, 'd': 13},
  {'sym': '♓', 'name': {'en': 'Meena (Pisces)', 'ur': 'مین', 'hi': 'मीन', 'ar': 'مينا'}, 'm': 3, 'd': 14},
];

const Map<String, Map<String, String>> _lcT = {
  'wTitle': {'en': 'Zodiac Date Calculator', 'ur': 'برج تاریخ کیلکولیٹر', 'hi': 'राशि तिथि कैलकुलेटर', 'ar': 'حاسبة تواريخ الأبراج'},
  'vTitle': {'en': 'Rashi Date Calculator', 'ur': 'راشی تاریخ کیلکولیٹر', 'hi': 'राशि तिथि कैलकुलेटर', 'ar': 'حاسبة تواريخ الراشي'},
  'wIntro': {'en': 'Enter any year to see the Western (Tropical) sign dates and whether that year is leap or common.', 'ur': 'کوئی بھی سال درج کریں اور مغربی (Tropical) برجوں کی تاریخیں دیکھیں، ساتھ ہی یہ کہ وہ سال لیپ تھا یا عام۔', 'hi': 'कोई भी वर्ष दर्ज करें और पश्चिमी (सायन) राशि तिथियाँ देखें, साथ ही वह वर्ष लीप था या सामान्य।', 'ar': 'أدخل أيّ سنة لرؤية تواريخ الأبراج الغربية (المداريّة) وما إذا كانت السنة كبيسة أو عاديّة.'},
  'vIntro': {'en': 'Enter any year to see the Vedic (Sidereal / Lahiri) rashi dates and whether that year is leap or common.', 'ur': 'کوئی بھی سال درج کریں اور وید (Sidereal / لاہڑی) راشیوں کی تاریخیں دیکھیں، ساتھ ہی یہ کہ وہ سال لیپ تھا یا عام۔', 'hi': 'कोई भी वर्ष दर्ज करें और वैदिक (निरयन / लाहिड़ी) राशि तिथियाँ देखें, साथ ही वह वर्ष लीप था या सामान्य।', 'ar': 'أدخل أيّ سنة لرؤية تواريخ الراشي الفيدية (الفلكية / لاهيري) وما إذا كانت السنة كبيسة أو عاديّة.'},
  'yearLbl': {'en': 'Enter Year:', 'ur': 'سال درج کریں:', 'hi': 'वर्ष दर्ज करें:', 'ar': 'أدخل السنة:'},
  'calc': {'en': 'Calculate', 'ur': 'حساب لگائیں', 'hi': 'गणना करें', 'ar': 'احسب'},
  'backTop': {'en': '↑ Back to top', 'ur': '↑ اوپر جائیں', 'hi': '↑ ऊपर जाएँ', 'ar': '↑ العودة إلى الأعلى'},
  'leap': {'en': 'Leap Year — 366 days', 'ur': 'لیپ سال — ۳۶۶ دن', 'hi': 'लीप वर्ष — 366 दिन', 'ar': 'سنة كبيسة — ٣٦٦ يومًا'},
  'common': {'en': 'Common Year — 365 days', 'ur': 'عام سال — ۳۶۵ دن', 'hi': 'सामान्य वर्ष — 365 दिन', 'ar': 'سنة عاديّة — ٣٦٥ يومًا'},
  'thSign': {'en': 'Sign', 'ur': 'برج', 'hi': 'राशि', 'ar': 'البرج'},
  'thRashi': {'en': 'Rashi / Sign', 'ur': 'راشی / برج', 'hi': 'राशि', 'ar': 'الراشي / البرج'},
  'thStart': {'en': 'Start Date', 'ur': 'آغاز', 'hi': 'आरंभ तिथि', 'ar': 'تاريخ البدء'},
  'thEnd': {'en': 'End Date', 'ur': 'اختتام', 'hi': 'अंत तिथि', 'ar': 'تاريخ الانتهاء'},
  'exHead': {'en': 'Why do these dates shift?', 'ur': 'یہ تاریخیں کیوں بدلتی ہیں؟', 'hi': 'ये तिथियाँ क्यों बदलती हैं?', 'ar': 'لماذا تتغيّر هذه التواريخ؟'},
  'wExp': {'en': "Western (tropical) dates follow the Sun and the seasons — Aries always begins at the spring equinox. A solar year is about 365.2422 days, but the calendar uses 365, so the equinox drifts ~6 hours each year. The leap day every 4 years resets this, which is why a sign's start date bounces between, for example, March 19, 20 and 21.", 'ur': "مغربی (Tropical) تاریخیں سورج اور موسموں کے ساتھ چلتی ہیں — برجِ حمل ہمیشہ بہار کے اعتدال (Equinox) پر شروع ہوتا ہے۔ شمسی سال تقریباً ۳۶۵.۲۴۲۲ دن کا ہے مگر کیلنڈر ۳۶۵ دن کا، اِس لیے ہر سال تقریباً ۶ گھنٹے کا فرق آ جاتا ہے۔ ہر ۴ سال بعد لیپ کا دن اِسے درست کر دیتا ہے، اِسی لیے کسی برج کی ابتدائی تاریخ مثلاً ۱۹، ۲۰ اور ۲۱ مارچ کے درمیان بدلتی رہتی ہے۔", 'hi': "पश्चिमी (सायन) तिथियाँ सूर्य और ऋतुओं का अनुसरण करती हैं — मेष सदा वसंत विषुव (Equinox) पर आरंभ होता है। सौर वर्ष लगभग 365.2422 दिन का है, पर कैलेंडर 365 दिन का, इसलिए हर वर्ष लगभग 6 घंटे का अंतर आता है। हर 4 वर्ष में लीप दिवस इसे संतुलित कर देता है, इसीलिए किसी राशि की आरंभ तिथि उदाहरणतः 19, 20 और 21 मार्च के बीच बदलती रहती है।", 'ar': "تتبع التواريخ الغربية (المداريّة) الشمس والفصول — يبدأ الحمل دائمًا عند الاعتدال الربيعيّ. السنة الشمسيّة نحو ٣٦٥.٢٤٢٢ يومًا لكنّ التقويم يعتمد ٣٦٥، فينزاح الاعتدال ~٦ ساعات سنويًّا. واليوم الكبيس كلّ ٤ سنوات يصحّح ذلك، ولهذا يتنقّل تاريخ بدء البرج بين ١٩ و٢٠ و٢١ مارس مثلًا."},
  'vExp': {'en': "Vedic (sidereal) dates are measured against the fixed stars. Because Earth slowly wobbles on its axis — the precession of the equinoxes — the alignment drifts about 50.3 arcseconds a year, roughly one full day every 72 years. This steady shift (the ayanamsa) is why the rashi dates move gradually forward across the decades. Leap days still nudge each individual year by a day.", 'ur': "وید (Sidereal) تاریخیں ثابت ستاروں کے مقابلے میں ناپی جاتی ہیں۔ زمین اپنے محور پر آہستہ لرزتی ہے — Precession of Equinoxes — جس سے ہر سال زاویہ تقریباً ۵۰.۳ آرک سیکنڈ بدلتا ہے، یعنی ہر ۷۲ سال میں تقریباً ۱ پورا دن۔ یہی مستقل فرق (ایانامسا) دہائیوں میں راشی تاریخوں کو آہستہ آگے لے جاتا ہے۔ لیپ کے دن ہر سال کو ایک دن آگے پیچھے بھی کرتے ہیں۔", 'hi': "वैदिक (निरयन) तिथियाँ स्थिर तारों के सापेक्ष मापी जाती हैं। पृथ्वी अपने अक्ष पर धीरे डगमगाती है — विषुवों का अयन (Precession) — जिससे संरेखण प्रति वर्ष लगभग 50.3 आर्कसेकंड खिसकता है, यानी हर 72 वर्ष में लगभग 1 पूरा दिन। यही निरंतर बदलाव (अयनांश) दशकों में राशि तिथियों को धीरे आगे ले जाता है। लीप दिवस प्रत्येक वर्ष को एक दिन और भी खिसकाते हैं।", 'ar': "تُقاس التواريخ الفيدية (الفلكية) بالنسبة إلى النجوم الثابتة. ولأنّ الأرض تترنّح ببطء حول محورها — مبادرة الاعتدالين — ينزاح المحاذاة نحو ٥٠.٣ ثانية قوسيّة سنويًّا، أي يومًا كاملًا كلّ ٧٢ سنة تقريبًا. هذا الانزياح الثابت (الأيانامسا) هو سبب تقدّم تواريخ الراشي تدريجيًّا عبر العقود. وما تزال الأيام الكبيسة تزحزح كلّ سنة بيوم."},
};

class DateCalculatorScreen extends StatefulWidget {
  final bool vedic;
  const DateCalculatorScreen({super.key, required this.vedic});
  @override
  State<DateCalculatorScreen> createState() => _DateCalculatorScreenState();
}

class _DateCalculatorScreenState extends State<DateCalculatorScreen> {
  late final TextEditingController _yc;
  final ScrollController _sc = ScrollController();
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _yc = TextEditingController(text: '$_year');
  }

  @override
  void dispose() { _yc.dispose(); _sc.dispose(); super.dispose(); }

  void _toTop() => _sc.animateTo(0,
    duration: const Duration(milliseconds: 350), curve: Curves.easeOut);

  // Real image icon for each sign (same /app/icons/ files the rest of the app
  // uses) — NOT a unicode glyph, so it looks identical on every device.
  Widget _signIcon(int i) => CachedNetworkImage(
    imageUrl: signSymbolUrl(i, vedic: widget.vedic),
    width: 22, height: 22, fit: BoxFit.contain,
    placeholder: (_, __) => const SizedBox(width: 22, height: 22),
    errorWidget: (_, __, ___) => Text(signs[i].symbol,
      style: const TextStyle(color: kGold, fontSize: 15)));

  bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  int _westShift(int year) {
    int cycle = (year - 2000) % 4; if (cycle < 0) cycle += 4;
    int shift = 0;
    if (cycle == 0) { shift = -1; } else if (cycle == 3) { shift = 1; }
    shift += ((year - 2000) / 100).floor() - ((year - 2000) / 400).floor();
    return shift;
  }

  int _vedShift(int year) => ((year - 2000) / 72).floor();

  String _fmt(int m, int d) {
    const back = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    const fwd  = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    while (d < 1) { m--; if (m < 1) m = 12; d += back[m - 1]; }
    int dim = fwd[m - 1];
    while (d > dim) { d -= dim; m++; if (m > 12) m = 1; dim = fwd[m - 1]; }
    return '${_lcMonths[m - 1]} $d';
  }

  void _calc() {
    final v = int.tryParse(_yc.text.trim());
    if (v == null) return;
    final y = v < 1 ? 1 : (v > 3000 ? 3000 : v);
    setState(() => _year = y);
    FocusScope.of(context).unfocus();
  }

  String _stripB(String s) => s.replaceAll('<b>', '').replaceAll('</b>', '');

  Widget _cell(Widget child, {int flex = 1, Alignment? align}) => Expanded(
    flex: flex, child: Align(
      alignment: align ??
        (rtl ? Alignment.centerRight : Alignment.centerLeft), child: child));

  @override
  Widget build(BuildContext context) {
    final ved = widget.vedic;
    final lang = currentLang.value.name;
    String t(String k) => _lcT[k]?[lang] ?? _lcT[k]?['en'] ?? '';
    final signs = ved ? _lcVedic : _lcWestern;
    final leap = _isLeap(_year);

    // header row
    final tableRows = <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: const BoxDecoration(color: kCard),
        child: Row(children: [
          _cell(Text(ved ? t('thRashi') : t('thSign'),
            style: TextStyle(color: kLight, fontSize: 12.5,
              fontWeight: FontWeight.w700, fontFamily: urduFont)), flex: 5),
          _cell(Text(t('thStart'),
            style: TextStyle(color: kLight, fontSize: 12.5,
              fontWeight: FontWeight.w700, fontFamily: urduFont)), flex: 4),
          _cell(Text(t('thEnd'),
            style: TextStyle(color: kLight, fontSize: 12.5,
              fontWeight: FontWeight.w700, fontFamily: urduFont)), flex: 4),
        ])),
    ];
    for (int i = 0; i < signs.length; i++) {
      final s = signs[i];
      final ns = signs[(i + 1) % signs.length];
      final sm = s['m'] as int, sd = s['d'] as int;
      final nm = ns['m'] as int, nd = ns['d'] as int;
      final sh = ved ? _vedShift(_year) : _westShift(_year);
      final startStr = _fmt(sm, sd + sh);
      final endStr = _fmt(nm, nd + sh - 1);
      final endYear = (sm >= nm) ? _year + 1 : _year;
      final nameMap = s['name'] as Map<String, dynamic>;
      final nm2 = (nameMap[lang] ?? nameMap['en']).toString();
      tableRows.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: i.isEven ? kBg : Colors.transparent,
          border: const Border(top: BorderSide(color: kBorder, width: 0.6))),
        child: Row(children: [
          _cell(Row(mainAxisSize: MainAxisSize.min, children: [
            _signIcon(i),
            const SizedBox(width: 8),
            Flexible(child: Text(nm2,
              style: TextStyle(color: kOn, fontSize: 13,
                fontWeight: FontWeight.w700, fontFamily: urduFont))),
          ]), flex: 5),
          _cell(Text('$startStr, $_year',
            style: const TextStyle(color: kMuted, fontSize: 12.5)), flex: 4),
          _cell(Text('$endStr, $endYear',
            style: const TextStyle(color: kMuted, fontSize: 12.5)), flex: 4),
        ])));
    }

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          iconTheme: const IconThemeData(color: kGold),
          title: Text(ved ? t('vTitle') : t('wTitle'),
            style: TextStyle(color: kGold, fontSize: 18,
              fontWeight: FontWeight.w800, fontFamily: urduFont))),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            controller: _sc,
            padding: EdgeInsets.fromLTRB(18, 12, 18,
              28 + MediaQuery.of(context).viewPadding.bottom),
            children: [
              Text(ved ? t('vIntro') : t('wIntro'),
                style: TextStyle(color: kMuted, fontSize: 13.5, height: 1.7,
                  fontFamily: urduFont)),
              const SizedBox(height: 16),
              Row(children: [
                Text(t('yearLbl'),
                  style: TextStyle(color: kOn, fontSize: 14,
                    fontWeight: FontWeight.w600, fontFamily: urduFont)),
                const SizedBox(width: 10),
                SizedBox(width: 100, child: TextField(
                  controller: _yc,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kOn, fontSize: 15,
                    fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true, filled: true, fillColor: kCard,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBorder)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kPrimary))),
                  onSubmitted: (_) => _calc())),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 13)),
                  onPressed: _calc,
                  child: Text(t('calc'),
                    style: TextStyle(fontWeight: FontWeight.w700,
                      fontFamily: urduFont))),
              ]),
              const SizedBox(height: 16),
              // leap / common badge
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      (leap ? elementColor('earth') : kGold).withOpacity(0.16),
                      kCard),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color:
                      (leap ? elementColor('earth') : kGold).withOpacity(0.5))),
                  child: Text('$_year — ${leap ? t('leap') : t('common')}',
                    style: TextStyle(
                      color: leap ? elementColor('earth') : kGold,
                      fontSize: 13, fontWeight: FontWeight.w700,
                      fontFamily: urduFont)))),
              const SizedBox(height: 16),
              // dates table
              ClipRRect(borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorder)),
                  child: Column(children: tableRows))),
              const SizedBox(height: 20),
              // explanation
              Text(t('exHead'),
                style: TextStyle(color: kLight, fontSize: 15,
                  fontWeight: FontWeight.w800, fontFamily: urduFont)),
              const SizedBox(height: 8),
              Text(_stripB(ved ? t('vExp') : t('wExp')),
                style: TextStyle(color: kOn, fontSize: 13.5, height: 1.85,
                  fontFamily: urduFont)),
              const SizedBox(height: 22),
              Center(child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kLight,
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99))),
                onPressed: _toTop,
                child: Text(t('backTop'),
                  style: TextStyle(fontWeight: FontWeight.w700,
                    fontFamily: urduFont)))),
            ])))));
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
                    SignIcon(i, size: 44),
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
              SignArt(sign),
              const SizedBox(height: 10),
              Center(child: Text(
                '${sign.name[lang] ?? sign.name[AppLang.en]!}  ·  ${sign.vname[lang] ?? sign.vname[AppLang.en]!}',
                style: TextStyle(color: kOn, fontSize: 22,
                  fontWeight: FontWeight.w800, fontFamily: urduFont))),
              const SizedBox(height: 14),
              _sheetRow(tr('western'), sign.westDates),
              _sheetRow(tr('vedic'), sign.vedicDates),
              _sheetRow(tr('element'), tr(sign.element)),
              _sheetRow(tr('planet'),
                sign.planet[lang] ?? sign.planet[AppLang.en]!),
              const SizedBox(height: 14),
              Text(sign.trait[lang] ?? sign.trait[AppLang.en]!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15.5, height: 1.9,
                  fontFamily: urduFont)),
              const SizedBox(height: 14),
              // Build 4: poori LIVE reading yahin sheet ke andar
              DailyReadingCard(
                key: ValueKey('sheet-${sign.key}-${currentLang.value.name}'),
                sign: sign),
              const SizedBox(height: 4),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProfileScreen(sign: sign)));
                },
                icon: const Icon(Icons.auto_stories, size: 18),
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
                  SignIcon(i, size: 30),
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
        idx != null
          ? SignIcon(idx, size: 46)
          : const Text('＋',
              style: TextStyle(fontSize: 40, color: kMuted)),
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
          Text('${signName(signs[_a!])}  +  ${signName(signs[_b!])}',
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
