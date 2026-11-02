import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SwiggyCloneApp());

class SwiggyCloneApp extends StatelessWidget {
  const SwiggyCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swiggy Clone',
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: Colors.white),
      home: const HomeShell(),
    );
  }
}

/* ───────────────────────── THEME DATA PER CATEGORY ───────────────────────── */

class NavItem {
  final String label;
  final IconData icon;
  final String? badge;
  const NavItem(this.label, this.icon, {this.badge});
}

class SectionTheme {
  final String label;
  final String emoji;
  final String? tabBadge;
  final Color dark; // header + tab strip
  final Color panel; // selected tab + top panel of the page
  final Color accent; // bottom nav selected colour
  final String title;
  final String subtitle;
  final List<NavItem> nav;

  const SectionTheme({
    required this.label,
    required this.emoji,
    this.tabBadge,
    required this.dark,
    required this.panel,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.nav,
  });
}

const sections = <SectionTheme>[
  SectionTheme(
    label: 'Food',
    emoji: '🍔',
    dark: Color(0xFF1B0010),
    panel: Color(0xFF4A0420),
    accent: Color(0xFFFC8019),
    title: 'ankita jha',
    subtitle: '311, nikhil more, New Link Rd, kandivali (West),...',
    nav: [
      NavItem('Food', Icons.rice_bowl_rounded),
      NavItem('Bolt', Icons.bolt_rounded, badge: '15 MIN'),
      NavItem('Gourmet', Icons.restaurant_rounded),
      NavItem('EatRight', Icons.favorite_rounded, badge: 'NEW'),
      NavItem('Reorder', Icons.shopping_cart_checkout_rounded),
    ],
  ),
  SectionTheme(
    label: 'Instamart',
    emoji: '🧺',
    tabBadge: '12 mins',
    dark: Color(0xFF0F1B4D),
    panel: Color(0xFF2A4BA0),
    accent: Color(0xFF1B1B1B),
    title: '13 mins',
    subtitle: 'To ankita jha: 311, nikhil more, New Link Rd, ka...',
    nav: [
      NavItem('Instamart', Icons.shopping_basket_rounded),
      NavItem('Categories', Icons.grid_view_rounded),
      NavItem('Reorder', Icons.shopping_cart_checkout_rounded),
      NavItem('Print', Icons.print_outlined),
    ],
  ),
  SectionTheme(
    label: 'Dineout',
    emoji: '🍽️',
    dark: Color(0xFF07251B),
    panel: Color(0xFF1B5E3F),
    accent: Color(0xFF1B7F52),
    title: 'Kandivali (West)',
    subtitle: 'Book tables & get up to 50% off',
    nav: [
      NavItem('Dineout', Icons.restaurant_menu_rounded),
      NavItem('Offers', Icons.local_offer_rounded),
      NavItem('Bookings', Icons.event_available_rounded),
    ],
  ),
  SectionTheme(
    label: 'Scenes',
    emoji: '🪩',
    dark: Color(0xFF24082F),
    panel: Color(0xFF5B1A87),
    accent: Color(0xFF8E24AA),
    title: 'Mumbai',
    subtitle: 'Events, concerts & things to do',
    nav: [
      NavItem('Scenes', Icons.celebration_rounded),
      NavItem('Tonight', Icons.nightlife_rounded),
      NavItem('Tickets', Icons.confirmation_number_rounded),
    ],
  ),
];

