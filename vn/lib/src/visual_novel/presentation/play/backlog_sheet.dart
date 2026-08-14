import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

/// 回顧列表：由下往上捲，最新的一句在最下面（貼近玩家點開時的閱讀習慣）。
class BacklogSheet extends StatelessWidget {
  const BacklogSheet({required this.entries, super.key});

  final List<BacklogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        reverse: true,
        padding: const EdgeInsets.all(24),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = entries[entries.length - 1 - index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (entry.speakerName != null)
                Text(entry.speakerName!, style: Theme.of(context).textTheme.labelMedium),
              Text(entry.text, style: Theme.of(context).textTheme.bodyLarge),
            ],
          );
        },
      ),
    );
  }
}
