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
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
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
// Chart plate — the purple disc/panel the wheel & box sit on. Matches the
// farooqstars.com Live-Sky pages (SVG disc fill #221436, box border #6b5a8a).
const kPlate       = Color(0xFF221436);
const kPlateBorder = Color(0xFF6b5a8a);
// Per-system accent — Western = gold (sun), Vedic = purple (moon). Mirrors the
// website's --violet variable: #e0a73a on farooq-western, #9a6fe0 on
// farooq-vedic. Used to theme the Birth Chart screen by the chosen system.
const kAccentW = Color(0xFFe0a73a); // Western gold accent
const kAccentV = Color(0xFF9a6fe0); // Vedic purple accent
Color accentColor(bool vedic) => vedic ? kAccentV : kAccentW;
// Nakshatra ring text on the Vedic wheel — sky-blue, matching the website
// (farooq-now-vedic SVG fill:#7cc0f0).
const kNak = Color(0xFF7cc0f0);

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
  tzdata.initializeTimeZones(); // IANA tz db for DST-correct birth times
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
  'birthTab':   {AppLang.en: 'Birth', AppLang.ur: 'پیدائش', AppLang.hi: 'जन्म', AppLang.ar: 'الميلاد'},
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
      LiveSkyTab(), TodayTab(), BirthChartTab(), MatchTab(), MoreTab(),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: [
        // Build 12: new Live Sky "Today" tab in front; the perfected sign
        // tab is now "Zodiac". The old sign grid stays for now (removed later).
        NavigationDestination(icon: const Icon(Icons.auto_awesome), label: tr('today')),
        NavigationDestination(icon: const Icon(Icons.brightness_7), label: tr('zodiac')),
        NavigationDestination(icon: const Icon(Icons.pie_chart_outline), label: tr('birthTab')),
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
            onPressed: () => openUrl(kWebsite)),
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
// 27 nakshatras from 0° sidereal Aries. Long compound names are abbreviated
// like the website (U.Phalguni, P.Ashadha, U.Bhadra …).
const List<String> _nakshatras = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
  'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'P.Phalguni', 'U.Phalguni',
  'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha', 'Jyeshtha', 'Mula',
  'P.Ashadha', 'U.Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha',
  'P.Bhadra', 'U.Bhadra', 'Revati',
];
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
  final bool vedic;
  final int? houseRefSign; // House 1 sign for numbering (null = Ascendant)
  _WheelPainter(this.chart, {this.vedic = false, this.houseRefSign});

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
    final rOut = size.width / 2 - (vedic ? 34.0 : 20.0), rIn = rOut - 24;
    final rHouse = rIn - 22;
    // Purple chart plate behind the whole wheel — matches the website disc
    // (SVG <circle fill="#221436">). Draw first so everything sits on top.
    cv.drawCircle(Offset(c, c), c - 2, Paint()..color = kPlate);
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
      // Sign SYMBOL icons are drawn as widgets in _wheel() (vedic-aware:
      // zsymbol*.png for Western, hzsymbol*.png for Vedic rashis), so the old
      // text abbreviations (Ari/Tau/…) are no longer painted here.
      // whole-sign house number (house 1 = Ascendant's sign)
      final h1s = houseRefSign ?? chart.ascSign;
      final hn = ((i - h1s) % 12 + 12) % 12 + 1;
      _label(cv, '$hn', _pos(i * 30.0 + 15, rHouse - 11, c),
        elementColor(signs[i].element), 9.5, FontWeight.w700);
    }
    // Vedic only: 27-nakshatra ring in the outer band, names rotated tangentially.
    if (vedic) {
      final rNakOut = size.width / 2 - 6;
      final rNakLbl = (rOut + rNakOut) / 2;
      cv.drawCircle(Offset(c, c), rNakOut,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 1
          ..color = const Color(0x33c77dff));
      const step = 360.0 / 27.0;
      for (int n = 0; n < 27; n++) {
        cv.drawLine(_pos(n * step, rOut, c), _pos(n * step, rNakOut, c),
          Paint()..color = const Color(0x334a3866)..strokeWidth = 0.7);
        final pos = _pos(n * step + step / 2, rNakLbl, c);
        double rot = math.atan2(pos.dy - c, pos.dx - c) + math.pi / 2;
        if (rot > math.pi / 2) rot -= math.pi;
        if (rot < -math.pi / 2) rot += math.pi;
        final tp = TextPainter(
          text: TextSpan(text: _nakshatras[n],
            style: const TextStyle(color: kNak, fontSize: 7,
              fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)..layout();
        cv.save();
        cv.translate(pos.dx, pos.dy);
        cv.rotate(rot);
        tp.paint(cv, Offset(-tp.width / 2, -tp.height / 2));
        cv.restore();
      }
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

// North-Indian square chart frame: outer square + both diagonals + the
// mid-point diamond. Together these carve the 12 houses. House content
// (sign + planets) is placed as widgets in _box().
class _BoxPainter extends CustomPainter {
  @override
  void paint(Canvas cv, Size size) {
    final s = size.width;
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2
      ..color = const Color(0xFF4a3866);
    // Purple chart plate + brighter outer border — matches the website box
    // (SVG <rect fill="#221436" stroke="#6b5a8a">).
    cv.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = kPlate);
    cv.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 1.4..color = kPlateBorder);
    cv.drawLine(const Offset(0, 0), Offset(s, s), p);
    cv.drawLine(Offset(s, 0), Offset(0, s), p);
    cv.drawPath(Path()
      ..moveTo(s / 2, 0)..lineTo(s, s / 2)..lineTo(s / 2, s)..lineTo(0, s / 2)
      ..close(), p);
  }
  @override
  bool shouldRepaint(_BoxPainter o) => false;
}

// ---------------------------------------------------------------------------
// Reusable chart renderer — the round wheel and the North-Indian box, both
// painted with _WheelPainter / _BoxPainter. Shared by the Live Sky (transit)
// screen and the Birth Chart tab (natal), so the drawing lives in ONE place.
// ---------------------------------------------------------------------------
class NatalChartView extends StatelessWidget {
  final LiveChart chart;
  final bool vedic;
  final bool boxMode;
  final int? selSign;    // box: sign that becomes House 1 (null = Ascendant's sign)
  final int? houseRefSign; // House-1 sign for numbering (Sun/Moon/Asc); overrides selSign
  final String ascWord;  // "Ascendant" / "Lagna" label for the box pill
  final Color pillColor; // box ascendant-pill accent (gold for Live Sky)
  final bool showDeg;    // show planet degrees (false for divisional charts)
  const NatalChartView({super.key, required this.chart, required this.vedic,
    this.boxMode = false, this.selSign, this.houseRefSign, this.ascWord = 'Asc',
    this.pillColor = kGold, this.showDeg = true});

  Widget _planetChip(LiveBody b) {
    // Uniform planet size on the wheel (Sun a touch bigger). Retrograde planets
    // get a soft magenta glow behind the icon (retroglow.png).
    final bool isSun = b.key == 'Sun';
    final double icon = isSun ? 28 : 22;
    final double glow = icon + 14;
    return SizedBox(width: 40, height: 44,
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
        Positioned(bottom: 0, child: Text(
          '${(b.lon % 30).floor()}°',
          style: const TextStyle(color: kLight, fontSize: 8.5,
            fontWeight: FontWeight.w800))),
      ]));
  }

  Widget _wheel() => LayoutBuilder(builder: (_, box) {
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
    final signR = sz / 2 - (vedic ? 46.0 : 32.0); // matches painter ring
    return Center(child: SizedBox(width: sz, height: sz, child: Stack(children: [
      CustomPaint(size: Size(sz, sz),
        painter: _WheelPainter(chart, vedic: vedic, houseRefSign: houseRefSign)),
      // Sign symbol icons around the ring (Western zodiac / Vedic rashi).
      ...List.generate(12, (i) {
        final a = (180 + (i * 30.0 + 15 - chart.asc)) * _d2r;
        final pos = Offset(c + signR * math.cos(a), c - signR * math.sin(a));
        return Positioned(
          left: pos.dx - 11, top: pos.dy - 11,
          child: CachedNetworkImage(
            imageUrl: signSymbolUrl(i, vedic: vedic),
            width: 22, height: 22, fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const SizedBox(width: 22, height: 22)));
      }),
      ...placed.map((p) => Positioned(
        left: p.pos.dx - 20, top: p.pos.dy - 22, child: _planetChip(p.body))),
    ])));
  });

  // House-content centres for the North-Indian square (unit square, top-left
  // origin), index 0 = House 1 … index 11 = House 12.
  static const List<List<double>> _houseC = [
    [0.50, 0.26], [0.26, 0.14], [0.14, 0.26], [0.28, 0.50],
    [0.14, 0.74], [0.26, 0.86], [0.50, 0.74], [0.74, 0.86],
    [0.86, 0.74], [0.72, 0.50], [0.86, 0.26], [0.74, 0.14],
  ];
  Widget _boxPlanet(LiveBody b) => SizedBox(width: 26,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 26, height: 26,
        child: Stack(alignment: Alignment.center, children: [
          if (b.retro) CachedNetworkImage(
            imageUrl: '$kWebsite/app/planet-icons-v2/retroglow.png',
            width: 26, height: 26, fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const SizedBox.shrink()),
          CachedNetworkImage(
            imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[b.key]}',
            width: 20, height: 20, fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 20)),
        ])),
      if (showDeg) Text('${(b.lon % 30).floor()}°',
        style: const TextStyle(color: kMuted, fontSize: 7.5,
          fontWeight: FontWeight.w700)),
    ]));
  Widget _boxHouse(int h, int signIdx, List<LiveBody> here) => Column(
    mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$h', style: TextStyle(
          color: elementColor(signs[signIdx].element),
          fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(width: 3),
        CachedNetworkImage(
          imageUrl: signSymbolUrl(signIdx, vedic: vedic),
          width: 22, height: 22, fit: BoxFit.contain,
          errorWidget: (_, __, ___) => const SizedBox(width: 22, height: 22)),
      ]),
      if (here.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
        child: Wrap(spacing: 2, runSpacing: 1, alignment: WrapAlignment.center,
          children: here.map(_boxPlanet).toList())),
    ]);
  // House 1 = the tapped sign (selSign) or, if none, the Ascendant's sign;
  // the rest settle around it (whole-sign houses).
  Widget _box() => LayoutBuilder(builder: (_, box) {
    final sz = math.min(box.maxWidth, 360.0);
    final h1 = houseRefSign ?? selSign ?? chart.ascSign;
    final kids = <Widget>[
      CustomPaint(size: Size(sz, sz), painter: _BoxPainter()),
    ];
    for (int h = 1; h <= 12; h++) {
      final signIdx = (h1 + h - 1) % 12;
      final here = chart.bodies.where((b) =>
        ((b.sign - h1) % 12 + 12) % 12 + 1 == h).toList();
      final cx = _houseC[h - 1][0] * sz, cy = _houseC[h - 1][1] * sz;
      kids.add(Positioned(
        left: cx - 44, top: cy - 36, width: 88, height: 72,
        child: Center(child: FittedBox(fit: BoxFit.scaleDown,
          child: _boxHouse(h, signIdx, here)))));
    }
    // Ascendant / Lagna pill — placed in the house that currently holds the
    // Ascendant, so it MOVES as the chart changes (not fixed), like the site.
    final ascHouse = ((chart.ascSign - h1) % 12 + 12) % 12 + 1;
    final acx = _houseC[ascHouse - 1][0] * sz, acy = _houseC[ascHouse - 1][1] * sz;
    kids.add(Positioned(
      left: acx - 54, top: (acy - 46).clamp(0.0, sz - 20).toDouble(), width: 108,
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pillColor, width: 1.3)),
        child: Text('$ascWord ${_fmtDeg(chart.asc)}',
          maxLines: 1,
          style: TextStyle(color: pillColor, fontSize: 10,
            fontWeight: FontWeight.w800))))));
    return Center(child: SizedBox(width: sz, height: sz,
      child: Stack(children: kids)));
  });

  @override
  Widget build(BuildContext context) => boxMode ? _box() : _wheel();
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

  Widget _boxRow(LiveBody b, AppLang l) {
    final signName = signs[b.sign].name[l] ?? signs[b.sign].name[AppLang.en]!;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        // Planet icon with a magenta retro glow behind it when retrograde.
        SizedBox(width: 28, height: 28, child: Stack(
          clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (b.retro) CachedNetworkImage(
              imageUrl: '$kWebsite/app/planet-icons-v2/retroglow.png',
              width: 26, height: 26, fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox.shrink()),
            CachedNetworkImage(
              imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[b.key]}',
              width: 20, height: 20, fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 20)),
          ])),
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

  // ±90-day time travel for the whole sky. The astronomy already takes a
  // DateTime, so we just offset "now" by _dayOffset days and recompute.
  int _dayOffset = 0;
  Widget _dayArrow(IconData ic, int dir) => Material(
    color: kCard, shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() =>
        _dayOffset = (_dayOffset + dir).clamp(-90, 90).toInt()),
      child: Padding(padding: const EdgeInsets.all(8),
        child: Icon(ic, color: kGold, size: 22))));
  String _liveDateLabel(DateTime t) => '${t.day}/${t.month}/${t.year}';

  // ±24-hour control — shifting by hours mainly sweeps the Ascendant/houses
  // through the signs (planets barely move within a day).
  int _hourOffset = 0;
  // Selected sign in the top strip (kept for the Box view, later).
  int? _selSign;
  Widget _hourPill(String label, int dir) => Material(
    color: kCard, borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() =>
        _hourOffset = (_hourOffset + dir).clamp(-24, 24).toInt()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Text(label, style: const TextStyle(color: kLight,
          fontSize: 13, fontWeight: FontWeight.w800)))));
  Widget _zodiacStrip() => SizedBox(height: 58,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 12,
      itemBuilder: (_, k) {
        final i = 11 - k; // Pisces … Aries, like the website strip
        final sel = _selSign == i;
        final name = signs[i].name[currentLang.value]
          ?? signs[i].name[AppLang.en]!;
        return GestureDetector(
          onTap: () => setState(() => _selSign = sel ? null : i),
          child: Container(
            width: 56,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sel ? kGold : Colors.transparent, width: 1.4)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CachedNetworkImage(
                  imageUrl: signSymbolUrl(i, vedic: widget.vedic),
                  width: 26, height: 26, fit: BoxFit.contain,
                  errorWidget: (_, __, ___) =>
                    const SizedBox(width: 26, height: 26)),
                const SizedBox(height: 2),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: sel ? kGold : kMuted,
                    fontSize: 9, fontWeight: FontWeight.w700)),
              ])));
      }));

  // Circle ⟷ Box view toggle (default: circle).
  bool _boxMode = false;
  Widget _viewToggle(bool boxMode, IconData ic) {
    final active = _boxMode == boxMode;
    return Material(
      color: active ? kGold : kCard, shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _boxMode = boxMode),
        child: Padding(padding: const EdgeInsets.all(9),
          child: Icon(ic, color: active ? kBg : kLight, size: 22))));
  }

  @override
  Widget build(BuildContext context) {
    final l = currentLang.value;
    final city = _pickCity();
    final lat = (city['lat'] as num).toDouble();
    final lonE = (city['lon'] as num).toDouble();
    final baseTime =
      DateTime.now().add(Duration(days: _dayOffset, hours: _hourOffset));
    final chart = computeChart(baseTime.toUtc(), lat, lonE, widget.vedic);
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
            fontWeight: FontWeight.w800, fontFamily: urduFont)),
          actions: [
            Padding(padding: const EdgeInsets.only(right: 14),
              child: Center(child: Text(
                '${city['n']}  ${_flag(city['c'] as String)}',
                style: const TextStyle(color: kMuted, fontSize: 12.5,
                  fontWeight: FontWeight.w700)))),
          ]),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
              28 + MediaQuery.of(context).viewPadding.bottom),
            children: [
              // TOP: Ascendant ±24-hour control. Tapping the time resets it.
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _hourPill('−1h', -1),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: _hourOffset == 0
                    ? null : () => setState(() => _hourOffset = 0),
                  child: Text(
                    '$ascWord  $ascSignName  ${baseTime.hour.toString().padLeft(2, '0')}:${baseTime.minute.toString().padLeft(2, '0')}${_hourOffset == 0 ? '' : '  ⟲'}',
                    style: TextStyle(
                      color: _hourOffset == 0 ? kMuted : kLight,
                      fontSize: 12.5, fontWeight: FontWeight.w800,
                      fontFamily: urduFont))),
                const SizedBox(width: 14),
                _hourPill('+1h', 1),
              ]),
              const SizedBox(height: 10),
              // 12 zodiac signs — shown ONLY in Box mode. Tapping one makes it
              // House 1 and rearranges the box (they don't apply to the circle).
              if (_boxMode) ...[
                _zodiacStrip(),
                const SizedBox(height: 10),
              ],
              NatalChartView(chart: chart, vedic: widget.vedic,
                boxMode: _boxMode, selSign: _selSign, ascWord: ascWord),
              const SizedBox(height: 8),
              // Bottom bar: Circle toggle (left) · date nav · Box toggle (right).
              Row(children: [
                _viewToggle(false, Icons.circle_outlined),
                Expanded(child: Center(child: Row(
                  mainAxisSize: MainAxisSize.min, children: [
                    _dayArrow(Icons.chevron_left, -1),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _dayOffset == 0
                        ? null : () => setState(() => _dayOffset = 0),
                      child: Text(
                        _dayOffset == 0
                          ? _liveDateLabel(baseTime)
                          : '${_liveDateLabel(baseTime)}  ⟲',
                        style: TextStyle(
                          color: _dayOffset == 0 ? kMuted : kGold,
                          fontSize: 13, fontWeight: FontWeight.w800,
                          fontFamily: urduFont))),
                    const SizedBox(width: 12),
                    _dayArrow(Icons.chevron_right, 1),
                  ]))),
                _viewToggle(true, Icons.crop_square),
              ]),
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
          onPressed: () => openUrl(kWebsite),
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
// Worldwide city search — Open-Meteo geocoding (same API the website uses).
// Returns the picked result map {name, country_code, latitude, longitude,
// timezone (IANA), admin1, country} via Navigator.pop.
// ===========================================================================
class CitySearchSheet extends StatefulWidget {
  const CitySearchSheet({super.key});
  @override
  State<CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<CitySearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _deb;
  List<Map<String, dynamic>> _res = [];
  bool _loading = false;
  String _msg = '';

  void _onChanged(String q) {
    _deb?.cancel();
    final s = q.trim();
    if (s.length < 2) { setState(() { _res = []; _msg = ''; }); return; }
    _deb = Timer(const Duration(milliseconds: 320), () => _search(s));
  }

