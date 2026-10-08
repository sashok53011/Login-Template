/// Which action produced the outcome shown on the result screen.
enum ActionKind { register, login }

/// A single label/value pair shown on the result screen.
class ResultRow {
  const ResultRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// Outcome of the last register / login attempt.
///
/// Written to [actionResultProvider] before navigating so that route
/// redirects (which run asynchronously) cannot lose it.
class ActionResult {
  const ActionResult({
    required this.success,
    required this.kind,
    required this.message,
    this.description,
    this.rows = const <ResultRow>[],
  });

  /// `true` when the action completed, `false` for a failure.
  final bool success;

  final ActionKind kind;

  /// Headline, e.g. «Регистрация прошла успешно».
  final String message;

  /// Supporting text: what happened next, or the error description.
  final String? description;

  /// Identity details (email / username / id) shown as a card.
  final List<ResultRow> rows;
}
