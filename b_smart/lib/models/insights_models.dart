// Models for the Insights endpoints (see `insights-api.md`).
//
// The parsers are deliberately tolerant: a breakdown may arrive as a map
// (`{"male": 4, "female": 2}`) or as a list of rows
// (`[{"label": "male", "count": 4}]`), and numbers may be strings. Missing
// data stays empty — nothing is invented to fill a chart.

import '../utils/url_helper.dart';

num _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0;
}

int _int(dynamic v) => _num(v).toInt();

num _firstNum(Map? m, List<String> keys) {
  if (m == null) return 0;
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return _num(m[k]);
  }
  return 0;
}

String _firstStr(Map? m, List<String> keys) {
  if (m == null) return '';
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is Map) {
      final nested = _firstStr(v, const ['name', 'label', 'city', 'country']);
      if (nested.isNotEmpty) return nested;
      continue;
    }
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

Map? _map(dynamic v) => v is Map ? v : null;
List _list(dynamic v) => v is List ? v : const [];

DateTime? _date(dynamic v) {
  if (v == null) return null;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// One labelled count in a breakdown (gender, age bucket, location, …).
class InsightBucket {
  final String label;
  final num value;
  const InsightBucket(this.label, this.value);
}

/// Parses `{label: count}` maps or `[{label/_id/…, count/…}]` lists.
List<InsightBucket> parseBuckets(dynamic raw) {
  final out = <InsightBucket>[];
  if (raw is Map) {
    raw.forEach((k, v) {
      if (v is Map) {
        out.add(InsightBucket(
          k.toString(),
          _firstNum(v, const ['count', 'value', 'total', 'views', 'viewers']),
        ));
      } else if (v is num || num.tryParse('$v') != null) {
        out.add(InsightBucket(k.toString(), _num(v)));
      }
    });
  } else if (raw is List) {
    for (final item in raw) {
      if (item is! Map) continue;
      final label = _firstStr(item, const [
        'label',
        'name',
        'key',
        '_id',
        'bucket',
        'range',
        'gender',
        'age',
        'age_group',
        'location',
        'territory',
        'city',
        'country',
      ]);
      out.add(InsightBucket(
        label.isEmpty ? 'Unknown' : label,
        _firstNum(item, const [
          'count',
          'value',
          'total',
          'views',
          'viewers',
          'unique_viewers',
          'users',
        ]),
      ));
    }
  }
  out.removeWhere((b) => b.value <= 0);
  out.sort((a, b) => b.value.compareTo(a.value));
  return out;
}

/// A point on a retention curve: [percent] of the way through the reel
/// (10…100) and [value] = % of viewers who got at least that far.
class RetentionPoint {
  final double percent;
  final double value;
  const RetentionPoint(this.percent, this.value);
}

List<RetentionPoint> parseRetention(dynamic raw) {
  final list = _list(raw);
  final out = <RetentionPoint>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is num) {
      out.add(RetentionPoint(((i + 1) * 100 / list.length).toDouble(),
          item.toDouble()));
    } else if (item is Map) {
      final x = _firstNum(item, const [
        'percent',
        'point',
        'at',
        'threshold',
        'fraction',
        'progress',
        'x',
      ]).toDouble();
      final y = _firstNum(item, const [
        'value',
        'pct',
        'percentage',
        'retention',
        'viewers_pct',
        'viewers',
        'y',
      ]).toDouble();
      out.add(RetentionPoint(x <= 1 && x > 0 ? x * 100 : x, y));
    }
  }
  // Values given as 0…1 fractions → scale to percent.
  if (out.isNotEmpty && out.every((p) => p.value <= 1)) {
    return out.map((p) => RetentionPoint(p.percent, p.value * 100)).toList();
  }
  return out;
}

class InsightComment {
  final String id;
  final String text;
  final String username;
  final String avatarUrl;
  final DateTime? createdAt;

  const InsightComment({
    required this.id,
    required this.text,
    required this.username,
    required this.avatarUrl,
    required this.createdAt,
  });

  factory InsightComment.fromJson(Map json) {
    final user = _map(json['user']) ?? _map(json['user_id']) ?? _map(json['author']);
    return InsightComment(
      id: _firstStr(json, const ['_id', 'id']),
      text: _firstStr(json, const ['text', 'content', 'comment', 'body']),
      username: _firstStr(user, const ['username', 'full_name', 'name']).isNotEmpty
          ? _firstStr(user, const ['username', 'full_name', 'name'])
          : _firstStr(json, const ['username']),
      avatarUrl: UrlHelper.normalizeUrl(
          _firstStr(user, const ['avatar_url', 'avatar', 'profile_picture'])),
      createdAt: _date(json['createdAt'] ?? json['created_at']),
    );
  }
}

