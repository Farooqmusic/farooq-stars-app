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
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      LiveSkyTab(), TodayTab(), ZodiacTab(), MatchTab(), MoreTab(),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: [
        // Build 12: new Live Sky "Today" tab in front; the perfected sign
        // tab is now "Zodiac". The old sign grid stays for now (removed later).
        NavigationDestination(icon: const Icon(Icons.auto_awesome), label: tr('today')),
        NavigationDestination(icon: const Icon(Icons.brightness_7), label: tr('zodiac')),
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
      // Western = Sun, Vedic = Moon — the app's own planet icons.
      Widget half(String label, String iconUrl, bool sel, VoidCallback tap) =>
        Expanded(
          child: GestureDetector(onTap: tap, child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? kPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, children: [
                CachedNetworkImage(imageUrl: iconUrl, width: 18, height: 18,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox.shrink()),
                const SizedBox(width: 7),
                Text(label, textAlign: TextAlign.center,
                  style: TextStyle(color: sel ? Colors.white : kMuted,
                    fontWeight: FontWeight.w700, fontSize: 13.5)),
              ]))));
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: kCard,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kBorder)),
        child: Row(children: [
          half(tr('western'), '$kWebsite/app/planet-icons-v2/sun.png',
            !vedic, () {
            useVedic.value = false;
            prefs.setBool('useVedic', false);
          }),
          half(tr('vedic'), '$kWebsite/app/planet-icons-v2/moon.png',
            vedic, () {
            useVedic.value = true;
            prefs.setBool('useVedic', true);
          }),
        ]));
    });
}

// ===========================================================================
// Build 12: LIVE SKY — native port of the website's client-side astronomy
// (Keplerian planet positions + truncated lunar series + Rahu Kaal). Verified
// against the site: same formulas & constants, so it produces identical
// Sun/Moon signs, moon phase, retrogrades and Rahu Kaal times — offline, no
// WebView. Powers the new Today tab.
// ===========================================================================
const double _d2r = math.pi / 180, _r2d = 180 / math.pi;
double _norm(double d) => ((d % 360) + 360) % 360;

double _julianDay(int y, int m, int d, double hour) {
  if (m <= 2) { y -= 1; m += 12; }
  final a = (y / 100).floor(), b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() +
    d + b - 1524.5 + hour / 24;
}

// Keplerian orbital elements: [base(6), rate-per-century(6)]
const Map<String, List<List<double>>> _elem = {
  'mercury': [[0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593], [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]],
  'venus': [[0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255], [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]],
  'earth': [[1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0], [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]],
  'mars': [[1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891], [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]],
  'jupiter': [[5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909], [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]],
  'saturn': [[9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448], [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]],
  'uranus': [[19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503], [-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589]],
  'neptune': [[30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574], [0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664]],
  'pluto': [[39.48211675, 0.24882730, 17.14001206, 238.92903833, 224.06891629, 110.30393684], [-0.00031596, 0.00005170, 0.00004818, 145.20780515, -0.04062942, -0.01183482]],
};

List<double> _helioXY(String name, double t) {
  final a = _elem[name]!, v = a[0], r = a[1];
  final sa = v[0] + r[0] * t, e = v[1] + r[1] * t, inc = (v[2] + r[2] * t) * _d2r,
    l = v[3] + r[3] * t, peri = v[4] + r[4] * t, nodeD = v[5] + r[5] * t,
    node = nodeD * _d2r, w = (peri - nodeD) * _d2r;
  double m = _norm(l - peri); if (m > 180) m -= 360; m *= _d2r;
  double ecc = m + e * math.sin(m);
  for (int i = 0; i < 8; i++) {
    final de = (ecc - e * math.sin(ecc) - m) / (1 - e * math.cos(ecc));
    ecc -= de; if (de.abs() < 1e-9) break;
  }
  final xp = sa * (math.cos(ecc) - e), yp = sa * math.sqrt(1 - e * e) * math.sin(ecc);
  final cw = math.cos(w), sw = math.sin(w), cn = math.cos(node), sn = math.sin(node),
    ci = math.cos(inc);
  return [(cw * cn - sw * sn * ci) * xp + (-sw * cn - cw * sn * ci) * yp,
          (cw * sn + sw * cn * ci) * xp + (-sw * sn + cw * cn * ci) * yp];
}

double _precession(double t) => (5028.796195 * t + 1.1054348 * t * t) / 3600;
double _planetLon(String name, double t) {
  final p = _helioXY(name, t), ex = _helioXY('earth', t);
  return _norm(math.atan2(p[1] - ex[1], p[0] - ex[0]) * _r2d + _precession(t));
}
double _sunLon(double t) {
  final ex = _helioXY('earth', t);
  return _norm(math.atan2(-ex[1], -ex[0]) * _r2d + _precession(t));
}

// Truncated lunar longitude series: [D, M, M', F, coeff]
const List<List<int>> _moonTerms = [
  [0,0,1,0,6288774],[2,0,-1,0,1274027],[2,0,0,0,658314],[0,0,2,0,213618],
  [0,1,0,0,-185116],[0,0,0,2,-114332],[2,0,-2,0,58793],[2,-1,-1,0,57066],
  [2,0,1,0,53322],[2,-1,0,0,45758],[0,1,-1,0,-40923],[1,0,0,0,-34720],
  [0,1,1,0,-30383],[2,0,0,-2,15327],[0,0,1,2,-12528],[0,0,1,-2,10980],
  [4,0,-1,0,10675],[0,0,3,0,10034],[4,0,-2,0,8548],[2,1,-1,0,-7888],
  [2,1,0,0,-6766],[1,0,-1,0,-5163],[1,1,0,0,4987],[2,-1,1,0,4036],
  [2,0,2,0,3994],[4,0,0,0,3861],[2,0,-3,0,3665],[0,1,-2,0,-2689],
  [2,0,-1,2,-2602],[2,-1,-2,0,2390],[1,0,1,0,-2348],[2,-2,0,0,2236],
  [0,1,2,0,-2120],[0,2,0,0,-2069],[2,-2,-1,0,2048],
];
double _moonLon(double t) {
  final lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t + t * t * t / 538841 - t * t * t * t / 65194000;
  final dm = 297.8501921 + 445267.1114034 * t - 0.0018819 * t * t + t * t * t / 545868 - t * t * t * t / 113065000;
  final mm = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t + t * t * t / 24490000;
  final mp = 134.9633964 + 477198.8675055 * t + 0.0087414 * t * t + t * t * t / 69699 - t * t * t * t / 14712000;
  final f = 93.2720950 + 483202.0175233 * t - 0.0036539 * t * t - t * t * t / 3526000 + t * t * t * t / 863310000;
  final ec = 1 - 0.002516 * t - 0.0000074 * t * t;
  double s = 0;
  for (final term in _moonTerms) {
    final arg = (term[0] * dm + term[1] * mm + term[2] * mp + term[3] * f) * _d2r;
    double co = term[4].toDouble();
    if (term[1].abs() == 1) { co *= ec; } else if (term[1].abs() == 2) { co *= ec * ec; }
    s += co * math.sin(arg);
  }
  return _norm(lp + s / 1000000);
}

