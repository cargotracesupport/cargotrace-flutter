/// Backend configuration for the CargoTrace driver app.
///
/// The Supabase URL and anon key are PUBLIC by design — the very values the web
/// app already ships as NEXT_PUBLIC_*. Row-Level Security on the database is the
/// real guard, so embedding them here is safe. The service_role key must NEVER
/// appear in this app.
class Config {
  static const supabaseUrl = 'https://ahfrdgbcatlnnckopvni.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFoZnJkZ2JjYXRsbm5ja29wdm5pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5MDEyMzksImV4cCI6MjA5NzQ3NzIzOX0.DqIyD1l0rXFWdxA-aqI45hwJRZRle31ncS3ss11cmKA';

  /// Deployed Next.js base URL — used later for the GPS ingest endpoint
  /// (/api/track). Set per build with --dart-define=API_BASE_URL=...
  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
}
