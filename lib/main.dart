import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teacher_vault/app.dart';
import 'package:teacher_vault/core/bootstrap/web_plugin_registration.dart';
import 'package:teacher_vault/core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerWebPluginsEarly();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Optional file; [Env] may still resolve via --dart-define.
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: TeacherVaultApp()));
}