/* ───────────────────────────── MAIN SHELL ───────────────────────────── */

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final PageController _pc = PageController();
  final List<int> _navIdx = List.filled(sections.length, 0);
  int _index = 0;
  bool _animating = false;

  static const _anim = Duration(milliseconds: 350);

  Future<void> _goTo(int i) async {
    if (i == _index) return;
    setState(() => _index = i);
    _animating = true;
    await _pc.animateToPage(i, duration: _anim, curve: Curves.easeOutCubic);
    _animating = false;
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = sections[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Column(
          children: [
            // Header + tab strip
            AnimatedContainer(
              duration: _anim,
              color: t.dark,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _Header(theme: t),
                    const SizedBox(height: 14),
                    _TabStrip(
                      selected: _index,
                      onTap: _goTo,
                    ),
                  ],
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) {
                  if (!_animating) setState(() => _index = i);
                },
                children: const [
                  FoodPage(),
                  InstamartPage(),
                  GenericPage(sectionIndex: 2),
                  GenericPage(sectionIndex: 3),
                ],
              ),
            ),
            // Bottom nav (changes per section)
            _BottomNav(
              theme: t,
              selected: _navIdx[_index],
              sectionKey: _index,
              onTap: (i) => setState(() => _navIdx[_index] = i),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────────── HEADER ───────────────────────────── */

class _Header extends StatelessWidget {
  final SectionTheme theme;
  const _Header({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.25), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(theme.label),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          theme.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFE0F0),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 26),
                    ],
                  ),
                  Text(
                    theme.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB347), Color(0xFFE8590C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: const Text('FREE',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Container(
            width: 56,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.format_align_right_rounded,
                color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────── CURVED TAB STRIP ───────────────────────────── */

class _TabStrip extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _TabStrip({required this.selected, required this.onTap});

  static const double height = 86;

  @override
  Widget build(BuildContext context) {
    final panel = sections[selected].panel;
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, c) {
        final tabW = c.maxWidth / sections.length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // unselected backgrounds
            Row(
              children: List.generate(
                sections.length,
                (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                ),
              ),
            ),
            // sliding selected shape (flows into the panel below)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              left: selected * tabW,
              width: tabW,
              top: 0,
              bottom: 0,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: panel),
                duration: const Duration(milliseconds: 350),
                builder: (context, color, _) => CustomPaint(
                  painter: _TabShapePainter(color ?? panel),
                ),
              ),
            ),
            // labels
            Row(
              children: List.generate(sections.length, (i) {
                final s = sections[i];
                final sel = i == selected;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: sel ? 1.15 : 0.9,
                          duration: const Duration(milliseconds: 250),
                          child: AnimatedOpacity(
                            opacity: sel ? 1 : 0.7,
                            duration: const Duration(milliseconds: 250),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Text(s.emoji,
                                    style: const TextStyle(fontSize: 32)),
                                if (s.tabBadge != null)
                                  Positioned(
                                    bottom: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2347FF),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(s.tabBadge!,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.white70,
                            fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 14,
                          ),
                          child: Text(s.label),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      }),
    );
  }
}

class _TabShapePainter extends CustomPainter {
  final Color color;
  _TabShapePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const f = 22.0; // flare into the panel
    const r = 20.0; // top corner radius
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(-f, h)
      ..quadraticBezierTo(0, h, 0, h - f)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - f)
      ..quadraticBezierTo(w, h, w + f, h)
      ..lineTo(w + f, h + 2)
      ..lineTo(-f, h + 2)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TabShapePainter old) => old.color != color;
}

/* ───────────────────────────── BOTTOM NAV ───────────────────────────── */

