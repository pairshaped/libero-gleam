//// Direct tests for libero/codegen helper functions.

import gleam/list
import gleam/option
import gleam/string
import libero/codegen
import libero/field_type
import libero/scanner

// -- to_pascal_case --

pub fn to_pascal_case_single_word_test() {
  let assert "Get" = codegen.to_pascal_case("get")
}

pub fn to_pascal_case_multi_word_test() {
  let assert "GetItems" = codegen.to_pascal_case("get_items")
}

pub fn to_pascal_case_three_words_test() {
  let assert "CreateNewItem" = codegen.to_pascal_case("create_new_item")
}

pub fn to_pascal_case_already_pascal_test() {
  let assert "Get" = codegen.to_pascal_case("Get")
}

// -- module_to_underscored --

pub fn module_to_underscored_single_segment_test() {
  let assert "handler" = codegen.module_to_underscored("handler")
}

pub fn module_to_underscored_multi_segment_test() {
  let assert "shared_discount" =
    codegen.module_to_underscored("shared/discount")
}

pub fn module_to_underscored_deep_path_test() {
  let assert "shared_admin_items" =
    codegen.module_to_underscored("shared/admin/items")
}

// -- variant_pattern --

pub fn variant_pattern_zero_params_test() {
  let assert "GetItems" =
    codegen.variant_pattern(variant_name: "GetItems", params: [])
}

pub fn variant_pattern_with_params_test() {
  let assert "CreateItem(params:, id:)" =
    codegen.variant_pattern(variant_name: "CreateItem", params: [
      #("params", field_type.UserType("shared/types", "ItemParams", [])),
      #("id", field_type.IntField),
    ])
}

// -- is_dict / is_option --

pub fn is_dict_detects_dict_test() {
  let assert True =
    codegen.is_dict(field_type.DictOf(
      field_type.StringField,
      field_type.IntField,
    ))
}

pub fn is_dict_returns_false_for_list_test() {
  let assert False = codegen.is_dict(field_type.ListOf(field_type.IntField))
}

pub fn is_option_detects_option_test() {
  let assert True = codegen.is_option(field_type.OptionOf(field_type.IntField))
}

pub fn is_option_returns_false_for_result_test() {
  let assert False =
    codegen.is_option(field_type.ResultOf(
      field_type.IntField,
      field_type.NilField,
    ))
}

// -- endpoints_contain --

fn single_endpoint(return_ok: field_type.FieldType) -> scanner.HandlerEndpoint {
  scanner.HandlerEndpoint(
    module_path: "server/handler",
    fn_name: "test",
    return_ok: return_ok,
    return_err: field_type.NilField,
    params: [],
    mutates_context: True,
    msg_type_name: option.None,
  )
}

pub fn endpoints_contain_finds_option_in_return_ok_test() {
  let ep = single_endpoint(field_type.OptionOf(field_type.IntField))
  let assert True =
    codegen.endpoints_contain(endpoints: [ep], predicate: codegen.is_option)
}

pub fn endpoints_contain_returns_false_when_absent_test() {
  let ep = single_endpoint(field_type.IntField)
  let assert False =
    codegen.endpoints_contain(endpoints: [ep], predicate: codegen.is_option)
}

pub fn endpoints_contain_finds_option_in_params_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "test",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("opt", field_type.OptionOf(field_type.StringField))],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let assert True =
    codegen.endpoints_contain(endpoints: [ep], predicate: codegen.is_option)
}

pub fn endpoints_contain_finds_option_in_return_err_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "test",
      return_ok: field_type.IntField,
      return_err: field_type.OptionOf(field_type.StringField),
      params: [],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let assert True =
    codegen.endpoints_contain(endpoints: [ep], predicate: codegen.is_option)
}

// -- import_if --

pub fn import_if_emits_import_when_predicate_true_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "test",
      return_ok: field_type.OptionOf(field_type.IntField),
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let result =
    codegen.import_if(
      endpoints: [ep],
      predicate: codegen.is_option,
      import_line: "import gleam/option.{type Option}",
    )
  let assert True = string.contains(result, "gleam/option")
}

pub fn import_if_returns_empty_when_predicate_false_test() {
  let ep = single_endpoint(field_type.IntField)
  let result =
    codegen.import_if(
      endpoints: [ep],
      predicate: codegen.is_option,
      import_line: "import gleam/option.{type Option}",
    )
  let assert "" = result
}

// -- emit_client_msg_variants --

pub fn emit_client_msg_variants_zero_param_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "get_items",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let lines =
    codegen.emit_client_msg_variants(
      [ep],
      resolve_alias: field_type.last_segment,
    )
  let assert ["  ServerGetItems"] = lines
}

pub fn emit_client_msg_variants_with_params_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "create_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [
        #("params", field_type.UserType("shared/types", "ItemParams", [])),
        #("id", field_type.IntField),
      ],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let lines =
    codegen.emit_client_msg_variants(
      [ep],
      resolve_alias: field_type.last_segment,
    )
  let assert ["  ServerCreateItem(params: types.ItemParams, id: Int)"] = lines
}

// -- collect_endpoint_type_imports --

pub fn collect_endpoint_type_imports_params_only_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "test",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [
        #("item", field_type.UserType("shared/types", "Item", [])),
      ],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let imports =
    codegen.collect_endpoint_type_imports(
      [ep],
      include_return: False,
      resolve_alias: field_type.last_segment,
    )
  let assert ["import shared/types"] = imports
}

pub fn collect_endpoint_type_imports_includes_return_test() {
  let ep =
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "test",
      return_ok: field_type.UserType("shared/result", "Payload", []),
      return_err: field_type.UserType("shared/result", "Err", []),
      params: [
        #("item", field_type.UserType("shared/types", "Item", [])),
      ],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let imports =
    codegen.collect_endpoint_type_imports(
      [ep],
      include_return: True,
      resolve_alias: field_type.last_segment,
    )
  let assert 2 = list.length(imports)
  let assert True = list.contains(imports, "import shared/result")
  let assert True = list.contains(imports, "import shared/types")
}

pub fn collect_endpoint_type_imports_deduplicates_test() {
  let ep1 =
    scanner.HandlerEndpoint(
      module_path: "server/a",
      fn_name: "fn1",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [
        #("item", field_type.UserType("shared/types", "Item", [])),
      ],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let ep2 =
    scanner.HandlerEndpoint(
      module_path: "server/b",
      fn_name: "fn2",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [
        #("item", field_type.UserType("shared/types", "Item", [])),
      ],
      mutates_context: True,
      msg_type_name: option.None,
    )
  let imports =
    codegen.collect_endpoint_type_imports(
      [ep1, ep2],
      include_return: False,
      resolve_alias: field_type.last_segment,
    )
  let assert ["import shared/types"] = imports
}
