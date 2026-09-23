// Shared, readability-focused rendering for the ASAN Terms of Use.
//
// Both `LegalTermsScreen` and `LegalTermsAgreementScreen` render the same
// `TermsSection` list (from legal_terms_content.dart) through these
// widgets, so any future visual tweak only needs to happen in one place.
//
// Design language deliberately mirrors the rest of the app rather than
// inventing a new one:
//   • The gold gradient used for onboarding's subtitle text and page
//     indicators is reused here for the reading-progress bar.
//   • The "STEP 1 OF 3" eyebrow pattern from onboarding becomes
//     "SECTION 03" above each term's title.
//   • Cards use the same secondarySystemBackground + 8%-opacity
//     separator border as your input fields, so they read as part of
//     the same design system, not a different screen bolted on.
//
// Readability choices carried over from the previous pass:
//   • Bullet lines are parsed into real rows with a dot marker and a
//     hanging indent, not "• " sitting inline inside a paragraph.
//   • Body text is 15px/1.6 line-height at 72%-opacity label color —
//     more legible than iOS's default secondaryLabel over long copy.
//   • Content is capped at 640px and centered so lines don't stretch
//     edge-to-edge into unreadable length on a tablet.

import 'dart:async';

import 'package:asan_evac_app/screens/legal/legal_terms_content.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../admin/admin_dashboard_screen.dart';

/// Same "Lux Gold" gradient used for onboarding's subtitle text and page
/// indicators — reused here so the reading-progress bar feels like part
/// of the same app, not a generic loading bar.
const LinearGradient legalGoldGradient = LinearGradient(
  colors: [Color(0xFFFFDF00), Color(0xFFF1A80A)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// ---------------------------------------------------------------------
// Section icon + short label lookup
// ---------------------------------------------------------------------

IconData legalIconForSection(String number) {
  switch (number) {
    case '1':
      return CupertinoIcons.shield_fill; // Purpose
    case '2':
      return CupertinoIcons.person_3_fill; // Authorized Users
    case '3':
      return CupertinoIcons.checkmark_seal_fill; // Responsible Use
    case '4':
      return CupertinoIcons.location_solid; // Location Information
    case '5':
      return CupertinoIcons.bell_fill; // Emergency Notifications & SMS
    case '6':
      return CupertinoIcons.eye_slash_fill; // Privacy
    case '7':
      return CupertinoIcons.lock_fill; // Account & Access Security
    case '8':
      return CupertinoIcons.doc_text_fill; // Intellectual Property
    case '9':
      return CupertinoIcons.exclamationmark_triangle_fill; // Limitation
    default:
      return CupertinoIcons.hand_raised_fill; // Welcome / intro
  }
}

/// Compact label for the quick-jump chip row — full section titles are
/// too long to sit comfortably in a pill.
String legalShortLabelForSection(String number) {
  switch (number) {
    case '1':
      return 'Purpose';
    case '2':
      return 'Users';
    case '3':
      return 'Responsible Use';
    case '4':
      return 'Location';
    case '5':
      return 'Notifications';
    case '6':
      return 'Privacy';
    case '7':
      return 'Security';
    case '8':
      return 'IP Rights';
    case '9':
      return 'Limitations';
    default:
      return 'Welcome';
  }
}

// ---------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------

/// Caps content at a comfortable reading width and centers it — a no-op
/// on phones, but keeps line length sane on tablets/wide screens.
class LegalReadingWidth extends StatelessWidget {
  final Widget child;

  const LegalReadingWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    );
  }
}

/// Thin gold progress bar showing how far through the document the
/// reader has scrolled. Sits pinned above the scroll view on both
/// screens — on the agreement screen it doubles as a visual echo of the
/// "keep going" gate.
class LegalReadingProgressBar extends StatelessWidget {
  /// 0.0 – 1.0
  final double progress;

  const LegalReadingProgressBar({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      width: double.infinity,
      color: CupertinoColors.separator.resolveFrom(context).withValues(
        alpha: 0.15,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 120),
          curve: Curves.linear,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(decoration: const BoxDecoration(gradient: legalGoldGradient)),
        ),
      ),
    );
  }
}

/// FractionallySizedBox doesn't animate on its own — this wraps it in an
/// implicit animation so the gold fill glides rather than jumps as the
/// user scrolls.
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
    required super.duration,
    super.curve,
  });

  @override
  ImplicitlyAnimatedWidgetState<AnimatedFractionallySizedBox> createState() =>
      _AnimatedFractionallySizedBoxState();
}

class _AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
          (value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _widthFactor?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}