double _ayanamsa(double jd) {
  final y = 2000.0 + (jd - 2451545.0) / 365.25;
  return 23.85 + (y - 2000) * 0.013969;
}
double _rahuLon(double t) => _norm(125.0445479 - 1934.1362891 * t +
  0.0020754 * t * t + t * t * t / 467410);
double _obliquity(double t) => 23.439291 - 0.0130042 * t -
  0.00000016 * t * t + 0.000000504 * t * t * t;
// Ascendant + Midheaven for a given instant and observer location.
List<double> _anglesOf(double jd, double lonE, double lat) {
  final t = (jd - 2451545.0) / 36525;
  final gmst = _norm(280.46061837 + 360.98564736629 * (jd - 2451545.0) +
    0.000387933 * t * t - t * t * t / 38710000);
  final lst = _norm(gmst + lonE), ramc = lst * _d2r,
    eps = _obliquity(t) * _d2r, phi = lat * _d2r;
  double asc = _norm(math.atan2(math.cos(ramc),
    -(math.sin(ramc) * math.cos(eps) + math.tan(phi) * math.sin(eps))) * _r2d);
  if (_norm(asc - lst) > 180) asc = _norm(asc + 180);
  double mc = _norm(math.atan2(math.sin(ramc),
    math.cos(ramc) * math.cos(eps)) * _r2d);
  final off = _norm(mc - lst);
  if (off > 90 && off < 270) mc = _norm(mc + 180);
  return [asc, mc];
}
double _lonAt(String name, double t) {
  switch (name) {
    case 'Sun': return _sunLon(t);
    case 'Moon': return _moonLon(t);
    case 'Rahu': return _rahuLon(t);
    case 'Ketu': return _norm(_rahuLon(t) + 180);
    default: return _planetLon(name.toLowerCase(), t);
  }
}
double _motionOf(String name, double t) {
  final a = _lonAt(name, t), b = _lonAt(name, t + 1 / 36525);
  return ((b - a + 540) % 360) - 180;
}

// planets that can retrograde, with the mean-motion divisor used for the fade
const Map<String, double> _retroDiv = {
  'mercury': 1.3, 'venus': 0.62, 'mars': 0.4, 'jupiter': 0.14, 'saturn': 0.085,
};

class LiveSky {
  final int sunW, moonW, sunV, moonV, illum;
  final bool waxing;
  final List<String> retro;
  const LiveSky(this.sunW, this.moonW, this.sunV, this.moonV, this.illum,
    this.waxing, this.retro);
}

LiveSky computeSky(DateTime u) {
  final jd = _julianDay(u.year, u.month, u.day,
    u.hour + u.minute / 60 + u.second / 3600);
  final t = (jd - 2451545.0) / 36525, ay = _ayanamsa(jd);
  final sunL = _sunLon(t), moonL = _moonLon(t);
  final retro = <String>[];
  _retroDiv.forEach((k, div) {
    final m = _motionOf(k, t);
    final rr = m < 0 ? math.min(1.0, (-m) / div) : 0.0;
    if (rr > 0.45) retro.add(k);
  });
  final elong = _norm(moonL - sunL);
  final illum = ((1 - math.cos(elong * _d2r)) / 2 * 100).round();
  return LiveSky(
    (_norm(sunL) / 30).floor(), (_norm(moonL) / 30).floor(),
    (_norm(sunL - ay) / 30).floor(), (_norm(moonL - ay) / 30).floor(),
    illum, elong < 180, retro);
}

// ---- Rahu Kaal ----
const List<Map<String, dynamic>> _cities = [
  {'n':'Doha','c':'QA','lat':25.29,'lon':51.53,'tz':3.0},
  {'n':'Dubai','c':'AE','lat':25.2,'lon':55.27,'tz':4.0},
  {'n':'Abu Dhabi','c':'AE','lat':24.45,'lon':54.38,'tz':4.0},
  {'n':'Riyadh','c':'SA','lat':24.71,'lon':46.68,'tz':3.0},
  {'n':'Manama','c':'BH','lat':26.23,'lon':50.59,'tz':3.0},
  {'n':'Kuwait City','c':'KW','lat':29.38,'lon':47.99,'tz':3.0},
  {'n':'Muscat','c':'OM','lat':23.59,'lon':58.41,'tz':4.0},
  {'n':'Baghdad','c':'IQ','lat':33.31,'lon':44.36,'tz':3.0},
  {'n':'Tehran','c':'IR','lat':35.69,'lon':51.39,'tz':3.5},
  {'n':'Karachi','c':'PK','lat':24.86,'lon':67.01,'tz':5.0},
  {'n':'Lahore','c':'PK','lat':31.55,'lon':74.34,'tz':5.0},
  {'n':'Delhi','c':'IN','lat':28.61,'lon':77.21,'tz':5.5},
  {'n':'Mumbai','c':'IN','lat':19.08,'lon':72.88,'tz':5.5},
  {'n':'Dhaka','c':'BD','lat':23.81,'lon':90.41,'tz':6.0},
  {'n':'Colombo','c':'LK','lat':6.93,'lon':79.86,'tz':5.5},
  {'n':'Kathmandu','c':'NP','lat':27.72,'lon':85.32,'tz':5.75},
  {'n':'Istanbul','c':'TR','lat':41.01,'lon':28.98,'tz':3.0},
  {'n':'Cairo','c':'EG','lat':30.04,'lon':31.24,'tz':2.0},
  {'n':'London','c':'GB','lat':51.51,'lon':-0.13,'tz':0.0},
  {'n':'Paris','c':'FR','lat':48.86,'lon':2.35,'tz':1.0},
  {'n':'New York','c':'US','lat':40.71,'lon':-74.01,'tz':-5.0},
  {'n':'Los Angeles','c':'US','lat':34.05,'lon':-118.24,'tz':-8.0},
  {'n':'Toronto','c':'CA','lat':43.65,'lon':-79.38,'tz':-5.0},
  {'n':'Singapore','c':'SG','lat':1.35,'lon':103.82,'tz':8.0},
  {'n':'Sydney','c':'AU','lat':-33.87,'lon':151.21,'tz':11.0},
];
const List<int> _rkPart = [8, 2, 7, 5, 6, 4, 3]; // Sun..Sat
const List<String> _dowNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday',
  'Thursday', 'Friday', 'Saturday'];

