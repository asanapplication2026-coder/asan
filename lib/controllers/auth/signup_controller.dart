import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';

class SignupController extends GetxController {
  final _authService = AuthService();

  final schoolIdController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  /// True once signUp() succeeds — at this point the auth user exists
  /// but there's no session/profile yet. UI should show a "check your
  /// email to confirm" state, not navigate into the app.
  final RxBool awaitingEmailConfirmation = false.obs;

  Future<void> signup() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _authService.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        schoolIdNumber: schoolIdController.text.trim(),
      );
      awaitingEmailConfirmation.value = true;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    schoolIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}