/// Horizontally scrollable row of section chips for quick navigation.
/// Only used on the read-only `LegalTermsScreen` — deliberately kept off
/// `LegalTermsAgreementScreen`, where letting someone jump straight to
/// the last section would satisfy the "scrolled to the end" check
/// without them reading anything in between.
class LegalSectionChipRow extends StatelessWidget {
  final ValueChanged<int> onSelect;

  const LegalSectionChipRow({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kTermsSections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = kTermsSections[index];
          return _SectionChip(
            icon: legalIconForSection(section.number),
            label: legalShortLabelForSection(section.number),
            onTap: () => onSelect(index),
          );
        },
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SectionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(
            context,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: CupertinoColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: primaryRed),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: CupertinoColors.label.resolveFrom(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------

class LegalDocumentHeader extends StatelessWidget {
  /// e.g. 'LEGAL' or 'PLEASE READ BEFORE CONTINUING'
  final String eyebrow;

  const LegalDocumentHeader({super.key, required this.eyebrow});

  @override
  Widget build(BuildContext context) {
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(
      context,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: secondaryLabelColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              primaryRed,
              Color.lerp(primaryRed, Colors.white, 0.28) ?? primaryRed,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
          child: const Text(
            kTermsDocumentTitle,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.4,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          kTermsDocumentSubtitle,
          style: TextStyle(
            color: secondaryLabelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Section card
// ---------------------------------------------------------------------

/// One section of the document, rendered as its own card so the reader
/// can scan section-to-section instead of parsing one long scroll.
class LegalTermsSectionCard extends StatelessWidget {
  final TermsSection section;

  const LegalTermsSectionCard({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    // A touch darker than iOS's default secondaryLabel — more legible
    // over a long document while still reading as secondary to titles.
    final bodyColor = labelColor.withValues(alpha: 0.72);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: CupertinoColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(section: section, labelColor: labelColor),
          const SizedBox(height: 14),
          ..._buildBodyBlocks(section.body, bodyColor),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final TermsSection section;
  final Color labelColor;

  const _SectionHeading({required this.section, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    final eyebrow = section.number.isEmpty
        ? 'INTRODUCTION'
        : 'SECTION ${section.number.padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primaryRed.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            legalIconForSection(section.number),
            size: 19,
            color: primaryRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: primaryRed.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                section.title,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Splits a section's body into paragraphs on blank lines. A paragraph
/// whose every line starts with '• ' is rendered as a real bullet list
/// (dot marker + hanging indent); everything else renders as prose with
/// generous line-height.
List<Widget> _buildBodyBlocks(String body, Color bodyColor) {
  final proseStyle = TextStyle(
    color: bodyColor,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: -0.1,
  );

  final paragraphs = body.split('\n\n');
  final blocks = <Widget>[];

  for (var i = 0; i < paragraphs.length; i++) {
    final paragraph = paragraphs[i];
    final lines = paragraph
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final isBulletList =
        lines.isNotEmpty && lines.every((l) => l.startsWith('• '));

    if (isBulletList) {
      blocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BulletLine(
                  text: line.substring(2),
                  style: proseStyle,
                  dotColor: bodyColor,
                ),
              ),
          ],
        ),
      );
    } else {
      blocks.add(Text(paragraph, style: proseStyle));
    }

    if (i != paragraphs.length - 1) {
      blocks.add(const SizedBox(height: 14));
    }
  }

  return blocks;
}

class _BulletLine extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color dotColor;

  const _BulletLine({
    required this.text,
    required this.style,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// End marker
// ---------------------------------------------------------------------

class LegalEndOfDocumentMarker extends StatelessWidget {
  const LegalEndOfDocumentMarker({super.key});

  @override
  Widget build(BuildContext context) {
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(
      context,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: CupertinoColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'End of document',
              style: TextStyle(
                color: secondaryLabelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: CupertinoColors.separator
                  .resolveFrom(context)
                  .withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Staggered entrance animation
// ---------------------------------------------------------------------

/// Wraps a card in a subtle fade + upward-slide that plays once, staggered
/// by `index` so cards settle in one after another rather than popping in
/// all at once. Purely cosmetic polish on first build — has no effect on
/// scroll position or the agreement screen's read-to-the-end gate.
class LegalFadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;

  const LegalFadeSlideIn({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<LegalFadeSlideIn> createState() => _LegalFadeSlideInState();
}

class _LegalFadeSlideInState extends State<LegalFadeSlideIn> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index * 45).clamp(0, 320);
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      opacity: _visible ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        offset: _visible ? Offset.zero : const Offset(0, 0.04),
        child: widget.child,
      ),
    );
  }
}