//// Scanning for handler-as-contract endpoints.
////
//// Walks a source tree to discover handler functions whose signatures
//// define the wire contract: public functions with a `server_` prefix,
//// a context parameter, and a Result return type.

import glance
import gleam/bool
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import libero/field_type
import libero/gen_error.{
  type GenError, CannotReadDir, CannotReadFile, DuplicateEndpoint, ParseFailed,
}
import simplifile

// ---------- Types ----------

/// A single handler endpoint discovered by scanning function signatures.
/// Each represents one RPC function that clients can call.
pub type HandlerEndpoint {
  HandlerEndpoint(
    /// Handler module path, e.g. "pages/login"
    module_path: String,
    /// Function name WITHOUT the server_ prefix, e.g. "login"
    fn_name: String,
    /// Ok payload of the handler's `Result`.
    return_ok: field_type.FieldType,
    /// Err payload of the handler's `Result`.
    return_err: field_type.FieldType,
    /// Parameters excluding the context param, with labels and resolved
    /// types. Each entry is #(label, FieldType).
    params: List(#(String, field_type.FieldType)),
    /// True when the handler returns `#(Result(_, _), ContextType)`,
    /// signalling it may have produced a new context value. False when
    /// the handler returns a bare `Result(_, _)`.
    mutates_context: Bool,
    /// When set, the handler takes a single message type param instead of
    /// individual params. Dispatch passes the whole coerced message.
    /// The params list still contains the type's fields (for wire contract).
    msg_type: option.Option(#(String, String)),
  )
}

// ---------- Source discovery ----------

/// Recursively walk a directory, returning every `.gleam` file found.
/// Skips any subdirectory named `generated`.
pub fn walk_directory(path path: String) -> Result(List(String), GenError) {
  use entries <- result.try(
    simplifile.read_directory(path)
    |> result.map_error(fn(cause) { CannotReadDir(path: path, cause: cause) }),
  )
  use files <- result.map(
    list.try_fold(over: entries, from: [], with: fn(acc, entry) {
      visit_entry(acc: acc, parent: path, entry: entry)
    }),
  )
  list.sort(files, by: string.compare)
}

fn visit_entry(
  acc acc: List(String),
  parent parent: String,
  entry entry: String,
) -> Result(List(String), GenError) {
  let child = parent <> "/" <> entry
  let is_symlink = simplifile.is_symlink(child) |> result.unwrap(False)
  let is_dir = result.unwrap(simplifile.is_directory(child), False)
  use <- bool.guard(when: is_symlink && is_dir, return: Ok(acc))
  case is_dir {
    True -> visit_subdirectory(acc: acc, entry: entry, child: child)
    False -> Ok(visit_file(acc: acc, entry: entry, child: child))
  }
}

fn visit_subdirectory(
  acc acc: List(String),
  entry entry: String,
  child child: String,
) -> Result(List(String), GenError) {
  use <- bool.guard(when: entry == "generated", return: Ok(acc))
  use nested <- result.try(walk_directory(path: child))
  Ok(list.append(nested, acc))
}

fn visit_file(
  acc acc: List(String),
  entry entry: String,
  child child: String,
) -> List(String) {
  use <- bool.guard(when: !string.ends_with(entry, ".gleam"), return: acc)
  [child, ..acc]
}

// ---------- Module path derivation ----------

/// Derive the Gleam module path from a file path by finding the last
/// occurrence of `/src/` and taking everything after it, then stripping
/// the `.gleam` extension.
pub fn derive_module_path(file_path file_path: String) -> String {
  let without_extension = case string.ends_with(file_path, ".gleam") {
    True ->
      string.slice(
        from: file_path,
        at_index: 0,
        length: string.length(file_path) - string.length(".gleam"),
      )
    False -> file_path
  }
  case string.split(without_extension, "/src/") {
    [_only] -> without_extension
    parts -> list.last(parts) |> result.unwrap(or: without_extension)
  }
}

// ---------- Handler endpoint scanning ----------

/// Scan a source directory for handler functions.
/// Looks for: pub fn server_*(args..., context: T) -> Result(ok, err)
/// Returns the endpoint list or structured errors.
pub fn scan(
  src_dir src_dir: String,
  context_type_name context_type_name: String,
) -> Result(List(HandlerEndpoint), List(GenError)) {
  use files <- result.try(
    walk_directory(path: src_dir)
    |> result.map_error(fn(cause) { [cause] }),
  )
  let module_files =
    list.fold(files, dict.new(), fn(acc, file_path) {
      dict.insert(acc, derive_module_path(file_path:), file_path)
    })
  // All-or-nothing: if any file fails to parse, the entire scan fails.
  // Valid endpoints from other files are discarded. This prevents codegen
  // from producing partial dispatch tables that silently drop handlers.
  let #(endpoints_rev, errors_rev) =
    list.fold(files, #([], []), fn(acc, file_path) {
      let #(eps_acc, errs_acc) = acc
      case parse_endpoints(file_path:, context_type_name:, module_files:) {
        Ok(eps) -> #(list.append(list.reverse(eps), eps_acc), errs_acc)
        Error(err) -> #(eps_acc, [err, ..errs_acc])
      }
    })
  case errors_rev {
    [] -> {
      let endpoints = list.reverse(endpoints_rev)
      case duplicate_fn_name_errors(endpoints) {
        [] -> Ok(endpoints)
        dup_errors -> Error(dup_errors)
      }
    }
    _ -> Error(list.reverse(errors_rev))
  }
}

/// Collect type seeds from scanned endpoints for the walker.
/// Returns #(module_path, type_name) pairs from all param and return types.
pub fn collect_seeds(
  endpoints: List(HandlerEndpoint),
) -> List(#(String, String)) {
  list.flat_map(endpoints, fn(e) {
    let from_params =
      list.flat_map(e.params, fn(p) { field_type.collect_user_types(p.1) })
    let from_ok = field_type.collect_user_types(e.return_ok)
    let from_err = field_type.collect_user_types(e.return_err)
    list.flatten([from_params, from_ok, from_err])
  })
  |> list.unique()
}

fn duplicate_fn_name_errors(
  endpoints: List(HandlerEndpoint),
) -> List(GenError) {
  let by_name =
    list.fold(endpoints, dict.new(), fn(acc, ep) {
      let existing = dict.get(acc, ep.fn_name) |> result.unwrap([])
      dict.insert(acc, ep.fn_name, [ep.module_path, ..existing])
    })
  by_name
  |> dict.to_list
  |> list.sort(by: fn(a, b) { string.compare(a.0, b.0) })
  |> list.filter_map(fn(pair) {
    let #(fn_name, modules_rev) = pair
    case modules_rev {
      [_, _, ..] ->
        Ok(DuplicateEndpoint(
          fn_name:,
          modules: list.reverse(modules_rev) |> list.unique,
        ))
      _ -> Error(Nil)
    }
  })
}

/// Read a `.gleam` file and parse it via `glance`, surfacing both I/O and
/// parser failures as `GenError` variants tagged with the file path.
pub fn parse_module(
  file_path file_path: String,
) -> Result(glance.Module, GenError) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(cause) { CannotReadFile(path: file_path, cause:) }),
  )
  glance.module(content)
  |> result.map_error(fn(cause) { ParseFailed(path: file_path, cause:) })
}

