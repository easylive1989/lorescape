/// Where a narration playback was triggered from.
///
/// Used by analytics events to attribute engagement to the surface that
/// originated playback. Values are persisted by [name] (snake_case in
/// JSON), so renaming an existing member is a breaking change.
enum NarrationEventSource {
  /// Triggered from the Explore tab (nearby places / story-hook flow).
  explore,

  /// Triggered from the Journey timeline (replaying a saved entry).
  journey,

  /// Triggered from the Daily Story feature.
  dailyStory,

  /// Triggered from the Onboarding welcome carousel demo.
  onboarding;

  /// Wire-format identifier (snake_case).
  String get wireName {
    switch (this) {
      case NarrationEventSource.explore:
        return 'explore';
      case NarrationEventSource.journey:
        return 'journey';
      case NarrationEventSource.dailyStory:
        return 'daily_story';
      case NarrationEventSource.onboarding:
        return 'onboarding';
    }
  }
}