  Future<void> _search(String q) async {
    setState(() { _loading = true; _msg = ''; });
    try {
      final r = await http.get(Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search'
        '?name=${Uri.encodeQueryComponent(q)}&count=10&language=en&format=json'))
        .timeout(const Duration(seconds: 12));
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final res = ((d['results'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _res = res; _loading = false;
        _msg = res.isEmpty ? 'noCity' : '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _msg = 'failCity'; });
    }
  }

  @override
  void dispose() { _deb?.cancel(); _ctrl.dispose(); super.dispose(); }

  String _t(Map<AppLang, String> m) => m[currentLang.value] ?? m[AppLang.en]!;

  @override
  Widget build(BuildContext context) {
    final msgText = _msg == 'noCity'
      ? _t({AppLang.en: 'No match — try another spelling.',
          AppLang.ur: 'کوئی نتیجہ نہیں — دوسری ہجے آزمائیں۔',
          AppLang.hi: 'कोई मेल नहीं — दूसरी वर्तनी आज़माएँ।',
          AppLang.ar: 'لا نتيجة — جرّب تهجئة أخرى.'})
      : _msg == 'failCity'
        ? _t({AppLang.en: 'Search failed — check your connection.',
            AppLang.ur: 'تلاش ناکام — اپنا کنکشن دیکھیں۔',
            AppLang.hi: 'खोज विफल — कनेक्शन जाँचें।',
            AppLang.ar: 'فشل البحث — تحقق من اتصالك.'})
        : '';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: kBorder,
              borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _ctrl, autofocus: true, onChanged: _onChanged,
              style: const TextStyle(color: kOn, fontSize: 15),
              decoration: InputDecoration(
                hintText: _t({AppLang.en: 'Search any city…',
                  AppLang.ur: 'کوئی بھی شہر تلاش کریں…',
                  AppLang.hi: 'कोई भी शहर खोजें…',
                  AppLang.ar: 'ابحث عن أي مدينة…'}),
                hintStyle: const TextStyle(color: kMuted),
                prefixIcon: const Icon(Icons.search, color: kMuted),
                isDense: true, filled: true, fillColor: kBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimary))))),
          if (_loading) const LinearProgressIndicator(
            minHeight: 2, color: kPrimary, backgroundColor: kCard),
          if (msgText.isNotEmpty) Padding(
            padding: const EdgeInsets.all(20),
            child: Text(msgText, textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 13.5))),
          Expanded(child: ListView.builder(
            itemCount: _res.length,
            itemBuilder: (_, i) {
              final c = _res[i];
              final sub = [c['admin1'], c['country']]
                .where((x) => x != null && '$x'.isNotEmpty).join(', ');
              return ListTile(
                leading: Text(_flag((c['country_code'] ?? '') as String? ?? ''),
                  style: const TextStyle(fontSize: 22)),
                title: Text('${c['name']}',
                  style: const TextStyle(color: kOn, fontWeight: FontWeight.w700)),
                subtitle: Text(sub,
                  style: const TextStyle(color: kMuted, fontSize: 12)),
                onTap: () => Navigator.pop(context, c));
            })),
        ]))));
  }
}

// ===========================================================================
// PER-PLANET READING (Overall) — ported verbatim from the website reading
// engine (VR_* tables). The same classical dignity table serves BOTH Western
// and Vedic; only the planet's sign (tropical vs sidereal) and the title
// differ. Covers the 9 classical grahas (no Uranus/Neptune/Pluto).
// ===========================================================================
// Exaltation sign index per planet; own signs (debilitation = exalt + 6).
const Map<String, int> _rExalt = {
  'Sun': 0, 'Moon': 1, 'Mars': 9, 'Mercury': 5, 'Jupiter': 3,
  'Venus': 11, 'Saturn': 6, 'Rahu': 1, 'Ketu': 7,
};
const Map<String, List<int>> _rOwn = {
  'Sun': [4], 'Moon': [3], 'Mars': [0, 7], 'Mercury': [2, 5],
  'Jupiter': [8, 11], 'Venus': [1, 6], 'Saturn': [9, 10], 'Rahu': [], 'Ketu': [],
};
const List<String> _rGrahas = ['Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter',
  'Venus', 'Saturn', 'Rahu', 'Ketu'];

String _rDignity(String k, int si) {
  final ex = _rExalt[k]!;
  if (si == ex) return 'exalt';
  if ((ex + 6) % 12 == si) return 'debil';
  if ((_rOwn[k] ?? const []).contains(si)) return 'own';
  return 'neutral';
}
String _rToneKey(String d) =>
  (d == 'exalt' || d == 'own') ? 'good' : (d == 'debil' ? 'tender' : 'mixed');
Color _rDigColor(String d) => (d == 'exalt' || d == 'own')
  ? const Color(0xFF57d39a)
  : (d == 'debil' ? const Color(0xFFe6a6cc) : const Color(0xFFe3b23c));

const Map<String, Map<AppLang, String>> _rPlanetName = {
  'Sun': {AppLang.en: 'Sun', AppLang.ur: 'سورج', AppLang.hi: 'सूर्य', AppLang.ar: 'الشمس'},
  'Moon': {AppLang.en: 'Moon', AppLang.ur: 'چاند', AppLang.hi: 'चंद्र', AppLang.ar: 'القمر'},
  'Mercury': {AppLang.en: 'Mercury', AppLang.ur: 'عطارد', AppLang.hi: 'बुध', AppLang.ar: 'عطارد'},
  'Venus': {AppLang.en: 'Venus', AppLang.ur: 'زہرہ', AppLang.hi: 'शुक्र', AppLang.ar: 'الزهرة'},
  'Mars': {AppLang.en: 'Mars', AppLang.ur: 'مریخ', AppLang.hi: 'मंगल', AppLang.ar: 'المرّيخ'},
  'Jupiter': {AppLang.en: 'Jupiter', AppLang.ur: 'مشتری', AppLang.hi: 'गुरु', AppLang.ar: 'المشتري'},
  'Saturn': {AppLang.en: 'Saturn', AppLang.ur: 'زحل', AppLang.hi: 'शनि', AppLang.ar: 'زحل'},
  'Rahu': {AppLang.en: 'Rahu', AppLang.ur: 'راہو', AppLang.hi: 'राहु', AppLang.ar: 'راهو'},
  'Ketu': {AppLang.en: 'Ketu', AppLang.ur: 'کیتو', AppLang.hi: 'केतु', AppLang.ar: 'كيتو'},
};
const Map<String, Map<AppLang, String>> _rGSig = {
  'Sun': {AppLang.en: "the soul, vitality, confidence and one's father", AppLang.ur: 'روح، توانائی، اعتماد اور والد', AppLang.hi: 'आत्मा, ऊर्जा, आत्मविश्वास और पिता', AppLang.ar: 'الروح والحيوية والثقة والأب'},
  'Moon': {AppLang.en: "the mind, emotions, comfort and one's mother", AppLang.ur: 'ذہن، جذبات، سکون اور والدہ', AppLang.hi: 'मन, भावनाएँ, सुकून और माता', AppLang.ar: 'العقل والعواطف والراحة والأم'},
  'Mars': {AppLang.en: 'energy, courage, drive and action', AppLang.ur: 'توانائی، ہمت، جوش اور عمل', AppLang.hi: 'ऊर्जा, साहस, जोश और कर्म', AppLang.ar: 'الطاقة والشجاعة والاندفاع والفعل'},
  'Mercury': {AppLang.en: 'intellect, speech, learning and communication', AppLang.ur: 'عقل، گفتگو، سیکھنا اور رابطہ', AppLang.hi: 'बुद्धि, वाणी, सीखना और संवाद', AppLang.ar: 'الذكاء والكلام والتعلّم والتواصل'},
  'Jupiter': {AppLang.en: 'wisdom, growth, fortune and guidance', AppLang.ur: 'حکمت، ترقی، خوش بختی اور رہنمائی', AppLang.hi: 'ज्ञान, विकास, भाग्य और मार्गदर्शन', AppLang.ar: 'الحكمة والنموّ والحظّ والإرشاد'},
  'Venus': {AppLang.en: 'love, beauty, relationships and pleasures', AppLang.ur: 'محبت، حُسن، تعلقات اور لطافتیں', AppLang.hi: 'प्रेम, सौंदर्य, रिश्ते और सुख', AppLang.ar: 'الحبّ والجمال والعلاقات والمتع'},
  'Saturn': {AppLang.en: "discipline, patience, duty and life's lessons", AppLang.ur: 'نظم، صبر، فرض اور زندگی کے اسباق', AppLang.hi: 'अनुशासन, धैर्य, कर्तव्य और जीवन के सबक', AppLang.ar: 'الانضباط والصبر والواجب ودروس الحياة'},
  'Rahu': {AppLang.en: 'ambition, desire and the unconventional', AppLang.ur: 'حرص، خواہش اور غیر روایتی پن', AppLang.hi: 'महत्वाकांक्षा, इच्छा और अपरंपरागतता', AppLang.ar: 'الطموح والرغبة وغير المألوف'},
  'Ketu': {AppLang.en: 'detachment, intuition and spirituality', AppLang.ur: 'بے نیازی، باطنی ادراک اور روحانیت', AppLang.hi: 'वैराग्य, अंतर्ज्ञान और आध्यात्म', AppLang.ar: 'الانفصال والحدس والروحانية'},
};
const List<Map<AppLang, String>> _rHouse = [
  {AppLang.en: 'the self, body & personality', AppLang.ur: 'ذات، جسم اور شخصیت', AppLang.hi: 'स्वयं, शरीर और व्यक्तित्व', AppLang.ar: 'الذات والجسد والشخصية'},
  {AppLang.en: 'wealth, family & speech', AppLang.ur: 'دولت، خاندان اور گفتار', AppLang.hi: 'धन, परिवार और वाणी', AppLang.ar: 'الثروة والعائلة والكلام'},
  {AppLang.en: 'courage, siblings & effort', AppLang.ur: 'ہمت، بہن بھائی اور کوشش', AppLang.hi: 'साहस, भाई-बहन और प्रयास', AppLang.ar: 'الشجاعة والإخوة والجهد'},
  {AppLang.en: 'home, mother & inner peace', AppLang.ur: 'گھر، والدہ اور باطنی سکون', AppLang.hi: 'घर, माता और भीतरी शांति', AppLang.ar: 'البيت والأم والسكينة'},
  {AppLang.en: 'creativity, romance & children', AppLang.ur: 'تخلیق، رومانس اور اولاد', AppLang.hi: 'रचनात्मकता, प्रेम और संतान', AppLang.ar: 'الإبداع والرومانسية والأبناء'},
  {AppLang.en: 'health, work & obstacles', AppLang.ur: 'صحت، کام اور رکاوٹیں', AppLang.hi: 'स्वास्थ्य, कार्य और बाधाएँ', AppLang.ar: 'الصحّة والعمل والعقبات'},
  {AppLang.en: 'partnership & marriage', AppLang.ur: 'شراکت اور شادی', AppLang.hi: 'साझेदारी और विवाह', AppLang.ar: 'الشراكة والزواج'},
  {AppLang.en: 'transformation & hidden things', AppLang.ur: 'تبدیلی اور پوشیدہ امور', AppLang.hi: 'रूपांतरण और गुप्त बातें', AppLang.ar: 'التحوّل والأمور الخفية'},
  {AppLang.en: 'fortune, beliefs & dharma', AppLang.ur: 'قسمت، عقائد اور دھرم', AppLang.hi: 'भाग्य, आस्था और धर्म', AppLang.ar: 'الحظّ والمعتقدات والمبادئ'},
  {AppLang.en: 'career, status & public life', AppLang.ur: 'کیریئر، مقام اور سماجی زندگی', AppLang.hi: 'करियर, प्रतिष्ठा और सार्वजनिक जीवन', AppLang.ar: 'المهنة والمكانة والحياة العامة'},
  {AppLang.en: 'gains, friends & hopes', AppLang.ur: 'حاصلات، دوست اور امیدیں', AppLang.hi: 'लाभ, मित्र और आशाएँ', AppLang.ar: 'المكاسب والأصدقاء والآمال'},
  {AppLang.en: 'rest, release & the inner world', AppLang.ur: 'آرام، رہائی اور باطنی دنیا', AppLang.hi: 'विश्राम, मुक्ति और भीतरी संसार', AppLang.ar: 'الراحة والتحرّر والعالم الداخلي'},
];
const Map<String, Map<AppLang, String>> _rDig = {
  'exalt': {AppLang.en: 'exalted and very strong', AppLang.ur: 'اوچ یافتہ اور بہت مضبوط', AppLang.hi: 'उच्च का और बहुत प्रबल', AppLang.ar: 'في الشرف وقويّ جدًّا'},
  'own': {AppLang.en: 'in its own sign — steady and at home', AppLang.ur: 'اپنی راشی میں — مستحکم اور پُرسکون', AppLang.hi: 'अपनी राशि में — स्थिर और सहज', AppLang.ar: 'في برجه — ثابت ومستقرّ'},
  'debil': {AppLang.en: 'weakened, asking for patience', AppLang.ur: 'کمزور، صبر کا تقاضا کرتا', AppLang.hi: 'नीच का, धैर्य माँगता', AppLang.ar: 'ضعيف، يطلب الصبر'},
  'neutral': {AppLang.en: 'fairly neutral and balanced', AppLang.ur: 'معتدل اور متوازن', AppLang.hi: 'तटस्थ और संतुलित', AppLang.ar: 'محايد ومتوازن'},
};
const Map<String, Map<AppLang, String>> _rTone = {
  'good': {AppLang.en: 'A supportive placement — a natural strength to lean on.', AppLang.ur: 'ایک سازگار مقام — ایک قدرتی طاقت جس پر بھروسا کیا جا سکے۔', AppLang.hi: 'एक सहायक स्थिति — एक स्वाभाविक शक्ति जिस पर भरोसा करें।', AppLang.ar: 'موضع داعم — قوّة طبيعية يمكن الاتّكاء عليها.'},
  'mixed': {AppLang.en: 'A balanced placement — its effects depend on the whole chart and your choices.', AppLang.ur: 'ایک متوازن مقام — اس کے اثرات پورے چارٹ اور آپ کے فیصلوں پر منحصر۔', AppLang.hi: 'एक संतुलित स्थिति — इसके प्रभाव पूरे चार्ट और आपके चुनावों पर निर्भर।', AppLang.ar: 'موضع متوازن — تعتمد آثاره على المخطّط كلّه واختياراتك.'},
  'tender': {AppLang.en: 'A tender placement — growth here often comes through patience.', AppLang.ur: 'ایک نازک مقام — یہاں ترقی اکثر صبر سے آتی ہے۔', AppLang.hi: 'एक कोमल स्थिति — यहाँ विकास अक्सर धैर्य से आता है।', AppLang.ar: 'موضع رقيق — غالبًا ما يأتي النموّ هنا بالصبر.'},
};
const Map<AppLang, String> _rTitleW = {AppLang.en: 'Your Western Reading', AppLang.ur: 'آپ کی مغربی ریڈنگ', AppLang.hi: 'आपकी पश्चिमी रीडिंग', AppLang.ar: 'قراءتك الغربية'};
const Map<AppLang, String> _rTitleV = {AppLang.en: 'Your Vedic Reading', AppLang.ur: 'آپ کی ویدک ریڈنگ', AppLang.hi: 'आपकी वैदिक रीडिंग', AppLang.ar: 'قراءتك الفيدية'};
const Map<AppLang, String> _rSub = {AppLang.en: 'Each planet, by house · for curiosity & fun', AppLang.ur: 'ہر سیارہ، گھر کے لحاظ سے · تجسس و تفریح کے لیے', AppLang.hi: 'प्रत्येक ग्रह, घर अनुसार · जिज्ञासा व मनोरंजन हेतु', AppLang.ar: 'كلّ كوكب بحسب البيت · للفضول والمتعة'};
const Map<AppLang, String> _rDisc = {AppLang.en: 'For curiosity and fun — a poetic reading, not a prediction.', AppLang.ur: 'محض تجسس و تفریح — ایک شاعرانہ تشریح، کوئی پیشین گوئی نہیں۔', AppLang.hi: 'केवल जिज्ञासा व मनोरंजन — एक काव्यात्मक पाठ, कोई भविष्यवाणी नहीं।', AppLang.ar: 'للفضول والمتعة — قراءة شاعرية لا تنبّؤ.'};

String _rHouseLabel(AppLang l, int n) {
  switch (l) {
    case AppLang.hi: return '${n}वाँ घर';
    case AppLang.ur: return 'گھر $n';
    case AppLang.ar: return 'البيت $n';
    default: return 'House $n';
  }
}
String _rIntro(AppLang l, String a, String m) {
  switch (l) {
    case AppLang.ur: return 'آپ کے سورج کی راشی $a اور چاند کی راشی $m ہے — یہی آپ کے چارٹ کا مزاج طے کرتے ہیں۔ نیچے ہر سیارہ اپنے گھر کے مطابق آپ کی کہانی میں اپنا رنگ شامل کرتا ہے۔';
    case AppLang.hi: return 'आपकी सूर्य राशि $a और चंद्र राशि $m है — ये मिलकर आपके चार्ट का मिज़ाज तय करते हैं। नीचे प्रत्येक ग्रह अपने घर के अनुसार आपकी कहानी में अपना रंग जोड़ता है।';
    case AppLang.ar: return 'برج شمسك هو $a وبرج قمرك $m — معًا يحدّدان مزاج مخطّطك. في الأسفل، يضيف كلّ كوكب لونه إلى قصّتك بحسب البيت الذي يقع فيه.';
    default: return 'Your Sun sign is $a and your Moon sign is $m — together they set the tone of your chart. Below, each planet adds its own colour to your story, according to the house it sits in.';
  }
}
// The per-planet sentence split into (before, after) around the coloured
// dignity phrase, so we can render the dignity word in its strength colour.
List<String> _rSentenceParts(AppLang l, String name, String sig,
    String sign, String tone) {
  switch (l) {
    case AppLang.ur:
      return ['$name، $sig کی نمائندگی کرتا ہے۔ اِس گھر میں یہ کیفیت زندگی کے اِس پہلو کو رنگ دیتی ہے۔ یہ $sign میں ہے، جہاں یہ ', '۔ $tone'];
    case AppLang.hi:
      return ['$name, $sig का प्रतिनिधित्व करता है। इस घर में यह गुण जीवन के इस पहलू को रंग देता है। यह $sign में है, जहाँ यह ', '। $tone'];
    case AppLang.ar:
      return ['$name يمثّل $sig. في هذا البيت تُلوّن هذه الطاقة هذا الجانب من الحياة. وهو في $sign، حيث يكون ', '. $tone'];
    default:
      return ['$name represents $sig. In this house, that quality colours how this part of life unfolds. It sits in $sign, where it is ', '. $tone'];
  }
}

