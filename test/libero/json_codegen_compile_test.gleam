import glance
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import libero/field_type.{FloatField, IntField, StringField}
import libero/json/codegen
import libero/walker.{DiscoveredType, DiscoveredVariant}

pub fn generated_codec_parses_for_simple_record_test() {
  // Single type with one labelled variant: glance can parse this
  // because the generated code uses `if` guards that glance handles
  // for short enough inputs.
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title"), Some("body")],
          fields: [StringField, StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)
  let assert Ok(_) = glance.module(source)
  Nil
}

pub fn generated_codec_no_todo_stubs_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title")],
          fields: [StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)
  string.contains(source, "todo") |> should.be_false
}

pub fn generated_encoder_wraps_raw_values_as_json_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title")],
          fields: [StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  // Encoder should wrap fields in json.string(), not emit raw vars
  string.contains(source, "json.string(f0)") |> should.be_true
  // But should NOT contain bare field variable without json wrapper
  string.contains(source, "#(\"title\", f0)") |> should.be_false
}

pub fn generated_decoder_uses_decode_run_pattern_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title")],
          fields: [StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  // Decoder should use decode.run with decode.field, not bare decode.field
  string.contains(source, "decode.run(value, decode.field(\"type\"")
  |> should.be_true

  string.contains(source, "decode.run(value, decode.field(\"variant\"")
  |> should.be_true

  string.contains(source, "decode.run(value, decode.field(\"fields\"")
  |> should.be_true

  string.contains(source, "decode.run(fields, decode.field(\"title\"")
  |> should.be_true
}

pub fn generated_decoder_rejects_bare_decode_field_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title")],
          fields: [StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  // No bare "decode.field(value" or "decode.field(fields" without decode.run
  string.contains(source, "decode.field(value") |> should.be_false
  string.contains(source, "decode.field(fields") |> should.be_false
}

pub fn generated_codec_has_encoder_and_decoder_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title")],
          fields: [StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  string.contains(source, "pub fn json_encode_shared_article__article")
  |> should.be_true

  string.contains(source, "pub fn json_decode_shared_article__article")
  |> should.be_true
}

pub fn generated_codec_uses_decode_success_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title")],
          fields: [StringField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  // All decode.field calls should use decode.success in the closure
  string.contains(source, "decode.success") |> should.be_true
}

pub fn generated_encoder_checks_safe_int_range_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("count")],
          fields: [IntField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  // Must contain safe int range constants
  string.contains(source, "-9007199254740991") |> should.be_true
  string.contains(source, "9007199254740991") |> should.be_true
  // Must contain the panic message
  string.contains(source, "Int outside JavaScript safe integer range")
  |> should.be_true
}

pub fn generated_encoder_checks_finite_float_test() {
  let types = [
    DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("score")],
          fields: [FloatField],
        ),
      ],
    ),
  ]

  let assert Ok(source) = codegen.generate(types)

  // Must contain NaN/Infinity check (float multiplication uses *.)
  string.contains(source, "*. 0.0 == 0.0") |> should.be_true
  // Must contain the panic message
  string.contains(source, "Float must be finite") |> should.be_true
}
