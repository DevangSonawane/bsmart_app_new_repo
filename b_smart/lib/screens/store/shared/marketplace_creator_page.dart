// Creator page ("iPhone 18 Pro - 9" in the Bsmart Figma file), opened from
// the PEOPLE tab. Profile details come from the creator's store profile;
// listings are that creator's items in the live marketplace catalog.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../api/chat_api.dart';
import '../../chat_conversation_screen.dart';
import '../../messaging_screen.dart';
import '../store_models.dart';
import '../store_profile_state.dart';
import 'marketplace_figma_home.dart';
import 'marketplace_people_section.dart';
import 'store_shared_widgets.dart';

const _cover = 'assets/store/marketplace/home/creator_cover_default.webp';

enum _CreatorListing { all, products, services }

class MkCreatorPage extends StatefulWidget {
  final MkCreator creator;
  const MkCreatorPage({super.key, required this.creator});

  @override
  State<MkCreatorPage> createState() => _MkCreatorPageState();
}

class _MkCreatorPageState extends State<MkCreatorPage> {
  _CreatorListing _filter = _CreatorListing.all;
  bool _openingChat = false;

  MkCreator get c => widget.creator;

  @override
  void initState() {
    super.initState();
    StoreProfileState.instance.addListener(_changed);
    StoreMockState.instance.addListener(_changed);
    MkFollowing.ids.addListener(_changed);
    unawaited(StoreProfileState.instance.ensureLoaded(c.id));
    unawaited(MkFollowing.load());
  }

  @override
  void dispose() {
    StoreProfileState.instance.removeListener(_changed);
    StoreMockState.instance.removeListener(_changed);
    MkFollowing.ids.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleFollow() async {
    try {
      await MkFollowing.toggle(c.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  Future<void> _openChat() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final conversation =
          await ChatApi().createOrGetConversation(participantId: c.id);
      if (!mounted) return;
      final id = (conversation['_id'] ?? conversation['id'])?.toString();
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => id == null || id.isEmpty
            ? const MessagingScreen()
            : ChatConversationScreen(
                conversationId: id,
                initialConversation: conversation,
              ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Couldn't start a chat with this creator.")),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreMockState.instance;
    final products =
        store.products.where((i) => mkOwnerIdOf(i.raw) == c.id).toList();
    final services =
        store.services.where((i) => mkOwnerIdOf(i.raw) == c.id).toList();
    final profile = StoreProfileState.instance.profileFor(c.id);
    final following =
        MkFollowing.isFollowing(c.id) || (profile?.isFollowing ?? false);

    final title = (profile?.storeType.trim().isNotEmpty ?? false)
        ? profile!.storeType.trim()
        : c.subtitle;
    final location = (profile?.serviceAreas ?? const <String>[])
        .where((s) => s.trim().isNotEmpty)
        .take(2)
        .join(', ');
    final about = profile?.about.trim() ?? '';
    final tags = c.categories.take(4).toList();
    final listing = switch (_filter) {
      _CreatorListing.all => [...products, ...services],
      _CreatorListing.products => products,
      _CreatorListing.services => services,
    };
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Cover, under the status bar like the Figma frame.
                SizedBox(
                  height: top + 192,
                  width: double.infinity,
                  child: Image.asset(_cover, fit: BoxFit.cover),
                ),
                Positioned(
                  left: 19,
                  top: top + 11,
                  child: _CircleButton(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: top + 11,
                  child: _CircleButton(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    active: following,
                    onTap: _toggleFollow,
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: top + 166),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileCard(
                        creator: c,
                        title: title,
                        chatBusy: _openingChat,
                        onChat: _openChat,
                      ),
                      const SizedBox(height: 16),
                      _MetaRow(
                        rating: c.rating,
                        reviews: c.reviews,
                        offerings: products.length + services.length,
                        location: location,
                      ),
                      if (about.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          about,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: const Color(0xFF252525),
                            height: 1.56,
                          ),
                        ),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 9,
                          runSpacing: 8,
                          children: [for (final t in tags) _CategoryTag(t)],
                        ),
                      ],
                      const SizedBox(height: 15),
                      const Divider(height: 1, color: Color(0xFF9E9E9E)),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CountChip(
                              label: 'All',
                              count: products.length + services.length,
                              selected: _filter == _CreatorListing.all,
                              onTap: () =>
                                  setState(() => _filter = _CreatorListing.all),
                            ),
                            const SizedBox(width: 10),
                            _CountChip(
                              label: 'Products',
                              count: products.length,
                              selected: _filter == _CreatorListing.products,
                              onTap: () => setState(
                                  () => _filter = _CreatorListing.products),
                            ),
                            const SizedBox(width: 10),
                            _CountChip(
                              label: 'Services',
                              count: services.length,
                              selected: _filter == _CreatorListing.services,
                              onTap: () => setState(
                                  () => _filter = _CreatorListing.services),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: store.catalogLoading && listing.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : listing.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: StoreEmptyState(
                          icon: LucideIcons.store,
                          title: 'Nothing here yet',
                          body: switch (_filter) {
                            _CreatorListing.products =>
                              '${c.name} has no products listed.',
                            _CreatorListing.services =>
                              '${c.name} has no services listed.',
                            _CreatorListing.all =>
                              '${c.name} has not published anything yet.',
                          },
                        ),
                      )
                    : MkProductGrid(items: listing, ownerUserId: c.id),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final bool active;
  final VoidCallback onTap;
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.activeIcon,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFA3F5E), width: 1.5),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: Icon(
            active ? (activeIcon ?? icon) : icon,
            key: ValueKey(active),
            size: 20,
            color: const Color(0xFFFA3F5E),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final MkCreator creator;
  final String title;
  final bool chatBusy;
  final VoidCallback onChat;
  const _ProfileCard({
    required this.creator,
    required this.title,
    required this.chatBusy,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEDEE3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          MkRingAvatar(creator: creator),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        creator.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: MkColors.ink,
                        ),
                      ),
                    ),
                    if (creator.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified,
                          size: 20, color: Color(0xFF22A447)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: const Color(0xFF434343),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFFFA3F5E),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: chatBusy ? null : onChat,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: chatBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.messageCircleMore,
                          size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final double? rating;
  final int reviews;
  final int offerings;
  final String location;
  const _MetaRow({
    required this.rating,
    required this.reviews,
    required this.offerings,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.sourceSans3(fontSize: 14, color: MkColors.ink);
    Widget dot() => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFA6A6A6),
            shape: BoxShape.circle,
          ),
        );
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 17, color: Color(0xFFFFA01B)),
        const SizedBox(width: 1),
        Text('${(rating ?? 0).toStringAsFixed(1)} ($reviews)', style: style),
        dot(),
        Text('$offerings Offering${offerings == 1 ? '' : 's'}', style: style),
        if (location.isNotEmpty) ...[
          dot(),
          Flexible(
            child: Text(location,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
        ],
      ],
    );
  }
}

class _CategoryTag extends StatelessWidget {
  final String label;
  const _CategoryTag(this.label);

  @override
  Widget build(BuildContext context) {
    // No `alignment` here: it would make the pill fill the Wrap's width.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22C2FD).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MkColors.ink,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _CountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
        decoration: ShapeDecoration(
          color: selected
              ? const Color(0xFFFA3F5E).withValues(alpha: 0.10)
              : Colors.white,
          shape: StadiumBorder(
            side: BorderSide(
              color:
                  selected ? const Color(0xFFFA3F5E) : const Color(0xFF3B3B3B),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected ? const Color(0xFFFA3F5E) : MkColors.ink,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MkColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