class EngagementBreakdown {
  final int total;
  final List<InsightBucket> byGender;
  final List<InsightBucket> byAge;

  const EngagementBreakdown({
    required this.total,
    required this.byGender,
    required this.byAge,
  });

  factory EngagementBreakdown.fromJson(dynamic raw) {
    final m = _map(raw);
    final gender = parseBuckets(m?['by_gender']);
    final age = parseBuckets(m?['by_age']);
    var total = _int(_firstNum(m, const ['total', 'count']));
    if (total == 0 && raw is num) total = raw.toInt();
    if (total == 0 && gender.isNotEmpty) {
      total = gender.fold<num>(0, (s, b) => s + b.value).toInt();
    }
    return EngagementBreakdown(total: total, byGender: gender, byAge: age);
  }

  bool get hasBreakdown => byGender.isNotEmpty || byAge.isNotEmpty;
}

/// Response of `/posts/:id/stats` and `/promote-reels/:id/stats`.
class ContentInsights {
  final String id;
  final String type; // 'reel' | 'post' | 'promote'
  final String thumbnailUrl;
  final String caption;
  final DateTime? createdAt;
  final EngagementBreakdown likes;
  final EngagementBreakdown dislikes;
  final bool hasDislikes;
  final int commentsTotal;
  final List<InsightComment> recentComments;
  final int shares;
  final int saves;
  final int viewsTotal;
  final int viewsUnique;
  final int viewsCompleted;
  final List<InsightBucket> viewsByLocation;
  final List<InsightBucket> viewsByAge;
  final List<RetentionPoint> retention;
  final List<RetentionPoint> platformRetention;

  const ContentInsights({
    required this.id,
    required this.type,
    required this.thumbnailUrl,
    required this.caption,
    required this.createdAt,
    required this.likes,
    required this.dislikes,
    required this.hasDislikes,
    required this.commentsTotal,
    required this.recentComments,
    required this.shares,
    required this.saves,
    required this.viewsTotal,
    required this.viewsUnique,
    required this.viewsCompleted,
    required this.viewsByLocation,
    required this.viewsByAge,
    required this.retention,
    required this.platformRetention,
  });

  bool get isReel => type == 'reel' || type == 'promote' || retention.isNotEmpty;

  /// % of views that were watched to the end.
  double get completionRate =>
      viewsTotal == 0 ? 0 : (viewsCompleted / viewsTotal * 100).clamp(0, 100);

  /// (likes + comments) / unique views, as a percent.
  double get engagementRate {
    final denom = viewsUnique > 0 ? viewsUnique : viewsTotal;
    if (denom == 0) return 0;
    return ((likes.total + commentsTotal + shares + saves) / denom * 100);
  }

  factory ContentInsights.fromJson(Map<String, dynamic> json,
      {String? fallbackType}) {
    final post = _map(json['post']) ?? _map(json['reel']) ?? _map(json['content']);
    final comments = _map(json['comments']);
    final views = _map(json['views']);
    final rawType = _firstStr(json, const ['type', 'content_type']).isNotEmpty
        ? _firstStr(json, const ['type', 'content_type'])
        : _firstStr(post, const ['type', 'content_type']);
    final thumb = _firstStr(json, const ['thumbnail_url', 'thumbnail']).isNotEmpty
        ? _firstStr(json, const ['thumbnail_url', 'thumbnail'])
        : _firstStr(post, const ['thumbnail_url', 'thumbnail', 'media_url']);
    final recent = _list(comments?['recent'])
        .whereType<Map>()
        .map(InsightComment.fromJson)
        .where((c) => c.text.isNotEmpty)
        .toList();

    return ContentInsights(
      id: _firstStr(json, const ['post_id', 'id', '_id']).isNotEmpty
          ? _firstStr(json, const ['post_id', 'id', '_id'])
          : _firstStr(post, const ['_id', 'id']),
      type: (rawType.isEmpty ? (fallbackType ?? 'post') : rawType).toLowerCase(),
      thumbnailUrl: UrlHelper.normalizeUrl(thumb),
      caption: _firstStr(json, const ['caption']).isNotEmpty
          ? _firstStr(json, const ['caption'])
          : _firstStr(post, const ['caption', 'description']),
      createdAt: _date(json['created_at'] ??
          json['createdAt'] ??
          post?['createdAt'] ??
          post?['created_at']),
      likes: EngagementBreakdown.fromJson(json['likes']),
      dislikes: EngagementBreakdown.fromJson(json['dislikes']),
      hasDislikes: json['dislikes'] != null,
      commentsTotal: comments != null
          ? _int(_firstNum(comments, const ['total', 'count']))
          : _int(json['comments']),
      recentComments: recent,
      shares: _int(_firstNum(json, const ['shares', 'shares_count'])),
      saves: _int(_firstNum(json, const ['saves', 'saves_count', 'saved'])),
      viewsTotal: views != null
          ? _int(_firstNum(views, const ['total', 'count']))
          : _int(json['views']),
      viewsUnique: _int(_firstNum(views, const ['unique', 'unique_views'])),
      viewsCompleted:
          _int(_firstNum(views, const ['completed', 'completed_views'])),
      viewsByLocation: parseBuckets(views?['by_location']),
      viewsByAge: parseBuckets(views?['by_age']),
      retention: parseRetention(json['retention_curve']),
      platformRetention: parseRetention(json['platform_avg_retention_curve']),
    );
  }
}

