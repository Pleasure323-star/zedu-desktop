/// Hides most of an email address for display, e.g. `pl***@gmail.com`.
///
/// The name before the `@` keeps its first 2 characters when it has 3 or more,
/// only its first character when it has 2, and nothing when it has 1, so a
/// short address is never shown in full. A value without a usable `@` is
/// returned unchanged.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  final local = email.substring(0, at);
  final domain = email.substring(at + 1);
  final visible = local.length > 2 ? 2 : local.length - 1;
  return '${local.substring(0, visible)}***@$domain';
}
