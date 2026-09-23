// Read-only Terms of Use screen.
//
// Use this when someone just wants to *view* the policy — e.g. from
// Settings > Legal, a footer link, or a "Read our Terms" button anywhere
// that isn't gating an action. It never blocks or asks for agreement;
// it's pure reading.
//
// For the version that requires scrolling to the end before the user can
// agree (e.g. during signup), see `legal_terms_agreement_screen.dart`.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:asan_evac_app/generated/assets.dart';
import '../admin/admin_dashboard_screen.dart'; // Retained for primaryRed
import 'legal_terms_content.dart';

class LegalTermsScreen extends StatelessWidget {
  const LegalTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
      context,
    );
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(
      context,
    );

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withValues(alpha: 0.9),
        middle: const Text(
          'Terms of Use',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      child: Stack(
        children: [
          // 1. Premium Ambient Background Layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryRed.withValues(alpha: 0.06),
                    backgroundColor,
                    backgroundColor,
                  ],
                ),
              ),
            ),
          ),

          // 2. Elegant Background Watermark Logo
          Positioned(
            right: -40,
            top: 60,
            child: Opacity(
              opacity: 0.05,
              child: SizedBox(
                width: 260,
                height: 260,
                child: Assets.asanLogo.image(fit: BoxFit.contain),
              ),
            ),
          ),

          // 3. Scrollable Content
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DocumentHeader(secondaryLabelColor: secondaryLabelColor),
                      const SizedBox(height: 32),
                      for (final section in kTermsSections) ...[
                        _TermsSectionBlock(
                          section: section,
                          secondaryLabelColor: secondaryLabelColor,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  final Color secondaryLabelColor;

  const _DocumentHeader({required this.secondaryLabelColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LEGAL',
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

class _TermsSectionBlock extends StatelessWidget {
  final TermsSection section;
  final Color secondaryLabelColor;

  const _TermsSectionBlock({
    required this.section,
    required this.secondaryLabelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.number.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  section.number,
                  style: TextStyle(
                    color: primaryRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            section.title,
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          section.body,
          style: TextStyle(
            color: secondaryLabelColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}