Map<String, dynamic> _pickCity() {
  final off = DateTime.now().timeZoneOffset.inMinutes / 60.0;
  for (final c in _cities) {
    if ((c['tz'] as num).toDouble() == off) return c;
  }
  return _cities[0]; // default Doha
}

String _flag(String cc) {
  if (cc.length != 2) return '';
  return String.fromCharCodes(
    cc.toUpperCase().codeUnits.map((c) => 127397 + c));
}

String _hm(double h) {
  int hh = h.floor();
  int mm = ((h - hh) * 60).round();
  if (mm == 60) { hh++; mm = 0; }
  hh = ((hh % 24) + 24) % 24;
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

class RahuInfo {
  final bool ok;
  final String start, end, rise, sunsetStr, city, flag;
  final int dow;
  const RahuInfo({required this.ok, this.start = '', this.end = '',
    this.rise = '', this.sunsetStr = '', this.city = '', this.flag = '',
    this.dow = 0});
}

RahuInfo computeRahu(DateTime local) {
  final city = _pickCity();
  final y = local.year, mo = local.month, d = local.day;
  final dow = DateTime(y, mo, d).weekday % 7; // Dart Mon=1..Sun=7 -> Sun=0..Sat=6
  final lat = (city['lat'] as num).toDouble(),
    lon = (city['lon'] as num).toDouble(), tz = (city['tz'] as num).toDouble();
  final n = (_julianDay(y, mo, d, 12) - 2451545.0).round();
  final jstar = n - lon / 360;
  final mDeg = ((357.5291 + 0.98560028 * jstar) % 360 + 360) % 360, mr = mDeg * _d2r;
  final c = 1.9148 * math.sin(mr) + 0.0200 * math.sin(2 * mr) + 0.0003 * math.sin(3 * mr);
  final lam = ((mDeg + c + 180 + 102.9372) % 360 + 360) % 360, lamr = lam * _d2r;
  final jt = 2451545.0 + jstar + 0.0053 * math.sin(mr) - 0.0069 * math.sin(2 * lamr);
  final sinDec = math.sin(lamr) * math.sin(23.4397 * _d2r), dec = math.asin(sinDec);
  final cosw = (math.sin(-0.833 * _d2r) - math.sin(lat * _d2r) * sinDec) /
    (math.cos(lat * _d2r) * math.cos(dec));
  if (cosw > 1 || cosw < -1) return const RahuInfo(ok: false);
  final w0 = math.acos(cosw) * _r2d;
  double toL(double j) { final u = ((j + 0.5) % 1) * 24, l = u + tz; return ((l % 24) + 24) % 24; }
  final rise = toL(jt - w0 / 360), setH = toL(jt + w0 / 360);
  final p = (setH - rise) / 8, part = _rkPart[dow];
  return RahuInfo(ok: true, start: _hm(rise + (part - 1) * p),
    end: _hm(rise + part * p), rise: _hm(rise), sunsetStr: _hm(setH),
    city: city['n'] as String, flag: _flag(city['c'] as String), dow: dow);
}

// small localisation for the Live Sky cards
const Map<String, Map<AppLang, String>> _skyWords = {
  'sun': {AppLang.en: 'Sun', AppLang.ur: 'سورج', AppLang.hi: 'सूर्य', AppLang.ar: 'الشمس'},
  'moon': {AppLang.en: 'Moon', AppLang.ur: 'چاند', AppLang.hi: 'चंद्र', AppLang.ar: 'القمر'},
  'wax': {AppLang.en: 'Waxing', AppLang.ur: 'بڑھتا', AppLang.hi: 'बढ़ता', AppLang.ar: 'متزايد'},
  'wan': {AppLang.en: 'Waning', AppLang.ur: 'گھٹتا', AppLang.hi: 'घटता', AppLang.ar: 'متناقص'},
  'retro': {AppLang.en: 'Retrograde', AppLang.ur: 'رجعت', AppLang.hi: 'वक्री', AppLang.ar: 'تراجع'},
  'rahu': {AppLang.en: 'Rahu Kaal', AppLang.ur: 'راہو کال', AppLang.hi: 'राहु काल', AppLang.ar: 'راهو كال'},
  'sunrise': {AppLang.en: 'sunrise', AppLang.ur: 'طلوع', AppLang.hi: 'सूर्योदय', AppLang.ar: 'الشروق'},
  'sunset': {AppLang.en: 'sunset', AppLang.ur: 'غروب', AppLang.hi: 'सूर्यास्त', AppLang.ar: 'الغروب'},
};
const Map<String, Map<AppLang, String>> _skyEyebrow = {
  'west': {AppLang.en: 'WESTERN · LIVE SKY', AppLang.ur: 'مغربی · لائیو اسکائی', AppLang.hi: 'पश्चिमी · लाइव स्काई', AppLang.ar: 'غربي · السماء الحية'},
  'ved': {AppLang.en: 'VEDIC · LIVE SKY', AppLang.ur: 'ویدک · لائیو اسکائی', AppLang.hi: 'वैदिक · लाइव स्काई', AppLang.ar: 'فيدي · السماء الحية'},
};
const Map<String, Map<AppLang, String>> _planetNamesLive = {
  'mercury': {AppLang.en: 'Mercury', AppLang.ur: 'عطارد', AppLang.hi: 'बुध', AppLang.ar: 'عطارد'},
  'venus': {AppLang.en: 'Venus', AppLang.ur: 'زہرہ', AppLang.hi: 'शुक्र', AppLang.ar: 'الزهرة'},
  'mars': {AppLang.en: 'Mars', AppLang.ur: 'مریخ', AppLang.hi: 'मंगल', AppLang.ar: 'المريخ'},
  'jupiter': {AppLang.en: 'Jupiter', AppLang.ur: 'مشتری', AppLang.hi: 'बृहस्पति', AppLang.ar: 'المشتري'},
  'saturn': {AppLang.en: 'Saturn', AppLang.ur: 'زحل', AppLang.hi: 'शनि', AppLang.ar: 'زحل'},
};

// ===========================================================================
// Build 13: in-app web view — hosts the big Live Sky charts (circle + box +
// Ascendant) and the calendars page inside the app.
// ===========================================================================
class WebViewScreen extends StatefulWidget {
  final String url, title;
  const WebViewScreen({super.key, required this.url, required this.title});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _c;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kBg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _loading = false); }))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg, elevation: 0,
        iconTheme: const IconThemeData(color: kGold),
        actions: [
          IconButton(icon: const Icon(Icons.open_in_new, color: kGold, size: 20),
            tooltip: 'Open in browser',
            onPressed: () => openUrl(widget.url)),
        ],
        title: Text(widget.title,
          style: TextStyle(color: kGold, fontSize: 18,
            fontWeight: FontWeight.w800, fontFamily: urduFont))),
      body: Stack(children: [
        WebViewWidget(controller: _c),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: kPrimary)),
      ])));
}

