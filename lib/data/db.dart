import 'package:supabase_flutter/supabase_flutter.dart';

/// The app-wide Supabase client. Valid only after [Supabase.initialize] has run
/// in main(); as a lazily-initialized top-level final, it is first read after
/// that completes.
final supabase = Supabase.instance.client;
