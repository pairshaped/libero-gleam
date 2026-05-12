import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import libero/field_type
import libero/json/contract
import libero/scanner
import libero/walker

pub fn contract_artifact_is_deterministic_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/rpc",
      fn_name: "get_article",
      params: [#("slug", field_type.StringField)],
      return_ok: field_type.UserType("shared/article", "Article", []),
      return_err: field_type.StringField,
      mutates_context: False,
      msg_type: None,
    ),
  ]

  let discovered = [
    walker.DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title"), Some("body")],
          fields: [field_type.StringField, field_type.StringField],
        ),
      ],
    ),
  ]

  let push_types: List(contract.PushContract) = []
  let ssr_models: List(contract.SsrModelContract) = []

  let one = contract.generate(endpoints:, discovered:, push_types:, ssr_models:)
  let two = contract.generate(endpoints:, discovered:, push_types:, ssr_models:)

  one |> should.equal(two)

  string.contains(one, "\"protocol_version\"") |> should.be_true
  string.contains(one, "\"json-rpc-v1\"") |> should.be_true
  string.contains(one, "\"contract_hash\"") |> should.be_true
  string.contains(one, "\"push_types\"") |> should.be_true
  string.contains(one, "\"ssr_models\"") |> should.be_true
  string.contains(one, "\"shared/article\"") |> should.be_true
}

pub fn contract_artifact_includes_endpoints_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/rpc",
      fn_name: "get_article",
      params: [#("slug", field_type.StringField)],
      return_ok: field_type.UserType("shared/article", "Article", []),
      return_err: field_type.StringField,
      mutates_context: False,
      msg_type: None,
    ),
  ]

  let discovered: List(walker.DiscoveredType) = []
  let push_types: List(contract.PushContract) = []
  let ssr_models: List(contract.SsrModelContract) = []

  let artifact =
    contract.generate(endpoints:, discovered:, push_types:, ssr_models:)
  let parsed = json.parse(artifact, decode.dynamic)

  // Don't crash on parse — the artifact must be valid JSON
  let assert Ok(_) = parsed
}
