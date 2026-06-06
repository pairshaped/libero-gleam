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
      module_path: "server/api",
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
  string.contains(one, "\"libero-json-v1\"") |> should.be_true
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
      module_path: "server/api",
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

pub fn contract_hash_distinguishes_same_shaped_custom_type_names_test() {
  let endpoints: List(scanner.HandlerEndpoint) = []
  let push_types: List(contract.PushContract) = []
  let ssr_models: List(contract.SsrModelContract) = []
  let draft = [
    json_contract_record_type(
      module_path: "shared/forms",
      type_name: "Draft",
      variant_name: "Draft",
    ),
  ]
  let published = [
    json_contract_record_type(
      module_path: "shared/forms",
      type_name: "Published",
      variant_name: "Published",
    ),
  ]

  let draft_hash =
    contract.generate_hash(
      endpoints:,
      discovered: draft,
      push_types:,
      ssr_models:,
    )
  let published_hash =
    contract.generate_hash(
      endpoints:,
      discovered: published,
      push_types:,
      ssr_models:,
    )

  draft_hash |> should.not_equal(published_hash)
}

pub fn contract_hash_distinguishes_same_named_custom_type_paths_test() {
  let endpoints: List(scanner.HandlerEndpoint) = []
  let push_types: List(contract.PushContract) = []
  let ssr_models: List(contract.SsrModelContract) = []
  let public = [
    json_contract_record_type(
      module_path: "shared/public",
      type_name: "Marker",
      variant_name: "Marker",
    ),
  ]
  let private = [
    json_contract_record_type(
      module_path: "shared/private",
      type_name: "Marker",
      variant_name: "Marker",
    ),
  ]

  let public_hash =
    contract.generate_hash(
      endpoints:,
      discovered: public,
      push_types:,
      ssr_models:,
    )
  let private_hash =
    contract.generate_hash(
      endpoints:,
      discovered: private,
      push_types:,
      ssr_models:,
    )

  public_hash |> should.not_equal(private_hash)
}

pub fn contract_artifact_keeps_same_named_types_from_different_paths_test() {
  let endpoints: List(scanner.HandlerEndpoint) = []
  let push_types: List(contract.PushContract) = []
  let ssr_models: List(contract.SsrModelContract) = []
  let discovered = [
    json_contract_record_type(
      module_path: "shared/public",
      type_name: "Marker",
      variant_name: "Marker",
    ),
    json_contract_record_type(
      module_path: "shared/private",
      type_name: "Marker",
      variant_name: "Marker",
    ),
  ]

  let artifact =
    contract.generate(endpoints:, discovered:, push_types:, ssr_models:)

  string.contains(artifact, "\"module_path\":\"shared/public\"")
  |> should.be_true
  string.contains(artifact, "\"module_path\":\"shared/private\"")
  |> should.be_true
  string.contains(artifact, "\"type_name\":\"Marker\"") |> should.be_true
}

pub fn canonical_typed_json_contract_artifact_snapshot_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/api",
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
      msg_type: Some(#("shared/messages", "RequestMsg")),
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
      type_name: "RequestMsg",
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

fn json_contract_record_type(
  module_path module_path: String,
  type_name type_name: String,
  variant_name variant_name: String,
) -> walker.DiscoveredType {
  walker.DiscoveredType(module_path:, type_name:, type_params: [], variants: [
    walker.DiscoveredVariant(
      module_path:,
      variant_name:,
      atom_name: walker.qualified_atom_name(module_path:, variant_name:),
      float_field_indices: [],
      field_labels: [Some("id"), Some("label")],
      fields: [field_type.IntField, field_type.StringField],
    ),
  ])
}