// ===========================================================================
// Build 13: "today's reading" quick access. Sun -> 12 Western signs, Moon ->
// 12 Vedic rashis; pick one and read only TODAY's reading (same source as the
// Zodiac tab) without going into the Zodiac tab.
// ===========================================================================
class DailyPickerScreen extends StatelessWidget {
  final bool vedic;
  const DailyPickerScreen({super.key, required this.vedic});

  @override
  Widget build(BuildContext context) {
    final l = currentLang.value;
    final title = vedic
      ? {AppLang.en: 'Moon · Today\'s Reading', AppLang.ur: 'چاند · آج کی reading', AppLang.hi: 'चंद्र · आज की reading', AppLang.ar: 'القمر · قراءة اليوم'}[l]!
      : {AppLang.en: 'Sun · Today\'s Reading', AppLang.ur: 'سورج · آج کی reading', AppLang.hi: 'सूर्य · आज की reading', AppLang.ar: 'الشمس · قراءة اليوم'}[l]!;
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          iconTheme: const IconThemeData(color: kGold),
          title: Text(title, style: TextStyle(color: kGold, fontSize: 17,
            fontWeight: FontWeight.w800, fontFamily: urduFont))),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LayoutBuilder(builder: (_, box) {
            final cols = (box.maxWidth / 170).floor().clamp(2, 5);
            return GridView.builder(
              padding: EdgeInsets.fromLTRB(20, 16, 20,
                24 + MediaQuery.of(context).viewPadding.bottom),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols, mainAxisSpacing: 12,
                crossAxisSpacing: 12, childAspectRatio: 1.02),
              itemCount: signs.length,
              itemBuilder: (ctx, i) {
                final name = vedic
                  ? (signs[i].vname[l] ?? signs[i].vname[AppLang.en]!)
                  : (signs[i].name[l] ?? signs[i].name[AppLang.en]!);
                return GestureDetector(
                  onTap: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => DailyReadingScreen(
                      sign: signs[i], vedic: vedic))),
                  child: Container(
                    decoration: BoxDecoration(color: kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kBorder)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl: signSymbolUrl(i, vedic: vedic),
                          width: 44, height: 44, fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Text(signs[i].symbol,
                            style: const TextStyle(fontSize: 34, color: kGold))),
                        const SizedBox(height: 6),
                        Text(name, style: TextStyle(color: kOn, fontSize: 15,
                          fontWeight: FontWeight.w700, fontFamily: urduFont)),
                      ])));
              });
          })))));
  }
}

class DailyReadingScreen extends StatelessWidget {
  final ZSign sign;
  final bool vedic;
  const DailyReadingScreen({super.key, required this.sign, required this.vedic});

  @override
  Widget build(BuildContext context) {
    final l = currentLang.value;
    final name = vedic
      ? (sign.vname[l] ?? sign.vname[AppLang.en]!)
      : (sign.name[l] ?? sign.name[AppLang.en]!);
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          iconTheme: const IconThemeData(color: kGold),
          title: Text(name, style: TextStyle(color: kGold, fontSize: 18,
            fontWeight: FontWeight.w800, fontFamily: urduFont))),
        body: CenteredList(children: [
          DailyReadingCard(
            key: ValueKey('daily-${sign.key}-${currentLang.value.name}'),
            sign: sign, dailyOnly: true),
        ])));
  }
}

// ===========================================================================
// Build 15: full NATIVE Live Sky — real planet positions + Ascendant/Lagna
// drawn as a zodiac wheel and a detail box, Western (tropical) & Vedic
// (sidereal). Location = timezone city (Doha for the user); GPS comes next.
// ===========================================================================
const List<String> _livePlanets = ['Sun', 'Moon', 'Mercury', 'Venus', 'Mars',
  'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto', 'Rahu', 'Ketu'];
