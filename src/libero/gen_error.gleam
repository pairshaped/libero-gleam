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
  /// A field declares `Dict(K, V)` with K something other than Int,
  /// String, or Bool. Other key types have ambiguous JS-side identity
  /// or wire-encoding rules; the codegen rejects them upfront so
  /// behaviour is symmetric across BEAM and JS.
  ///
  /// `field_path` locates the offending field, e.g.
  /// `admin/discounts.Discount field[2].value.key` for a nested case.
  /// `key_type_repr` is the FieldType's canonical token string for
  /// readability in the error box.
  DictKeyMustBePrimitive(field_path: String, key_type_repr: String)
  /// A field's type still contains an unresolved type variable
  /// (generic parameter that survived to runtime). Wire transformer
  /// codegen needs the concrete type to emit encode/decode logic; a
  /// generic survives only if the user wrote a wire type with an
  /// uninstantiated generic parameter, which is a logic error.
  WireTypeContainsTypeVar(field_path: String, var_name: String)
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

    DictKeyMustBePrimitive(field_path, key_type_repr) ->
      error_box(
        title: "Unsupported Dict key type",
        path: field_path,
        body_lines: [
          "Field declares Dict(" <> key_type_repr <> ", _) but only Int,",
          "String, and Bool are allowed as Dict keys on the wire.",
        ],
        hint: Some(
          "Use Int/String/Bool keys, or restructure the data as\n        List(#(KeyType, ValueType)) and convert at the application\n        boundary.",
        ),
      )

    WireTypeContainsTypeVar(field_path, var_name) ->
      error_box(
        title: "Wire type contains unresolved generic",
        path: field_path,
        body_lines: [
          "Type variable `" <> var_name <> "` survived to runtime in this",
          "field. Wire transformer codegen needs concrete types so it can",
          "emit per-field encode/decode logic.",
        ],
        hint: Some(
          "Replace the generic parameter with a concrete type at the\n        wire boundary, or wrap it in a fully-applied user type before\n        the value crosses the wire.",
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
