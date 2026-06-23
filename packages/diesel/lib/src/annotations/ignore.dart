/// Excludes a field from generation (e.g. a computed field that is not a column).
/// The field must be optional in the constructor so its default can be used.
class Ignore {
  const Ignore();
}

/// Shorthand for [Ignore]: `@ignore final User? author;`.
const ignore = Ignore();
