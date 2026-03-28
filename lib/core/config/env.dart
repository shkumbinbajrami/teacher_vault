import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase config from `--dart-define` first, then `.env` (bundled asset).
class Env {
  Env._();

  static String get supabaseUrl {
    const fromDefine = String.fromEnvironment('SUPABASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    final v = dotenv.env['SUPABASE_URL'];
    if (v == null || v.trim().isEmpty) {
      throw StateError(
        'SUPABASE_URL is missing. Use --dart-define=SUPABASE_URL=... '
        'or add it to `.env` (see `.env.example`).',
      );
    }
    return v.trim();
  }

  /// Publishable key or legacy anon JWT — passed to [Supabase.initialize] as `anonKey`.
  static String get supabaseAnonKey {
    const publishableDefine = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    if (publishableDefine.isNotEmpty) return publishableDefine;
    const legacyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (legacyDefine.isNotEmpty) return legacyDefine;
    final publishable = dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim();
    if (publishable != null && publishable.isNotEmpty) return publishable;
    final legacy = dotenv.env['SUPABASE_ANON_KEY']?.trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    throw StateError(
      'Client API key is missing. Use --dart-define=SUPABASE_PUBLISHABLE_KEY=... '
      'or SUPABASE_ANON_KEY, or add SUPABASE_PUBLISHABLE_KEY to `.env`.',
    );
  }
}
