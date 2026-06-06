import gleam/option.{None}
import gleam/string
import gleeunit/should
import libero
import libero/field_type
import libero/json/codegen as json_codegen
import libero/json/contract
import libero/scanner

pub fn generated_request_msg_module_is_separate_from_dispatch_test() {
  let endpoints = [save_article_endpoint()]

  let source = libero.generate_request_msg_module(endpoints)

  string.contains(source, "pub type RequestMsg") |> should.be_true()
  string.contains(source, "import gleam/option.{type Option}")
  |> should.be_true()
  string.contains(source, "import shared/article")
  |> should.be_true()
  string.contains(
    source,
    "ServerSaveArticle(article: article.Article, maybe_id: Option(Int))",
  )
  |> should.be_true()
  string.contains(source, "libero/etf/wire") |> should.be_false()
}

pub fn generated_json_contract_can_include_request_msg_type_test() {
  let endpoints = [save_article_endpoint()]
  let request_msg_type =
    json_codegen.request_msg_discovered_type(
      endpoints:,
      module_path: "generated/libero/requests",
      type_name: "RequestMsg",
    )
  let artifact =
    contract.generate(
      endpoints:,
      discovered: [request_msg_type],
      push_types: [],
      ssr_models: [],
    )

  string.contains(artifact, "\"module_path\":\"generated/libero/requests\"")
  |> should.be_true()
  string.contains(artifact, "\"type_name\":\"RequestMsg\"")
  |> should.be_true()
  string.contains(artifact, "\"variant_name\":\"ServerSaveArticle\"")
  |> should.be_true()
}

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

pub fn generated_etf_codec_module_exposes_protocol_facade_test() {
  let source =
    libero.generate_etf_codec_module(
      atoms_module: "generated@libero_atoms",
      decoders_module: "generated/libero/decoders",
    )

  string.contains(source, "pub fn encode_request(") |> should.be_true()
  string.contains(source, "etf_wire.encode_request(") |> should.be_true()
  string.contains(source, "pub fn decode_request(") |> should.be_true()
  string.contains(source, "etf_wire.decode_request(bytes)") |> should.be_true()

  string.contains(source, "pub fn encode_response(") |> should.be_true()
  string.contains(source, "etf_wire.encode_response(") |> should.be_true()
  string.contains(source, "pub fn decode_server_frame(") |> should.be_true()
  string.contains(source, "etf_wire.decode_server_frame(bytes)")
  |> should.be_true()

  string.contains(source, "pub fn encode_push(") |> should.be_true()
  string.contains(source, "etf_wire.encode_push(") |> should.be_true()

  string.contains(source, "pub fn encode_flags(") |> should.be_true()
  string.contains(source, "etf_wire.encode_flags(value)") |> should.be_true()
  string.contains(source, "pub fn decode_flags_typed(") |> should.be_true()
  string.contains(source, "etf_wire.decode_flags_typed(") |> should.be_true()
}

pub fn generated_decoders_skip_request_import_when_no_endpoints_test() {
  let source =
    libero.generate_decoders_ffi(
      discovered: [],
      endpoints: [],
      package: "app",
      dependency_packages: [],
    )

  string.contains(source, "requests.mjs") |> should.be_false()
}

pub fn json_contract_hash_helper_returns_contract_hash_test() {
  let endpoints = [save_article_endpoint()]
  let discovered = [
    json_codegen.request_msg_discovered_type(
      endpoints:,
      module_path: "generated/libero/requests",
      type_name: "RequestMsg",
    ),
  ]

  let artifact =
    libero.generate_json_contract(
      endpoints:,
      discovered:,
      push_types: [],
      ssr_models: [],
    )
  let hash =
    libero.generate_json_contract_hash(
      endpoints:,
      discovered:,
      push_types: [],
      ssr_models: [],
    )

  string.contains(artifact, "\"contract_hash\":\"" <> hash <> "\"")
  |> should.be_true()
}

fn save_article_endpoint() -> scanner.HandlerEndpoint {
  scanner.HandlerEndpoint(
    module_path: "server/handler",
    fn_name: "save_article",
    return_ok: field_type.UserType("shared/article", "Article", []),
    return_err: field_type.StringField,
    params: [
      #("article", field_type.UserType("shared/article", "Article", [])),
      #("maybe_id", field_type.OptionOf(field_type.IntField)),
    ],
    mutates_context: False,
    msg_type: None,
  )
}
