import birdie
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
  string.contains(one, "\"typed_value_contract\"") |> should.be_true
  string.contains(one, "\"typed-json-v1\"") |> should.be_true
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

pub fn canonical_typed_json_contract_artifact_snapshot_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/rpc",
      fn_name: "save_article",
      params: [
        #("article", field_type.UserType("shared/article", "Article", [])),
      ],
      return_ok: field_type.UserType("shared/article", "Article", []),
      return_err: field_type.ResultOf(
        field_type.StringField,
        field_type.NilField,
      ),
      mutates_context: True,
      msg_type: Some(#("shared/messages", "ClientMsg")),
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
          float_field_indices: [2],
          field_labels: [
            Some("title"),
            Some("body"),
            Some("rating"),
            Some("image"),
            Some("tags"),
            Some("metadata"),
            Some("position"),
            Some("status"),
          ],
          fields: [
            field_type.StringField,
            field_type.StringField,
            field_type.FloatField,
            field_type.BitArrayField,
            field_type.ListOf(field_type.StringField),
            field_type.DictOf(field_type.StringField, field_type.StringField),
            field_type.TupleOf([field_type.IntField, field_type.IntField]),
            field_type.OptionOf(
              field_type.UserType("shared/status", "Status", []),
            ),
          ],
        ),
      ],
    ),
    walker.DiscoveredType(
      module_path: "shared/messages",
      type_name: "ClientMsg",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/messages",
          variant_name: "Save",
          atom_name: "shared_messages__save",
          float_field_indices: [],
          field_labels: [None],
          fields: [
            field_type.UserType("shared/article", "Article", []),
          ],
        ),
      ],
    ),
    walker.DiscoveredType(
      module_path: "shared/status",
      type_name: "Status",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/status",
          variant_name: "Draft",
          atom_name: "shared_status__draft",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/status",
          variant_name: "Published",
          atom_name: "shared_status__published",
          float_field_indices: [],
          field_labels: [Some("slug")],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let push_types = [
    contract.PushContract(
      module: "public/pages/article",
      type_module: "shared/messages",
      type_name: "ServerMsg",
    ),
  ]
  let ssr_models = [
    contract.SsrModelContract(
      route_module: "public/pages/article",
      type_module: "shared/article",
      type_name: "Article",
    ),
  ]

  contract.generate(endpoints:, discovered:, push_types:, ssr_models:)
  |> birdie.snap(title: "canonical typed JSON contract artifact")
}
