//// Direct tests for libero/codegen helper functions.

import gleam/dict
import libero/codegen

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

pub fn build_module_alias_map_uses_last_segment_when_unique_test() {
  let aliases =
    codegen.build_module_alias_map(["shared/article", "pages/profile"])

  let assert Ok("article") = aliases |> dict.get("shared/article")
  let assert Ok("profile") = aliases |> dict.get("pages/profile")
}

pub fn build_module_alias_map_uses_full_path_on_collision_test() {
  let aliases =
    codegen.build_module_alias_map(["shared/article", "pages/article"])

  let assert Ok("shared_article") = aliases |> dict.get("shared/article")
  let assert Ok("pages_article") = aliases |> dict.get("pages/article")
}
