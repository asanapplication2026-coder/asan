import 'package:asan_evac_app/services/profile_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Prompts the signed-in user to register a contact number.
/// No OTP step — this just persists the number to
/// profiles.registered_phone_number and calls [onSaved].
///
/// barrierDismissible is false: the caller decides whether to show this
/// at all (i.e. only when the number is missing), so once shown it
/// should be completed rather than dismissed accidentally.
Future<void> showPhoneRegistrationDialog(
    BuildContext context, {
      required String profileId,
      required VoidCallback onSaved,
    }) async {
  final controller = TextEditingController();
  final errorNotifier = ValueNotifier<String?>(null);
  final savingNotifier = ValueNotifier<bool>(false);
  final service = ProfileService();

  await showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add a contact number',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'We need a number to reach you on during a drill or real emergency. '
                    'You can update this later in your profile.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              CupertinoTextField(
                controller: controller,
                placeholder: '09XX XXX XXXX',
                keyboardType: TextInputType.phone,
                autofocus: true,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: errorNotifier,
                builder: (context, error, _) => error == null
                    ? const SizedBox(height: 20)
                    : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    error,
                    style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: savingNotifier,
                builder: (context, saving, _) => CupertinoButton(
                  color: const Color(0xFF7B1113),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: saving
                      ? null
                      : () async {
                    final raw = controller.text.trim();
                    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      errorNotifier.value = 'Enter a valid phone number.';
                      return;
                    }
                    savingNotifier.value = true;
                    errorNotifier.value = null;
                    try {
                      await service.updateRegisteredPhoneNumber(
                        profileId: profileId,
                        phoneNumber: raw,
                      );
                      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      onSaved();
                    } catch (e) {
                      errorNotifier.value = 'Could not save: $e';
                    } finally {
                      savingNotifier.value = false;
                    }
                  },
                  child: saving
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}