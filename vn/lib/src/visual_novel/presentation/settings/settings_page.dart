import 'package:flutter/material.dart';

/// 設定頁：Task 14 實作完整內容，這裡先給能編譯、能導覽的最小佔位。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: const SizedBox.shrink(),
    );
  }
}