/// One item in `top_posts` / `recent_content`.
class InsightContentItem {
  final String id;
  final String type;
  final String thumbnailUrl;
  final String caption;
  final DateTime? createdAt;
  final int views;
  final int likes;
  final int comments;

  const InsightContentItem({
    required this.id,
    required this.type,
    required this.thumbnailUrl,
    required this.caption,
    required this.createdAt,
    required this.views,
    required this.likes,
    required this.comments,
  });

  bool get isReel => type == 'reel' || type == 'video';

  factory InsightContentItem.fromJson(Map json) {
    var thumb = _firstStr(json, const ['thumbnail_url', 'thumbnail', 'media_url']);
    if (thumb.isEmpty) {
      final media = _list(json['media']);
      if (media.isNotEmpty) {
        final first = media.first;
        thumb = first is Map
            ? _firstStr(first, const ['thumbnail_url', 'thumbnail', 'url', 'fileUrl'])
            : first.toString();
      }
    }
    return InsightContentItem(
      id: _firstStr(json, const ['_id', 'id', 'post_id']),
      type: _firstStr(json, const ['type', 'content_type']).toLowerCase(),
      thumbnailUrl: UrlHelper.normalizeUrl(thumb),
      caption: _firstStr(json, const ['caption', 'description']),
      createdAt: _date(json['createdAt'] ?? json['created_at']),
      views: _int(_firstNum(json, const ['views', 'views_count', 'plays'])),
      likes: _int(_firstNum(json, const ['likes', 'likes_count'])),
      comments: _int(_firstNum(json, const ['comments', 'comments_count'])),
    );
  }
}

class DailyCount {
  final DateTime date;
  final int count;
  const DailyCount(this.date, this.count);
}

/// Response of `/users/:id/insights`.
class AccountInsights {
  final int posts;
  final int views;
  final int likes;
  final int comments;
  final int followers;
  final int following;
  final List<InsightContentItem> topPosts;
  final List<InsightContentItem> recentContent;
  final List<DailyCount> followerGrowth;
  final int reachFollowers;
  final int reachNonFollowers;
  final List<InsightBucket> topTerritories;

  /// 7 rows (day of week, Sunday first unless the API says otherwise) × 24.
  final List<List<int>> heatmap;

  const AccountInsights({
    required this.posts,
    required this.views,
    required this.likes,
    required this.comments,
    required this.followers,
    required this.following,
    required this.topPosts,
    required this.recentContent,
    required this.followerGrowth,
    required this.reachFollowers,
    required this.reachNonFollowers,
    required this.topTerritories,
    required this.heatmap,
  });

  int get reachTotal => reachFollowers + reachNonFollowers;
  int get newFollowers30d =>
      followerGrowth.fold<int>(0, (s, d) => s + d.count);
  bool get hasHeatmap => heatmap.any((row) => row.any((v) => v > 0));

