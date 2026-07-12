// Smoke test: the app builds, shows the brand header and all four tabs.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farooq_stars/main.dart';

void main() {
  testWidgets('App builds and shows brand + tabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(const FarooqStarsApp());
    await tester.pumpAndSettle();
    expect(find.text('FAROOQ STARS ✦'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Zodiac'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });
}
