import gleam/option.{None}
import gleam/string
import gleeunit/should
import libero
import libero/field_type
import libero/walker

pub fn generated_etf_codec_module_wraps_neutral_runtime_test() {
  let source =
    libero.generate_etf_codec_module(
      atoms_module: "generated@libero_atoms",
      decoders_module: "generated/libero/decoders",
    )

  string.contains(source, "import generated/libero/decoders")
  |> should.be_true()
  string.contains(source, "import libero/etf/wire as etf_wire")
  |> should.be_true()
  string.contains(
    source,
    "@external(erlang, \"generated@libero_atoms\", \"ensure\")",
  )
  |> should.be_true()
  string.contains(source, "pub fn ensure() -> Nil")
  |> should.be_true()
  string.contains(source, "pub fn encode(value: a) -> BitArray")
  |> should.be_true()
  string.contains(source, "pub fn decode(bytes: BitArray)")
  |> should.be_true()
  string.contains(source, "api/to_client") |> should.be_false()
  string.contains(source, "api/to_server") |> should.be_false()
}

pub fn generated_etf_codec_module_exposes_only_rally_codec_surface_test() {
  let source =
    libero.generate_etf_codec_module(
      atoms_module: "generated@libero_atoms",
      decoders_module: "generated/libero/decoders",
    )

  string.contains(source, "pub fn ensure() -> Nil") |> should.be_true()
  string.contains(source, "pub fn encode(value: a) -> BitArray")
  |> should.be_true()
  string.contains(source, "pub fn decode(bytes: BitArray)")
  |> should.be_true()

  string.contains(source, "pub fn encode_request(") |> should.be_false()
  string.contains(source, "pub fn decode_request(") |> should.be_false()
  string.contains(source, "pub fn encode_response(") |> should.be_false()
  string.contains(source, "pub fn decode_server_frame(") |> should.be_false()
  string.contains(source, "pub fn encode_push(") |> should.be_false()
  string.contains(source, "pub fn encode_flags(") |> should.be_false()
  string.contains(source, "pub fn decode_flags_typed(") |> should.be_false()
}

pub fn generated_decoders_do_not_import_framework_protocol_test() {
  let source =
    libero.generate_decoders_ffi(
      discovered: [],
      package: "app",
      dependency_packages: [],
    )

  string.contains(source, "requests.mjs") |> should.be_false()
}

pub fn json_contract_hash_helper_returns_contract_hash_test() {
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
          field_labels: [None],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let artifact =
    libero.generate_json_contract(discovered:, push_types: [], ssr_models: [])
  let hash =
    libero.generate_json_contract_hash(
      discovered:,
      push_types: [],
      ssr_models: [],
    )

  string.contains(artifact, "\"contract_hash\":\"" <> hash <> "\"")
  |> should.be_true()
}