// Live "Deeper AI reading" — Claude, via the same Cloudflare worker the
// website uses. Posts the chart summary, shows the returned reading.
const String kAiProxyUrl = 'https://farooq-stars-ai.babaqatar.workers.dev';
// The worker only answers requests whose Origin is farooqstars.com. Browsers
// block setting Origin, but a native app can send it, so the app is allowed.
const String kSiteOrigin = 'https://www.farooqstars.com';
const Map<AppLang, String> _aiBtn = {AppLang.en: 'Deeper AI reading', AppLang.ur: 'گہری AI ریڈنگ', AppLang.hi: 'गहरी AI रीडिंग', AppLang.ar: 'قراءة AI أعمق'};
const Map<AppLang, String> _aiLoading = {AppLang.en: 'Reading your stars…', AppLang.ur: 'آپ کے ستارے پڑھے جا رہے ہیں…', AppLang.hi: 'आपके सितारे पढ़े जा रहे हैं…', AppLang.ar: 'تُقرأ نجومك…'};
const Map<AppLang, String> _aiErr = {AppLang.en: 'Could not load the AI reading right now. Please try again later.', AppLang.ur: 'ابھی AI ریڈنگ نہیں مل سکی۔ بعد میں دوبارہ کوشش کریں۔', AppLang.hi: 'अभी AI रीडिंग नहीं मिल सकी। बाद में पुनः प्रयास करें।', AppLang.ar: 'تعذّر تحميل قراءة AI الآن. حاول لاحقًا.'};
const Map<AppLang, String> _aiRefresh = {AppLang.en: 'Refresh AI', AppLang.ur: 'دوبارہ AI', AppLang.hi: 'फिर से AI', AppLang.ar: 'تحديث AI'};

class AiReadingButton extends StatefulWidget {
  final LiveChart chart;
  final bool vedic;
  final AppLang l;
  final Color accent;
  final int houseRefSign;
  final String birthSig;
  const AiReadingButton({super.key, required this.chart, required this.vedic,
    required this.l, required this.accent, required this.houseRefSign,
    required this.birthSig});
  @override
  State<AiReadingButton> createState() => _AiReadingButtonState();
}

class _AiReadingButtonState extends State<AiReadingButton> {
  static final Map<String, String> _cache = {};
  bool _loading = false;
  bool _error = false;
  String? _text;

  String get _key =>
    '${widget.birthSig}|${widget.vedic ? 'vedic' : 'western'}|${widget.l.name}';

  @override
  void initState() { super.initState(); _text = _cache[_key]; }

  Map<String, dynamic> _payload() {
    final byKey = {for (final b in widget.chart.bodies) b.key: b};
    String en(int i) => signs[i].name[AppLang.en]!;
    final moon = byKey['Moon'];
    return {
      'lang': widget.l.name,
      'system': widget.vedic ? 'vedic' : 'western',
      'section': 'overall',
      'ascendant': en(widget.chart.ascSign),
      'moonSign': moon == null ? '' : en(moon.sign),
      'planets': _rGrahas.where(byKey.containsKey).map((k) {
        final b = byKey[k]!;
        final house = ((b.sign - widget.houseRefSign) % 12 + 12) % 12 + 1;
        return {
          'name': k, 'sign': en(b.sign), 'house': house,
          'dignity': _rDignity(k, b.sign), 'retro': b.retro,
        };
      }).toList(),
    };
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = false; });
    try {
      final r = await http.post(Uri.parse(kAiProxyUrl),
        headers: const {'content-type': 'application/json', 'origin': kSiteOrigin},
        body: jsonEncode(_payload())).timeout(const Duration(seconds: 60));
      final d = jsonDecode(r.body);
      final reading = (d is Map && d['reading'] is String)
        ? (d['reading'] as String).trim() : '';
      if (!mounted) return;
      if (reading.isNotEmpty) {
        _cache[_key] = reading;
        setState(() { _text = reading; _loading = false; });
      } else {
        setState(() { _error = true; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    if (_loading) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
            strokeWidth: 2, color: widget.accent)),
          const SizedBox(width: 10),
          Text(_aiLoading[l]!, style: TextStyle(color: kMuted, fontSize: 13,
            fontFamily: urduFont)),
        ]));
    }
    final btn = Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _fetch,
        icon: Icon(Icons.auto_awesome, size: 18, color: widget.accent),
        label: Text(_text == null ? _aiBtn[l]! : _aiRefresh[l]!,
          style: TextStyle(color: widget.accent, fontSize: 13.5,
            fontWeight: FontWeight.w800, fontFamily: urduFont)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: widget.accent.withOpacity(0.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 4),
      btn,
      if (_error) Padding(padding: const EdgeInsets.only(top: 8),
        child: Text(_aiErr[l]!, style: TextStyle(color: kMuted, fontSize: 12.5,
          fontFamily: urduFont))),
      if (_text != null) Padding(padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.accent.withOpacity(0.35))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: _text!.split(RegExp(r'\n\n+')).map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p.trim(), style: TextStyle(color: kOn, fontSize: 13,
                height: 1.6, fontFamily: urduFont)))).toList()))),
    ]);
  }
}

const Map<String, Map<AppLang, String>> _rTabLbl = {
  'overall': {AppLang.en: 'Overall', AppLang.ur: 'مجموعی', AppLang.hi: 'समग्र', AppLang.ar: 'إجمالي'},
  'today': {AppLang.en: 'Today', AppLang.ur: 'آج', AppLang.hi: 'आज', AppLang.ar: 'اليوم'},
  'week': {AppLang.en: 'This Week', AppLang.ur: 'اس ہفتے', AppLang.hi: 'इस सप्ताह', AppLang.ar: 'هذا الأسبوع'},
  'month': {AppLang.en: 'This Month', AppLang.ur: 'اس مہینے', AppLang.hi: 'इस महीने', AppLang.ar: 'هذا الشهر'},
};
const Map<AppLang, String> _rSource = {AppLang.en: 'Source: AstrologyAPI', AppLang.ur: 'ماخذ: AstrologyAPI', AppLang.hi: 'स्रोत: AstrologyAPI', AppLang.ar: 'المصدر: AstrologyAPI'};

// The reading section — tabs: Overall (offline per-planet reading + live Claude
// button) and Today / This Week / This Month (real forecast from AstrologyAPI
// via the worker, with a "Source: AstrologyAPI" badge).
class BirthReadingSection extends StatefulWidget {
  final LiveChart chart;
  final bool vedic;
  final AppLang l;
  final Color accent;
  final int houseRefSign; // House-1 sign (Sun/Moon/Asc)
  final String birthSig;
  const BirthReadingSection({super.key, required this.chart,
    required this.vedic, required this.l, required this.accent,
    required this.houseRefSign, required this.birthSig});
  @override
  State<BirthReadingSection> createState() => _BirthReadingSectionState();
}

class _BirthReadingSectionState extends State<BirthReadingSection> {
  String _tab = 'overall';
  static final Map<String, String> _fcache = {};
  bool _fLoading = false;
  bool _fError = false;
  String? _fText;

  int _house(int sign) => ((sign - widget.houseRefSign) % 12 + 12) % 12 + 1;

  Widget _pImg(String key) => CachedNetworkImage(
    imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[key]}',
    width: 20, height: 20, fit: BoxFit.contain,
    errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 20));

  // Forecast is by sign — Western uses the Sun sign, Vedic the Moon sign.
  String _forecastSign() {
    final byKey = {for (final b in widget.chart.bodies) b.key: b};
    final b = widget.vedic ? byKey['Moon'] : byKey['Sun'];
    final si = b?.sign ?? widget.chart.ascSign;
    return signs[si].name[AppLang.en]!.toLowerCase();
  }

  String get _fkey =>
    '${widget.vedic ? 'v' : 'w'}|$_tab|${widget.l.name}|${_forecastSign()}';

  Future<void> _loadForecast() async {
    final k = _fkey;
    final cached = _fcache[k];
    if (cached != null) {
      setState(() { _fText = cached; _fLoading = false; _fError = false; });
      return;
    }
    setState(() { _fLoading = true; _fError = false; _fText = null; });
    try {
      final r = await http.post(Uri.parse(kAiProxyUrl),
        headers: const {'content-type': 'application/json', 'origin': kSiteOrigin},
        body: jsonEncode({
          'horoFeature': _tab, 'sign': _forecastSign(), 'lang': widget.l.name,
        })).timeout(const Duration(seconds: 45));
      final d = jsonDecode(r.body);
      final txt = (d is Map && d['reading'] is String)
        ? (d['reading'] as String).trim() : '';
      if (!mounted) return;
      if (txt.isNotEmpty) {
        _fcache[k] = txt;
        setState(() { _fText = txt; _fLoading = false; });
      } else {
        setState(() { _fError = true; _fLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _fError = true; _fLoading = false; });
    }
  }

  void _setTab(String t) {
    if (_tab == t) return;
    setState(() { _tab = t; _fText = null; _fError = false; _fLoading = false; });
    if (t != 'overall') _loadForecast();
  }

  Widget _tabBar() {
    const order = ['overall', 'today', 'week', 'month'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: order.map((t) {
        final sel = _tab == t;
        return Padding(padding: const EdgeInsetsDirectional.only(end: 8),
          child: GestureDetector(onTap: () => _setTab(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? widget.accent : kCard,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: sel ? widget.accent : kBorder)),
              child: Text(_rTabLbl[t]![widget.l]!,
                style: TextStyle(color: sel ? kBg : kMuted,
                  fontWeight: FontWeight.w700, fontSize: 12.5,
                  fontFamily: urduFont)))));
      }).toList()));
  }

  List<Widget> _overallBody() {
    final l = widget.l;
    final byKey = {for (final b in widget.chart.bodies) b.key: b};
    String signName(int i) => signs[i].name[l] ?? signs[i].name[AppLang.en]!;
    final sun = byKey['Sun'], moon = byKey['Moon'];
    final intro = _rIntro(l,
      sun == null ? '' : signName(sun.sign),
      moon == null ? '' : signName(moon.sign));
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder)),
        child: Text(intro, style: TextStyle(color: kOn, fontSize: 13,
          height: 1.6, fontFamily: urduFont))),
      const SizedBox(height: 6),
      ..._rGrahas.where(byKey.containsKey).map((k) {
        final b = byKey[k]!;
        final dig = _rDignity(k, b.sign);
        final name = _rPlanetName[k]![l]!;
        final parts = _rSentenceParts(l, name, _rGSig[k]![l]!,
          signName(b.sign), _rTone[_rToneKey(dig)]![l]!);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _pImg(k),
                const SizedBox(width: 8),
                Text(name, style: TextStyle(color: kOn, fontSize: 14,
                  fontWeight: FontWeight.w800, fontFamily: urduFont)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '${_rHouseLabel(l, _house(b.sign))} · ${_rHouse[_house(b.sign) - 1][l]}',
                  style: TextStyle(color: kMuted, fontSize: 11.5,
                    fontWeight: FontWeight.w600, fontFamily: urduFont))),
              ]),
              const SizedBox(height: 4),
              Text.rich(TextSpan(children: [
                TextSpan(text: parts[0]),
                TextSpan(text: _rDig[dig]![l]!, style: TextStyle(
                  color: _rDigColor(dig), fontWeight: FontWeight.w700)),
                TextSpan(text: parts[1]),
              ]), style: TextStyle(color: kOn, fontSize: 13, height: 1.6,
                fontFamily: urduFont)),
            ]));
      }),
      const SizedBox(height: 6),
      AiReadingButton(chart: widget.chart, vedic: widget.vedic, l: l,
        accent: widget.accent, houseRefSign: widget.houseRefSign,
        birthSig: widget.birthSig),
    ];
  }

  List<Widget> _forecastBody() {
    final l = widget.l;
    if (_fLoading) {
      return [Padding(padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: widget.accent))))];
    }
    if (_fError) {
      return [Padding(padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(_aiErr[l]!, style: TextStyle(color: kMuted, fontSize: 13,
          fontFamily: urduFont)))];
    }
    if (_fText == null) return const [SizedBox.shrink()];
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: _fText!.split(RegExp(r'\n\n+')).map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p.trim(), style: TextStyle(color: kOn, fontSize: 13,
              height: 1.6, fontFamily: urduFont)))).toList())),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.verified_outlined, size: 14, color: widget.accent),
        const SizedBox(width: 6),
        Text(_rSource[l]!, style: const TextStyle(color: kMuted,
          fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return card(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.vedic ? _rTitleV[l]! : _rTitleW[l]!,
          style: TextStyle(color: widget.accent, fontSize: 17,
            fontWeight: FontWeight.w800, fontFamily: urduFont)),
        const SizedBox(height: 2),
        Text(_rSub[l]!, style: TextStyle(color: kMuted, fontSize: 12,
          fontFamily: urduFont)),
        const SizedBox(height: 12),
        _tabBar(),
        const SizedBox(height: 12),
        ...(_tab == 'overall' ? _overallBody() : _forecastBody()),
        const SizedBox(height: 10),
        Text(_rDisc[l]!, style: TextStyle(color: kMuted, fontSize: 11.5,
          fontStyle: FontStyle.italic, fontFamily: urduFont)),
      ]));
  }
}

// North-Indian house-content centres (unit square), shared by the chart and
// the shareable report card. index 0 = House 1 … 11 = House 12.
const List<List<double>> _kHouseC = [
  [0.50, 0.26], [0.26, 0.14], [0.14, 0.26], [0.28, 0.50],
  [0.14, 0.74], [0.26, 0.86], [0.50, 0.74], [0.74, 0.86],
  [0.86, 0.74], [0.72, 0.50], [0.86, 0.26], [0.74, 0.14],
];

// Fetch a network image as a dart:ui Image (for the shareable report canvas).
Future<ui.Image?> _loadUiImage(String url) async {
  try {
    final r = await http.get(Uri.parse(url))
      .timeout(const Duration(seconds: 20));
    if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(r.bodyBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

// Bundle of decoded images used across every report page (fetched once).
class _RptImgs {
  final ui.Image? bg;
  final ui.Image? glow;
  final Map<String, ui.Image?> planets;
  final Map<int, ui.Image?> signs;
  const _RptImgs(this.bg, this.glow, this.planets, this.signs);
}

Future<_RptImgs> _fetchRptImgs(bool vedic, int refSign) async {
  final imgs = await Future.wait<ui.Image?>([
    _loadUiImage(signBigArtUrl(refSign)),
    _loadUiImage('$kWebsite/app/planet-icons-v2/retroglow.png'),
    ..._rGrahas.map((k) =>
      _loadUiImage('$kWebsite/app/planet-icons-v2/${_livePlanetIcon[k]}')),
    ...List.generate(12, (i) => _loadUiImage(signSymbolUrl(i, vedic: vedic))),
  ]);
  final planets = <String, ui.Image?>{};
  for (int i = 0; i < _rGrahas.length; i++) planets[_rGrahas[i]] = imgs[2 + i];
  final signsM = <int, ui.Image?>{};
  for (int i = 0; i < 12; i++) signsM[i] = imgs[2 + _rGrahas.length + i];
  return _RptImgs(imgs[0], imgs[1], planets, signsM);
}

// Draw a ui.Image into a destination rect (no-op if null).
void _drawUi(Canvas c, ui.Image? im, Rect dst) {
  if (im == null) return;
  c.drawImageRect(im,
    Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
    dst, Paint()..filterQuality = FilterQuality.medium);
}

// A laid-out TextPainter (uses the phone's fonts → every script renders).
TextPainter _rptTp(String s, double size, Color col,
    {FontWeight fw = FontWeight.w600, TextAlign align = TextAlign.left,
     double maxW = 100000}) {
  return TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size,
      fontWeight: fw, height: 1.4, fontFamily: urduFont)),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    textAlign: align)
    ..layout(maxWidth: maxW);
}

// Draw the North-Indian box (sign symbols + house numbers + planets) at (x0,y0)
// with side cs. Shared by the report card and each D-chart page.
void _drawReportBox(Canvas c, double x0, double y0, double cs,
    LiveChart chart, int h1, _RptImgs im) {
  c.drawRect(Rect.fromLTWH(x0, y0, cs, cs), Paint()..color = kPlate);
  final frame = Paint()..style = PaintingStyle.stroke
    ..strokeWidth = cs * 0.004 + 0.6..color = const Color(0xFF4A3866);
  c.drawRect(Rect.fromLTWH(x0, y0, cs, cs), Paint()..style = PaintingStyle.stroke
    ..strokeWidth = cs * 0.005 + 0.6..color = kPlateBorder);
  c.drawLine(Offset(x0, y0), Offset(x0 + cs, y0 + cs), frame);
  c.drawLine(Offset(x0 + cs, y0), Offset(x0, y0 + cs), frame);
  c.drawPath(Path()
    ..moveTo(x0 + cs / 2, y0)..lineTo(x0 + cs, y0 + cs / 2)
    ..lineTo(x0 + cs / 2, y0 + cs)..lineTo(x0, y0 + cs / 2)..close(), frame);
  final sIc = cs * 0.07, pIc = cs * 0.064, gIc = cs * 0.084;
  for (int hh = 1; hh <= 12; hh++) {
    final signIdx = (h1 + hh - 1) % 12;
    final here = chart.bodies.where((b) => _rGrahas.contains(b.key) &&
      ((b.sign - h1) % 12 + 12) % 12 + 1 == hh).toList();
    final hx = x0 + _kHouseC[hh - 1][0] * cs, hy = y0 + _kHouseC[hh - 1][1] * cs;
    _drawUi(c, im.signs[signIdx],
      Rect.fromCenter(center: Offset(hx + cs * 0.032, hy - cs * 0.038),
        width: sIc, height: sIc));
    final tp = _rptTp('$hh', cs * 0.04, elementColor(signs[signIdx].element),
      fw: FontWeight.w800);
    tp.paint(c, Offset(hx - cs * 0.05, hy - cs * 0.075));
    if (here.isNotEmpty) {
      double px = hx - (here.length - 1) * cs * 0.038;
      for (final b in here) {
        if (b.retro) {
          _drawUi(c, im.glow,
            Rect.fromCenter(center: Offset(px, hy + cs * 0.04), width: gIc, height: gIc));
        }
        _drawUi(c, im.planets[b.key],
          Rect.fromCenter(center: Offset(px, hy + cs * 0.04), width: pIc, height: pIc));
        px += cs * 0.076;
      }
    }
  }
}

// A single stacked element on a report page (measure height, then draw).
class _RE {
  final double Function(double w) measure;
  final void Function(Canvas c, double x, double y, double w) draw;
  final double gap;
  double h = 0;
  _RE(this.measure, this.draw, {this.gap = 10});
}

_RE _reSpace(double gap) => _RE((w) => 0, (c, x, y, w) {}, gap: gap);

