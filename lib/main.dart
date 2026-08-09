import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/app_providers.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: every screen is a single column, and rotation on a low-end
  // device costs a relayout for nothing.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Opened before the first frame so favorites, history, and the saved locale
  // are available synchronously everywhere else.
  final storage = await StorageService.open();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const UssdPayApp(),
    ),
  );
}
