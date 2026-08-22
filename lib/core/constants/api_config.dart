/// API configuration for Supabase and Odoo ERP
/// Secrets are injected via compile-time environment variables:
/// flutter run --dart-define-from-file=.env
/// flutter build web --release --dart-define-from-file=.env
class ApiConfig {
  // Supabase Credentials (injected via .env)
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String supabaseSecretKey = String.fromEnvironment('SUPABASE_SECRET_KEY');

  // Odoo ERP Credentials (injected via .env)
  static const String odooUrl = String.fromEnvironment('ODOO_URL');
  static const String odooDatabase = String.fromEnvironment('ODOO_DATABASE');
  static const String odooEmail = String.fromEnvironment('ODOO_EMAIL');
  static const String odooApiKey = String.fromEnvironment('ODOO_API_KEY');
}
