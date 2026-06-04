import gleam/option.{None}
import gleam/string
import gleeunit/should
import libero
import libero/field_type
import libero/json/codegen as json_codegen
import libero/json/contract
import libero/scanner

pub fn generated_client_msg_module_is_separate_from_dispatch_test() {
  let endpoints = [save_article_endpoint()]

  let source = libero.generate_client_msg_module(endpoints)

  string.contains(source, "pub type ClientMsg") |> should.be_true()
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

pub fn generated_json_contract_can_include_client_msg_type_test() {
  let endpoints = [save_article_endpoint()]
  let client_msg_type =
    json_codegen.client_msg_discovered_type(
      endpoints:,
      module_path: "generated/libero/messages",
      type_name: "ClientMsg",
    )
  let artifact =
    contract.generate(
      endpoints:,
      discovered: [client_msg_type],
      push_types: [],
      ssr_models: [],
    )

  string.contains(artifact, "\"module_path\":\"generated/libero/messages\"")
  |> should.be_true()
  string.contains(artifact, "\"type_name\":\"ClientMsg\"")
  |> should.be_true()
  string.contains(artifact, "\"variant_name\":\"ServerSaveArticle\"")
  |> should.be_true()
}

pub fn generated_etf_codec_module_wraps_neutral_runtime_test() {
  let source =
    libero.generate_etf_codec_module(
      atoms_module: "generated@rpc_atoms",
      decoders_module: "generated/libero/rpc_decoders",
    )

  string.contains(source, "import generated/libero/rpc_decoders")
  |> should.be_true()
  string.contains(source, "import libero/etf/wire as etf_wire")
  |> should.be_true()
  string.contains(
    source,
    "@external(erlang, \"generated@rpc_atoms\", \"ensure\")",
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

pub fn json_contract_hash_helper_returns_contract_hash_test() {
  let endpoints = [save_article_endpoint()]
  let discovered = [
    json_codegen.client_msg_discovered_type(
      endpoints:,
      module_path: "generated/libero/messages",
      type_name: "ClientMsg",
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
