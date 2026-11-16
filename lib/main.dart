import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'app.dart';
import 'core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Chrome / Web
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  
  // Load confidential environment variables (.env)
  await AppConfig.init();

  runApp(
    const ProviderScope(
      child: DoloApp(),
    ),
  );
}
