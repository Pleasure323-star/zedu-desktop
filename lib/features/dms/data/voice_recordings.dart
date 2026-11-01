/// Paths of voice recordings this app created itself.
///
/// Only these files may be deleted automatically. A file the user picked is
/// never in this set, even if its name or folder looks like a recording.
final Set<String> appRecordedPaths = <String>{};
