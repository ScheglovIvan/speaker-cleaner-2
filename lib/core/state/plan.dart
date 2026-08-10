/// The speaker-maintenance model.
///
/// Maintenance is a single optional tool, not a program: one low-frequency
/// water-eject run that vibrates trapped water out of the speaker after the
/// phone gets wet. The list below therefore holds exactly one entry; the shape
/// is kept so remote config can still override its length.
class PlanDay {
  const PlanDay({
    required this.day,
    required this.title,
    required this.durationSeconds,
    required this.premium,
  });

  /// 1-based entry index.
  final int day;

  /// Short tool label.
  final String title;

  /// Fixed run length in seconds.
  final int durationSeconds;

  /// Whether this entry requires the Pro entitlement.
  final bool premium;
}

/// The maintenance tool set: one free water-eject run.
const List<PlanDay> kDefaultPlan = <PlanDay>[
  PlanDay(day: 1, title: 'Water Eject', durationSeconds: 36, premium: false),
];

/// Number of maintenance entries.
const int kPlanLength = 1;