class _BottomNav extends StatelessWidget {
  final SectionTheme theme;
  final int selected;
  final int sectionKey;
  final ValueChanged<int> onTap;
  const _BottomNav({
    required this.theme,
    required this.selected,
    required this.sectionKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            key: ValueKey(sectionKey),
            height: 66,
            child: Row(
              children: List.generate(theme.nav.length, (i) {
                final item = theme.nav[i];
                final sel = i == selected;
                final color = sel ? theme.accent : Colors.grey.shade600;
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(item.icon, color: color, size: 28),
                            if (item.badge != null)
                              Positioned(
                                bottom: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(item.badge!,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(item.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────────── SHARED WIDGETS ───────────────────────────── */

class _PanelWrap extends StatelessWidget {
  final Color color;
  final Widget child;
  const _PanelWrap({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      padding: const EdgeInsets.only(top: 22, bottom: 18),
      child: child,
    );
  }
}

class _SearchBox extends StatelessWidget {
  final String hint;
  final Widget trailing;
  const _SearchBox({required this.hint, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(hint,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 18)),
          ),
          trailing,
        ],
      ),
    );
  }
}

/* ───────────────────────────── FOOD PAGE ───────────────────────────── */

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  bool _veg = false;
  int _chip = 0;
  int _seg = 0;

  static const _chips = [
    ('ALL', Icons.apps_rounded),
    ('GOURMET', Icons.restaurant_rounded),
    ('OFFERS', Icons.local_offer_rounded),
    ('BOLT', Icons.bolt_rounded),
    ('EATRIGHT', Icons.favorite_rounded),
  ];

  static const _offers = [
    ('Get\n70% OFF', '🎟️'),
    ('Get A\nFree Treat', '🧁'),
    ('Up To ₹225\nCashback', '🍽️'),
    ('Binge-Watch\nOffers', '💰'),
  ];

  static const _restaurants = [
    ("McDonald's", '🍟', '₹80 OFF', 'ABOVE ₹399', '4.4', '25-30 mins', Color(0xFFC62828)),
    ('Jumboking Burgers', '🍔', 'ITEMS', 'AT ₹99', '4.3', '15-20 mins', Color(0xFF2E7D32)),
    ("Hakim's", '🍛', 'ITEMS', 'AT ₹79', '4.3', '60-70 mins', Color(0xFF8D4E2A)),
    ('Wow! Momo', '🥟', 'FLAT', '50% OFF', '4.2', '30-35 mins', Color(0xFF6A1B9A)),
  ];

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF4A0420);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PanelWrap(
          color: panel,
          child: Column(
            children: [
              // search + veg
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchBox(
                        hint: "Search for 'Pizza'",
                        trailing: Row(children: [
                          Container(
                              width: 1, height: 28, color: Colors.grey.shade300),
                          const SizedBox(width: 12),
                          const Icon(Icons.mic_rounded,
                              color: Color(0xFFFC6A19), size: 28),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _veg = !_veg),
                      child: Container(
                        width: 62,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('VEG',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade700,
                                    fontSize: 14)),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 34,
                              height: 14,
                              padding: const EdgeInsets.all(2),
                              alignment: _veg
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              decoration: BoxDecoration(
                                color: _veg
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // category chips
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _chips.length,
                  itemBuilder: (_, i) {
                    final sel = i == _chip;
                    return GestureDetector(
                      onTap: () => setState(() => _chip = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: sel ? Colors.white : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Row(children: [
                          Icon(_chips[i].$2,
                              size: 20,
                              color: sel ? Colors.white : Colors.white54),
                          const SizedBox(width: 6),
                          Text(_chips[i].$1,
                              style: TextStyle(
                                  color: sel ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // banner
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🍟', style: TextStyle(fontSize: 44)),
                    Column(children: [
                      Text('FLAVOURFEST',
                          style: TextStyle(
                            color: Color(0xFFFFD43B),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          )),
                      Text('ORDER NOW',
                          style: TextStyle(
                              color: Color(0xFFFFD43B),
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ]),
                    Text('🍔', style: TextStyle(fontSize: 44)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // offer cards
              SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _offers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => Container(
                    width: 120,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8319C),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(_offers[i].$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                height: 1.2)),
                        const Spacer(),
                        Text(_offers[i].$2,
                            style: const TextStyle(fontSize: 56)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // segmented REORDER / FOOD IN 15 MINS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 54,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: List.generate(2, (i) {
                final sel = i == _seg;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _seg = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        i == 0 ? 'REORDER' : 'FOOD IN 15 MINS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: sel
                              ? const Color(0xFFFC6A19)
                              : const Color(0xFF222222),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _restaurants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) {
              final r = _restaurants[i];
              return SizedBox(
                width: 170,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 170,
                      width: 170,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [r.$7.withOpacity(0.55), r.$7],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Stack(
                        children: [
                          const Align(
                            alignment: Alignment.topRight,
                            child: Icon(Icons.favorite_border_rounded,
                                color: Colors.white),
                          ),
                          Center(
                              child: Text(r.$2,
                                  style: const TextStyle(fontSize: 60))),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.$3,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20)),
                                Text(r.$4,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(r.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.stars_rounded,
                          color: Color(0xFF2E9E4F), size: 18),
                      const SizedBox(width: 4),
                      Text('${r.$5} • ${r.$6}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────────── INSTAMART PAGE ───────────────────────────── */

class InstamartPage extends StatefulWidget {
  const InstamartPage({super.key});

  @override
  State<InstamartPage> createState() => _InstamartPageState();
}

class _InstamartPageState extends State<InstamartPage> {
  int _deal = 0;
  Duration _left = const Duration(hours: 3, minutes: 37, seconds: 36);
  Timer? _timer;

  static const _tiles = [
    ('📱🎧', 'Phones & gadgets', 'UP TO 95% OFF'),
    ('🧸🚗', 'Toys & stationery', 'STARTS AT ₹5'),
    ('⌚📲', 'Tech elevated', 'SAMSUNG'),
    ('🍲💡', 'Home & kitchen', 'STARTS AT ₹19'),
    ('₹1', 'Deal Zone', ''),
    ('🧴🌾', 'Big pack savings', 'UP TO 80% OFF'),
  ];

  static const _dealChips = ['Crazy Deals', 'Under Rs 99 Deals', 'Flat 50% OFF'];

  static const _products = [
    ('🥛', 'Fresh Milk 500ml', '₹29', '₹34'),
    ('🍞', 'Brown Bread', '₹45', '₹55'),
    ('🍜', 'Yippee Noodles', '₹12', '₹15'),
    ('🍎', 'Apples 1kg', '₹149', '₹199'),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left.inSeconds > 0 && mounted) {
        setState(() => _left -= const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFF2A4BA0);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: panel,
          padding: const EdgeInsets.only(top: 22, bottom: 14),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchBox(
                        hint: "Search for 'Umbrella'",
                        trailing: Row(children: [
                          Icon(Icons.search_rounded,
                              color: Colors.grey.shade700, size: 30),
                          const SizedBox(width: 10),
                          Container(
                              width: 1, height: 28, color: Colors.grey.shade300),
                          const SizedBox(width: 10),
                          Icon(Icons.edit_note_rounded,
                              color: Colors.grey.shade800, size: 30),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 62,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.bookmark_border_rounded,
                          color: Colors.black87, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text('QUICK',
                  style: TextStyle(
                      color: Color(0xFF3CC8FF),
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1)),
              const Text('INDIA MOVEMENT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white54),
                ),
                child: const Text('LIVE NOW',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.88,
                  children: _tiles
                      .map((t) => _CatTile(emoji: t.$1, title: t.$2, tag: t.$3))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              const Text.rich(
                TextSpan(
                  style: TextStyle(color: Colors.white, fontSize: 15),
                  children: [
                    TextSpan(
                        text: '10% OFF up to ₹5500',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: ' on '),
                    TextSpan(
                        text: ' HDFC BANK ',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            backgroundColor: Colors.white,
                            color: Color(0xFF1B3C8C))),
                    TextSpan(text: ' credit card'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('DEALS LIVE NOW',
                  style: TextStyle(
                      color: Color(0xFF1B2F8F),
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2F8F),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(children: [
                  const Icon(Icons.timer_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(_fmt(_left),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dealChips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final sel = i == _deal;
              return GestureDetector(
                onTap: () => setState(() => _deal = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFFE8EEFF) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFF2A4BA0)
                            : Colors.grey.shade300,
                        width: sel ? 2 : 1),
                  ),
                  child: Row(children: [
                    Text(i == 0 ? '🏷️' : i == 1 ? '🪙' : '⚡',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(_dealChips[i],
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? const Color(0xFF2A4BA0)
                                : Colors.grey.shade700)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F7F5),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text.rich(TextSpan(
            style: TextStyle(fontSize: 17),
            children: [
              TextSpan(
                  text: 'FREE DELIVERY',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' on orders above ₹99'),
            ],
          )),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: _products
                .map((p) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: [
                        Text(p.$1, style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.$2,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text(p.$3,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 6),
                                Text(p.$4,
                                    style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                        fontSize: 12)),
                              ]),
                            ],
                          ),
                        ),
                      ]),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _CatTile extends StatelessWidget {
  final String emoji, title, tag;
  const _CatTile({required this.emoji, required this.title, required this.tag});

  @override
  Widget build(BuildContext context) {
    final isDeal = emoji == '₹1';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: isDeal
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B3FD6),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: const Color(0xFFFFD43B), width: 3),
                      ),
                      child: const Text('₹1',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900)),
                    )
                  : Text(emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
          Text(title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF5BD0FF),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Text(tag.isEmpty ? 'DEAL ZONE' : tag,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF1B2F8F),
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── DINEOUT / SCENES (generic) ───────────────────────── */

class GenericPage extends StatelessWidget {
  final int sectionIndex;
  const GenericPage({super.key, required this.sectionIndex});

  @override
  Widget build(BuildContext context) {
    final s = sections[sectionIndex];
    final isDine = sectionIndex == 2;
    final items = isDine
        ? const [
            ('🍕', 'Pizza Express', 'Flat 40% OFF'),
            ('🍣', 'Sushi Samba', 'Up to 30% OFF'),
            ('🥘', 'Barbeque Nation', 'Flat 25% OFF'),
            ('🍰', 'Theobroma', 'Free dessert'),
          ]
        : const [
            ('🎤', 'Stand-up Night', 'Tonight • 8 PM'),
            ('🎸', 'Live Band Fest', 'Sat • 7 PM'),
            ('🎭', 'Theatre Weekend', 'Sun • 6 PM'),
            ('🎧', 'EDM Rooftop', 'Fri • 10 PM'),
          ];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PanelWrap(
          color: s.panel,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchBox(
                  hint: isDine
                      ? "Search for 'Restaurants'"
                      : "Search for 'Concerts'",
                  trailing: Icon(Icons.search_rounded,
                      color: Colors.grey.shade700, size: 30),
                ),
              ),
              const SizedBox(height: 28),
              Text(s.emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 8),
              Text(isDine ? 'DINE OUT & SAVE' : 'FIND YOUR SCENE',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(s.subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(isDine ? 'Top picks near you' : 'Happening soon',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        ...items.map((e) => Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: s.panel.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Text(e.$1, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(e.$3,
                          style: TextStyle(
                              color: s.panel, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ]),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}