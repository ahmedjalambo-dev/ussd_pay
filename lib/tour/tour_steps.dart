import '../l10n/generated/app_localizations.dart';

/// Widgets the tour can point at. Each is marked in the widget tree by a
/// `TourAnchor` with the same value, so the tour never reaches into a screen's
/// internals to find them.
enum TourTarget {
  walletCard,
  phoneField,
  amountField,
  reviewButton,
  paymentBack,
  pinNotice,
  favoritesTab,
  historyTab,
  settingsButton,
  confirmBySms,
  confirmManually,
  appTourTile,

  /// Tab bodies. Never highlighted: they become ready when their tab is the
  /// one on screen, which is how a tap on a tab (or the end of a pop back to
  /// the tabs) is noticed.
  homePage,
  favoritesPage,
  historyPage,

  /// The Settings screen's body, ready once Settings is open and settled.
  settingsPage,
}

/// One coach mark.
class TourStep {
  const TourStep({
    required this.target,
    required this.title,
    required this.body,
    this.advanceWhenReady,
    this.optional = false,
  });

  /// What the spotlight is on.
  final TourTarget target;

  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;

  /// Null: the user moves on with Next. Otherwise the step is interactive:
  /// the spotlight lets taps through to the real widget, and the step is
  /// passed once this target is ready -- that is, once the user's own tap has
  /// done what the widget does. Observing the outcome rather than the tap
  /// also accepts the system back gesture where it does the same thing.
  final TourTarget? advanceWhenReady;

  /// For a feature that is not always there: skipped, rather than shown
  /// without a spotlight, when its screen is open but the target is not.
  /// The SMS confirmation settings, say, are absent off Android and for
  /// wallets with no SMS patterns.
  final bool optional;

  bool get interactive => advanceWhenReady != null;
}

/// The tour, in order.
///
/// It goes through the payment form but never past Review: no interactive
/// step leads to the confirm screen or the dialer, so the tour cannot start a
/// payment. Review is explained, not pressed. It ends in Settings, on how a
/// payment handed to the dialer gets confirmed afterwards.
final List<TourStep> tourSteps = [
  TourStep(
    target: TourTarget.walletCard,
    title: (l) => l.tourWalletTitle,
    body: (l) => l.tourWalletBody,
    advanceWhenReady: TourTarget.phoneField,
  ),
  TourStep(
    target: TourTarget.phoneField,
    title: (l) => l.tourPhoneTitle,
    body: (l) => l.tourPhoneBody,
  ),
  TourStep(
    target: TourTarget.amountField,
    title: (l) => l.tourAmountTitle,
    body: (l) => l.tourAmountBody,
  ),
  TourStep(
    target: TourTarget.reviewButton,
    title: (l) => l.tourReviewTitle,
    body: (l) => l.tourReviewBody,
  ),
  TourStep(
    target: TourTarget.paymentBack,
    title: (l) => l.tourBackTitle,
    body: (l) => l.tourBackBody,
    advanceWhenReady: TourTarget.homePage,
  ),
  TourStep(
    target: TourTarget.pinNotice,
    title: (l) => l.tourPinTitle,
    body: (l) => l.tourPinBody,
  ),
  TourStep(
    target: TourTarget.favoritesTab,
    title: (l) => l.tourFavoritesTitle,
    body: (l) => l.tourFavoritesBody,
    advanceWhenReady: TourTarget.favoritesPage,
  ),
  TourStep(
    target: TourTarget.historyTab,
    title: (l) => l.tourHistoryTitle,
    body: (l) => l.tourHistoryBody,
    advanceWhenReady: TourTarget.historyPage,
  ),
  TourStep(
    target: TourTarget.settingsButton,
    title: (l) => l.tourSettingsTitle,
    body: (l) => l.tourSettingsBody,
    advanceWhenReady: TourTarget.settingsPage,
  ),
  TourStep(
    target: TourTarget.confirmBySms,
    title: (l) => l.tourConfirmSmsTitle,
    body: (l) => l.tourConfirmSmsBody,
    optional: true,
  ),
  TourStep(
    target: TourTarget.confirmManually,
    title: (l) => l.tourConfirmAskTitle,
    body: (l) => l.tourConfirmAskBody,
    optional: true,
  ),
  TourStep(
    target: TourTarget.appTourTile,
    title: (l) => l.tourReplayTitle,
    body: (l) => l.tourReplayBody,
  ),
];
