// Terms of Use screen that requires the user to actually scroll through
// the whole document before they can agree and continue.
//
// Gating logic (unchanged from previous versions):
//   1. `_hasReachedEnd` flips true only once the scroll offset reaches
//      (effectively) the bottom of the content.
//   2. The "Agree & Continue" button is disabled until `_hasReachedEnd`
//      is true — there's no checkbox; reaching the bottom of the
//      document IS the consent gate. Tapping the button when enabled
//      counts as agreement, made explicit by the "By continuing, you
//      agree..." disclaimer sitting right above it.
//
// Deliberately does NOT have quick-jump chips like `LegalTermsScreen`
// does — letting someone tap straight to the last section would satisfy
// `_hasReachedEnd` without them reading anything in between, which
// defeats the point of this screen. The gold progress bar is read-only
// feedback, not a navigation control.
//
// Drop this in before letting someone reach SignupScreen, e.g. from
// LoginScreen's "Sign Up" button:
//
//   Get.to(() => LegalTermsAgreementScreen(
//     onAgree: () => Get.off(() => SignupScreen()),
//   ));
//
// Section rendering (cards, bullets, spacing, contrast, icons) lives in
// `legal_terms_widgets.dart`, shared with `legal_terms_screen.dart`.

import 'package:asan_evac_app/screens/legal/widget/legal_terms_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:asan_evac_app/generated/assets.dart';
import '../admin/admin_dashboard_screen.dart'; // Retained for primaryRed
import 'legal_terms_content.dart';

class LegalTermsAgreementScreen extends StatefulWidget {
  /// Called when the user has scrolled through the whole document and
  /// tapped "Agree & Continue".
  final VoidCallback onAgree;

  /// Called when the user backs out instead. If omitted, "Decline" just
  /// pops the screen.
  final VoidCallback? onDecline;

  const LegalTermsAgreementScreen({
    super.key,
    required this.onAgree,
    this.onDecline,
  });

  @override
  State<LegalTermsAgreementScreen> createState() =>
      _LegalTermsAgreementScreenState();
}

class _LegalTermsAgreementScreenState
    extends State<LegalTermsAgreementScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _progress = ValueNotifier(0.0);

  bool _hasReachedEnd = false;

  // How close to the true bottom counts as "reached the end". A small
  // tolerance avoids requiring a pixel-perfect scroll on every device.
  static const double _bottomTolerance = 24.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    // Handles the (rare) case where the content is short enough to fit
    // on screen without any scrolling being possible at all.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;

    _progress.value =
    maxExtent <= 0 ? 1.0 : (position.pixels / maxExtent).clamp(0.0, 1.0);

    final reachedEnd = maxExtent <= 0 || position.pixels >= maxExtent - _bottomTolerance;
    if (reachedEnd && !_hasReachedEnd) {
      setState(() => _hasReachedEnd = true);
    }
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: widget.onDecline ?? () => Navigator.of(context).pop(),
          child: Text(
            'Decline',
            style: TextStyle(
              color: secondaryLabelColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
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

          // 3. Content + Bottom Agreement Bar
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Column(
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, value, _) =>
                          LegalReadingProgressBar(progress: value),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
                            child: LegalReadingWidth(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: LegalDocumentHeader(
                                      eyebrow:
                                      'PLEASE READ BEFORE CONTINUING',
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  for (
                                  var i = 0;
                                  i < kTermsSections.length;
                                  i++
                                  ) ...[
                                    LegalFadeSlideIn(
                                      index: i,
                                      child: LegalTermsSectionCard(
                                        section: kTermsSections[i],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: LegalEndOfDocumentMarker(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Floating "keep scrolling" hint, fades out
                          // once the end of the document is reached.
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              ignoring: _hasReachedEnd,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: _hasReachedEnd ? 0.0 : 1.0,
                                child: _ScrollHint(
                                  backgroundColor: backgroundColor,
                                  onTap: _scrollToEnd,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _AgreementBar(
                      hasReachedEnd: _hasReachedEnd,
                      secondaryLabelColor: secondaryLabelColor,
                      onContinue: _hasReachedEnd ? widget.onAgree : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollHint extends StatelessWidget {
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ScrollHint({required this.backgroundColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            backgroundColor.withValues(alpha: 0.0),
            backgroundColor.withValues(alpha: 0.92),
            backgroundColor,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(
                  context,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scroll to read the full terms',
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 13,
                    color: primaryRed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementBar extends StatelessWidget {
  final bool hasReachedEnd;
  final Color secondaryLabelColor;
  final VoidCallback? onContinue;

  const _AgreementBar({
    required this.hasReachedEnd,
    required this.secondaryLabelColor,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status / disclaimer line — swaps from a "keep reading" nudge
          // to the explicit consent disclaimer once unlocked.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasReachedEnd
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.lock_fill,
                size: 15,
                color: hasReachedEnd
                    ? primaryRed
                    : secondaryLabelColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasReachedEnd
                      ? 'By continuing, you agree to the Terms of Use and '
                      'Service Policy.'
                      : 'Scroll to the end of the document to continue.',
                  style: TextStyle(
                    color: hasReachedEnd
                        ? CupertinoColors.label.resolveFrom(context)
                        : secondaryLabelColor.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: hasReachedEnd ? 1.0 : 0.4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      primaryRed,
                      Color.lerp(primaryRed, Colors.black, 0.12) ??
                          primaryRed,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: hasReachedEnd
                      ? [
                    BoxShadow(
                      color: primaryRed.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onContinue,
                  child: const Text(
                    'Agree & Continue',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
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