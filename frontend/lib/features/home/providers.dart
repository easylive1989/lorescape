import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:context_app/features/home/domain/globe/world_outline.dart';

/// 地球儀的世界輪廓。只解析一次，之後所有畫面共用。
final worldOutlineProvider = FutureProvider<WorldOutline>(
  (ref) => WorldOutline.load(rootBundle),
);