_RE _reText(String s, double size, Color col,
    {FontWeight fw = FontWeight.w600, TextAlign align = TextAlign.start,
     double gap = 10}) {
  final a = align == TextAlign.start
    ? (rtl ? TextAlign.right : TextAlign.left) : align;
  TextPainter? tp;
  return _RE(
    (w) { tp = _rptTp(s, size, col, fw: fw, align: a, maxW: w); return tp!.height; },
    (c, x, y, w) => tp!.paint(c, Offset(x, y)), gap: gap);
}

_RE _reRich(List<TextSpan> spans, double size, {double gap = 12}) {
  TextPainter? tp;
  return _RE(
    (w) {
      tp = TextPainter(
        text: TextSpan(style: TextStyle(fontSize: size, height: 1.45,
          color: kOn, fontFamily: urduFont), children: spans),
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: rtl ? TextAlign.right : TextAlign.left)..layout(maxWidth: w);
      return tp!.height;
    },
    (c, x, y, w) => tp!.paint(c, Offset(x, y)), gap: gap);
}

_RE _reIconRich(ui.Image? icon, List<TextSpan> spans, double size,
    {double gap = 12}) {
  TextPainter? tp;
  final isz = size * 1.35;
  return _RE(
    (w) {
      tp = TextPainter(
        text: TextSpan(style: TextStyle(fontSize: size, height: 1.45,
          color: kOn, fontFamily: urduFont), children: spans),
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: rtl ? TextAlign.right : TextAlign.left)
        ..layout(maxWidth: w - isz - 14);
      return math.max(tp!.height, isz);
    },
    (c, x, y, w) {
      if (rtl) {
        _drawUi(c, icon, Rect.fromLTWH(x + w - isz, y, isz, isz));
        tp!.paint(c, Offset(x, y));
      } else {
        _drawUi(c, icon, Rect.fromLTWH(x, y, isz, isz));
        tp!.paint(c, Offset(x + isz + 14, y));
      }
    }, gap: gap);
}

_RE _reRow(ui.Image? icon, String left, String right, double size,
    Color lc, Color rc, {double gap = 8}) {
  final isz = size * 1.3;
  TextPainter? lt, rt;
  return _RE(
    (w) {
      lt = _rptTp(left, size, lc, fw: FontWeight.w700, maxW: w * 0.55);
      rt = _rptTp(right, size, rc, fw: FontWeight.w600, maxW: w * 0.42);
      return math.max(isz, math.max(lt!.height, rt!.height));
    },
    (c, x, y, w) {
      final rh = math.max(isz, math.max(lt!.height, rt!.height));
      if (rtl) {
        _drawUi(c, icon, Rect.fromLTWH(x + w - isz, y + (rh - isz) / 2, isz, isz));
        lt!.paint(c, Offset(x + w - isz - 12 - lt!.width, y + (rh - lt!.height) / 2));
        rt!.paint(c, Offset(x, y + (rh - rt!.height) / 2));
      } else {
        _drawUi(c, icon, Rect.fromLTWH(x, y + (rh - isz) / 2, isz, isz));
        lt!.paint(c, Offset(x + isz + 12, y + (rh - lt!.height) / 2));
        rt!.paint(c, Offset(x + w - rt!.width, y + (rh - rt!.height) / 2));
      }
    }, gap: gap);
}

_RE _reBox(LiveChart chart, int h1, _RptImgs im, double cs, {double gap = 18}) =>
  _RE((w) => cs, (c, x, y, w) =>
    _drawReportBox(c, x + (w - cs) / 2, y, cs, chart, h1, im), gap: gap);

// Render a list of stacked elements to a variable-height PNG page.
Future<List<Object>?> _renderReportPage(List<_RE> els, Color accent,
    {double width = 1000, double pad = 56}) async {
  final cw = width - pad * 2;
  double y = pad;
  for (final e in els) { e.h = e.measure(cw); y += e.h + e.gap; }
  final total = y + pad;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, Rect.fromLTWH(0, 0, width, total));
  c.drawRect(Rect.fromLTWH(0, 0, width, total), Paint()..color = kBg);
  c.drawRect(Rect.fromLTWH(18, 18, width - 36, total - 36),
    Paint()..style = PaintingStyle.stroke..strokeWidth = 3
      ..color = accent.withOpacity(0.7));
  double yy = pad;
  for (final e in els) { e.draw(c, pad, yy, cw); yy += e.h + e.gap; }
  final img = await rec.endRecording().toImage(width.toInt(), total.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bd == null) return null;
  return [bd.buffer.asUint8List(), width, total];
}

// ===========================================================================
// DIVISIONAL (VARGA) CHARTS — D1..D60, Vedic only. vargaSign() ported verbatim
// from the website (Parashari rules), verified in Python. Each chart re-maps a
// planet's sidereal longitude to its divisional sign.
// ===========================================================================
int _vmod12(int x) => ((x % 12) + 12) % 12;
bool _vMov(int s) => s == 0 || s == 3 || s == 6 || s == 9;
bool _vFix(int s) => s == 1 || s == 4 || s == 7 || s == 10;

int _vargaSign(double lon, int d) {
  final s = (lon / 30).floor() % 12;
  final deg = ((lon % 30) + 30) % 30;
  final part = (deg / (30 / d)).floor();
  switch (d) {
    case 1: return s;
    case 2:
      if (s % 2 == 0) return deg < 15 ? 4 : 3;
      return deg < 15 ? 3 : 4;
    case 3: return _vmod12(s + part * 4);
    case 4: return _vmod12(s + part * 3);
    case 7: return _vmod12((s % 2 == 0 ? s : _vmod12(s + 6)) + part);
    case 9: return _vmod12((lon / (30 / 9)).floor());
    case 10: return _vmod12((s % 2 == 0 ? s : _vmod12(s + 8)) + part);
    case 12: return _vmod12(s + part);
    case 16: return _vmod12((_vMov(s) ? 0 : (_vFix(s) ? 4 : 8)) + part);
    case 20: return _vmod12((_vMov(s) ? 0 : (_vFix(s) ? 8 : 4)) + part);
    case 24: return _vmod12((s % 2 == 0 ? 4 : 3) + part);
    case 27: return _vmod12(const [0, 3, 6, 9][s % 4] + part);
    case 30:
      if (s % 2 == 0) {
        if (deg < 5) return 0;
        if (deg < 10) return 10;
        if (deg < 18) return 8;
        if (deg < 25) return 2;
        return 6;
      } else {
        if (deg < 5) return 1;
        if (deg < 12) return 5;
        if (deg < 20) return 11;
        if (deg < 25) return 9;
        return 7;
      }
    case 40: return _vmod12((s % 2 == 0 ? 0 : 6) + part);
    case 45: return _vmod12((_vMov(s) ? 0 : (_vFix(s) ? 4 : 8)) + part);
    case 60: return _vmod12(s + (deg * 2).floor());
    default: return s;
  }
}

class _Varga {
  final int d;
  final String name;
  final Map<AppLang, String> short;
  final Map<AppLang, String> sig;
  const _Varga(this.d, this.name, this.short, this.sig);
}

const List<_Varga> _vargas = [
  _Varga(1, 'Rasi (Lagna)', {AppLang.en: 'Life', AppLang.ur: 'زندگی', AppLang.hi: 'जीवन', AppLang.ar: 'الحياة'}, {AppLang.en: 'The main birth chart — your overall life, body, health, personality and the broad shape of your destiny. Every other chart is read against this one.', AppLang.ur: 'بنیادی پیدائشی چارٹ — آپ کی مجموعی زندگی، جسم، صحت، شخصیت اور قسمت کا مجموعی خاکہ۔ باقی تمام چارٹ اِسی کے مقابل پڑھے جاتے ہیں۔', AppLang.hi: 'मुख्य जन्म चार्ट — आपका समग्र जीवन, शरीर, स्वास्थ्य, व्यक्तित्व और भाग्य की कुल रूपरेखा। बाकी सभी चार्ट इसी के सापेक्ष पढ़े जाते हैं।', AppLang.ar: 'المخطط الأساسي للميلاد — حياتك العامّة وجسدك وصحّتك وشخصيّتك وملامح مصيرك. وتُقرأ كلّ المخطّطات الأخرى في ضوئه.'}),
  _Varga(2, 'Hora', {AppLang.en: 'Wealth', AppLang.ur: 'دولت', AppLang.hi: 'धन', AppLang.ar: 'الثروة'}, {AppLang.en: 'Wealth and money. The Hora chart examines your finances, earning capacity and material prosperity.', AppLang.ur: 'دولت اور مال۔ ہورا چارٹ آپ کی مالی حالت، کمائی کی صلاحیت اور خوشحالی کو دیکھتا ہے۔', AppLang.hi: 'धन और संपत्ति। होरा चार्ट आपकी आर्थिक स्थिति, कमाई की क्षमता और समृद्धि को देखता है।', AppLang.ar: 'الثروة والمال. يبحث مخطّط هورا في وضعك المالي وقدرتك على الكسب وازدهارك.'}),
  _Varga(3, 'Drekkana', {AppLang.en: 'Siblings', AppLang.ur: 'بہن بھائی', AppLang.hi: 'भाई-बहन', AppLang.ar: 'الإخوة'}, {AppLang.en: 'Siblings, courage and initiative. It also reflects your drive, efforts and short journeys.', AppLang.ur: 'بہن بھائی، ہمت اور پہل۔ یہ آپ کے حوصلے، محنت اور چھوٹے سفر کو ظاہر کرتا ہے۔', AppLang.hi: 'भाई-बहन, साहस और पहल। यह आपके हौसले, परिश्रम और छोटी यात्राओं को दर्शाता है।', AppLang.ar: 'الإخوة والشجاعة والمبادرة. يعكس أيضًا دوافعك وجهودك وأسفارك القصيرة.'}),
  _Varga(4, 'Chaturthamsha', {AppLang.en: 'Home', AppLang.ur: 'گھر', AppLang.hi: 'घर', AppLang.ar: 'المنزل'}, {AppLang.en: 'Home, property and fixed assets. It shows comforts, real estate, and your sense of inner security and fortune.', AppLang.ur: 'گھر، جائیداد اور مستقل اثاثے۔ یہ آرام، رئیل اسٹیٹ اور اندرونی تحفظ و قسمت دکھاتا ہے۔', AppLang.hi: 'घर, संपत्ति और स्थायी संपत्तियाँ। यह सुख, अचल संपत्ति और आंतरिक सुरक्षा व भाग्य दिखाता है।', AppLang.ar: 'المنزل والعقارات والأصول الثابتة. يُظهر الراحة والممتلكات وشعورك بالأمان الداخليّ والحظّ.'}),
  _Varga(7, 'Saptamsha', {AppLang.en: 'Children', AppLang.ur: 'اولاد', AppLang.hi: 'संतान', AppLang.ar: 'الأبناء'}, {AppLang.en: 'Children and progeny. The Saptamsha reflects offspring, fertility and creative continuation.', AppLang.ur: 'اولاد اور تخلیق۔ سپتامشا اولاد، زرخیزی اور تخلیقی تسلسل کو ظاہر کرتا ہے۔', AppLang.hi: 'संतान और सृजन। सप्तांश संतान, प्रजनन और रचनात्मक निरंतरता को दर्शाता है।', AppLang.ar: 'الأبناء والذرّيّة. يعكس سابتامشا النسل والخصوبة والاستمرار الإبداعيّ.'}),
  _Varga(9, 'Navamsha', {AppLang.en: 'Marriage', AppLang.ur: 'شادی', AppLang.hi: 'विवाह', AppLang.ar: 'الزواج'}, {AppLang.en: 'The most important chart after D1. It reveals marriage and the spouse, your deeper purpose, and the true inner strength of each planet. A planet strong in D1 but weak here loses much of its promise.', AppLang.ur: 'D1 کے بعد سب سے اہم چارٹ۔ یہ شادی اور جیون ساتھی، آپ کے گہرے مقصد، اور ہر سیارے کی اصل اندرونی طاقت دکھاتا ہے۔ جو سیارہ D1 میں مضبوط مگر یہاں کمزور ہو، اپنا وعدہ پورا نہیں کرتا۔', AppLang.hi: 'D1 के बाद सबसे महत्वपूर्ण चार्ट। यह विवाह और जीवनसाथी, आपके गहरे उद्देश्य, और हर ग्रह की वास्तविक आंतरिक शक्ति दिखाता है। जो ग्रह D1 में मज़बूत पर यहाँ कमज़ोर हो, अपना वादा पूरा नहीं करता।', AppLang.ar: 'أهمّ مخطّط بعد D1. يكشف الزواج والشريك، وهدفك الأعمق، والقوّة الداخليّة الحقيقيّة لكلّ كوكب. والكوكب القويّ في D1 لكنّه ضعيف هنا لا يفي بوعده.'}),
  _Varga(10, 'Dashamsha', {AppLang.en: 'Career', AppLang.ur: 'کیریئر', AppLang.hi: 'करियर', AppLang.ar: 'المهنة'}, {AppLang.en: 'Career and public life. It shows your profession, status, achievements and reputation in the world.', AppLang.ur: 'کیریئر اور سماجی زندگی۔ یہ آپ کے پیشے، رتبے، کامیابیوں اور شہرت کو دکھاتا ہے۔', AppLang.hi: 'करियर और सार्वजनिक जीवन। यह आपके पेशे, पद, उपलब्धियों और प्रतिष्ठा को दिखाता है।', AppLang.ar: 'المهنة والحياة العامّة. يُظهر مهنتك ومكانتك وإنجازاتك وسمعتك في العالم.'}),
  _Varga(12, 'Dwadashamsha', {AppLang.en: 'Parents', AppLang.ur: 'والدین', AppLang.hi: 'माता-पिता', AppLang.ar: 'الوالدان'}, {AppLang.en: 'Parents and ancestry. It reflects your mother and father, their wellbeing, and what you inherit from your lineage.', AppLang.ur: 'والدین اور نسب۔ یہ ماں باپ، اُن کی خیریت اور خاندانی ورثے کو ظاہر کرتا ہے۔', AppLang.hi: 'माता-पिता और वंश। यह माता-पिता, उनकी भलाई और पारिवारिक विरासत को दर्शाता है।', AppLang.ar: 'الوالدان والأصل. يعكس الأمّ والأب وعافيتهما وما تَرِثه من نسبك.'}),
  _Varga(16, 'Shodashamsha', {AppLang.en: 'Comforts', AppLang.ur: 'آسائشیں', AppLang.hi: 'सुख', AppLang.ar: 'الرفاهية'}, {AppLang.en: 'Vehicles, comforts and luxuries. It indicates material happiness, conveyances and the ease (or unease) of everyday life.', AppLang.ur: 'سواریاں، آسائشیں اور آرام۔ یہ مادی خوشی، سواری اور روزمرہ زندگی کی آسانی (یا مشکل) بتاتا ہے۔', AppLang.hi: 'वाहन, सुख और विलासिता। यह भौतिक सुख, सवारी और दैनिक जीवन की सहजता (या असहजता) बताता है।', AppLang.ar: 'المركبات والرفاهية ووسائل الراحة. يدلّ على السعادة المادّيّة والمركبات ويسر الحياة اليوميّة أو عسرها.'}),
  _Varga(20, 'Vimshamsha', {AppLang.en: 'Inner growth', AppLang.ur: 'باطنی نشوونما', AppLang.hi: 'आंतरिक विकास', AppLang.ar: 'النموّ الداخلي'}, {AppLang.en: 'Inner growth and the spiritual side of life. It reflects devotion, discipline of the mind, and progress along a personal or spiritual path.', AppLang.ur: 'باطنی نشوونما اور روحانی پہلو۔ یہ لگن، ذہنی نظم اور کسی ذاتی یا روحانی راہ پر پیش رفت کو ظاہر کرتا ہے۔', AppLang.hi: 'आंतरिक विकास और जीवन का आध्यात्मिक पक्ष। यह लगन, मन के अनुशासन और किसी व्यक्तिगत या आध्यात्मिक राह पर प्रगति को दर्शाता है।', AppLang.ar: 'النموّ الداخليّ والجانب الروحيّ من الحياة. يعكس الإخلاص وانضباط الذهن والتقدّم في مسارٍ شخصيٍّ أو روحيّ.'}),
  _Varga(24, 'Chaturvimshamsha', {AppLang.en: 'Education', AppLang.ur: 'تعلیم', AppLang.hi: 'शिक्षा', AppLang.ar: 'التعليم'}, {AppLang.en: 'Education and learning. It shows academic success, knowledge, and skill in study.', AppLang.ur: 'تعلیم اور سیکھنا۔ یہ علمی کامیابی، علم اور پڑھائی میں مہارت دکھاتا ہے۔', AppLang.hi: 'शिक्षा और ज्ञान। यह शैक्षणिक सफलता, ज्ञान और अध्ययन में दक्षता दिखाता है।', AppLang.ar: 'التعليم والمعرفة. يُظهر النجاح الدراسيّ والعلم والمهارة في التحصيل.'}),
  _Varga(27, 'Bhamsha', {AppLang.en: 'Strength', AppLang.ur: 'قوت', AppLang.hi: 'बल', AppLang.ar: 'القوّة'}, {AppLang.en: 'Strengths and weaknesses. It measures overall vitality, stamina and the underlying durability of body and mind.', AppLang.ur: 'قوت اور کمزوری۔ یہ مجموعی توانائی، قوتِ برداشت اور جسم و ذہن کی بنیادی مضبوطی ناپتا ہے۔', AppLang.hi: 'बल और दुर्बलता। यह समग्र ऊर्जा, सहनशक्ति और शरीर व मन की मूल मज़बूती मापता है।', AppLang.ar: 'القوّة والضعف. يقيس الحيويّة العامّة والقدرة على التحمّل ومتانة الجسد والعقل الأساسيّة.'}),
  _Varga(30, 'Trimshamsha', {AppLang.en: 'Troubles', AppLang.ur: 'مشکلات', AppLang.hi: 'कष्ट', AppLang.ar: 'المصاعب'}, {AppLang.en: 'Troubles and vulnerabilities. It points to weaknesses, health risks and the difficulties one must guard against.', AppLang.ur: 'مشکلات اور کمزوریاں۔ یہ کمزور پہلوؤں، صحت کے خطرات اور اُن مشکلات کی نشاندہی کرتا ہے جن سے بچنا ہے۔', AppLang.hi: 'कष्ट और कमज़ोरियाँ। यह कमज़ोर पहलुओं, स्वास्थ्य जोखिमों और उन कठिनाइयों की ओर इशारा करता है जिनसे बचना है।', AppLang.ar: 'المصاعب ومواطن الضعف. يشير إلى نقاط الضعف والمخاطر الصحّيّة والصعوبات التي ينبغي الحذر منها.'}),
  _Varga(40, 'Khavedamsha', {AppLang.en: 'Maternal', AppLang.ur: 'مادری', AppLang.hi: 'मातृ-पक्ष', AppLang.ar: 'من الأمّ'}, {AppLang.en: 'Maternal legacy. It reflects matrilineal influences and the auspicious or challenging effects passed down the mother’s line.', AppLang.ur: 'مادری ورثہ۔ یہ ماں کی طرف سے اثرات اور ننہیال سے ملنے والے اچھے یا مشکل اثرات دکھاتا ہے۔', AppLang.hi: 'मातृ-पक्ष की विरासत। यह माँ की ओर से प्रभाव और ननिहाल से मिलने वाले शुभ या कठिन प्रभाव दिखाता है।', AppLang.ar: 'إرث جهة الأمّ. يعكس تأثيرات الخطّ الأموميّ وما ينتقل منه من آثارٍ ميمونةٍ أو صعبة.'}),
  _Varga(45, 'Akshavedamsha', {AppLang.en: 'Paternal', AppLang.ur: 'پدری', AppLang.hi: 'पितृ-पक्ष', AppLang.ar: 'من الأب'}, {AppLang.en: 'Paternal legacy and character. It reflects the father’s line, conduct, and one’s overall moral character.', AppLang.ur: 'پدری ورثہ اور کردار۔ یہ باپ کی طرف، چال چلن اور مجموعی اخلاقی کردار کو ظاہر کرتا ہے۔', AppLang.hi: 'पितृ-पक्ष और चरित्र। यह पिता की ओर, आचरण और समग्र नैतिक चरित्र को दर्शाता है।', AppLang.ar: 'إرث جهة الأب والأخلاق. يعكس خطّ الأب والسلوك والطابع الأخلاقيّ العامّ.'}),
  _Varga(60, 'Shashtiamsha', {AppLang.en: 'Karma', AppLang.ur: 'کرم', AppLang.hi: 'कर्म', AppLang.ar: 'القدر'}, {AppLang.en: 'The most subtle chart — a fine summary of the whole life. In tradition it reflects deep-rooted tendencies and past-life karma, and needs a very precise birth time.', AppLang.ur: 'سب سے باریک چارٹ — پوری زندگی کا مہین خلاصہ۔ روایت میں یہ گہری فطری رجحانات اور پچھلے جنم کے کرموں کو ظاہر کرتا ہے، اور اِس کے لیے پیدائش کا وقت سیکنڈوں تک درست ہونا ضروری ہے۔', AppLang.hi: 'सबसे सूक्ष्म चार्ट — पूरे जीवन का महीन सारांश। परंपरा में यह गहरी प्रवृत्तियों और पूर्व-जन्म के कर्मों को दर्शाता है, और इसके लिए जन्म-समय सेकंड तक सही होना ज़रूरी है।', AppLang.ar: 'أدقّ المخطّطات — خلاصةٌ رقيقةٌ للحياة كلّها. وهو في التقليد يعكس النزعات العميقة وقَدَر الأعمال السابقة، ويتطلّب وقت ميلادٍ دقيقًا حتى الثواني.'}),
];

