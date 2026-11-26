// Renders the Insights screens with sample data and writes PNG screenshots.
//
//   flutter test test/insights_screenshots_test.dart
//
// Output folder: $INSIGHTS_SHOTS_DIR (defaults to build/insights_shots).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:b_smart/models/insights_models.dart';
import 'package:b_smart/screens/insights/account_insights_screen.dart';
import 'package:b_smart/screens/insights/post_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Map<String, dynamic> _reelStats() => {
      'post_id': 'r1',
      'type': 'reel',
      'caption': 'Sunset run along Marine Drive 🌅 #mumbai #reels',
      'created_at': DateTime.now()
          .subtract(const Duration(days: 3, hours: 4))
          .toIso8601String(),
      'likes': {
        'total': 1284,
        'by_gender': {'female': 702, 'male': 548, 'other': 34},
        'by_age': {'18-24': 512, '25-34': 438, '35-44': 201, '13-17': 88, '45+': 45},
      },
      'dislikes': {
        'total': 3120,
        'by_gender': {'male': 1650, 'female': 1380, 'other': 90},
        'by_age': {'18-24': 1200, '25-34': 1100},
      },
      'comments': {
        'total': 96,
        'recent': [
          {'text': 'This view is unreal 😍', 'user': {'username': 'priya.k'}, 'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
          {'text': 'Which camera did you use?', 'user': {'username': 'rahul_shoots'}, 'createdAt': DateTime.now().subtract(const Duration(hours: 9)).toIso8601String()},
          {'text': 'Mumbai sunsets hit different', 'user': {'username': 'ananya.travels'}, 'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String()},
        ],
      },
      'views': {
        'total': 18420,
        'unique': 12960,
        'completed': 6210,
        'by_location': [
          {'location': 'Mumbai', 'count': 5120},
          {'location': 'Pune', 'count': 2210},
          {'location': 'Delhi', 'count': 1840},
          {'location': 'Bengaluru', 'count': 1460},
          {'location': 'Ahmedabad', 'count': 690},
        ],
        'by_age': {'18-24': 5400, '25-34': 4300, '35-44': 1900, '13-17': 900, '45+': 460},
      },
      'retention_curve': [96, 84, 73, 65, 58, 52, 47, 43, 39, 34],
      'platform_avg_retention_curve': [92, 76, 63, 54, 47, 41, 36, 32, 29, 25],
    };

Map<String, dynamic> _accountInsights() {
  final now = DateTime.now();
  final growthCounts = [
    4, 6, 3, 8, 5, 9, 12, 7, 6, 10, 14, 11, 9, 13, 18,
    15, 12, 16, 22, 19, 17, 24, 28, 21, 19, 26, 31, 27, 25, 34,
  ];
  final heat = List.generate(7, (d) {
    return List.generate(24, (h) {
      final evening = h >= 18 && h <= 22 ? 60 : 0;
      final lunch = h >= 12 && h <= 14 ? 25 : 0;
      final night = h < 7 ? 2 : 10;
      final weekend = (d == 0 || d == 6) ? 15 : 0;
      return evening + lunch + night + weekend + (h == 20 && d == 5 ? 40 : 0);
    });
  });
  Map<String, dynamic> item(String id, String type, String caption, int views,
          int likes, int comments, int daysAgo) =>
      {
        '_id': id,
        'type': type,
        'caption': caption,
        'views_count': views,
        'likes_count': likes,
        'comments_count': comments,
        'createdAt': now.subtract(Duration(days: daysAgo)).toIso8601String(),
      };
  return {
    'totals': {
      'posts': 142,
      'views': 486200,
      'likes': 38410,
      'comments': 2911,
      'followers': 12480,
      'following': 318,
    },
    'top_posts': [
      item('a', 'reel', 'Sunset run 🌅', 18420, 1284, 96, 3),
      item('b', 'reel', 'Street food tour', 15100, 1102, 140, 12),
      item('c', 'post', 'Studio day', 9200, 840, 52, 20),
      item('d', 'reel', 'Monsoon vibes', 8800, 702, 61, 25),
      item('e', 'post', 'New merch drop', 6400, 590, 77, 30),
    ],
    'recent_content': [
      item('a', 'reel', 'Sunset run along Marine Drive 🌅', 18420, 1284, 96, 3),
      item('f', 'post', 'Coffee + code ☕️', 2100, 260, 18, 5),
      item('g', 'reel', 'Behind the scenes', 4300, 390, 22, 8),
      item('b', 'reel', 'Street food tour — part 2', 15100, 1102, 140, 12),
    ],
    'follower_growth': [
      for (var i = 0; i < 30; i++)
        {
          'date': now.subtract(Duration(days: 29 - i)).toIso8601String(),
          'count': growthCounts[i],
        }
    ],
    'reel_viewer_reach': {'followers': 7420, 'non_followers': 21860},
    'top_territories': [
      {'location': 'Mumbai', 'count': 9120},
      {'location': 'Pune', 'count': 4210},
      {'location': 'Delhi', 'count': 3330},
      {'location': 'Bengaluru', 'count': 2760},
      {'location': 'Hyderabad', 'count': 1490},
    ],
    'posting_time_heatmap': heat,
  };
}

Map<String, dynamic> _performance() => {
      'period': {
        'days': 28,
        'start': DateTime.now().subtract(const Duration(days: 28)).toIso8601String(),
        'end': DateTime.now().toIso8601String(),
      },
      'current': {
        'all': {'content_count': 14, 'plays': 84210, 'likes': 6120, 'comments': 512, 'saves': 840, 'watch_time_ms': 172800000, 'engagement_rate': 8.9},
        'reel': {'content_count': 8, 'plays': 71200, 'likes': 4980, 'comments': 402, 'saves': 690, 'watch_time_ms': 172800000, 'engagement_rate': 8.5},
        'post': {'content_count': 5, 'plays': 11800, 'likes': 1050, 'comments': 98, 'saves': 140, 'watch_time_ms': 0, 'engagement_rate': 10.9},
        'story': {'content_count': 1, 'plays': 1210, 'likes': 90, 'comments': 12, 'saves': 10, 'watch_time_ms': 0, 'engagement_rate': 9.3},
      },
      'previous': {
        'all': {'content_count': 11, 'plays': 71100, 'likes': 5410, 'comments': 560, 'saves': 610, 'watch_time_ms': 140000000, 'engagement_rate': 9.2},
        'reel': {'content_count': 6, 'plays': 58800, 'likes': 4200, 'comments': 430, 'saves': 500, 'watch_time_ms': 140000000, 'engagement_rate': 8.8},
        'post': {'content_count': 5, 'plays': 12300, 'likes': 1210, 'comments': 130, 'saves': 110, 'watch_time_ms': 0, 'engagement_rate': 11.8},
        'story': {'content_count': 0, 'plays': 0, 'likes': 0, 'comments': 0, 'saves': 0, 'watch_time_ms': 0, 'engagement_rate': 0},
      },
    };

void main() {
  final outDir = Platform.environment['INSIGHTS_SHOTS_DIR'] ?? 'build/insights_shots';

  setUpAll(() async {
    const fonts = '/Users/devangsonawane/tools/flutter/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', [
      '$fonts/Roboto-Regular.ttf',
      '$fonts/Roboto-Medium.ttf',
      '$fonts/Roboto-Bold.ttf',
      '$fonts/Roboto-Black.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
    final lucide = Directory('${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev')
        .listSync()
        .whereType<Directory>()
        .firstWhere((d) => d.path.contains('lucide_icons_flutter-3'));
    await _loadFont('packages/lucide_icons_flutter/Lucide', ['${lucide.path}/assets/lucide.ttf']);
    Directory(outDir).createSync(recursive: true);
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget screen, {
    required Brightness brightness,
    double height = 844,
  }) async {
    const width = 390.0;
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: brightness,
          fontFamily: 'Roboto',
          useMaterial3: true,
          scaffoldBackgroundColor:
              brightness == Brightness.dark ? Colors.black : Colors.white,
        ),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(width, 844),
            padding: EdgeInsets.only(top: 47, bottom: 34),
            devicePixelRatio: 2,
          ),
          child: screen,
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  final reel = ContentInsights.fromJson(_reelStats());
  final photo = ContentInsights.fromJson({
    ..._reelStats(),
    'type': 'post',
    'caption': 'Studio day 📸',
    'retention_curve': <dynamic>[],
    'platform_avg_retention_curve': <dynamic>[],
    'views': {'total': 9200, 'unique': 7100, 'completed': 0},
  });
  final account = AccountInsights.fromJson(_accountInsights());
  final perf = {28: ContentPerformance.fromJson(_performance())};

  for (final b in Brightness.values) {
    final tag = b == Brightness.dark ? 'dark' : 'light';
    testWidgets('reel insights $tag', (t) async {
      await shoot(t, 'reel_insights_full_$tag',
          PostInsightsScreen(postId: 'r1', preloaded: reel),
          brightness: b, height: 2950);
    });
    testWidgets('account insights $tag', (t) async {
      await shoot(
          t,
          'account_insights_full_$tag',
          AccountInsightsScreen(
              userId: 'u1',
              preloadedInsights: account,
              preloadedPerformance: perf),
          brightness: b,
          height: 3950);
    });
  }

  testWidgets('photo post insights', (t) async {
    await shoot(t, 'post_insights_full_dark',
        PostInsightsScreen(postId: 'p1', preloaded: photo),
        brightness: Brightness.dark, height: 2050);
  });

  testWidgets('promoted reel insights', (t) async {
    await shoot(
        t,
        'promoted_reel_insights_full_dark',
        PostInsightsScreen(postId: 'pr1', isPromoted: true, preloaded: reel),
        brightness: Brightness.dark,
        height: 2200);
  });
}