const Map<String, String> _livePlanetIcon = {
  'Sun': 'sun.png', 'Moon': 'moon.png', 'Mercury': 'mercury.png',
  'Venus': 'venus.png', 'Mars': 'mars.png', 'Jupiter': 'jupiter.png',
  'Saturn': 'saturn.png', 'Uranus': 'uranus.png', 'Neptune': 'neptune.png',
  'Pluto': 'pluto.png', 'Rahu': 'rahu.png', 'Ketu': 'ketu.png',
};
const Map<String, Color> _livePlanetColor = {
  'Sun': Color(0xFFf0a93c), 'Moon': Color(0xFF6aa3e0), 'Mercury': Color(0xFF2bc5ad),
  'Venus': Color(0xFFe85fad), 'Mars': Color(0xFFff6b54), 'Jupiter': Color(0xFFf0aa3c),
  'Saturn': Color(0xFFd8c084), 'Uranus': Color(0xFF7fd4e0), 'Neptune': Color(0xFF45c0c0),
  'Pluto': Color(0xFFb576e0), 'Rahu': Color(0xFFa3b3c0), 'Ketu': Color(0xFFcf9a6a),
};
const List<String> _signAbbr = ['Ari', 'Tau', 'Gem', 'Cnc', 'Leo', 'Vir',
  'Lib', 'Sco', 'Sag', 'Cap', 'Aqr', 'Psc'];

String _fmtDeg(double lon) {
  final x = _norm(lon) % 30;
  final d = x.floor(), m = ((x - d) * 60).floor();
  return "$d°${m.toString().padLeft(2, '0')}'";
}

class LiveBody {
  final String key;
  final double lon;
  final bool retro;
  final int sign, house;
  const LiveBody(this.key, this.lon, this.retro, this.sign, this.house);
}

class LiveChart {
  final double asc, mc;
  final int ascSign;
  final List<LiveBody> bodies;
  const LiveChart(this.asc, this.mc, this.ascSign, this.bodies);
}

LiveChart computeChart(DateTime utc, double lat, double lonE, bool vedic) {
  final jd = _julianDay(utc.year, utc.month, utc.day,
    utc.hour + utc.minute / 60 + utc.second / 3600);
  final t = (jd - 2451545.0) / 36525, ay = _ayanamsa(jd);
  final ang = _anglesOf(jd, lonE, lat);
  double asc = ang[0], mc = ang[1];
  if (vedic) { asc = _norm(asc - ay); mc = _norm(mc - ay); }
  final ascSign = (_norm(asc) / 30).floor();
  final bodies = <LiveBody>[];
  for (final k in _livePlanets) {
    double tl = _lonAt(k, t);
    if (vedic) tl = _norm(tl - ay);
    bool retro = false;
    if (k != 'Sun' && k != 'Moon' && k != 'Rahu' && k != 'Ketu') {
      double b = _lonAt(k, t + 1 / 36525);
      if (vedic) b = _norm(b - ay);
      retro = (((b - tl + 540) % 360) - 180) < 0;
    }
    final sign = (_norm(tl) / 30).floor();
    final house = ((sign - ascSign) % 12 + 12) % 12 + 1;
    bodies.add(LiveBody(k, _norm(tl), retro, sign, house));
  }
  return LiveChart(_norm(asc), _norm(mc), ascSign, bodies);
}

class _Placed {
  final LiveBody body;
  final Offset pos;
  const _Placed(this.body, this.pos);
}

class _WheelPainter extends CustomPainter {
  final LiveChart chart;
  _WheelPainter(this.chart);

  Offset _pos(double lon, double r, double c) {
    final a = (180 + (lon - chart.asc)) * _d2r;
    return Offset(c + r * math.cos(a), c - r * math.sin(a));
  }

  void _label(Canvas cv, String s, Offset at, Color col, double fs, FontWeight w) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs, fontWeight: w)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(cv, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas cv, Size size) {
    final c = size.width / 2;
    final rOut = size.width / 2 - 20, rIn = rOut - 24;
    final rHouse = rIn - 22;
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2
      ..color = const Color(0xFF4a3866);
    cv.drawCircle(Offset(c, c), rOut, ring);
    cv.drawCircle(Offset(c, c), rIn, ring);
    cv.drawCircle(Offset(c, c), rHouse,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1
        ..color = const Color(0x33c77dff));
    // 360° graduated ring — tiny ticks on the inner edge for a subtle degree
    // dial. Minor tick every 1°, a slightly longer/brighter one every 10°.
    for (int d = 0; d < 360; d++) {
      final bool major = d % 10 == 0;
      final double len = major ? 5.0 : 2.5;
      cv.drawLine(_pos(d.toDouble(), rIn - len, c), _pos(d.toDouble(), rIn, c),
        Paint()
          ..color = major ? const Color(0x66c77dff) : const Color(0x2bc77dff)
          ..strokeWidth = major ? 1.0 : 0.6);
    }
    for (int i = 0; i < 12; i++) {
      final bl = i * 30.0;
      cv.drawLine(_pos(bl, rIn, c), _pos(bl, rOut, c),
        Paint()..color = const Color(0xFF4a3866)..strokeWidth = 1);
      _label(cv, _signAbbr[i], _pos(i * 30.0 + 15, (rIn + rOut) / 2, c),
        elementColor(signs[i].element), 11.5, FontWeight.w700);
      // whole-sign house number (house 1 = Ascendant's sign)
      final hn = ((i - chart.ascSign) % 12 + 12) % 12 + 1;
      _label(cv, '$hn', _pos(i * 30.0 + 15, rHouse - 11, c),
        kMuted, 9.5, FontWeight.w700);
    }
    // Axis cross — horizon (ASC–DESC) and meridian (MC–IC)
    final desc = _norm(chart.asc + 180), ic = _norm(chart.mc + 180);
    cv.drawLine(_pos(chart.asc, rIn, c), _pos(desc, rIn, c),
      Paint()..color = kGold.withOpacity(0.45)..strokeWidth = 1.4);
    cv.drawLine(_pos(chart.mc, rIn, c), _pos(ic, rIn, c),
      Paint()..color = kLight.withOpacity(0.45)..strokeWidth = 1.4);
    void axisMark(double lon, String s, Color col) {
      cv.drawLine(_pos(lon, rIn - 3, c), _pos(lon, rOut + 2, c),
        Paint()..color = col..strokeWidth = 2.4);
      _label(cv, s, _pos(lon, rOut + 10, c), col, 9, FontWeight.w800);
    }
    axisMark(chart.asc, 'ASC', kGold);
    axisMark(desc, 'DESC', kGold.withOpacity(0.75));
    axisMark(chart.mc, 'MC', kLight);
    axisMark(ic, 'IC', kLight.withOpacity(0.75));
    cv.drawCircle(Offset(c, c), 2.5, Paint()..color = kGold);
  }

  @override
  bool shouldRepaint(_WheelPainter o) => true;
}

