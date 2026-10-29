import 'package:b_smart/screens/store/store_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('store theme forces light palette in dark mode', (tester) async {
    late ThemeData storeTheme;
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            storeTheme = BStoreTheme.data(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(storeTheme.brightness, Brightness.light);
    expect(storeTheme.scaffoldBackgroundColor, BStoreColors.background);
    expect(storeTheme.colorScheme.brightness, Brightness.light);
    expect(storeTheme.colorScheme.surface, BStoreColors.surface);
  });

  testWidgets('store switches are white thumb + teal/grey track',
      (tester) async {
    late ThemeData storeTheme;
    await tester.pumpWidget(
      MaterialApp(
        themeMode: ThemeMode.dark,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            storeTheme = BStoreTheme.data(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final thumb = storeTheme.switchTheme.thumbColor!;
    final track = storeTheme.switchTheme.trackColor!;

    expect(thumb.resolve(<WidgetState>{}), Colors.white);
    expect(thumb.resolve(<WidgetState>{WidgetState.selected}), Colors.white);
    expect(track.resolve(<WidgetState>{}), BStoreColors.border);
    expect(
      track.resolve(<WidgetState>{WidgetState.selected}),
      BStoreColors.primary,
    );
    expect(
      storeTheme.switchTheme.trackOutlineColor!.resolve(<WidgetState>{}),
      Colors.transparent,
    );
  });
}
