import gleam/list

pub type JsonError {
  JsonError(path: String, message: String)
}

pub fn at(path path: String, message message: String) -> JsonError {
  JsonError(path:, message:)
}

/// Convert a list of JSON errors to protocol-neutral path+message tuples
/// suitable for the shared `ServerFrame` Error variant.
pub fn to_frame_errors(errors: List(JsonError)) -> List(#(String, String)) {
  list.map(errors, fn(e) { #(e.path, e.message) })
}

/// Append a segment to all error paths in the list. Used to contextualize
/// errors from nested decode (e.g. prepend "fields.slug" to errors from
/// decoding a String field).
pub fn prefix(
  errors errors: List(JsonError),
  segment segment: String,
) -> List(JsonError) {
  list.map(errors, fn(e) {
    JsonError(
      path: case e.path {
        "" -> segment
        _ -> segment <> "." <> e.path
      },
      message: e.message,
    )
  })
}