fn parse_endpoints(
  file_path file_path: String,
  context_type_name context_type_name: String,
  module_files module_files: dict.Dict(String, String),
) -> Result(List(HandlerEndpoint), GenError) {
  use parsed <- result.map(parse_module(file_path:))
  let module_path = derive_module_path(file_path: file_path)
  let type_imports = build_type_import_map(parsed.imports)
  let alias_map = build_alias_resolution_map(parsed.imports)
  let type_alias_originals = build_type_alias_originals(parsed.imports)
  list.filter_map(parsed.functions, fn(def) {
    let glance.Definition(_, func) = def
    case func.publicity == glance.Public {
      False -> Error(Nil)
      True ->
        parse_single_endpoint(
          func: func,
          module_path: module_path,
          type_imports: type_imports,
          alias_map: alias_map,
          type_alias_originals: type_alias_originals,
          context_type_name: context_type_name,
          custom_types: parsed.custom_types,
          module_files: module_files,
        )
    }
  })
}

/// Build a map from unqualified type names to the full module path of their import.
pub fn build_type_import_map(
  imports: List(glance.Definition(glance.Import)),
) -> dict.Dict(String, String) {
  list.fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    list.fold(imp.unqualified_types, acc, fn(inner_acc, uq) {
      let key = case uq.alias {
        option.Some(alias) -> alias
        option.None -> uq.name
      }
      dict.insert(inner_acc, key, imp.module)
    })
  })
}

