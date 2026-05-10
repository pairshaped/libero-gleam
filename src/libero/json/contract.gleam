import gleam/bit_array
import gleam/crypto
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import libero/field_type.{type FieldType}
import libero/scanner.{type HandlerEndpoint}
import libero/walker.{type DiscoveredType, type DiscoveredVariant}

pub type PushContract {
  PushContract(module: String, type_module: String, type_name: String)
}

pub type SsrModelContract {
  SsrModelContract(route_module: String, type_module: String, type_name: String)
}

pub fn generate(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  push_types push_types: List(PushContract),
  ssr_models ssr_models: List(SsrModelContract),
) -> String {
  let sorted_endpoints =
    endpoints
    |> list.sort(fn(a, b) { string.compare(a.fn_name, b.fn_name) })

  let sorted_types =
    discovered
    |> list.sort(fn(a, b) {
      string.compare(
        a.module_path <> "." <> a.type_name,
        b.module_path <> "." <> b.type_name,
      )
    })

  let canonical =
    json.object([
      #("protocol_version", json.string("json-rpc-v1")),
      #("libero_version", json.string("6.0.0")),
      #("endpoints", json.array(sorted_endpoints, of: endpoint_json)),
      #("push_types", json.array(push_types, of: push_contract_json)),
      #("ssr_models", json.array(ssr_models, of: ssr_model_json)),
      #("types", json.array(sorted_types, of: discovered_type_json)),
    ])

  let canonical_text = json.to_string(canonical)
  let contract_hash = compute_contract_hash(canonical_text)

  json.object([
    #("protocol_version", json.string("json-rpc-v1")),
    #("libero_version", json.string("6.0.0")),
    #("contract_hash", json.string(contract_hash)),
    #("endpoints", json.array(sorted_endpoints, of: endpoint_json)),
    #("push_types", json.array(push_types, of: push_contract_json)),
    #("ssr_models", json.array(ssr_models, of: ssr_model_json)),
    #("types", json.array(sorted_types, of: discovered_type_json)),
  ])
  |> json.to_string
}

fn compute_contract_hash(canonical_text: String) -> String {
  canonical_text
  |> bit_array.from_string
  |> crypto.hash(crypto.Sha256, _)
  |> bit_array.base16_encode
  |> string.lowercase
}

fn endpoint_json(e: HandlerEndpoint) -> json.Json {
  json.object([
    #("module_path", json.string(e.module_path)),
    #("fn_name", json.string(e.fn_name)),
    #(
      "params",
      json.array(e.params, of: fn(p) {
        json.object([
          #("label", json.string(p.0)),
          #("type", field_type_json(p.1)),
        ])
      }),
    ),
    #("return_ok", field_type_json(e.return_ok)),
    #("return_err", field_type_json(e.return_err)),
  ])
}

fn push_contract_json(push: PushContract) -> json.Json {
  json.object([
    #("module", json.string(push.module)),
    #("type_module", json.string(push.type_module)),
    #("type_name", json.string(push.type_name)),
  ])
}

fn ssr_model_json(model: SsrModelContract) -> json.Json {
  json.object([
    #("route_module", json.string(model.route_module)),
    #("type_module", json.string(model.type_module)),
    #("type_name", json.string(model.type_name)),
  ])
}

fn discovered_type_json(t: DiscoveredType) -> json.Json {
  let sorted_variants =
    t.variants
    |> list.sort(fn(a, b) { string.compare(a.variant_name, b.variant_name) })

  json.object([
    #("module_path", json.string(t.module_path)),
    #("type_name", json.string(t.type_name)),
    #("type_params", json.array(t.type_params, of: json.string)),
    #("variants", json.array(sorted_variants, of: variant_json)),
  ])
}

fn variant_json(v: DiscoveredVariant) -> json.Json {
  json.object([
    #("variant_name", json.string(v.variant_name)),
    #("field_labels", json.array(v.field_labels, of: field_label_json)),
    #("field_types", json.array(v.fields, of: field_type_json)),
  ])
}

fn field_type_json(ft: FieldType) -> json.Json {
  case ft {
    field_type.IntField -> json.string("Int")
    field_type.FloatField -> json.string("Float")
    field_type.StringField -> json.string("String")
    field_type.BoolField -> json.string("Bool")
    field_type.BitArrayField -> json.string("BitArray")
    field_type.NilField -> json.string("Nil")
    field_type.TypeVar(name:) ->
      json.object([
        #("kind", json.string("TypeVar")),
        #("name", json.string(name)),
      ])
    field_type.ListOf(element:) ->
      json.object([
        #("kind", json.string("List")),
        #("element", field_type_json(element)),
      ])
    field_type.OptionOf(inner:) ->
      json.object([
        #("kind", json.string("Option")),
        #("inner", field_type_json(inner)),
      ])
    field_type.ResultOf(ok:, err:) ->
      json.object([
        #("kind", json.string("Result")),
        #("ok", field_type_json(ok)),
        #("err", field_type_json(err)),
      ])
    field_type.DictOf(key:, value:) ->
      json.object([
        #("kind", json.string("Dict")),
        #("key", field_type_json(key)),
        #("value", field_type_json(value)),
      ])
    field_type.TupleOf(elements:) ->
      json.object([
        #("kind", json.string("Tuple")),
        #("elements", json.array(elements, of: field_type_json)),
      ])
    field_type.UserType(module_path:, type_name:, args:) ->
      json.object([
        #("kind", json.string("UserType")),
        #("module_path", json.string(module_path)),
        #("type_name", json.string(type_name)),
        #("args", json.array(args, of: field_type_json)),
      ])
  }
}

fn field_label_json(label: option.Option(String)) -> json.Json {
  case label {
    option.Some(s) -> json.string(s)
    option.None -> json.null()
  }
}
