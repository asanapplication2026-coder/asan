import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'auth_controller.dart';

class LoginController extends GetxController {
  final _authService = AuthService();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isPasswordVisible = false.obs;

  // Reactive error message state initialized as null
  final RxnString errorMessage = RxnString();

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  Future<void> login() async {
    // 1. Validation Logic
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || !GetUtils.isEmail(email)) {
      errorMessage.value = 'Please enter a valid email address.';
      return;
    }

    if (password.isEmpty || password.length < 6) {
      errorMessage.value = 'Password must be at least 6 characters long.';
      return;
    }

    // 2. Proceed with login
    isLoading.value = true;
    errorMessage.value = null;

    try {
      await _authService.signIn(
        email: email,
        password: password,
      );

      await Get.find<AuthController>().refreshProfile();
    } catch (e) {
      if (e is AuthApiException) {
        errorMessage.value = e.message;
      } else {
        errorMessage.value = 'An unexpected error occurred. Please try again.';
      }
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