/// Map locally-bound type names back to their original names from the
/// source module. Only populated when an import uses `type X as Y`.
pub fn build_type_alias_originals(
  imports: List(glance.Definition(glance.Import)),
) -> dict.Dict(String, String) {
  list.fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    list.fold(imp.unqualified_types, acc, fn(inner_acc, uq) {
      case uq.alias {
        option.Some(alias) -> dict.insert(inner_acc, alias, uq.name)
        option.None -> inner_acc
      }
    })
  })
}

/// Build a map from import aliases (and bare module names) to the full
/// module path.
pub fn build_alias_resolution_map(
  imports: List(glance.Definition(glance.Import)),
) -> dict.Dict(String, String) {
  list.fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    let last_seg = field_type.last_segment(imp.module)
    let alias = case imp.alias {
      option.Some(glance.Named(name)) -> name
      _ -> last_seg
    }
    dict.insert(acc, alias, imp.module)
  })
}

fn parse_single_endpoint(
  func func: glance.Function,
  module_path module_path: String,
  type_imports type_imports: dict.Dict(String, String),
  alias_map alias_map: dict.Dict(String, String),
  type_alias_originals type_alias_originals: dict.Dict(String, String),
  context_type_name context_type_name: String,
  custom_types custom_types: List(glance.Definition(glance.CustomType)),
  module_files module_files: dict.Dict(String, String),
) -> Result(HandlerEndpoint, Nil) {
  // Must have server_ prefix
  use <- bool.guard(
    when: !string.starts_with(func.name, "server_"),
    return: Error(Nil),
  )
  let wire_name = string.drop_start(func.name, string.length("server_"))

  use #(ok_type, err_type, payload_params, mutates_context) <- result.try(
    validate_handler_signature(func, context_type_name),
  )

  let to_ft = fn(t) {
    glance_type_to_field_type(
      type_: t,
      imports: type_imports,
      aliases: alias_map,
      type_alias_originals: type_alias_originals,
      current_module: module_path,
    )
  }

  let #(params_typed, msg_type) =
    try_resolve_msg_type(
      payload_params,
      module_path,
      custom_types,
      module_files,
      to_ft,
    )

  Ok(HandlerEndpoint(
    module_path: module_path,
    fn_name: wire_name,
    return_ok: to_ft(ok_type),
    return_err: to_ft(err_type),
    params: params_typed,
    mutates_context: mutates_context,
    msg_type: msg_type,
  ))
}

fn try_resolve_msg_type(
  payload_params: List(glance.FunctionParameter),
  current_module: String,
  custom_types: List(glance.Definition(glance.CustomType)),
  module_files: dict.Dict(String, String),
  to_ft: fn(glance.Type) -> field_type.FieldType,
) -> #(List(#(String, field_type.FieldType)), option.Option(#(String, String))) {
  let fallback = #(
    resolve_individual_params(payload_params, to_ft),
    option.None,
  )
  case payload_params {
    [param] -> {
      use type_ <- try_msg_param_type(param, fallback)
      case to_ft(type_) {
        field_type.UserType(module_path:, type_name:, args: []) ->
          resolve_msg_type_fields(
            module_path:,
            type_name:,
            current_module:,
            current_custom_types: custom_types,
            module_files:,
            current_to_ft: to_ft,
          )
          |> result.map(fn(fields) {
            #(fields, option.Some(#(module_path, type_name)))
          })
          |> result.unwrap(or: fallback)
        _ -> fallback
      }
    }
    _ -> fallback
  }
}

