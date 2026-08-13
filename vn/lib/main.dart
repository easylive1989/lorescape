import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VnApp(),
    ),
  );
}

class VnApp extends StatelessWidget {
  const VnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '龐貝 79',
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('龐貝 79'))),
    );
  }
}
