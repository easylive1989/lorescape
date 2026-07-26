import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/narration/presentation/widgets/reading_palette.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 導覽播放控制面板（Field Journal 深色音訊列）
///
/// 單列佈局：上一首 / 播放 / 下一首 控制鈕，接著進度條與播放百分比。
class NarrationControlPanel extends ConsumerWidget {
  final Place place;

  const NarrationControlPanel({super.key, required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final palette = ReadingPalette.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Container(
          decoration: BoxDecoration(
            color: palette.inkBg2,
            borderRadius: BorderRadius.circular(31),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59140C08),
                offset: Offset(0, 10),
                blurRadius: 28,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
          child: _ControlsRow(
            playerState: playerState,
            palette: palette,
            onPlayPause: () => playerController.playPause(),
            onSkipPrev: playerState.canSkipPrevious
                ? playerController.skipToPreviousSegment
                : null,
            onSkipNext: playerState.canSkipNext
                ? playerController.skipToNextSegment
                : null,
          ),
        ),
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  final NarrationState playerState;
  final ReadingPalette palette;
  final VoidCallback onPlayPause;
  final VoidCallback? onSkipPrev;
  final VoidCallback? onSkipNext;

  const _ControlsRow({
    required this.playerState,
    required this.palette,
    required this.onPlayPause,
    required this.onSkipPrev,
    required this.onSkipNext,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (playerState.progress.clamp(0.0, 1.0) * 100).round();
    return Row(
      children: [
        Opacity(
          opacity: playerState.canSkipPrevious ? 1.0 : 0.3,
          child: _CircleControl(
            icon: Icons.skip_previous,
            size: 38,
            filled: false,
            palette: palette,
            onPressed: onSkipPrev,
          ),
        ),
        const SizedBox(width: 4),
        _CircleControl(
          icon: playerState.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 46,
          filled: true,
          palette: palette,
          onPressed: playerState.isLoading || playerState.hasError
              ? null
              : onPlayPause,
        ),
        const SizedBox(width: 4),
        Opacity(
          opacity: playerState.canSkipNext ? 1.0 : 0.3,
          child: _CircleControl(
            icon: Icons.skip_next,
            size: 38,
            filled: false,
            palette: palette,
            onPressed: onSkipNext,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _ProgressBar(progress: playerState.progress, palette: palette),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 42,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.onDark2,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final ReadingPalette palette;
  const _ProgressBar({required this.progress, required this.palette});

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    const trackHeight = 5.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(trackHeight / 2),
      child: Stack(
        children: [
          Container(
            height: trackHeight,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(height: trackHeight, color: palette.clay),
          ),
        ],
      ),
    );
  }
}

/// Circular control: a filled clay play button, or a ghost skip button, on
/// the dark audio bar.
class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.size,
    required this.filled,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final double size;
  final bool filled;
  final ReadingPalette palette;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: filled
          ? (disabled ? palette.clay.withValues(alpha: 0.5) : palette.clay)
          : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: filled ? const Color(0xFFFBF1E9) : palette.onDark,
          ),
        ),
      ),
    );
  }
}