fn try_msg_param_type(
  param: glance.FunctionParameter,
  fallback: a,
  next: fn(glance.Type) -> a,
) -> a {
  param.type_ |> option.map(next) |> option.unwrap(or: fallback)
}

fn resolve_msg_type_fields(
  module_path module_path: String,
  type_name type_name: String,
  current_module current_module: String,
  current_custom_types current_custom_types: List(
    glance.Definition(glance.CustomType),
  ),
  module_files module_files: dict.Dict(String, String),
  current_to_ft current_to_ft: fn(glance.Type) -> field_type.FieldType,
) -> Result(List(#(String, field_type.FieldType)), Nil) {
  case module_path == current_module {
    True -> {
      use fields <- result.try(one_variant_fields(
        type_name:,
        custom_types: current_custom_types,
      ))
      labelled_fields_to_params(fields, current_to_ft)
    }
    False -> {
      use file_path <- result.try(
        dict.get(module_files, module_path) |> result.replace_error(Nil),
      )
      use parsed <- result.try(
        parse_module(file_path:) |> result.replace_error(Nil),
      )
      let to_ft = module_type_resolver(parsed.imports, module_path)
      use fields <- result.try(one_variant_fields(
        type_name:,
        custom_types: parsed.custom_types,
      ))
      labelled_fields_to_params(fields, to_ft)
    }
  }
}

fn module_type_resolver(
  imports: List(glance.Definition(glance.Import)),
  current_module: String,
) -> fn(glance.Type) -> field_type.FieldType {
  let type_imports = build_type_import_map(imports)
  let alias_map = build_alias_resolution_map(imports)
  let type_alias_originals = build_type_alias_originals(imports)
  fn(t) {
    glance_type_to_field_type(
      type_: t,
      imports: type_imports,
      aliases: alias_map,
      type_alias_originals: type_alias_originals,
      current_module: current_module,
    )
  }
}

fn one_variant_fields(
  type_name type_name: String,
  custom_types custom_types: List(glance.Definition(glance.CustomType)),
) -> Result(List(glance.VariantField), Nil) {
  case list.find(custom_types, fn(def) { def.definition.name == type_name }) {
    Ok(def) ->
      case def.definition.variants {
        [single_variant] -> Ok(single_variant.fields)
        _ -> Error(Nil)
      }
    Error(Nil) -> Error(Nil)
  }
}

fn labelled_fields_to_params(
  fields: List(glance.VariantField),
  to_ft: fn(glance.Type) -> field_type.FieldType,
) -> Result(List(#(String, field_type.FieldType)), Nil) {
  list.try_map(fields, fn(field) {
    case field {
      glance.LabelledVariantField(label:, item:) -> Ok(#(label, to_ft(item)))
      _ -> Error(Nil)
    }
  })
}

fn resolve_individual_params(
  params: List(glance.FunctionParameter),
  to_ft: fn(glance.Type) -> field_type.FieldType,
) -> List(#(String, field_type.FieldType)) {
  list.filter_map(params, fn(p) {
    case p.label, p.type_ {
      option.Some(label), option.Some(type_) -> Ok(#(label, to_ft(type_)))
      _, _ -> Error(Nil)
    }
  })
}

fn validate_handler_signature(
  func: glance.Function,
  context_type_name: String,
) -> Result(
  #(glance.Type, glance.Type, List(glance.FunctionParameter), Bool),
  Nil,
) {
  let params = func.parameters
  use <- bool.guard(when: list.is_empty(params), return: Error(Nil))

  // Find the context parameter (doesn't have to be last)
  let has_context =
    list.any(params, fn(p) {
      case p.type_ {
        option.Some(t) -> is_context_type(t, context_type_name)
        option.None -> False
      }
    })
  use <- bool.guard(when: !has_context, return: Error(Nil))

  use return_type <- result.try(option.to_result(func.return, Nil))
  use #(response_type, mutates_context) <- result.try(extract_response_type(
    return_type,
    context_type_name,
  ))

  use #(ok_type, err_type) <- result.try(extract_result_args(response_type))

  // Payload params are everything except the context param
  let payload_params =
    list.filter(params, fn(p) {
      case p.type_ {
        option.Some(t) -> !is_context_type(t, context_type_name)
        option.None -> True
      }
    })
  Ok(#(ok_type, err_type, payload_params, mutates_context))
}

fn extract_response_type(
  t: glance.Type,
  context_type_name: String,
) -> Result(#(glance.Type, Bool), Nil) {
  case t {
    glance.TupleType(elements: [response, state], ..) ->
      case is_context_type(state, context_type_name) {
        True -> Ok(#(response, True))
        False -> Error(Nil)
      }
    glance.NamedType(name: "Result", ..) -> Ok(#(t, False))
    _ -> Error(Nil)
  }
}

fn is_context_type(t: glance.Type, context_type_name: String) -> Bool {
  case t {
    glance.NamedType(name:, module: option.None, ..) ->
      name == context_type_name
    _ -> False
  }
}

fn extract_result_args(
  t: glance.Type,
) -> Result(#(glance.Type, glance.Type), Nil) {
  case t {
    glance.NamedType(name: "Result", parameters: [ok, err], ..) ->
      Ok(#(ok, err))
    _ -> Error(Nil)
  }
}

fn glance_type_to_field_type(
  type_ t: glance.Type,
  imports imports: dict.Dict(String, String),
  aliases aliases: dict.Dict(String, String),
  type_alias_originals type_alias_originals: dict.Dict(String, String),
  current_module current_module: String,
) -> field_type.FieldType {
  let recurse_named = fn(name, params) {
    builtin_or_user(
      name:,
      parameters: params,
      imports:,
      aliases:,
      type_alias_originals:,
      current_module:,
    )
  }
  let recurse = fn(t) {
    glance_type_to_field_type(
      type_: t,
      imports:,
      aliases:,
      type_alias_originals:,
      current_module:,
    )
  }
  case t {
    glance.NamedType(name:, module: option.None, parameters: [], ..) ->
      recurse_named(name, [])
    glance.NamedType(name:, module: option.None, parameters: params, ..) ->
      recurse_named(name, params)
    glance.NamedType(name:, module: option.Some(m), parameters: params, ..) -> {
      let module_path = dict.get(aliases, m) |> result.unwrap(or: m)
      field_type.UserType(
        module_path:,
        type_name: name,
        args: list.map(params, recurse),
      )
    }
    glance.TupleType(elements:, ..) ->
      field_type.TupleOf(elements: list.map(elements, recurse))
    glance.VariableType(name:, ..) -> field_type.TypeVar(name:)
    glance.FunctionType(..) -> field_type.TypeVar(name: "_fn")
    glance.HoleType(..) -> field_type.TypeVar(name: "_")
  }
}

fn builtin_or_user(
  name name: String,
  parameters parameters: List(glance.Type),
  imports imports: dict.Dict(String, String),
  aliases aliases: dict.Dict(String, String),
  type_alias_originals type_alias_originals: dict.Dict(String, String),
  current_module current_module: String,
) -> field_type.FieldType {
  let recurse = fn(t) {
    glance_type_to_field_type(
      type_: t,
      imports:,
      aliases:,
      type_alias_originals:,
      current_module:,
    )
  }
  case field_type.builtin_field_type(name:, parameters:, recurse:) {
    Ok(ft) -> ft
    Error(Nil) -> {
      let module_path =
        dict.get(imports, name) |> result.unwrap(or: current_module)
      let type_name =
        dict.get(type_alias_originals, name) |> result.unwrap(or: name)
      field_type.UserType(
        module_path:,
        type_name:,
        args: list.map(parameters, recurse),
      )
    }
  }
}