class LiveSkyScreen extends StatefulWidget {
  final bool vedic;
  const LiveSkyScreen({super.key, required this.vedic});
  @override
  State<LiveSkyScreen> createState() => _LiveSkyScreenState();
}

class _LiveSkyScreenState extends State<LiveSkyScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60),
      (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Widget _planetChip(LiveBody b) {
    // Uniform planet size on the wheel (close to the clean table look), with
    // the Sun a touch bigger. Retrograde planets get a soft magenta glow
    // behind the icon (retroglow.png), replacing the old small red dot.
    final bool isSun = b.key == 'Sun';
    final double icon = isSun ? 28 : 22;
    final double glow = icon + 14;
    return SizedBox(width: 40, height: 40,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        if (b.retro) CachedNetworkImage(
          imageUrl: '$kWebsite/app/planet-icons-v2/retroglow.png',
          width: glow, height: glow, fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const SizedBox.shrink()),
        CachedNetworkImage(
          imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[b.key]}',
          width: icon, height: icon, fit: BoxFit.contain,
          errorWidget: (_, __, ___) => Container(
            width: icon - 4, height: icon - 4,
            decoration: BoxDecoration(
              color: _livePlanetColor[b.key], shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(b.key[0],
              style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w800)))),
      ]));
  }

  Widget _wheel(LiveChart chart) => LayoutBuilder(builder: (_, box) {
    final sz = math.min(box.maxWidth, 360.0);
    final c = sz / 2, rP = sz / 2 - 74;
    final radii = [rP, rP - 20, rP - 40];
    final sorted = [...chart.bodies]..sort((a, b) => a.lon.compareTo(b.lon));
    final placed = <_Placed>[];
    double prev = -999; int ri = 0;
    for (final b in sorted) {
      double dd = (b.lon - prev).abs(); if (dd > 180) dd = 360 - dd;
      ri = dd < 12 ? (ri + 1) % radii.length : 0;
      prev = b.lon;
      final a = (180 + (b.lon - chart.asc)) * _d2r;
      final r = radii[ri];
      placed.add(_Placed(b, Offset(c + r * math.cos(a), c - r * math.sin(a))));
    }
    return Center(child: SizedBox(width: sz, height: sz, child: Stack(children: [
      CustomPaint(size: Size(sz, sz), painter: _WheelPainter(chart)),
      ...placed.map((p) => Positioned(
        left: p.pos.dx - 20, top: p.pos.dy - 20, child: _planetChip(p.body))),
    ])));
  });

  Widget _boxRow(LiveBody b, AppLang l) {
    final signName = signs[b.sign].name[l] ?? signs[b.sign].name[AppLang.en]!;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        CachedNetworkImage(
          imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[b.key]}',
          width: 20, height: 20, fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 20)),
        const SizedBox(width: 10),
        Expanded(child: Text(b.key,
          style: const TextStyle(color: kOn, fontSize: 14,
            fontWeight: FontWeight.w700))),
        if (b.retro) ...[
          const Text('R', style: TextStyle(color: Colors.redAccent,
            fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
        ],
        Text('$signName ${_fmtDeg(b.lon)}',
          style: TextStyle(color: kMuted, fontSize: 13,
            fontWeight: FontWeight.w600, fontFamily: urduFont)),
        const SizedBox(width: 8),
        Text('H${b.house}', style: const TextStyle(color: kLight,
          fontSize: 12, fontWeight: FontWeight.w700)),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    final l = currentLang.value;
    final city = _pickCity();
    final lat = (city['lat'] as num).toDouble();
    final lonE = (city['lon'] as num).toDouble();
    final chart = computeChart(DateTime.now().toUtc(), lat, lonE, widget.vedic);
    final ascWord = widget.vedic
      ? {AppLang.en: 'Lagna', AppLang.ur: 'لگنا', AppLang.hi: 'लग्न', AppLang.ar: 'الطالع'}[l]!
      : {AppLang.en: 'Ascendant', AppLang.ur: 'طالع', AppLang.hi: 'लग्न', AppLang.ar: 'الطالع'}[l]!;
    final ascSignName = signs[chart.ascSign].name[l] ?? signs[chart.ascSign].name[AppLang.en]!;
    final title = widget.vedic
      ? {AppLang.en: 'Vedic — Live Sky', AppLang.ur: 'ویدک — لائیو اسکائی', AppLang.hi: 'वैदिक — लाइव स्काई', AppLang.ar: 'فيدي — السماء الحية'}[l]!
      : {AppLang.en: 'Western — Live Sky', AppLang.ur: 'مغربی — لائیو اسکائی', AppLang.hi: 'पश्चिमी — लाइव स्काई', AppLang.ar: 'غربي — السماء الحية'}[l]!;

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg, elevation: 0,
          iconTheme: const IconThemeData(color: kGold),
          title: Text(title, style: TextStyle(color: kGold, fontSize: 17,
            fontWeight: FontWeight.w800, fontFamily: urduFont))),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
              28 + MediaQuery.of(context).viewPadding.bottom),
            children: [
              _wheel(chart),
              const SizedBox(height: 8),
              Center(child: Text('${city['n']}  ${_flag(city['c'] as String)}',
                style: const TextStyle(color: kMuted, fontSize: 12.5,
                  fontWeight: FontWeight.w600))),
              const SizedBox(height: 14),
              card(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Icon(Icons.arrow_upward, color: kGold, size: 18),
                    const SizedBox(width: 6),
                    Text('$ascWord: ',
                      style: TextStyle(color: kGold, fontSize: 14.5,
                        fontWeight: FontWeight.w800, fontFamily: urduFont)),
                    Text('$ascSignName ${_fmtDeg(chart.asc)}',
                      style: const TextStyle(color: kOn, fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                  ]),
                  const Divider(color: kBorder, height: 20),
                  ...chart.bodies.map((b) => _boxRow(b, l)),
                ])),
            ])))));
  }
}