const Map<AppLang, String> _vgHead = {AppLang.en: 'What this means for you', AppLang.ur: 'آپ کے لیے اس کا مطلب', AppLang.hi: 'आपके लिए इसका अर्थ', AppLang.ar: 'ماذا يعني لك'};
const Map<String, Map<AppLang, String>> _vgInfl = {
  'strong': {AppLang.en: 'A strong, supportive influence on your {t}.', AppLang.ur: 'آپ کے {t} پر ایک مضبوط، سازگار اثر۔', AppLang.hi: 'आपके {t} पर एक मज़बूत, सहायक प्रभाव।', AppLang.ar: 'تأثيرٌ قويّ وداعمٌ على {t}.'},
  'tender': {AppLang.en: 'A tender spot for your {t} — patience helps here.', AppLang.ur: 'آپ کے {t} کے لیے ایک نازک پہلو — یہاں صبر مددگار ہے۔', AppLang.hi: 'आपके {t} के लिए एक कोमल पक्ष — यहाँ धैर्य सहायक है।', AppLang.ar: 'موضعٌ رقيقٌ لـ{t} — يساعد الصبر هنا.'},
};
const Map<String, Map<AppLang, String>> _vgOverall = {
  'good': {AppLang.en: 'Overall, your {t} chart looks supportive and promising.', AppLang.ur: 'مجموعی طور پر، آپ کا {t} چارٹ سازگار اور حوصلہ افزا لگتا ہے۔', AppLang.hi: 'कुल मिलाकर, आपका {t} चार्ट सहायक और आशाजनक दिखता है।', AppLang.ar: 'إجمالًا، يبدو مخطّط {t} لديك داعمًا وواعدًا.'},
  'mixed': {AppLang.en: 'Overall, your {t} chart is mixed — strengths and lessons together.', AppLang.ur: 'مجموعی طور پر، آپ کا {t} چارٹ ملا جلا ہے — طاقتیں اور سبق ساتھ ساتھ۔', AppLang.hi: 'कुल मिलाकर, आपका {t} चार्ट मिश्रित है — शक्तियाँ और सबक साथ।', AppLang.ar: 'إجمالًا، مخطّط {t} لديك مختلط — قوّةٌ ودروسٌ معًا.'},
  'tender': {AppLang.en: 'Overall, your {t} chart is tender — it rewards patience and care.', AppLang.ur: 'مجموعی طور پر، آپ کا {t} چارٹ نازک ہے — یہ صبر اور توجہ کا صلہ دیتا ہے۔', AppLang.hi: 'कुल मिलाकर, आपका {t} चार्ट कोमल है — यह धैर्य और देखभाल का प्रतिफल देता है।', AppLang.ar: 'إجمالًا، مخطّط {t} لديك رقيق — يكافئ الصبر والعناية.'},
};
String _vgBalanced(AppLang l, String t) {
  switch (l) {
    case AppLang.ur: return 'یہاں سیارے متوازن برجوں میں ہیں — ایک مستحکم، ہموار $t تصویر۔';
    case AppLang.hi: return 'यहाँ ग्रह संतुलित राशियों में हैं — एक स्थिर, समतल $t तस्वीर।';
    case AppLang.ar: return 'الكواكب هنا في أبراجٍ متوازنة — صورةٌ ثابتةٌ ومتّزنةٌ لـ$t.';
    default: return 'The planets sit in balanced signs here — a steady, even picture for your $t.';
  }
}
const Map<AppLang, String> _vuiTitle = {AppLang.en: 'Divisional Charts', AppLang.ur: 'تقسیمی چارٹس', AppLang.hi: 'विभाजन कुंडलियाँ', AppLang.ar: 'المخطّطات التقسيمية'};
const Map<AppLang, String> _vuiSub = {AppLang.en: 'D1 – D60 · from your birth chart', AppLang.ur: 'D1 – D60 · آپ کے پیدائشی چارٹ سے', AppLang.hi: 'D1 – D60 · आपके जन्म चार्ट से', AppLang.ar: 'D1 – D60 · من مخطّط ميلادك'};
const Map<AppLang, String> _vuiShows = {AppLang.en: 'What it shows', AppLang.ur: 'یہ کیا دکھاتا ہے', AppLang.hi: 'यह क्या दिखाता है', AppLang.ar: 'ماذا يُظهر'};
const Map<AppLang, String> _vuiPlacements = {AppLang.en: 'Placements', AppLang.ur: 'مقامات', AppLang.hi: 'स्थितियाँ', AppLang.ar: 'المواضع'};
const Map<AppLang, String> _vuiNote = {AppLang.en: 'Calculated by dividing each 30° sign into {d} equal parts (Parashari rules) from your Lahiri sidereal birth positions.', AppLang.ur: 'ہر ۳۰° برج کو {d} برابر حصوں میں تقسیم کر کے (پراشر اصول) آپ کی Lahiri sidereal پیدائشی پوزیشنز سے نکالا گیا۔', AppLang.hi: 'प्रत्येक 30° राशि को {d} बराबर भागों में बाँटकर (पराशर नियम) आपकी लाहिड़ी निरयन जन्म-स्थितियों से गणना की गई।', AppLang.ar: 'تُحسب بقسمة كلّ برجٍ (30°) إلى {d} أجزاءٍ متساوية (قواعد بَراشَرا) من مواقع ميلادك الفلكية (لاهيري).'};

class DivisionalCharts extends StatefulWidget {
  final LiveChart chart; // vedic (sidereal) chart
  final AppLang l;
  final Color accent;
  const DivisionalCharts({super.key, required this.chart, required this.l,
    required this.accent});
  @override
  State<DivisionalCharts> createState() => _DivisionalChartsState();
}

class _DivisionalChartsState extends State<DivisionalCharts> {
  int _cur = 0;

  LiveChart _vChart(int d) {
    final ascV = _vargaSign(widget.chart.asc, d);
    final byKey = {for (final b in widget.chart.bodies) b.key: b};
    final bodies = <LiveBody>[];
    for (final k in _rGrahas) {
      final b = byKey[k];
      if (b == null) continue;
      final vs = _vargaSign(b.lon, d);
      final house = ((vs - ascV) % 12 + 12) % 12 + 1;
      bodies.add(LiveBody(k, vs * 30.0 + 15, b.retro, vs, house));
    }
    return LiveChart(ascV * 30.0 + 15, 0, ascV, bodies);
  }

  Widget _pImg(String key) => CachedNetworkImage(
    imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[key]}',
    width: 18, height: 18, fit: BoxFit.contain,
    errorWidget: (_, __, ___) => const SizedBox(width: 18, height: 18));

  List<Widget> _readingLines(_Varga v) {
    final l = widget.l;
    final theme = v.short[l]!;
    final byKey = {for (final b in widget.chart.bodies) b.key: b};
    final strong = <List<Object>>[], tender = <List<Object>>[];
    for (final k in _rGrahas) {
      final b = byKey[k];
      if (b == null) continue;
      final sg = _vargaSign(b.lon, v.d);
      final dig = _rDignity(k, sg);
      if (dig == 'exalt' || dig == 'own') {
        strong.add([k, sg, dig]);
      } else if (dig == 'debil') {
        tender.add([k, sg, dig]);
      }
    }
    final out = <Widget>[
      Text(_vgHead[l]!, style: TextStyle(color: widget.accent, fontSize: 13.5,
        fontWeight: FontWeight.w800, fontFamily: urduFont)),
      const SizedBox(height: 6),
    ];
    if (strong.isEmpty && tender.isEmpty) {
      out.add(Text(_vgBalanced(l, theme), style: const TextStyle(color: kOn,
        fontSize: 13, height: 1.6)));
    } else {
      for (final e in [...strong, ...tender]) {
        final k = e[0] as String, sg = e[1] as int, dig = e[2] as String;
        final kind = (dig == 'exalt' || dig == 'own') ? 'strong' : 'tender';
        final signName = signs[sg].name[l] ?? signs[sg].name[AppLang.en]!;
        final infl = _vgInfl[kind]![l]!.replaceAll('{t}', theme);
        out.add(Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _pImg(k),
            const SizedBox(width: 8),
            Expanded(child: Text.rich(TextSpan(children: [
              TextSpan(text: _rPlanetName[k]![l]!,
                style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: ' — '),
              TextSpan(text: _rDig[dig]![l]!, style: TextStyle(
                color: _rDigColor(dig), fontWeight: FontWeight.w700)),
              TextSpan(text: ' ($signName). $infl'),
            ]), style: TextStyle(color: kOn, fontSize: 12.5, height: 1.55,
              fontFamily: urduFont))),
          ])));
      }
    }
    final cat = strong.length > tender.length
      ? 'good' : (tender.length > strong.length ? 'tender' : 'mixed');
    out.add(const SizedBox(height: 8));
    out.add(Text(_vgOverall[cat]![l]!.replaceAll('{t}', theme),
      style: TextStyle(color: widget.accent, fontSize: 13,
        fontWeight: FontWeight.w700, height: 1.55, fontFamily: urduFont)));
    return out;
  }

  Widget _placeRow(String k) {
    final l = widget.l;
    final byKey = {for (final b in widget.chart.bodies) b.key: b};
    final b = byKey[k];
    if (b == null) return const SizedBox.shrink();
    final vs = _vargaSign(b.lon, _vargas[_cur].d);
    final signName = signs[vs].name[l] ?? signs[vs].name[AppLang.en]!;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        _pImg(k),
        const SizedBox(width: 10),
        Expanded(child: Text(_rPlanetName[k]![l]!,
          style: const TextStyle(color: kOn, fontSize: 13,
            fontWeight: FontWeight.w700, fontFamily: null))),
        Text(signName, style: TextStyle(color: kMuted, fontSize: 13,
          fontWeight: FontWeight.w600, fontFamily: urduFont)),
      ]));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final v = _vargas[_cur];
    final vChart = _vChart(v.d);
    return card(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_vuiTitle[l]!, style: TextStyle(color: widget.accent, fontSize: 17,
          fontWeight: FontWeight.w800, fontFamily: urduFont)),
        const SizedBox(height: 2),
        Text(_vuiSub[l]!, style: TextStyle(color: kMuted, fontSize: 12,
          fontFamily: urduFont)),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: _vargas.asMap().entries.map((e) {
            final i = e.key, vv = e.value;
            final sel = i == _cur;
            return Padding(padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(onTap: () => setState(() => _cur = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: sel ? widget.accent : kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? widget.accent : kBorder)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('D${vv.d}', style: TextStyle(color: sel ? kBg : kOn,
                      fontWeight: FontWeight.w800, fontSize: 13)),
                    Text(vv.short[l]!, style: TextStyle(
                      color: sel ? kBg : kMuted, fontSize: 9.5,
                      fontWeight: FontWeight.w600, fontFamily: urduFont)),
                  ]))));
          }).toList())),
        const SizedBox(height: 14),
        NatalChartView(chart: vChart, vedic: true, boxMode: true,
          houseRefSign: vChart.ascSign, ascWord: 'La', pillColor: widget.accent,
          showDeg: false),
        const SizedBox(height: 14),
        Text('D${v.d} · ${v.name}', style: TextStyle(color: widget.accent,
          fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_vuiShows[l]!.toUpperCase(), style: const TextStyle(color: kMuted,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(v.sig[l]!, style: const TextStyle(color: kOn, fontSize: 13,
          height: 1.6)),
        const SizedBox(height: 12),
        Text(_vuiPlacements[l]!.toUpperCase(), style: const TextStyle(
          color: kMuted, fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 0.5)),
        const SizedBox(height: 4),
        ..._rGrahas.map(_placeRow),
        const Divider(color: kBorder, height: 22),
        ..._readingLines(v),
        const SizedBox(height: 10),
        Text(_vuiNote[l]!.replaceAll('{d}', '${v.d}'),
          style: TextStyle(color: kMuted, fontSize: 11,
            fontStyle: FontStyle.italic, fontFamily: urduFont)),
      ]));
  }
}

// ===========================================================================
// BIRTH CHART tab — the user's own natal chart (Western + Vedic). Replaces the
// old duplicate Zodiac grid. v1: one saved birth profile (date/time/place) →
// box + round natal chart (via NatalChartView) + planet positions table with
// sign, nakshatra (Vedic), house and retrograde. Plus the per-planet reading.
// ===========================================================================
class BirthChartTab extends StatefulWidget {
  const BirthChartTab({super.key});
  @override
  State<BirthChartTab> createState() => _BirthChartTabState();
}

class _BirthChartTabState extends State<BirthChartTab> {
  bool _set = false;       // a birth profile has been saved
  bool _editing = false;   // showing the entry form
  String _name = '';
  int _y = 0, _mo = 0, _d = 0, _hh = 0, _mi = 0;
  // Birthplace — worldwide (Open-Meteo geocoding + IANA timezone).
  double _lat = 25.29, _lon = 51.53;
  String _tzName = 'Asia/Qatar', _cityName = 'Doha', _cc = 'QA';
  bool _datePicked = false, _timePicked = false, _placePicked = false;
  String? _gender;         // 'male' | 'female' | null
  bool _boxMode = false;   // circle (false) / box (true)
  // House reference — Western: 'sun'|'asc' (default Sun, like the website);
  // Vedic: 'moon'|'asc' (default Ascendant/Lagna). Rearranges chart + table +
  // reading when changed.
  String _refW = 'sun';
  String _refV = 'asc';
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _set = prefs.getBool('bSet') ?? false;
    _name = prefs.getString('bName') ?? '';
    _y = prefs.getInt('bY') ?? 0;
    _mo = prefs.getInt('bMo') ?? 0;
    _d = prefs.getInt('bD') ?? 0;
    _hh = prefs.getInt('bH') ?? 0;
    _mi = prefs.getInt('bMi') ?? 0;
    _lat = prefs.getDouble('bLat') ?? 25.29;
    _lon = prefs.getDouble('bLon') ?? 51.53;
    _tzName = prefs.getString('bTz') ?? 'Asia/Qatar';
    _cityName = prefs.getString('bCityName') ?? 'Doha';
    _cc = prefs.getString('bCC') ?? 'QA';
    _datePicked = _y > 0 && _mo > 0 && _d > 0;
    _timePicked = prefs.getBool('bTimeSet') ?? false;
    _placePicked = prefs.getString('bTz') != null;
    final g = prefs.getString('bGender');
    _gender = (g == null || g.isEmpty) ? null : g;
    _nameCtrl.text = _name;
    _editing = !_set;
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  String _t(Map<AppLang, String> m) => m[currentLang.value] ?? m[AppLang.en]!;

  // ---- birth moment → chart -------------------------------------------------
  LiveChart _compute(bool vedic) {
    // Birth wall-clock is local to the birth city. Use the IANA timezone (DST-
    // aware) to convert to real UTC; fall back to treating it as UTC if the
    // zone name is somehow unknown.
    DateTime utc;
    try {
      final loc = tz.getLocation(_tzName);
      utc = tz.TZDateTime(loc, _y, _mo, _d, _hh, _mi).toUtc();
    } catch (_) {
      utc = DateTime.utc(_y, _mo, _d, _hh, _mi);
    }
    return computeChart(utc, _lat, _lon, vedic);
  }

  String _nak(double lon) =>
    _nakshatras[(_norm(lon) / (360.0 / 27.0)).floor().clamp(0, 26)];
  String _dateStr() =>
    '${_d.toString().padLeft(2, '0')}/${_mo.toString().padLeft(2, '0')}/$_y';
  String _timeStr() =>
    '${_hh.toString().padLeft(2, '0')}:${_mi.toString().padLeft(2, '0')}';
  String _birthLine() =>
    '${_dateStr()}  ·  ${_timeStr()}  ·  $_cityName ${_flag(_cc)}';

  // ---- pickers --------------------------------------------------------------
  ThemeData _pickerTheme(BuildContext ctx) => Theme.of(ctx).copyWith(
    colorScheme: const ColorScheme.dark(
      primary: kPrimary, onPrimary: Colors.white,
      surface: kCard, onSurface: kOn));

