import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string

import glance

import libero/field_type

pub type UnsupportedTypePolicy {
  RejectUnsupported(path: String)
  PreserveUnsupported
}

pub opaque type TypeResolver {
  TypeResolver(
    unqualified: dict.Dict(String, TypeBinding),
    aliased: dict.Dict(String, String),
  )
}

type TypeBinding {
  TypeBinding(module_path: String, type_name: String)
}

pub fn resolver_from_imports(
  imports: List(glance.Definition(glance.Import)),
) -> Result(TypeResolver, String) {
  use unqualified <- result.try(build_unqualified(imports))
  Ok(TypeResolver(unqualified:, aliased: build_aliased(imports)))
}

pub fn type_to_field_type(
  type_ t: glance.Type,
  resolver resolver: TypeResolver,
  current_module current_module: String,
  policy policy: UnsupportedTypePolicy,
) -> Result(field_type.FieldType, String) {
  let recurse = fn(inner) {
    type_to_field_type(type_: inner, resolver:, current_module:, policy:)
  }
  case t {
    glance.NamedType(name:, module: option.None, parameters:, ..) ->
      resolve_unqualified(
        name:,
        parameters:,
        resolver:,
        current_module:,
        policy:,
      )
    glance.NamedType(name:, module: option.Some(m), parameters:, ..) -> {
      let module_path = dict.get(resolver.aliased, m) |> result.unwrap(or: m)
      use args <- result.try(list.try_map(parameters, recurse))
      Ok(field_type.UserType(module_path:, type_name: name, args:))
    }
    glance.TupleType(elements:, ..) -> {
      use elements <- result.try(list.try_map(elements, recurse))
      Ok(field_type.TupleOf(elements:))
    }
    glance.VariableType(name:, ..) -> Ok(field_type.TypeVar(name:))
    glance.FunctionType(..) ->
      case policy {
        RejectUnsupported(path) ->
          Error("Unsupported function type in " <> path)
        PreserveUnsupported -> Ok(field_type.TypeVar(name: "_fn"))
      }
    glance.HoleType(..) ->
      case policy {
        RejectUnsupported(path) -> Error("Unsupported hole type in " <> path)
        PreserveUnsupported -> Ok(field_type.TypeVar(name: "_"))
      }
  }
}

fn resolve_unqualified(
  name name: String,
  parameters parameters: List(glance.Type),
  resolver resolver: TypeResolver,
  current_module current_module: String,
  policy policy: UnsupportedTypePolicy,
) -> Result(field_type.FieldType, String) {
  let recurse = fn(inner) {
    type_to_field_type(type_: inner, resolver:, current_module:, policy:)
  }
  use args <- result.try(list.try_map(parameters, recurse))
  let identity = fn(x) { x }
  case dict.get(resolver.unqualified, name) {
    Ok(TypeBinding(module_path:, type_name:)) ->
      case is_stdlib_module_path(module_path) {
        True ->
          case
            field_type.builtin_field_type(
              name:,
              parameters: args,
              recurse: identity,
            )
          {
            Ok(ft) -> Ok(ft)
            Error(Nil) ->
              Ok(field_type.UserType(module_path:, type_name:, args:))
          }
        False -> Ok(field_type.UserType(module_path:, type_name:, args:))
      }
    Error(Nil) ->
      case
        field_type.builtin_field_type(
          name:,
          parameters: args,
          recurse: identity,
        )
      {
        Ok(ft) -> Ok(ft)
        Error(Nil) ->
          Ok(field_type.UserType(
            module_path: current_module,
            type_name: name,
            args:,
          ))
      }
  }
}

fn is_stdlib_module_path(path: String) -> Bool {
  path == "gleam" || string.starts_with(path, "gleam/")
}

fn build_unqualified(
  imports: List(glance.Definition(glance.Import)),
) -> Result(dict.Dict(String, TypeBinding), String) {
  list.try_fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    list.try_fold(imp.unqualified_types, acc, fn(inner_acc, uq) {
      let local_name = case uq.alias {
        option.Some(alias) -> alias
        option.None -> uq.name
      }
      let binding = TypeBinding(module_path: imp.module, type_name: uq.name)
      case dict.get(inner_acc, local_name) {
        Error(Nil) -> Ok(dict.insert(inner_acc, local_name, binding))
        Ok(existing) ->
          case
            existing.module_path == binding.module_path
            && existing.type_name == binding.type_name
          {
            True -> Ok(inner_acc)
            False ->
              Error(
                "Ambiguous import: \""
                <> local_name
                <> "\" is bound to "
                <> existing.module_path
                <> "."
                <> existing.type_name
                <> " and "
                <> binding.module_path
                <> "."
                <> binding.type_name,
              )
          }
      }
    })
  })
}

fn build_aliased(
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
