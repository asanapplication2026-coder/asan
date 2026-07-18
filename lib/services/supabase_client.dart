import 'package:supabase_flutter/supabase_flutter.dart';

/// Call once in main() before runApp().
Future<void> initSupabase() async {
  // Read variables passed via --dart-define
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // Optional but recommended: guard against missing environment variables
  if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
    throw Exception(
      'Missing Supabase configuration. Please provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY via --dart-define.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: publishableKey,
  );
}

/// Shorthand accessor used throughout the app instead of
/// Supabase.instance.client everywhere.
SupabaseClient get supabase => Supabase.instance.client;