  Future<void> _pickDate() async {
    final r = await showDatePicker(
      context: context,
      initialDate: _datePicked ? DateTime(_y, _mo, _d) : DateTime(1995, 1, 1),
      firstDate: DateTime(1900), lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!));
    if (r != null) {
      setState(() { _y = r.year; _mo = r.month; _d = r.day; _datePicked = true; });
    }
  }

  Future<void> _pickTime() async {
    final r = await showTimePicker(
      context: context,
      initialTime: _timePicked
        ? TimeOfDay(hour: _hh, minute: _mi) : const TimeOfDay(hour: 7, minute: 30),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!));
    if (r != null) {
      setState(() { _hh = r.hour; _mi = r.minute; _timePicked = true; });
    }
  }

  Future<void> _pickCity() async {
    final c = await showModalBottomSheet<Map<String, dynamic>>(
      context: context, backgroundColor: kCard, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const CitySearchSheet());
    if (c == null) return;
    setState(() {
      _cityName = '${c['name']}';
      _cc = (c['country_code'] as String?) ?? '';
      _lat = (c['latitude'] as num).toDouble();
      _lon = (c['longitude'] as num).toDouble();
      _tzName = (c['timezone'] as String?) ?? 'UTC';
      _placePicked = true;
    });
  }

  void _save() {
    _name = _nameCtrl.text.trim();
    prefs.setBool('bSet', true);
    prefs.setBool('bTimeSet', true);
    prefs.setString('bName', _name);
    prefs.setInt('bY', _y);
    prefs.setInt('bMo', _mo);
    prefs.setInt('bD', _d);
    prefs.setInt('bH', _hh);
    prefs.setInt('bMi', _mi);
    prefs.setDouble('bLat', _lat);
    prefs.setDouble('bLon', _lon);
    prefs.setString('bTz', _tzName);
    prefs.setString('bCityName', _cityName);
    prefs.setString('bCC', _cc);
    prefs.setString('bGender', _gender ?? '');
    setState(() { _set = true; _editing = false; });
  }

  // ---- form widgets ---------------------------------------------------------
  Widget _genderPill(String key, IconData ic, String label) {
    final sel = _gender == key;
    final acc = accentColor(useVedic.value);
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _gender = sel ? null : key),
      child: AnimatedContainer(duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: sel ? acc : kBg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sel ? acc : kBorder)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ic, size: 16, color: sel ? kBg : kMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: sel ? kBg : kOn,
            fontWeight: FontWeight.w700, fontSize: 13.5, fontFamily: urduFont)),
        ]))));
  }

  Widget _pickRow(String label, String value, IconData ic, VoidCallback tap) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(onTap: tap, borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(color: kBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder)),
          child: Row(children: [
            Icon(ic, color: accentColor(useVedic.value), size: 18),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: kMuted,
              fontSize: 13.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            Flexible(child: Text(value, textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: kOn, fontSize: 14,
                fontWeight: FontWeight.w700))),
          ]))));

  Widget _form() {
    final canShow = _datePicked && _timePicked && _placePicked;
    return ListView(
      padding: EdgeInsets.fromLTRB(18, 18, 18,
        28 + MediaQuery.of(context).viewPadding.bottom),
      children: [
        Center(child: Text(_t({
          AppLang.en: 'Your Birth Chart', AppLang.ur: 'آپ کا پیدائشی چارٹ',
          AppLang.hi: 'आपकी जन्म कुंडली', AppLang.ar: 'خريطة ميلادك'}),
          style: TextStyle(color: accentColor(useVedic.value), fontSize: 21,
            fontWeight: FontWeight.w800, fontFamily: urduFont))),
        const SizedBox(height: 6),
        Center(child: Text(_t({
          AppLang.en: 'Enter your birth date, time and place to see your natal chart.',
          AppLang.ur: 'اپنی پیدائش کی تاریخ، وقت اور جگہ درج کریں۔',
          AppLang.hi: 'अपनी जन्म तिथि, समय और स्थान भरें।',
          AppLang.ar: 'أدخل تاريخ ووقت ومكان ميلادك.'}),
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, fontSize: 13.5, height: 1.6))),
        const SizedBox(height: 18),
        card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: kOn, fontSize: 15,
                fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: _t({AppLang.en: 'Name (optional)',
                  AppLang.ur: 'نام (اختیاری)', AppLang.hi: 'नाम (वैकल्पिक)',
                  AppLang.ar: 'الاسم (اختياري)'}),
                hintStyle: const TextStyle(color: kMuted),
                isDense: true, filled: true, fillColor: kBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: accentColor(useVedic.value))))),
            const SizedBox(height: 10),
            Row(children: [
              _genderPill('male', Icons.male,
                _t({AppLang.en: 'Male', AppLang.ur: 'مرد', AppLang.hi: 'पुरुष', AppLang.ar: 'ذكر'})),
              _genderPill('female', Icons.female,
                _t({AppLang.en: 'Female', AppLang.ur: 'عورت', AppLang.hi: 'महिला', AppLang.ar: 'أنثى'})),
            ]),
            const SizedBox(height: 6),
            _pickRow(_t({AppLang.en: 'Date', AppLang.ur: 'تاریخ',
              AppLang.hi: 'तिथि', AppLang.ar: 'التاريخ'}),
              _datePicked ? _dateStr() : _t({AppLang.en: 'Select',
                AppLang.ur: 'منتخب کریں', AppLang.hi: 'चुनें', AppLang.ar: 'اختر'}),
              Icons.calendar_today, _pickDate),
            _pickRow(_t({AppLang.en: 'Time', AppLang.ur: 'وقت',
              AppLang.hi: 'समय', AppLang.ar: 'الوقت'}),
              _timePicked ? _timeStr() : _t({AppLang.en: 'Select',
                AppLang.ur: 'منتخب کریں', AppLang.hi: 'चुनें', AppLang.ar: 'اختر'}),
              Icons.access_time, _pickTime),
            _pickRow(_t({AppLang.en: 'Place', AppLang.ur: 'جگہ',
              AppLang.hi: 'स्थान', AppLang.ar: 'المكان'}),
              _placePicked
                ? '$_cityName ${_flag(_cc)}'
                : _t({AppLang.en: 'Search', AppLang.ur: 'تلاش',
                    AppLang.hi: 'खोजें', AppLang.ar: 'ابحث'}),
              Icons.place, _pickCity),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: canShow ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor(useVedic.value),
                disabledBackgroundColor: kCard,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
              child: Text(_t({AppLang.en: 'Show my chart',
                AppLang.ur: 'میرا چارٹ دکھائیں', AppLang.hi: 'मेरी कुंडली दिखाएँ',
                AppLang.ar: 'اعرض خريطتي'}),
                style: TextStyle(
                  // gold button → dark text; purple button → white text.
                  color: !canShow ? kMuted
                    : (useVedic.value ? Colors.white : kBg),
                  fontSize: 15,
                  fontWeight: FontWeight.w800, fontFamily: urduFont)))),
            if (_set) Center(child: TextButton(
              onPressed: () => setState(() => _editing = false),
              child: Text(_t({AppLang.en: 'Cancel', AppLang.ur: 'منسوخ',
                AppLang.hi: 'रद्द करें', AppLang.ar: 'إلغاء'}),
                style: const TextStyle(color: kMuted,
                  fontWeight: FontWeight.w700)))),
          ])),
      ]);
  }

  // ---- chart view widgets ---------------------------------------------------
  Widget _viewToggle(bool box, IconData ic) {
    final active = _boxMode == box;
    final acc = accentColor(useVedic.value);
    return Material(
      color: active ? acc : kCard, shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _boxMode = box),
        child: Padding(padding: const EdgeInsets.all(9),
          child: Icon(ic, color: active ? kBg : acc, size: 22))));
  }

  Widget _planetRow(LiveBody b, bool vedic, AppLang l, int refSign) {
    final sName = signs[b.sign].name[l] ?? signs[b.sign].name[AppLang.en]!;
    final house = ((b.sign - refSign) % 12 + 12) % 12 + 1;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 28, height: 28, child: Stack(
          clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (b.retro) CachedNetworkImage(
              imageUrl: '$kWebsite/app/planet-icons-v2/retroglow.png',
              width: 26, height: 26, fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox.shrink()),
            CachedNetworkImage(
              imageUrl: '$kWebsite/app/planet-icons-v2/${_livePlanetIcon[b.key]}',
              width: 20, height: 20, fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox(width: 20, height: 20)),
          ])),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: Text(b.key,
          style: const TextStyle(color: kOn, fontSize: 13.5,
            fontWeight: FontWeight.w700))),
        Expanded(flex: 4, child: Text('$sName ${_fmtDeg(b.lon)}',
          style: TextStyle(color: kMuted, fontSize: 12.5,
            fontWeight: FontWeight.w600, fontFamily: urduFont))),
        if (vedic) Expanded(flex: 3, child: Text(_nak(b.lon),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: accentColor(vedic), fontSize: 11.5,
            fontWeight: FontWeight.w600))),
        if (b.retro) const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('R', style: TextStyle(color: Colors.redAccent,
            fontSize: 11, fontWeight: FontWeight.w800))),
        SizedBox(width: 30, child: Text('H$house', textAlign: TextAlign.end,
          style: TextStyle(color: accentColor(vedic), fontSize: 12,
            fontWeight: FontWeight.w700))),
      ]));
  }

  // House-reference segmented control. Western: Sun / Asc. Vedic: Moon / Asc.
  // Compact (sizes to content) so it fits on the same row as circle/box.
  Widget _refHalf(String key, String? icon, String label, String cur,
      Color acc, void Function(String) onSet) {
    final sel = cur == key;
    return GestureDetector(onTap: () => onSet(key),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? acc : Colors.transparent,
          borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon != null
              ? CachedNetworkImage(
                  imageUrl: '$kWebsite/app/planet-icons-v2/$icon',
                  width: 16, height: 16, fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox(width: 16, height: 16))
              : Icon(Icons.arrow_upward, size: 15, color: sel ? kBg : acc),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: sel ? kBg : kMuted,
              fontWeight: FontWeight.w700, fontSize: 12.5,
              fontFamily: urduFont)),
          ])));
  }

  Widget _refSeg(bool vedic, Color acc) {
    final cur = vedic ? _refV : _refW;
    void onSet(String k) =>
      setState(() { if (vedic) { _refV = k; } else { _refW = k; } });
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kCard,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: kBorder)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _refHalf(vedic ? 'moon' : 'sun', vedic ? 'moon.png' : 'sun.png',
          vedic
            ? _t({AppLang.en: 'Moon', AppLang.ur: 'چاند', AppLang.hi: 'चंद्र', AppLang.ar: 'القمر'})
            : _t({AppLang.en: 'Sun', AppLang.ur: 'سورج', AppLang.hi: 'सूर्य', AppLang.ar: 'الشمس'}),
          cur, acc, onSet),
        _refHalf('asc', null,
          _t({AppLang.en: 'Asc', AppLang.ur: 'طالع', AppLang.hi: 'लग्न', AppLang.ar: 'الطالع'}),
          cur, acc, onSet),
      ]));
  }

  String _genderLabel(AppLang l) {
    if (_gender == 'male') {
      return _t({AppLang.en: 'Male', AppLang.ur: 'مرد', AppLang.hi: 'पुरुष', AppLang.ar: 'ذكر'});
    }
    if (_gender == 'female') {
      return _t({AppLang.en: 'Female', AppLang.ur: 'عورت', AppLang.hi: 'महिला', AppLang.ar: 'أنثى'});
    }
    return '';
  }

  String _shareCaption(bool vedic, int refSign, AppLang l) {
    final signName = signs[refSign].name[l] ?? signs[refSign].name[AppLang.en]!;
    final refMode = vedic ? _refV : _refW;
    final refLabel = refMode == 'asc'
      ? (vedic
          ? _t({AppLang.en: 'Lagna', AppLang.ur: 'لگنا', AppLang.hi: 'लग्न', AppLang.ar: 'الطالع'})
          : _t({AppLang.en: 'Ascendant', AppLang.ur: 'طالع', AppLang.hi: 'लग्न', AppLang.ar: 'الطالع'}))
      : (vedic ? _rPlanetName['Moon']![l]! : _rPlanetName['Sun']![l]!);
    final sysName = vedic
      ? _t({AppLang.en: 'Vedic Birth Chart', AppLang.ur: 'ویدک پیدائشی چارٹ', AppLang.hi: 'वैदिक जन्म कुंडली', AppLang.ar: 'خريطة الميلاد الفيدية'})
      : _t({AppLang.en: 'Western Birth Chart', AppLang.ur: 'مغربی پیدائشی چارٹ', AppLang.hi: 'पश्चिमी जन्म कुंडली', AppLang.ar: 'خريطة الميلاد الغربية'});
    return (StringBuffer()
      ..writeln('✦ ${_name.isEmpty ? sysName : '$_name — $sysName'}')
      ..writeln('$refLabel: $signName')
      ..writeln(_birthLine())
      ..writeln('')
      ..writeln('📲 Farooq Stars: $kWebsite')).toString();
  }

  // Share menu: quick colour card, or the full multi-page PDF report.
  Future<void> _shareChart(bool vedic, int refSign, AppLang l,
      LiveChart chart) async {
    final acc = accentColor(vedic);
    await showModalBottomSheet<void>(context: context, backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.image_outlined, color: acc),
            title: Text(_t({AppLang.en: 'Chart card (image)', AppLang.ur: 'چارٹ کارڈ (تصویر)', AppLang.hi: 'चार्ट कार्ड (इमेज)', AppLang.ar: 'بطاقة (صورة)'}),
              style: const TextStyle(color: kOn, fontWeight: FontWeight.w700,
                fontFamily: null)),
            subtitle: Text(_t({AppLang.en: 'Quick — the colour card', AppLang.ur: 'فوری — رنگین کارڈ', AppLang.hi: 'त्वरित — रंगीन कार्ड', AppLang.ar: 'سريع — البطاقة الملوّنة'}),
              style: const TextStyle(color: kMuted, fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _shareCardImage(vedic, refSign, l, chart); }),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: acc),
            title: Text(_t({AppLang.en: 'Full report (PDF)', AppLang.ur: 'مکمل رپورٹ (PDF)', AppLang.hi: 'पूरी रिपोर्ट (PDF)', AppLang.ar: 'التقرير الكامل (PDF)'}),
              style: const TextStyle(color: kOn, fontWeight: FontWeight.w700)),
            subtitle: Text(
              vedic
                ? _t({AppLang.en: 'Card + readings + all D-charts', AppLang.ur: 'کارڈ + ریڈنگ + تمام D-charts', AppLang.hi: 'कार्ड + रीडिंग + सभी D-charts', AppLang.ar: 'البطاقة + القراءات + كل المخططات'})
                : _t({AppLang.en: 'Card + full reading', AppLang.ur: 'کارڈ + مکمل ریڈنگ', AppLang.hi: 'कार्ड + पूरी रीडिंग', AppLang.ar: 'البطاقة + القراءة الكاملة'}),
              style: const TextStyle(color: kMuted, fontSize: 12)),
            onTap: () { Navigator.pop(ctx); _shareFullPdf(vedic, refSign, l, chart); }),
          const SizedBox(height: 12),
        ])));
  }

  Future<void> _shareCardImage(bool vedic, int refSign, AppLang l,
      LiveChart chart) async {
    final text = _shareCaption(vedic, refSign, l);
    showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(
        color: accentColor(vedic))));
    Uint8List? png;
    try { png = await _buildReportImage(vedic, refSign, l, chart); } catch (_) {}
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    try {
      if (png != null) {
        final f = File('${Directory.systemTemp.path}/farooq_card.png');
        await f.writeAsBytes(png);
        await Share.shareXFiles([XFile(f.path)], text: text);
        return;
      }
      final resp = await http.get(Uri.parse(signBigArtUrl(refSign)))
        .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final f = File('${Directory.systemTemp.path}/farooq_birth_$refSign.png');
        await f.writeAsBytes(resp.bodyBytes);
        await Share.shareXFiles([XFile(f.path)], text: text);
        return;
      }
    } catch (_) {/* fall through */}
    await openUrl('https://wa.me/?text=${Uri.encodeComponent(text)}');
  }

  Future<void> _shareFullPdf(bool vedic, int refSign, AppLang l,
      LiveChart chart) async {
    final text = _shareCaption(vedic, refSign, l);
    showDialog<void>(context: context, barrierDismissible: false,
      builder: (_) => Center(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: accentColor(vedic)),
          const SizedBox(height: 14),
          Text(_t({AppLang.en: 'Building your report…', AppLang.ur: 'رپورٹ بن رہی ہے…', AppLang.hi: 'रिपोर्ट बन रही है…', AppLang.ar: 'يُجهّز تقريرك…'}),
            style: const TextStyle(color: kOn, fontSize: 14)),
        ])));
    Uint8List? pdf;
    try { pdf = await _buildFullReportPdf(vedic, refSign, l, chart); } catch (_) {}
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (pdf != null) {
      try {
        final f = File('${Directory.systemTemp.path}/farooq_report.pdf');
        await f.writeAsBytes(pdf);
        await Share.shareXFiles([XFile(f.path)], text: text);
        return;
      } catch (_) {/* fall through */}
    }
    // Fallback: the card image.
    await _shareCardImage(vedic, refSign, l, chart);
  }

  // Assemble the full multi-page PDF: card + reading (+ all D-charts, Vedic).
  Future<Uint8List?> _buildFullReportPdf(bool vedic, int refSign, AppLang l,
      LiveChart chart) async {
    final acc = accentColor(vedic);
    final im = await _fetchRptImgs(vedic, refSign);
    final pages = <List<Object>>[];

    final card = await _buildReportImage(vedic, refSign, l, chart);
    if (card != null) pages.add([card, 1080.0, 1350.0]);

    final rp = await _renderReportPage(
      _readingEls(vedic, refSign, l, chart, im), acc);
    if (rp != null) pages.add(rp);

    if (vedic) {
      for (final v in _vargas) {
        final dp = await _renderReportPage(
          _dChartEls(v, refSign, l, chart, im), acc);
        if (dp != null) pages.add(dp);
      }
    }
    if (pages.isEmpty) return null;

    final doc = pw.Document();
    for (final p in pages) {
      final bytes = p[0] as Uint8List;
      final pw2 = (p[1] as double), ph = (p[2] as double);
      final mem = pw.MemoryImage(bytes);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(pw2, ph),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(mem, fit: pw.BoxFit.fill)));
    }
    return doc.save();
  }

  // Reading page elements (title, intro, per-planet blocks).
  List<_RE> _readingEls(bool vedic, int refSign, AppLang l, LiveChart chart,
      _RptImgs im) {
    final acc = accentColor(vedic);
    final byK = {for (final b in chart.bodies) b.key: b};
    String sn(int i) => signs[i].name[l] ?? signs[i].name[AppLang.en]!;
    int house(int sign) => ((sign - refSign) % 12 + 12) % 12 + 1;
    final sun = byK['Sun'], moon = byK['Moon'];
    final els = <_RE>[
      _reText(vedic ? _rTitleV[l]! : _rTitleW[l]!, 40, acc,
        fw: FontWeight.w800, align: TextAlign.center, gap: 4),
      _reText(_rSub[l]!, 22, kMuted, align: TextAlign.center, gap: 22),
      _reText(_rIntro(l, sun == null ? '' : sn(sun.sign),
        moon == null ? '' : sn(moon.sign)), 25, kOn, gap: 22),
    ];
    for (final k in _rGrahas) {
      final b = byK[k];
      if (b == null) continue;
      final dig = _rDignity(k, b.sign);
      final name = _rPlanetName[k]![l]!;
      final parts = _rSentenceParts(l, name, _rGSig[k]![l]!,
        sn(b.sign), _rTone[_rToneKey(dig)]![l]!);
      els.add(_reIconRich(im.planets[k], [
        TextSpan(text: name, style: TextStyle(color: kOn,
          fontWeight: FontWeight.w800)),
        TextSpan(text: '   ${_rHouseLabel(l, house(b.sign))} · ${_rHouse[house(b.sign) - 1][l]}',
          style: const TextStyle(color: kMuted, fontWeight: FontWeight.w600)),
      ], 25, gap: 4));
      els.add(_reRich([
        TextSpan(text: parts[0]),
        TextSpan(text: _rDig[dig]![l]!, style: TextStyle(
          color: _rDigColor(dig), fontWeight: FontWeight.w700)),
        TextSpan(text: parts[1]),
      ], 24, gap: 20));
    }
    els.add(_reSpace(6));
    els.add(_reText(_rDisc[l]!, 20, kMuted, gap: 0));
    return els;
  }

  // One divisional-chart page: box + description + placements + summary.
  List<_RE> _dChartEls(_Varga v, int refSign, AppLang l, LiveChart chart,
      _RptImgs im) {
    final acc = accentColor(true); // divisional charts are Vedic → purple
    final byK = {for (final b in chart.bodies) b.key: b};
    final ascV = _vargaSign(chart.asc, v.d);
    // Build a synthetic varga chart for the box.
    final vBodies = <LiveBody>[];
    for (final k in _rGrahas) {
      final b = byK[k];
      if (b == null) continue;
      final vs = _vargaSign(b.lon, v.d);
      vBodies.add(LiveBody(k, vs * 30.0 + 15, b.retro, vs,
        ((vs - ascV) % 12 + 12) % 12 + 1));
    }
    final vChart = LiveChart(ascV * 30.0 + 15, 0, ascV, vBodies);
    String sn(int i) => signs[i].name[l] ?? signs[i].name[AppLang.en]!;
    final theme = v.short[l]!;
    final strong = <List<Object>>[], tender = <List<Object>>[];
    for (final k in _rGrahas) {
      final b = byK[k];
      if (b == null) continue;
      final sg = _vargaSign(b.lon, v.d);
      final dig = _rDignity(k, sg);
      if (dig == 'exalt' || dig == 'own') strong.add([k, sg, dig]);
      else if (dig == 'debil') tender.add([k, sg, dig]);
    }
    final els = <_RE>[
      _reText('D${v.d} · ${v.name}', 38, acc, fw: FontWeight.w800,
        align: TextAlign.center, gap: 4),
      _reText(v.short[l]!, 22, kMuted, align: TextAlign.center, gap: 18),
      _reBox(vChart, ascV, im, 560, gap: 18),
      _reText(_vuiShows[l]!.toUpperCase(), 18, kMuted, fw: FontWeight.w700, gap: 4),
      _reText(v.sig[l]!, 24, kOn, gap: 18),
      _reText(_vuiPlacements[l]!.toUpperCase(), 18, kMuted, fw: FontWeight.w700, gap: 6),
    ];
    for (final k in _rGrahas) {
      final b = byK[k];
      if (b == null) continue;
      els.add(_reRow(im.planets[k], _rPlanetName[k]![l]!,
        sn(_vargaSign(b.lon, v.d)), 24, kOn, kMuted, gap: 6));
    }
    els.add(_reSpace(8));
    els.add(_reText(_vgHead[l]!, 22, acc, fw: FontWeight.w800, gap: 6));
    if (strong.isEmpty && tender.isEmpty) {
      els.add(_reText(_vgBalanced(l, theme), 23, kOn, gap: 8));
    } else {
      for (final e in [...strong, ...tender]) {
        final k = e[0] as String, sg = e[1] as int, dig = e[2] as String;
        final kind = (dig == 'exalt' || dig == 'own') ? 'strong' : 'tender';
        final infl = _vgInfl[kind]![l]!.replaceAll('{t}', theme);
        els.add(_reIconRich(im.planets[k], [
          TextSpan(text: _rPlanetName[k]![l]!,
            style: const TextStyle(fontWeight: FontWeight.w800)),
          const TextSpan(text: ' — '),
          TextSpan(text: _rDig[dig]![l]!, style: TextStyle(
            color: _rDigColor(dig), fontWeight: FontWeight.w700)),
          TextSpan(text: ' (${sn(sg)}). $infl'),
        ], 23, gap: 8));
      }
    }
    final cat = strong.length > tender.length
      ? 'good' : (tender.length > strong.length ? 'tender' : 'mixed');
    els.add(_reText(_vgOverall[cat]![l]!.replaceAll('{t}', theme), 23, acc,
      fw: FontWeight.w700, gap: 8));
    els.add(_reText(_vuiNote[l]!.replaceAll('{d}', '${v.d}'), 19, kMuted, gap: 0));
    return els;
  }

  // Draw the shareable report card on a canvas (matches the website _rcPaint).
  Future<Uint8List?> _buildReportImage(bool vedic, int refSign, AppLang l,
      LiveChart chart) async {
    const double w = 1080, h = 1350;
    final Color acc = accentColor(vedic);
    final byK = {for (final b in chart.bodies) b.key: b};

    // Fetch every image the card needs, in parallel.
    final imgs = await Future.wait<ui.Image?>([
      _loadUiImage(signBigArtUrl(refSign)),
      _loadUiImage('$kWebsite/app/planet-icons-v2/retroglow.png'),
      ..._rGrahas.map((k) =>
        _loadUiImage('$kWebsite/app/planet-icons-v2/${_livePlanetIcon[k]}')),
      ...List.generate(12, (i) => _loadUiImage(signSymbolUrl(i, vedic: vedic))),
    ]);
    final bgImg = imgs[0], glowImg = imgs[1];
    final planetImgs = <String, ui.Image?>{};
    for (int i = 0; i < _rGrahas.length; i++) {
      planetImgs[_rGrahas[i]] = imgs[2 + i];
    }
    final signImgs = <int, ui.Image?>{};
    for (int i = 0; i < 12; i++) {
      signImgs[i] = imgs[2 + _rGrahas.length + i];
    }

    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w, h));

    void draw(ui.Image? im, Rect dst) {
      if (im == null) return;
      c.drawImageRect(im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        dst, Paint()..filterQuality = FilterQuality.medium);
    }
    void line(String s, double y, double size, Color col,
        {FontWeight fw = FontWeight.w600, double cx = 540,
         TextAlign align = TextAlign.center}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size,
          fontWeight: fw, fontFamily: urduFont)),
        textDirection: TextDirection.ltr, textAlign: align)
        ..layout(maxWidth: w - 100);
      double x;
      if (align == TextAlign.right) {
        x = cx - tp.width;
      } else if (align == TextAlign.left) {
        x = cx;
      } else {
        x = cx - tp.width / 2;
      }
      tp.paint(c, Offset(x, y));
    }

    // Background: the sign artwork (cover) + dark overlay, or plain bg.
    if (bgImg != null) {
      final sc = math.max(w / bgImg.width, h / bgImg.height);
      final iw = bgImg.width * sc, ih = bgImg.height * sc;
      draw(bgImg, Rect.fromLTWH((w - iw) / 2, (h - ih) / 2, iw, ih));
      c.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xCC10081A));
    } else {
      c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = kBg);
    }
    c.drawRect(Rect.fromLTWH(30, 30, w - 60, h - 60),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = acc);
    c.drawRect(Rect.fromLTWH(46, 46, w - 92, h - 92),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2
        ..color = const Color(0x809A6FE0));

    double y = 66;
    line('✦ FAROOQ STARS', y, 46, acc, fw: FontWeight.w800);
    y += 66;
    final sysN = vedic
      ? _t({AppLang.en: 'Vedic', AppLang.ur: 'ویدک', AppLang.hi: 'वैदिक', AppLang.ar: 'فيدي'})
      : _t({AppLang.en: 'Western', AppLang.ur: 'مغربی', AppLang.hi: 'पश्चिमी', AppLang.ar: 'غربي'});
    final birthLbl = _t({AppLang.en: 'Birth chart', AppLang.ur: 'پیدائشی چارٹ', AppLang.hi: 'जन्म चार्ट', AppLang.ar: 'مخطط الميلاد'});
    line('$sysN · $birthLbl', y, 26, const Color(0xFFCBBCE6));
    y += 38;
    line('${_dateStr()}   ${_timeStr()}   $_cityName ${_flag(_cc)}', y, 22,
      const Color(0xFFA99BC6));
    y += 34;
    if (_name.isNotEmpty) {
      line(_name, y, 38, Colors.white, fw: FontWeight.w800);
      y += 52;
    }
    y += 8;

    String sn(int i) => signs[i].name[l] ?? signs[i].name[AppLang.en]!;
    String sd(double lon) => '${(lon % 30).floor()}°';
    final sunB = byK['Sun'], moonB = byK['Moon'];
    final boxData = <List<Object>>[
      [_t({AppLang.en: 'Ascendant', AppLang.ur: 'لگن', AppLang.hi: 'लग्न', AppLang.ar: 'الطالع'}), '${sn(chart.ascSign)} ${sd(chart.asc)}', const Color(0xFFC4A5F0)],
      [_t({AppLang.en: 'Sun', AppLang.ur: 'سورج', AppLang.hi: 'सूर्य', AppLang.ar: 'الشمس'}), sunB == null ? '—' : '${sn(sunB.sign)} ${sd(sunB.lon)}', const Color(0xFFF0A93C)],
      [_t({AppLang.en: 'Moon', AppLang.ur: 'چاند', AppLang.hi: 'चंद्र', AppLang.ar: 'القمر'}), moonB == null ? '—' : '${sn(moonB.sign)} ${sd(moonB.lon)}', const Color(0xFFCFD6E6)],
    ];
    const double bw = 300, gap = 20, bh = 104;
    final double startX = w / 2 - (bw * 1.5 + gap);
    for (int i = 0; i < 3; i++) {
      final bx = startX + i * (bw + gap);
      final rr = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, y, bw, bh), const Radius.circular(14));
      c.drawRRect(rr, Paint()..color = const Color(0x80140A1E));
      c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2
        ..color = acc.withOpacity(0.5));
      line(boxData[i][0] as String, y + 24, 22, boxData[i][2] as Color,
        fw: FontWeight.w800, cx: bx + bw / 2);
      line(boxData[i][1] as String, y + 58, 26, Colors.white,
        fw: FontWeight.w700, cx: bx + bw / 2);
    }
    y += bh + 26;

    // North-Indian box chart.
    const double cs = 500;
    final double bx0 = w / 2 - cs / 2, by0 = y;
    c.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(bx0 - 12, by0 - 12, cs + 24, cs + 24),
      const Radius.circular(18)), Paint()..color = const Color(0xFF140A1E));
    c.drawRect(Rect.fromLTWH(bx0, by0, cs, cs), Paint()..color = kPlate);
    final frame = Paint()..style = PaintingStyle.stroke..strokeWidth = 2
      ..color = const Color(0xFF4A3866);
    c.drawRect(Rect.fromLTWH(bx0, by0, cs, cs), Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 2.4..color = kPlateBorder);
    c.drawLine(Offset(bx0, by0), Offset(bx0 + cs, by0 + cs), frame);
    c.drawLine(Offset(bx0 + cs, by0), Offset(bx0, by0 + cs), frame);
    c.drawPath(Path()
      ..moveTo(bx0 + cs / 2, by0)..lineTo(bx0 + cs, by0 + cs / 2)
      ..lineTo(bx0 + cs / 2, by0 + cs)..lineTo(bx0, by0 + cs / 2)..close(),
      frame);
    final h1 = refSign;
    for (int hh = 1; hh <= 12; hh++) {
      final signIdx = (h1 + hh - 1) % 12;
      final here = chart.bodies.where((b) => _rGrahas.contains(b.key) &&
        ((b.sign - h1) % 12 + 12) % 12 + 1 == hh).toList();
      final hx = bx0 + _kHouseC[hh - 1][0] * cs;
      final hy = by0 + _kHouseC[hh - 1][1] * cs;
      draw(signImgs[signIdx],
        Rect.fromCenter(center: Offset(hx + 16, hy - 18), width: 34, height: 34));
      line('$hh', hy - 34, 20, elementColor(signs[signIdx].element),
        fw: FontWeight.w800, cx: hx - 16);
      if (here.isNotEmpty) {
        double px = hx - (here.length - 1) * 18;
        for (final b in here) {
          if (b.retro) {
            draw(glowImg,
              Rect.fromCenter(center: Offset(px, hy + 18), width: 42, height: 42));
          }
          draw(planetImgs[b.key],
            Rect.fromCenter(center: Offset(px, hy + 18), width: 32, height: 32));
          px += 36;
        }
      }
    }
    y += cs + 46;

    // Planet list, two columns.
    const double rowH = 56, colW = 460;
    final double gx0 = w / 2 - colW;
    for (int p = 0; p < _rGrahas.length; p++) {
      final k = _rGrahas[p], b = byK[k];
      if (b == null) continue;
      final col = p % 2, row = p ~/ 2;
      final px = gx0 + col * colW, py = y + row * rowH;
      draw(planetImgs[k], Rect.fromLTWH(px, py, 32, 32));
      line(_rPlanetName[k]![l]!, py + 4, 25, const Color(0xFFE7DFFB),
        fw: FontWeight.w600, cx: px + 46, align: TextAlign.left);
      line('${sn(b.sign)} ${sd(b.lon)}', py + 4, 24, const Color(0xFFCBBCE6),
        fw: FontWeight.w600, cx: px + colW - 16, align: TextAlign.right);
    }

    line('✦ ${_t({AppLang.en: 'For curiosity & fun', AppLang.ur: 'محض دلچسپی و تفریح کے لیے', AppLang.hi: 'जिज्ञासा व मनोरंजन हेतु', AppLang.ar: 'للفضول والمتعة'})}',
      h - 96, 26, const Color(0xFFB9A6E6));
    line('farooqstars.com', h - 54, 38, acc, fw: FontWeight.w800);

    final pic = rec.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

  Widget _chartView(bool vedic, AppLang l) {
    final chart = _compute(vedic);
    final byKey = {for (final b in chart.bodies) b.key: b};
    // House reference sign — Western default Sun, Vedic default Ascendant.
    final int refSign = vedic
      ? (_refV == 'moon' ? (byKey['Moon']?.sign ?? chart.ascSign) : chart.ascSign)
      : (_refW == 'sun' ? (byKey['Sun']?.sign ?? chart.ascSign) : chart.ascSign);
    final ascWord = vedic
      ? _t({AppLang.en: 'Lagna', AppLang.ur: 'لگنا', AppLang.hi: 'लग्न',
          AppLang.ar: 'الطالع'})
      : _t({AppLang.en: 'Ascendant', AppLang.ur: 'طالع', AppLang.hi: 'लग्न',
          AppLang.ar: 'الطالع'});
    final ascSignName =
      signs[chart.ascSign].name[l] ?? signs[chart.ascSign].name[AppLang.en]!;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16,
        28 + MediaQuery.of(context).viewPadding.bottom),
      children: [
        const SystemToggle(),
        card(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(
                _name.isEmpty
                  ? _t({AppLang.en: 'Birth Chart',
                      AppLang.ur: 'پیدائشی چارٹ', AppLang.hi: 'जन्म कुंडली',
                      AppLang.ar: 'خريطة الميلاد'})
                  : _name,
                style: TextStyle(color: accentColor(vedic), fontSize: 17,
                  fontWeight: FontWeight.w800, fontFamily: urduFont))),
              InkWell(
                onTap: () => _shareChart(vedic, refSign, l, chart),
                borderRadius: BorderRadius.circular(20),
                child: Padding(padding: const EdgeInsets.all(4),
                  child: Icon(Icons.ios_share,
                    color: accentColor(vedic), size: 19))),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() => _editing = true),
                borderRadius: BorderRadius.circular(20),
                child: Padding(padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit,
                    color: accentColor(vedic), size: 18))),
            ]),
            const SizedBox(height: 4),
            Text(
              _gender == null
                ? _birthLine()
                : '${_birthLine()}  ·  ${_genderLabel(l)}',
              style: const TextStyle(color: kMuted, fontSize: 13,
                fontWeight: FontWeight.w600)),
          ])),
        // Circle/box + house-reference (Sun/Moon · Asc) all on one row.
        FittedBox(fit: BoxFit.scaleDown, child: Row(
          mainAxisSize: MainAxisSize.min, children: [
            _viewToggle(false, Icons.circle_outlined),
            const SizedBox(width: 8),
            _viewToggle(true, Icons.crop_square),
            const SizedBox(width: 14),
            _refSeg(vedic, accentColor(vedic)),
          ])),
        const SizedBox(height: 10),
        NatalChartView(chart: chart, vedic: vedic,
          boxMode: _boxMode, houseRefSign: refSign, ascWord: ascWord,
          pillColor: accentColor(vedic)),
        const SizedBox(height: 14),
        card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.arrow_upward, color: accentColor(vedic), size: 18),
              const SizedBox(width: 6),
              Text('$ascWord: ',
                style: TextStyle(color: accentColor(vedic), fontSize: 14.5,
                  fontWeight: FontWeight.w800, fontFamily: urduFont)),
              Text('$ascSignName ${_fmtDeg(chart.asc)}',
                style: const TextStyle(color: kOn, fontSize: 14.5,
                  fontWeight: FontWeight.w700)),
            ]),
            const Divider(color: kBorder, height: 20),
            ...chart.bodies.map((b) => _planetRow(b, vedic, l, refSign)),
          ])),
        // Detailed per-planet reading (Overall) + live Claude AI reading.
        BirthReadingSection(chart: chart, vedic: vedic, l: l,
          accent: accentColor(vedic), houseRefSign: refSign,
          birthSig: '${_y}_${_mo}_${_d}_${_hh}_${_mi}_${_lat}_${_lon}_$refSign'),
        // Divisional (varga) charts D1–D60 — Vedic only.
        if (vedic) DivisionalCharts(chart: chart, l: l,
          accent: accentColor(vedic)),
      ]);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLang>(
    valueListenable: currentLang,
    builder: (_, l, __) => ValueListenableBuilder<bool>(
      valueListenable: useVedic,
      builder: (_, vedic, __) => Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: (_editing || !_set) ? _form() : _chartView(vedic, l))))));
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
// WESTERN GENERAL compatibility (sign × sign) — ported from the website zodiac
// page: six dimensions, aspect-based scores, verdict tier + summary, 4 langs.
// ===========================================================================
class _MCat {
  final String k;
  final String ic;
  final Map<AppLang, String> lbl;
  const _MCat(this.k, this.ic, this.lbl);
}
const List<_MCat> _mCats = [
  _MCat('sex', '💞', {AppLang.en: 'Romance & Intimacy', AppLang.ur: 'رومان و قربت', AppLang.hi: 'रोमांस और नज़दीकी', AppLang.ar: 'الرومانسية والحميمية'}),
  _MCat('trust', '🤝', {AppLang.en: 'Trust', AppLang.ur: 'اعتماد', AppLang.hi: 'भरोसा', AppLang.ar: 'الثقة'}),
  _MCat('comm', '💬', {AppLang.en: 'Communication & Intellect', AppLang.ur: 'رابطہ و فہم', AppLang.hi: 'संवाद और बुद्धि', AppLang.ar: 'التواصل والفكر'}),
  _MCat('emo', '🌊', {AppLang.en: 'Emotions', AppLang.ur: 'جذبات', AppLang.hi: 'भावनाएँ', AppLang.ar: 'المشاعر'}),
  _MCat('val', '⚖️', {AppLang.en: 'Values', AppLang.ur: 'اقدار', AppLang.hi: 'मूल्य', AppLang.ar: 'القيم'}),
  _MCat('act', '🎯', {AppLang.en: 'Shared Activities', AppLang.ur: 'مشترکہ مشاغل', AppLang.hi: 'साझा गतिविधियाँ', AppLang.ar: 'أنشطة مشتركة'}),
];
const Map<String, List<int>> _mScore = {
  'sex': [80, 55, 72, 78, 85, 60, 90], 'trust': [86, 60, 80, 50, 90, 55, 66],
  'comm': [82, 62, 88, 58, 84, 60, 73], 'emo': [84, 58, 76, 54, 88, 56, 70],
  'val': [88, 56, 78, 52, 86, 54, 60], 'act': [80, 60, 86, 64, 82, 58, 69],
};
const Map<String, int> _mSeed = {
  'sex': 3, 'trust': 5, 'comm': 7, 'emo': 11, 'val': 13, 'act': 17,
};
int _mAsp(int a, int b) => math.min((b - a + 12) % 12, (a - b + 12) % 12);
int _mPct(String k, int a, int b, int asp) {
  var v = _mScore[k]![asp] + (((a * b) + (a + b) + 1) * _mSeed[k]!) % 11 - 5;
  if (v > 97) v = 97;
  if (v < 33) v = 33;
  return v;
}
class _MVerd {
  final int min;
  final String c;
  final Map<AppLang, String> lbl;
  const _MVerd(this.min, this.c, this.lbl);
}
const List<_MVerd> _mVerds = [
  _MVerd(80, 'high', {AppLang.en: 'Excellent match', AppLang.ur: 'بہترین جوڑ', AppLang.hi: 'उत्तम मेल', AppLang.ar: 'توافق ممتاز'}),
  _MVerd(64, 'high', {AppLang.en: 'Strong match', AppLang.ur: 'مضبوط جوڑ', AppLang.hi: 'मज़बूत मेल', AppLang.ar: 'توافق قوي'}),
  _MVerd(50, 'mix', {AppLang.en: 'Fair match', AppLang.ur: 'مناسب جوڑ', AppLang.hi: 'ठीक-ठाक मेल', AppLang.ar: 'توافق معقول'}),
  _MVerd(0, 'low', {AppLang.en: 'Takes effort', AppLang.ur: 'محنت طلب', AppLang.hi: 'मेहनत-तलब', AppLang.ar: 'يحتاج جهدًا'}),
];
_MVerd _mVerdOf(int p) {
  for (final v in _mVerds) { if (p >= v.min) return v; }
  return _mVerds.last;
}
const List<Map<AppLang, String>> _mSum = [
  {AppLang.en: 'With so much in common, {A} and {B} understand each other almost instantly — a comfortable, strong bond, if they keep a little variety alive.', AppLang.ur: 'بے حد مماثلت کے باعث {A} اور {B} ایک دوسرے کو فوراً سمجھ لیں — آرام دہ، مضبوط رشتہ، بشرطیکہ تھوڑا تنوع رہے۔', AppLang.hi: 'बहुत कुछ समान होने से {A} और {B} एक-दूसरे को लगभग तुरंत समझ लें — आरामदेह, मज़बूत बंधन, बशर्ते थोड़ी विविधता रहे।', AppLang.ar: 'لتشابههما الكبير، يفهم {A} و{B} أحدهما الآخر فورًا — رابطةٌ مريحةٌ وقويّة، إن أبقيا بعض التنوّع.'},
  {AppLang.en: '{A} and {B} are different yet neighbourly; with patience and give-and-take they grow into a warm, well-rounded pair.', AppLang.ur: '{A} اور {B} مختلف مگر پڑوسی جیسے؛ صبر اور لین دین سے ایک گرم، متوازن جوڑی بن جاتے ہیں۔', AppLang.hi: '{A} और {B} भिन्न पर पड़ोसी-से; धैर्य और लेन-देन से एक गर्म, संतुलित जोड़ी बनें।', AppLang.ar: '{A} و{B} مختلفان لكن متجاوران؛ بالصبر والأخذ والعطاء يصيران ثنائيًّا دافئًا متوازنًا.'},
  {AppLang.en: '{A} and {B} blend easily — friendly, supportive and naturally in sync. One of the smoother, happier matches.', AppLang.ur: '{A} اور {B} آسانی سے گھل مل جائیں — دوستانہ، مددگار، قدرتی ہم آہنگی۔ خوشگوار جوڑوں میں سے ایک۔', AppLang.hi: '{A} और {B} सहजता से घुल-मिल जाएँ — मित्रवत, सहायक, स्वाभाविक तालमेल। सुखद जोड़ों में से एक।', AppLang.ar: 'يمتزج {A} و{B} بسهولة — ودودان وداعمان ومنسجمان طبيعيًّا. من أكثر التوافقات سلاسةً وسعادة.'},
  {AppLang.en: '{A} and {B} feel a strong but challenging pull. Passion runs high, yet lasting peace needs compromise and cooling-off.', AppLang.ur: '{A} اور {B} میں مضبوط مگر مشکل کشش۔ جذبہ بلند، مگر دیرپا سکون کو سمجھوتہ اور ٹھنڈک چاہیے۔', AppLang.hi: '{A} और {B} में मज़बूत पर चुनौतीपूर्ण खिंचाव। जुनून ऊँचा, पर टिकाऊ शांति को समझौता और ठंडक चाहिए।', AppLang.ar: 'ينجذب {A} و{B} بقوّةٍ لكن بتحدٍّ. الشغف عالٍ، لكنّ السلام الدائم يحتاج تنازلًا وتهدئة.'},
  {AppLang.en: '{A} and {B} share an effortless, harmonious flow. Trust and warmth come naturally — one of the most compatible pairs.', AppLang.ur: '{A} اور {B} میں بے ساختہ، ہم آہنگ بہاؤ۔ اعتماد و گرمجوشی فطری — سب سے ہم آہنگ جوڑوں میں۔', AppLang.hi: '{A} और {B} में सहज, सामंजस्यपूर्ण प्रवाह। भरोसा व गर्मजोशी स्वाभाविक — सबसे अनुकूल जोड़ों में।', AppLang.ar: 'يتشارك {A} و{B} انسيابًا عفويًّا ومنسجمًا. الثقة والدفء فطريّان — من أكثر الأزواج توافقًا.'},
  {AppLang.en: '{A} and {B} are wired quite differently and must keep adjusting. With effort and humour, the contrast still works well.', AppLang.ur: '{A} اور {B} کافی مختلف، مسلسل موافقت درکار۔ محنت اور خوش مزاجی سے تضاد بھی خوب چل پڑتا ہے۔', AppLang.hi: '{A} और {B} काफ़ी भिन्न, निरंतर तालमेल चाहिए। मेहनत और हँसी-मज़ाक से विरोध भी चल पड़ता है।', AppLang.ar: '{A} و{B} مختلفان جدًّا ويحتاجان تكيّفًا مستمرًّا. بالجهد والمرح ينجح التباين أيضًا.'},
  {AppLang.en: '{A} and {B} are opposites who magnetically complete each other. Balanced, it is powerful; unbalanced, it tips into tug-of-war.', AppLang.ur: '{A} اور {B} متضاد جو مقناطیسی طور پر ایک دوسرے کو مکمل کریں۔ توازن میں طاقتور؛ بے توازن ہو تو کھینچا تانی۔', AppLang.hi: '{A} और {B} विपरीत जो चुम्बकीय रूप से एक-दूसरे को पूर्ण करें। संतुलित हो तो शक्तिशाली; असंतुलित हो तो खींचतान।', AppLang.ar: '{A} و{B} ضدّان يكملان أحدهما الآخر مغناطيسيًّا. متوازنًا يكون قويًّا؛ ومختلًّا يتحوّل إلى شدٍّ وجذب.'},
];
Color _mBarCol(int p) => p >= 75
  ? const Color(0xFF57D39A) : (p >= 55 ? const Color(0xFF9A6FE0) : const Color(0xFFE3B23C));
