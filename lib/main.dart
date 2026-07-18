import 'package:asan_evac_app/screens/admin/admin_dashboard_screen.dart';
import 'package:asan_evac_app/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app.dart';
import 'services/supabase_client.dart';
import 'services/local_storage_service.dart';
import 'controllers/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure native bindings are initialized
  await initSupabase(); // Initialize Supabase client[cite: 4]
  await Firebase.initializeApp(); // Initialize Firebase instances[cite: 4]
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  ); // Set up notification listener[cite: 4]

  final localStorage =
      await LocalStorageService.init(); // Mount shared preferences locally[cite: 4]
  Get.put(
    localStorage,
    permanent: true,
  ); // Cache storage settings permanently[cite: 4]

  // Permanent — must survive for the lifetime of the app, since
  // RootRouter watches it on every rebuild. Registering this also
  // triggers PushNotificationService.instance.initialize() internally
  // (see AuthController._initPushNotificationsOnce), once a session is
  // available — do NOT also call initialize() here, it would double-fire
  // the permission prompt / topic subscription.
  Get.put(
    AuthController(),
    permanent: true,
  ); // Register AuthController[cite: 4]

  runApp(const EvacApp()); // Start the primary app instance[cite: 4]
}

class EvacApp extends StatelessWidget {
  const EvacApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'School Evacuation App', // Kept app branding title[cite: 4]
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Retained modern Material design standard[cite: 4]

        // 1. Swapped default indigo seed with your brand's primaryRed[cite: 4]
        colorSchemeSeed: primaryRed,

        // 2. Force App Bar elements to match the red design style
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryRed),
          actionsIconTheme: IconThemeData(color: primaryRed),
        ),

        // 3. Ensure global Tab Bars align with your primary brand colors
        // FIXED: TabBarTheme updated to TabBarThemeData to prevent compiler mismatch
        tabBarTheme: const TabBarThemeData(
          indicatorColor: primaryRed,
          labelColor: primaryRed,
          indicatorSize: TabBarIndicatorSize.tab,
        ),

        // 4. Force cursor selection handles to adhere to your brand colors
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: primaryRed,
          selectionColor: primaryRed,
          selectionHandleColor: primaryRed,
        ),
      ),
      home: const AppEntryPoint(), // Render the main navigation router[cite: 4]
    );
  }
}
