import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:asan_evac_app/generated/assets.dart';
import '../../controllers/signup_controller.dart';
import '../../controllers/auth_controller.dart';
import '../admin/admin_dashboard_screen.dart'; // Imports AuthController for email validation

class SignupScreen extends StatelessWidget {
  SignupScreen({super.key});

  final SignupController controller = Get.put(SignupController());
  final AuthController authController = Get.find<AuthController>();

  // Local observables for real-time validation tracking
  late final RxString _currentSchoolId = controller.schoolIdController.text.obs;
  late final RxString _currentEmail = controller.emailController.text.obs;
  late final RxString _currentPassword = controller.passwordController.text.obs;
  final RxBool _isPasswordVisible = false.obs;

  @override
  Widget build(BuildContext context) {
    // Dynamic iOS System Colors
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final systemGrayColor = CupertinoColors.systemFill.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
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
                    primaryRed.withValues(alpha: 0.06), // Soft top-left brand glow
                    backgroundColor,
                    backgroundColor, // Merges seamlessly into system background
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
              opacity: 0.05, // Ultra-subtle, clean watermark opacity
              child: SizedBox(
                width: 260,
                height: 260,
                child: Assets.asanLogo.image(
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // 3. Dynamic Interactive UI Layer
          Positioned.fill(
            child: Material( // Completely eradicates the yellow underline issue
              color: Colors.transparent,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start, // Clean left alignment
                        children: [
                          const SizedBox(height: 20),

                          // --- PRECISE TYPOGRAPHY HIERARCHY ---
                          Obx(() {
                            final awaitingConfirmation = controller.awaitingEmailConfirmation.value;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tier 1: Eyebrow (Quiet, sophisticated gray with high-tracking)
                                Text(
                                  awaitingConfirmation ? 'ALMOST THERE' : 'GET STARTED',
                                  style: TextStyle(
                                    color: systemGrayColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4), // Extremely tight spacing to lock it to the title

                                // Tier 2: Hero Brand Title (Vibrant, high-contrast Red Gradient)
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
                                    'Asan',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.8,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6), // Tight, deliberate spacing

                                // Tier 3: Subtitle Tagline (Clean, readable secondary text)
                                Text(
                                  awaitingConfirmation
                                      ? 'Confirm your email to finish setting up'
                                      : 'Digital headcount and evacuation hub',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.2,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            );
                          }),

                          // ------------------------------------

                          const SizedBox(height: 36),

                          // Alternating Form vs Success States
                          Obx(() {
                            if (controller.awaitingEmailConfirmation.value) {
                              return _buildSuccessContent(context, secondaryLabelColor);
                            }
                            return _buildFormContent(
                              context: context,
                              secondaryLabelColor: secondaryLabelColor,
                            );
                          }),

                          const SizedBox(height: 20),
                        ],
                      ),
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

  // --- UI STATES ---

  Widget _buildFormContent({
    required BuildContext context,
    required Color secondaryLabelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visually Separated Input Fields
        _buildInputField(
          context: context,
          textController: controller.schoolIdController,
          placeholder: 'School ID Number',
          onChanged: (value) => _currentSchoolId.value = value,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            'Must match the ID an admin already added you under',
            style: TextStyle(
              color: secondaryLabelColor,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        const SizedBox(height: 14),

        _buildEmailField(context),

        const SizedBox(height: 14),

        _buildPasswordField(context),

        const SizedBox(height: 12),

        // --- LIVE PASSWORD CHECKER CHECKLIST ---
        _buildPasswordRequirementsGrid(context),

        const SizedBox(height: 24),

        // Premium Action Button with Dynamic Shadowing & Validation State
        Obx(() {
          // Check all validation requirements
          final pwd = _currentPassword.value;
          final bool isPasswordValid =
              pwd.length >= 6 &&
                  RegExp(r'[a-z]').hasMatch(pwd) &&
                  RegExp(r'[A-Z]').hasMatch(pwd) &&
                  RegExp(r'[0-9]').hasMatch(pwd) &&
                  RegExp(r'[^a-zA-Z0-9\s]').hasMatch(pwd);

          final bool isEmailValid = authController.isValidEmail(_currentEmail.value.trim());

          final bool isFormValid =
              _currentSchoolId.value.trim().isNotEmpty &&
                  isEmailValid &&
                  isPasswordValid;

          final bool isButtonDisabled = controller.isLoading.value || !isFormValid;

          return Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: isButtonDisabled
                  ? null
                  : LinearGradient(
                colors: [
                  primaryRed,
                  Color.lerp(primaryRed, Colors.black, 0.12) ?? primaryRed,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              color: isButtonDisabled ? primaryRed.withValues(alpha: 0.4) : null,
              boxShadow: [
                if (!isButtonDisabled)
                  BoxShadow(
                    color: primaryRed.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: isButtonDisabled ? null : controller.signup,
              child: controller.isLoading.value
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text(
                'Create Account',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        // Footer Navigation Switcher
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Already have an account? ",
              style: TextStyle(
                color: secondaryLabelColor,
                fontSize: 14,
                letterSpacing: -0.1,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Get.back(),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  color: primaryRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),

        // Premium Error Toast Banner
        Obx(
              () => controller.errorMessage.value != null
              ? Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.destructiveRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                controller.errorMessage.value!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSuccessContent(BuildContext context, Color secondaryLabelColor) {
    return Column(
      children: [
        const Center(
          child: Icon(
            CupertinoIcons.mail_solid,
            size: 64,
            color: primaryRed,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'We sent a confirmation link to your email. Tap it, then sign in below to finish setting up your account.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryLabelColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Premium Action Button
        Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                primaryRed,
                Color.lerp(primaryRed, Colors.black, 0.12) ?? primaryRed,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryRed.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Get.back(),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- REUSABLE SUB-WIDGETS ---

  Widget _buildInputField({
    required BuildContext context,
    required TextEditingController textController,
    required String placeholder,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: CupertinoTextField(
        controller: textController,
        keyboardType: keyboardType,
        placeholder: placeholder,
        clearButtonMode: OverlayVisibilityMode.editing,
        onChanged: onChanged,
        placeholderStyle: TextStyle(
          color: CupertinoColors.placeholderText.resolveFrom(context),
          fontSize: 16,
        ),
        style: TextStyle(
          color: CupertinoColors.label.resolveFrom(context),
          fontSize: 16,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
    );
  }

  Widget _buildEmailField(BuildContext context) {
    return Obx(() {
      final bool isValid = authController.isValidEmail(_currentEmail.value.trim());

      return Container(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: CupertinoTextField(
          controller: controller.emailController,
          keyboardType: TextInputType.emailAddress,
          placeholder: 'Email',
          onChanged: (value) => _currentEmail.value = value,
          placeholderStyle: TextStyle(
            color: CupertinoColors.placeholderText.resolveFrom(context),
            fontSize: 16,
          ),
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(color: Colors.transparent),
          suffix: _currentEmail.value.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isValid ? 1.0 : 0.0,
              child: Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: CupertinoColors.systemGreen.resolveFrom(context),
                size: 20,
              ),
            ),
          )
              : const SizedBox.shrink(),
        ),
      );
    });
  }

  Widget _buildPasswordField(BuildContext context) {
    return Obx(
          () => Container(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: CupertinoTextField(
          controller: controller.passwordController,
          obscureText: !_isPasswordVisible.value,
          placeholder: 'Password',
          onChanged: (value) => _currentPassword.value = value,
          placeholderStyle: TextStyle(
            color: CupertinoColors.placeholderText.resolveFrom(context),
            fontSize: 16,
          ),
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(color: Colors.transparent),
          suffix: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _isPasswordVisible.toggle,
            child: Icon(
              _isPasswordVisible.value ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              color: CupertinoColors.label.resolveFrom(context),
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  // --- PREMIUM PASSWORD REQUIREMENTS CHECKER WIDGET ---

  Widget _buildPasswordRequirementsGrid(BuildContext context) {
    final activeGreen = CupertinoColors.systemGreen.resolveFrom(context);
    final inactiveGray = CupertinoColors.secondaryLabel.resolveFrom(context).withValues(alpha: 0.5);

    return Obx(() {
      final pwd = _currentPassword.value;

      // Validation Rules
      final bool hasMinLength = pwd.length >= 6;
      final bool hasLowercase = RegExp(r'[a-z]').hasMatch(pwd);
      final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(pwd);
      final bool hasDigit = RegExp(r'[0-9]').hasMatch(pwd);
      final bool hasSpecial = RegExp(r'[^a-zA-Z0-9\s]').hasMatch(pwd);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PASSWORD REQUIREMENTS',
              style: TextStyle(
                color: inactiveGray.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildRequirementItem('6+ characters', hasMinLength, activeGreen, inactiveGray),
                _buildRequirementItem('Lowercase', hasLowercase, activeGreen, inactiveGray),
                _buildRequirementItem('Uppercase', hasUppercase, activeGreen, inactiveGray),
                _buildRequirementItem('Number', hasDigit, activeGreen, inactiveGray),
                _buildRequirementItem('Special char', hasSpecial, activeGreen, inactiveGray),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRequirementItem(String title, bool isMet, Color metColor, Color unmetColor) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: 12,
        fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
        color: isMet ? metColor : unmetColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? metColor.withValues(alpha: 0.15) : Colors.transparent,
              border: Border.all(
                color: isMet ? metColor : unmetColor,
                width: 1.5,
              ),
            ),
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isMet ? 1.0 : 0.0,
                child: Icon(
                  CupertinoIcons.checkmark,
                  size: 9,
                  color: metColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(title),
        ],
      ),
    );
  }
}