Color _mTier(String c) => c == 'high'
  ? const Color(0xFF57D39A) : (c == 'mix' ? const Color(0xFF9A6FE0) : const Color(0xFFE3B23C));

class WesternGeneralCard extends StatelessWidget {
  final int a, b;
  final AppLang l;
  const WesternGeneralCard({super.key, required this.a, required this.b,
    required this.l});

  Widget _thumb(int i) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: CachedNetworkImage(
      imageUrl: '$kWebsite/Thumbnail_${signs[i].name[AppLang.en]!}.png',
      width: 48, height: 48, fit: BoxFit.cover,
      errorWidget: (_, __, ___) => SignIcon(i, size: 40)));

  Widget _bar(String ic, String label, int p, {bool big = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(ic, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: kOn,
          fontSize: big ? 14 : 13.5, fontWeight: FontWeight.w700,
          fontFamily: urduFont))),
        Text('$p%', style: TextStyle(color: _mBarCol(p),
          fontSize: big ? 15 : 13.5, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: p / 100, minHeight: 7,
          backgroundColor: kBg,
          valueColor: AlwaysStoppedAnimation(_mBarCol(p)))),
    ]));

  @override
  Widget build(BuildContext context) {
    final asp = _mAsp(a, b);
    int sum = 0;
    final rows = <Widget>[];
    for (final cat in _mCats) {
      final p = _mPct(cat.k, a, b, asp);
      sum += p;
      rows.add(_bar(cat.ic, cat.lbl[l] ?? cat.lbl[AppLang.en]!, p));
    }
    final tot = (sum / _mCats.length).round();
    final v = _mVerdOf(tot);
    final tier = _mTier(v.c);
    final aName = signs[a].name[l] ?? signs[a].name[AppLang.en]!;
    final bName = signs[b].name[l] ?? signs[b].name[AppLang.en]!;
    final summary = (_mSum[asp][l] ?? _mSum[asp][AppLang.en]!)
      .replaceAll('{A}', aName).replaceAll('{B}', bName);
    return card(child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _thumb(a),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('❤', style: TextStyle(color: Color(0xFFff6b6b),
            fontSize: 20))),
        _thumb(b),
      ]),
      const SizedBox(height: 8),
      Text('$aName  &  $bName', textAlign: TextAlign.center,
        style: TextStyle(color: kOn, fontSize: 16, fontWeight: FontWeight.w800,
          fontFamily: urduFont)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(color: tier.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tier.withOpacity(0.5))),
          child: Text('$tot%', style: TextStyle(color: tier, fontSize: 18,
            fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: tier.withOpacity(0.12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: tier.withOpacity(0.4))),
          child: Text(v.lbl[l] ?? v.lbl[AppLang.en]!,
            style: TextStyle(color: tier, fontSize: 13,
              fontWeight: FontWeight.w800, fontFamily: urduFont))),
      ]),
      const Divider(color: kBorder, height: 24),
      ...rows,
      const Divider(color: kBorder, height: 20),
      _bar('🧮', {AppLang.en: 'Summary', AppLang.ur: 'خلاصہ', AppLang.hi: 'सारांश', AppLang.ar: 'الخلاصة'}[l]!, tot, big: true),
      const SizedBox(height: 8),
      Text(summary, style: TextStyle(color: kMuted, fontSize: 13, height: 1.55,
        fontFamily: urduFont)),
    ]));
  }
}

