import glance
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import libero/field_type
import libero/json/codegen
import libero/walker

pub fn generated_encoder_emits_type_and_variant_test() {
  let types = [
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

  let source = assert_generated(codegen.generate(types, [], []))

  // Encoder function exists
  string.contains(source, "fn json_encode_shared_article__article")
  |> should.be_true
  // Type string
  string.contains(source, "shared/article.Article")
  |> should.be_true
  // Variant string
  string.contains(source, "\"Article\"")
  |> should.be_true
  // Field labels
  string.contains(source, "\"title\"")
  |> should.be_true
  string.contains(source, "\"body\"")
  |> should.be_true
  // Decoder function exists
  string.contains(source, "fn json_decode_shared_article__article")
  |> should.be_true
}

pub fn duplicate_variant_names_generate_distinct_codecs_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "page/a",
      type_name: "ToClient",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "page/a",
          variant_name: "Updated",
          atom_name: "page_a__updated",
          float_field_indices: [],
          field_labels: [Some("msg")],
          fields: [field_type.StringField],
        ),
      ],
    ),
    walker.DiscoveredType(
      module_path: "page/b",
      type_name: "ToClient",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "page/b",
          variant_name: "Updated",
          atom_name: "page_b__updated",
          float_field_indices: [],
          field_labels: [Some("msg")],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Both encode functions exist with distinct names
  string.contains(source, "json_encode_page_a__to_client")
  |> should.be_true
  string.contains(source, "json_encode_page_b__to_client")
  |> should.be_true
  // Both type strings appear
  string.contains(source, "page/a.ToClient")
  |> should.be_true
  string.contains(source, "page/b.ToClient")
  |> should.be_true
}

pub fn unlabelled_fields_encode_as_array_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/pair",
      type_name: "Pair",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/pair",
          variant_name: "Pair",
          atom_name: "shared_pair__pair",
          float_field_indices: [],
          field_labels: [None, None],
          fields: [field_type.StringField, field_type.IntField],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Unlabelled fields should use json.array for the fields value
  string.contains(source, "json.array(")
  |> should.be_true
}

pub fn mixed_labelled_unlabelled_is_rejected_for_json_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/mixed",
      type_name: "Mixed",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/mixed",
          variant_name: "Mixed",
          atom_name: "shared_mixed__mixed",
          float_field_indices: [],
          field_labels: [None, Some("limit")],
          fields: [field_type.StringField, field_type.IntField],
        ),
      ],
    ),
  ]

  let result = codegen.generate(types, [], [])

  // Should contain an error message about mixed fields
  case result {
    Ok(_) -> should.fail()
    Error(errors) -> {
      let messages = list.map(errors, fn(e) { e.message })
      list.any(messages, fn(m) { string.contains(m, "mixed") })
      |> should.be_true
    }
  }
}

pub fn zero_field_variant_encodes_empty_object_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/status",
      type_name: "Status",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/status",
          variant_name: "Ready",
          atom_name: "shared_status__ready",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Zero-field variants should include "fields" key
  string.contains(source, "\"fields\"")
  |> should.be_true
}

pub fn generated_codec_includes_user_module_imports_test() {
  let types = [
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
          field_labels: [Some("title")],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  string.contains(source, "import shared/article")
  |> should.be_true
}

pub fn generated_codec_uses_qualified_constructors_test() {
  let types = [
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
          field_labels: [Some("title")],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Encoder pattern uses qualified constructor (positional fields)
  string.contains(source, "article.Article(f0)")
  |> should.be_true

  // Decoder construction uses qualified constructor
  string.contains(source, "article.Article(title:)")
  |> should.be_true
}

pub fn generated_codec_includes_option_result_builtins_test() {
  let source = assert_generated(codegen.generate([], [], []))

  string.contains(source, "json_encode_gleam_option__option")
  |> should.be_true

  string.contains(source, "json_decode_gleam_option__option")
  |> should.be_true

  string.contains(source, "json_encode_gleam_result__result")
  |> should.be_true

  string.contains(source, "json_decode_gleam_result__result")
  |> should.be_true
}

pub fn generated_codec_option_field_uses_builtin_encoder_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/opt",
      type_name: "Opt",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/opt",
          variant_name: "Opt",
          atom_name: "shared_opt__opt",
          float_field_indices: [],
          field_labels: [Some("value")],
          fields: [field_type.OptionOf(field_type.StringField)],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Encoder for Option field calls builtin with inner encoder
  string.contains(
    source,
    "json_encode_gleam_option__option(f0, fn(x) { json.string(x) })",
  )
  |> should.be_true

  // Decoder for Option field calls builtin with inner decoder
  string.contains(source, "json_decode_gleam_option__option(raw, fn(inner_raw)")
  |> should.be_true
}

pub fn duplicate_modules_use_full_underscored_aliases_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/article",
      type_name: "A",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "A",
          atom_name: "shared_article__a",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
    walker.DiscoveredType(
      module_path: "pages/article",
      type_name: "B",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "pages/article",
          variant_name: "B",
          atom_name: "pages_article__b",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Both modules use underscored aliases since they share last segment
  string.contains(source, "import shared/article as shared_article")
  |> should.be_true
  string.contains(source, "import pages/article as pages_article")
  |> should.be_true

  // Constructors use their respective aliases
  string.contains(source, "shared_article.A")
  |> should.be_true
  string.contains(source, "pages_article.B")
  |> should.be_true
}

pub fn generated_codec_is_syntactically_valid_gleam_test() {
  let types = [
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
        walker.DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Draft",
          atom_name: "shared_article__draft",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
  ]

  let source = assert_generated(codegen.generate(types, [], []))

  // Verify the generated source is syntactically valid Gleam
  let assert Ok(_module) = glance.module(source)
}

fn assert_generated(result: Result(String, List(a))) -> String {
  let assert Ok(source) = result
  source
}