  factory AccountInsights.fromJson(Map<String, dynamic> json) {
    final totals = _map(json['totals']) ?? const {};
    final reach = _map(json['reel_viewer_reach']);

    final growth = <DailyCount>[];
    for (final item in _list(json['follower_growth'])) {
      if (item is! Map) continue;
      final d = _date(item['date'] ?? item['_id'] ?? item['day']);
      if (d == null) continue;
      growth.add(DailyCount(
          d, _int(_firstNum(item, const ['count', 'new_followers', 'value']))));
    }
    growth.sort((a, b) => a.date.compareTo(b.date));

    return AccountInsights(
      posts: _int(_firstNum(totals, const ['posts', 'posts_count'])),
      views: _int(_firstNum(totals, const ['views', 'views_count'])),
      likes: _int(_firstNum(totals, const ['likes', 'likes_count'])),
      comments: _int(_firstNum(totals, const ['comments', 'comments_count'])),
      followers: _int(_firstNum(totals, const ['followers', 'followers_count'])),
      following: _int(_firstNum(totals, const ['following', 'following_count'])),
      topPosts: _list(json['top_posts'])
          .whereType<Map>()
          .map(InsightContentItem.fromJson)
          .toList(),
      recentContent: _list(json['recent_content'])
          .whereType<Map>()
          .map(InsightContentItem.fromJson)
          .toList(),
      followerGrowth: growth,
      reachFollowers: _int(_firstNum(reach, const ['followers', 'follower'])),
      reachNonFollowers: _int(_firstNum(
          reach, const ['non_followers', 'nonFollowers', 'non_follower'])),
      topTerritories: parseBuckets(json['top_territories']),
      heatmap: _parseHeatmap(json['posting_time_heatmap']),
    );
  }

  static List<List<int>> _parseHeatmap(dynamic raw) {
    final grid = List.generate(7, (_) => List.filled(24, 0));
    if (raw is Map && raw['grid'] != null) raw = raw['grid'];
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final row = raw[i];
        if (row is List && i < 7) {
          for (var h = 0; h < row.length && h < 24; h++) {
            grid[i][h] = _int(row[h]);
          }
        } else if (row is Map) {
          final d = _int(_firstNum(row, const ['day', 'dow', 'day_of_week']));
          final h = _int(_firstNum(row, const ['hour', 'h']));
          if (d >= 0 && d < 7 && h >= 0 && h < 24) {
            grid[d][h] += _int(_firstNum(row, const ['count', 'views', 'value']));
          }
        }
      }
    }
    return grid;
  }
}

/// One bucket (`all` / `reel` / `post` / `story`) of a performance window.
class PerformanceMetrics {
  final int contentCount;
  final int plays;
  final int likes;
  final int comments;
  final int saves;
  final int watchTimeMs;
  final double engagementRate;

  const PerformanceMetrics({
    this.contentCount = 0,
    this.plays = 0,
    this.likes = 0,
    this.comments = 0,
    this.saves = 0,
    this.watchTimeMs = 0,
    this.engagementRate = 0,
  });

  factory PerformanceMetrics.fromJson(dynamic raw) {
    final m = _map(raw);
    if (m == null) return const PerformanceMetrics();
    return PerformanceMetrics(
      contentCount: _int(_firstNum(m, const ['content_count', 'count'])),
      plays: _int(_firstNum(m, const ['plays', 'views'])),
      likes: _int(m['likes']),
      comments: _int(m['comments']),
      saves: _int(m['saves']),
      watchTimeMs: _int(_firstNum(m, const ['watch_time_ms', 'watchTimeMs'])),
      engagementRate:
          _firstNum(m, const ['engagement_rate', 'engagementRate']).toDouble(),
    );
  }
}

/// Response of `/users/:id/content-performance`.
class ContentPerformance {
  final int days;
  final DateTime? start;
  final DateTime? end;
  final Map<String, PerformanceMetrics> current;
  final Map<String, PerformanceMetrics> previous;

  const ContentPerformance({
    required this.days,
    required this.start,
    required this.end,
    required this.current,
    required this.previous,
  });

  PerformanceMetrics currentFor(String key) =>
      current[key] ?? const PerformanceMetrics();
  PerformanceMetrics previousFor(String key) =>
      previous[key] ?? const PerformanceMetrics();

  static Map<String, PerformanceMetrics> _buckets(dynamic raw) {
    final m = _map(raw);
    if (m == null) return const {};
    return {
      for (final k in const ['all', 'reel', 'post', 'story'])
        k: PerformanceMetrics.fromJson(m[k] ?? m['${k}s']),
    };
  }

  factory ContentPerformance.fromJson(Map<String, dynamic> json,
      {int fallbackDays = 28}) {
    final period = _map(json['period']);
    return ContentPerformance(
      days: _int(_firstNum(period, const ['days'])) == 0
          ? fallbackDays
          : _int(_firstNum(period, const ['days'])),
      start: _date(period?['start'] ?? period?['from']),
      end: _date(period?['end'] ?? period?['to']),
      current: _buckets(json['current']),
      previous: _buckets(json['previous']),
    );
  }
}

/// % change between two values, or null when there's no baseline.
double? percentDelta(num current, num previous) {
  if (previous == 0) return current == 0 ? 0 : null;
  return (current - previous) / previous * 100;
}