// ===========================================================================
// MATCH tab — compatibility (3 systems: Western General, Western, Vedic)
// ===========================================================================
class MatchTab extends StatefulWidget {
  const MatchTab({super.key});
  @override
  State<MatchTab> createState() => _MatchTabState();
}

class _MatchTabState extends State<MatchTab> {
  int? _a, _b;
  String _mode = 'general'; // general · western · vedic

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
  Widget _modePill(String key, String label) {
    final sel = _mode == key;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _mode = key),
      child: AnimatedContainer(duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: sel ? kPrimary : kCard,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sel ? kPrimary : kBorder)),
        child: Text(label, textAlign: TextAlign.center, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: sel ? Colors.white : kMuted,
            fontSize: 12.5, fontWeight: FontWeight.w700,
            fontFamily: urduFont)))));
  }

  Widget _comingSoon(AppLang l, bool vedic) => card(child: Column(children: [
    const SizedBox(height: 6),
    Icon(vedic ? Icons.favorite : Icons.auto_graph, color: kLight, size: 40),
    const SizedBox(height: 12),
    Text(vedic
      ? _t({AppLang.en: 'Vedic Match — Guna Milan', AppLang.ur: 'ویدک میچ — گُن ملاپ', AppLang.hi: 'वैदिक मैच — गुण मिलान', AppLang.ar: 'التوافق الفيدي — غونا ميلان'}, l)
      : _t({AppLang.en: 'Western Match — Synastry', AppLang.ur: 'مغربی میچ — سناسٹری', AppLang.hi: 'पश्चिमी मैच — सिनैस्ट्री', AppLang.ar: 'التوافق الغربي'}, l),
      textAlign: TextAlign.center, style: TextStyle(color: kGold, fontSize: 16,
        fontWeight: FontWeight.w800, fontFamily: urduFont)),
    const SizedBox(height: 8),
    Text(_t({
      AppLang.en: 'Full birth-chart matching (your saved birth + your partner\'s details) with the complete report, shareable card and PDF — arriving in the next update.',
      AppLang.ur: 'مکمل پیدائشی چارٹ میچنگ (آپ کی محفوظ پیدائش + پارٹنر کی تفصیل) — اگلے اپڈیٹ میں مکمل رپورٹ، کارڈ اور PDF کے ساتھ۔',
      AppLang.hi: 'पूर्ण जन्म-कुंडली मिलान (आपकी सहेजी जन्म + साथी की जानकारी) — पूरी रिपोर्ट, कार्ड और PDF के साथ अगले अपडेट में।',
      AppLang.ar: 'مطابقة كاملة لمخطط الميلاد (ميلادك المحفوظ + تفاصيل الشريك) — بتقرير كامل وبطاقة وPDF في التحديث القادم.'}, l),
      textAlign: TextAlign.center, style: const TextStyle(color: kMuted,
        fontSize: 13, height: 1.6)),
    const SizedBox(height: 6),
  ]));

  String _t(Map<AppLang, String> m, AppLang l) => m[l] ?? m[AppLang.en]!;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppLang>(
    valueListenable: currentLang,
    builder: (_, l, __) => ValueListenableBuilder<bool>(
      valueListenable: useVedic,
      builder: (_, __, ___) {
        final ready = _a != null && _b != null;
        return CenteredList(children: [
          const SizedBox(height: 4),
          // Three matching systems.
          Row(children: [
            _modePill('general', _t({AppLang.en: 'Western General', AppLang.ur: 'مغربی عمومی', AppLang.hi: 'पश्चिमी सामान्य', AppLang.ar: 'غربي عام'}, l)),
            _modePill('western', _t({AppLang.en: 'Western', AppLang.ur: 'مغربی', AppLang.hi: 'पश्चिमी', AppLang.ar: 'غربي'}, l)),
            _modePill('vedic', _t({AppLang.en: 'Vedic', AppLang.ur: 'ویدک', AppLang.hi: 'वैदिक', AppLang.ar: 'فيدي'}, l)),
          ]),
          const SizedBox(height: 16),
          if (_mode == 'general') ...[
            Text(_t({
              AppLang.en: 'Pick two signs — general Western compatibility, just for fun.',
              AppLang.ur: 'دو سائن چنیں — عمومی مغربی مطابقت، محض دلچسپی کے لیے۔',
              AppLang.hi: 'दो राशियाँ चुनें — सामान्य पश्चिमी अनुकूलता, बस मनोरंजन के लिए।',
              AppLang.ar: 'اختر برجين — توافق غربي عام، للمتعة فقط.'}, l),
              textAlign: TextAlign.center, style: TextStyle(color: kMuted,
                fontSize: 13.5, height: 1.6, fontFamily: urduFont)),
            const SizedBox(height: 14),
            Row(children: [
              _slot(tr('firstSign'), _a, () => _pick(true)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('♥', style: TextStyle(color: kPrimary, fontSize: 26))),
              _slot(tr('secondSign'), _b, () => _pick(false)),
            ]),
            const SizedBox(height: 18),
            if (ready) WesternGeneralCard(a: _a!, b: _b!, l: l),
            if (ready) Padding(padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kLight,
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11)),
                onPressed: () {
                  final asp = _mAsp(_a!, _b!);
                  int s = 0;
                  for (final c in _mCats) s += _mPct(c.k, _a!, _b!, asp);
                  final tot = (s / _mCats.length).round();
                  final v = _mVerdOf(tot);
                  Share.share('${signName(signs[_a!])} & ${signName(signs[_b!])} — '
                    '$tot% ${v.lbl[l] ?? v.lbl[AppLang.en]!} ✨\nFarooq Stars · $kWebsite');
                },
                icon: const Icon(Icons.share, size: 18),
                label: Text(tr('share'), style: TextStyle(fontFamily: urduFont)))),
          ] else
            _comingSoon(l, _mode == 'vedic'),
        ]);
      }));
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