// ===========================================================================
// NEW Today tab — Live Sky (Western + Vedic) and Rahu Kaal, refreshed live.
// ===========================================================================
class LiveSkyTab extends StatefulWidget {
  const LiveSkyTab({super.key});
  @override
  State<LiveSkyTab> createState() => _LiveSkyTabState();
}

class _LiveSkyTabState extends State<LiveSkyTab> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60),
      (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String _bodyLine(String bodyKey, String signName, AppLang l) {
    final w = _skyWords[bodyKey]![l]!;
    switch (l) {
      case AppLang.en: return '$w in $signName';
      case AppLang.ar: return '$w في $signName';
      case AppLang.ur: return '$w $signName میں';
      case AppLang.hi: return '$w $signName में';
    }
  }

  Widget _liveIcon(String file) => CachedNetworkImage(
    imageUrl: '$kWebsite/app/planet-icons-v2/$file',
    width: 18, height: 18, fit: BoxFit.contain,
    errorWidget: (_, __, ___) => const SizedBox(width: 18, height: 18));

  Widget _skyCard(bool vedic, LiveSky s) {
    final l = currentLang.value;
    final sunIdx = vedic ? s.sunV : s.sunW;
    final moonIdx = vedic ? s.moonV : s.moonW;
    final sunName = signs[sunIdx].name[l] ?? signs[sunIdx].name[AppLang.en]!;
    final moonName = signs[moonIdx].name[l] ?? signs[moonIdx].name[AppLang.en]!;
    final phase = s.waxing ? _skyWords['wax']![l]! : _skyWords['wan']![l]!;
    final retroStr = s.retro
      .map((k) => _planetNamesLive[k]?[l] ?? k).join('، ');
    return GestureDetector(
      // Build 15: opens the NATIVE Live Sky (wheel + Ascendant + box).
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => LiveSkyScreen(vedic: vedic))),
      child: card(child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(_skyEyebrow[vedic ? 'ved' : 'west']![l]!,
            style: TextStyle(color: kGold, fontSize: 11.5,
              fontWeight: FontWeight.w800, letterSpacing: 1.4,
              fontFamily: urduFont)),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment:
            WrapCrossAlignment.center, spacing: 14, runSpacing: 8, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _liveIcon('sun.png'), const SizedBox(width: 6),
              Text(_bodyLine('sun', sunName, l),
                style: const TextStyle(color: kOn, fontSize: 15.5,
                  fontWeight: FontWeight.w700)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _liveIcon('moon.png'), const SizedBox(width: 6),
              Text(_bodyLine('moon', moonName, l),
                style: const TextStyle(color: kOn, fontSize: 15.5,
                  fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 8),
          Text(
            '— $phase ${s.illum}%'
            '${retroStr.isNotEmpty ? '  ·  $retroStr ${_skyWords['retro']![l]!}' : ''}',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 13, height: 1.5,
              fontWeight: FontWeight.w600, fontFamily: urduFont)),
        ])));
  }

  Widget _rahuBar(RahuInfo r, AppLang l) {
    if (!r.ok) return const SizedBox.shrink();
    return card(child: Column(crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('☾', style: TextStyle(color: kGold, fontSize: 17)),
          const SizedBox(width: 7),
          Text(_skyWords['rahu']![l]!,
            style: TextStyle(color: kGold, fontSize: 14.5,
              fontWeight: FontWeight.w800, fontFamily: urduFont)),
          const SizedBox(width: 10),
          Text('${r.start} – ${r.end}',
            style: const TextStyle(color: kLight, fontSize: 14.5,
              fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 7),
        Text(
          '${_dowNames[r.dow]}  ·  ${_skyWords['sunrise']![l]!} ${r.rise}'
          '  ·  ${_skyWords['sunset']![l]!} ${r.sunsetStr}',
          textAlign: TextAlign.center,
          style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.5,
            fontWeight: FontWeight.w600, fontFamily: urduFont)),
        const SizedBox(height: 4),
        Text('${r.city} ${r.flag}',
          style: const TextStyle(color: kOn, fontSize: 13,
            fontWeight: FontWeight.w700)),
      ]));
  }

  // Item 4: Sun / Moon "today's reading" split card.
  Widget _dailyCard() {
    final l = currentLang.value;
    final sunLabel = {AppLang.en: "Sun\nToday's Reading", AppLang.ur: 'سورج\nآج کی reading', AppLang.hi: 'सूर्य\nआज की reading', AppLang.ar: 'الشمس\nقراءة اليوم'}[l]!;
    final moonLabel = {AppLang.en: "Moon\nToday's Reading", AppLang.ur: 'چاند\nآج کی reading', AppLang.hi: 'चंद्र\nआज की reading', AppLang.ar: 'القمر\nقراءة اليوم'}[l]!;
    Widget half(String file, String label, bool vedic) => Expanded(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DailyPickerScreen(vedic: vedic))),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CachedNetworkImage(
              imageUrl: '$kWebsite/app/planet-icons-v2/$file',
              width: 34, height: 34, fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox(width: 34, height: 34)),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: kOn, fontSize: 13, height: 1.4,
                fontWeight: FontWeight.w700, fontFamily: urduFont)),
          ]))));
    return card(padding: EdgeInsets.zero,
      child: IntrinsicHeight(child: Row(children: [
        half('sun.png', sunLabel, false),
        Container(width: 1, color: kBorder),
        half('moon.png', moonLabel, true),
      ])));
  }

  // Item 5: Calendars (opens the site's calendars page in-app).
  Widget _calendarCard() {
    final l = currentLang.value;
    final label = {AppLang.en: 'World Calendars', AppLang.ur: 'کیلنڈرز', AppLang.hi: 'कैलेंडर', AppLang.ar: 'التقاويم'}[l]!;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => WebViewScreen(
          url: '$kWebsite/farooq-calendars.html', title: label))),
      child: card(child: Row(children: [
        const Text('🗓️', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
          style: TextStyle(color: kOn, fontSize: 16,
            fontWeight: FontWeight.w800, fontFamily: urduFont))),
        const Icon(Icons.chevron_right, color: kMuted),
      ])));
  }

  @override
  Widget build(BuildContext context) {
    final l = currentLang.value;
    final sky = computeSky(DateTime.now().toUtc());
    final rahu = computeRahu(DateTime.now());
    return CenteredList(children: [
      Padding(padding: const EdgeInsets.only(bottom: 14),
        child: Text(todayLine(), textAlign: TextAlign.center,
          style: TextStyle(color: kGold, fontSize: 15,
            fontWeight: FontWeight.w700, fontFamily: urduFont))),
      _skyCard(false, sky),   // 1 · Western Live Sky
      _skyCard(true, sky),    // 2 · Vedic Live Sky
      _rahuBar(rahu, l),      // 3 · Rahu Kaal
      _dailyCard(),           // 4 · Sun / Moon today's reading
      _calendarCard(),        // 5 · Calendars
    ]);
  }
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
    final rows = (sys?['rows'] ?? <String, dynamic>{}) as Map<String, dynamic>;

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
  final bool dailyOnly; // Build 13: lock to Today, hide the period pills
  const DailyReadingCard({super.key, required this.sign, this.dailyOnly = false});
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

  // Build 10: share the CURRENT reading (daily/weekly/monthly/yearly) straight
  // to WhatsApp — sign name, its qualities, the reading, and our web + app
  // links. Works the same in Western and Vedic, for every sign.
  Future<void> _shareWhatsApp() async {
    final sign = widget.sign;
    final vedic = useVedic.value;
    final lang = currentLang.value;

    // qualities/traits from the profiles json (already cached after first load)
    String qualities = '';
    final all = await loadProfiles();
    final sys = all?[vedic ? 'vedic' : 'western'] as Map<String, dynamic>?;
    final sg = sys?['signs']?[sign.key] as Map<String, dynamic>?;
    if (sg != null) {
      final tf = sg['traits'];
      final ts = (tf is Map ? (tf[lang.name] ?? tf['en'] ?? '') : (tf ?? ''))
        .toString();
      qualities = ts.split('·').map((e) => e.trim())
        .where((e) => e.isNotEmpty).join(' · ');
    }

    final name = vedic
      ? '${sign.vname[lang] ?? sign.vname[AppLang.en]!}'
        ' (${sign.name[lang] ?? sign.name[AppLang.en]!})'
      : (sign.name[lang] ?? sign.name[AppLang.en]!);
    final dates = vedic ? sign.vedicDates : sign.westDates;
    final web = vedic
      ? '$kWebsite/farooq-now-vedic.html'
      : '$kWebsite/farooq-now-western.html';

    final buf = StringBuffer()
      ..writeln('✨ Farooq Stars ✨')
      ..writeln('$name  •  $dates');
    if (qualities.isNotEmpty) buf.writeln(qualities);
    buf
      ..writeln('')
      ..writeln('🔮 ${tr('p_$_period')} — ${tr('dailyReading')}')
      ..writeln(_text ?? '')
      ..writeln('')
      ..writeln('🌐 $web')
      ..writeln('📲 Farooq Stars: $kWebsite');
    final text = buf.toString();

    // Attach the big sign artwork on top of the message, then let the user
    // pick WhatsApp. If the image can't be fetched, fall back to a text-only
    // WhatsApp share via wa.me.
    try {
      final i = signs.indexOf(sign);
      final resp = await http.get(Uri.parse(signBigArtUrl(i)))
        .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final f = File('${Directory.systemTemp.path}/farooq_${sign.key}.png');
        await f.writeAsBytes(resp.bodyBytes);
        await Share.shareXFiles([XFile(f.path)], text: text);
        return;
      }
    } catch (_) {/* fall through to text-only */}
    // wa.me opens WhatsApp directly (app if installed, else web WhatsApp).
    await openUrl('https://wa.me/?text=${Uri.encodeComponent(text)}');
  }

  @override
  Widget build(BuildContext context) {
    final vedic = useVedic.value;
    final url = vedic
      ? '$kWebsite/farooq-now-vedic.html'
      : '$kWebsite/farooq-now-western.html';
    final shareLabel = {
      AppLang.en: 'Share on WhatsApp',
      AppLang.ur: 'واٹس ایپ پر شیئر کریں',
      AppLang.hi: 'WhatsApp पर शेयर करें',
      AppLang.ar: 'مشاركة على واتساب',
    }[currentLang.value] ?? 'Share on WhatsApp';
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
        // Period selector — Today / Week / Month / Year (hidden when dailyOnly)
        if (!widget.dailyOnly) ...[
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
        ],
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
        // Share the current reading on WhatsApp — only once it has loaded.
        if (!_loading && !_error && _text != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(vertical: 12)),
            onPressed: _shareWhatsApp,
            icon: const Icon(Icons.chat, size: 18, color: Colors.white),
            label: Text(shareLabel,
              style: TextStyle(fontWeight: FontWeight.w700,
                color: Colors.white, fontFamily: urduFont))),
        ],
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
    final rows = (sys?['rows'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final tabs = (sys?['tabs'] ?? <String, dynamic>{}) as Map<String, dynamic>;
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
      final details = (sg['details'] ?? <String, dynamic>{}) as Map<String, dynamic>;
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
    final rows = (sys?['rows'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final tabs = (sys?['tabs'] ?? <String, dynamic>{}) as Map<String, dynamic>;

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

    final details = (sg['details'] ?? <String, dynamic>{}) as Map<String, dynamic>;
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
