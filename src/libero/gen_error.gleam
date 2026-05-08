import glance
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import glexer
import glexer/token
import simplifile

pub type GenError {
  CannotReadDir(path: String, cause: simplifile.FileError)
  CannotReadFile(path: String, cause: simplifile.FileError)
  ParseFailed(path: String, cause: glance.Error)
  UnresolvedTypeModule(module_path: String, type_name: String)
  TypeNotFound(module_path: String, type_name: String)
  DuplicateEndpoint(fn_name: String, modules: List(String))
  /// Two distinct canonical type signatures hashed to the same wire
  /// identity. Detected by `wire_identity.check_uniqueness` at codegen
  /// time. Vanishingly rare in practice (truncated SHA-256 birthday
  /// resistance), but the cost of catching it is small.
  TypeIdentityHashCollision(
    hash: String,
    signature_a: String,
    signature_b: String,
  )
}

pub fn print_error(err: GenError) -> Nil {
  io.println_error(to_string(err))
}

/// Format a structured error as the boxed message libero prints to the
/// terminal. `title` is the one-line headline, `path` is the source file
/// or context the error refers to (rendered after `┌─`), `body_lines`
/// are the explanation lines (each prefixed with `│`), and `hint` is an
/// optional remediation tip rendered below a separator.
///
/// Used by both typed `GenError` rendering and the TOML parser to keep
/// every error in the codebase consistent without duplicating the box
/// drawing.
pub fn error_box(
  title title: String,
  path path: String,
  body_lines body_lines: List(String),
  hint hint: Option(String),
) -> String {
  let body =
    body_lines
    |> list.map(fn(line) { "  \u{2502} " <> line })
    |> string.join("\n")
  let hint_block = case hint {
    None -> ""
    Some(h) -> "\n  \u{2502}\n  hint: " <> h
  }
  "error: "
  <> title
  <> "\n  \u{250c}\u{2500} "
  <> path
  <> "\n  \u{2502}\n"
  <> body
  <> hint_block
}

fn to_string(err: GenError) -> String {
  case err {
    CannotReadDir(path, cause) ->
      error_box(
        title: "Cannot read directory",
        path:,
        body_lines: [format_file_error(cause)],
        hint: None,
      )

    CannotReadFile(path, cause) ->
      error_box(
        title: "Cannot read file",
        path:,
        body_lines: [format_file_error(cause)],
        hint: None,
      )

    ParseFailed(path, cause) ->
      error_box(
        title: "Failed to parse Gleam source",
        path:,
        body_lines: format_glance_error(cause),
        hint: Some("Run `gleam check` to see the full compiler error"),
      )

    UnresolvedTypeModule(module_path, type_name) ->
      error_box(
        title: "Unresolved type module",
        path: module_path,
        body_lines: [
          "Type `" <> type_name <> "` could not be resolved to a file path",
        ],
        hint: Some(
          "Ensure the module exists in the scanned source tree.\n        Check that `"
          <> module_path
          <> "` is reachable from the file_paths\n        passed to walker.walk",
        ),
      )

    TypeNotFound(module_path, type_name) ->
      error_box(
        title: "Type not found",
        path: module_path <> ".gleam",
        body_lines: ["Type `" <> type_name <> "` was not found in this module"],
        hint: Some(
          "The type may be private (add `pub`) or the module path may be\n        incorrect. Libero scans for custom types, not type aliases.",
        ),
      )

    DuplicateEndpoint(fn_name, modules) ->
      error_box(
        title: "Duplicate handler endpoint",
        path: fn_name,
        body_lines: [
          "The same function name is exported from multiple handler",
          "modules:",
          ..list.map(modules, fn(m) { "  " <> m })
        ],
        hint: Some(
          "Handler function names must be unique across the server source\n        tree, since each one becomes a ClientMsg variant.",
        ),
      )

    TypeIdentityHashCollision(hash, signature_a, signature_b) ->
      error_box(
        title: "Type identity hash collision",
        path: "wire-identity",
        body_lines: [
          "Two distinct canonical type signatures hash to the same value:",
          "  Signature A: " <> signature_a,
          "  Signature B: " <> signature_b,
          "  Both hash to: " <> hash,
        ],
        hint: Some(
          "This is an extremely rare birthday collision. File a libero\n        issue with both canonical signatures so the hash algorithm\n        can be adjusted.",
        ),
      )
  }
}

fn format_file_error(err: simplifile.FileError) -> String {
  simplifile.describe_error(err)
}

/// Format a `glance.Error` cause into the body lines of a parse-failure
/// box. Surfaces the offending token's source text and its byte offset
/// so the user can locate the problem without re-running another tool.
/// `byte_offset` is the lexer's offset (codeunit offset on JavaScript).
fn format_glance_error(err: glance.Error) -> List(String) {
  case err {
    glance.UnexpectedEndOfInput -> [
      "glance hit unexpected end of input while parsing this file",
    ]
    glance.UnexpectedToken(token: tok, position: glexer.Position(byte_offset:)) -> [
      "unexpected token `"
      <> token.to_source(tok)
      <> "` at byte offset "
      <> int.to_string(byte_offset),
    ]
  }
}
