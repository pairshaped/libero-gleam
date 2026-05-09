import libero/codegen
import libero/scanner

// -- derive_module_path tests --

pub fn derive_module_path_standard_test() {
  let assert "shared/items" =
    scanner.derive_module_path(
      file_path: "test/fixtures/shared/src/shared/items.gleam",
    )
}

pub fn derive_module_path_nested_test() {
  let assert "shared/admin/items" =
    scanner.derive_module_path(
      file_path: "/some/project/shared/src/shared/admin/items.gleam",
    )
}

pub fn derive_module_path_root_module_test() {
  let assert "shared" =
    scanner.derive_module_path(file_path: "project/src/shared.gleam")
}

pub fn derive_module_path_no_src_segment_test() {
  let assert "some/path/module" =
    scanner.derive_module_path(file_path: "some/path/module.gleam")
}

// -- module_to_mjs_path tests --

pub fn module_to_mjs_multi_segment_test() {
  let assert "core/core/messages.mjs" =
    codegen.module_to_mjs_path(module_path: "core/messages", package: "core")
}

pub fn module_to_mjs_single_segment_test() {
  let assert "shared/shared.mjs" =
    codegen.module_to_mjs_path(module_path: "shared", package: "shared")
}

pub fn module_to_mjs_deep_path_test() {
  let assert "shared/shared/admin/items.mjs" =
    codegen.module_to_mjs_path(
      module_path: "shared/admin/items",
      package: "shared",
    )
}

pub fn module_to_mjs_different_package_test() {
  let assert "client/admin/pages/index.mjs" =
    codegen.module_to_mjs_path(
      module_path: "admin/pages/index",
      package: "client",
    )
}
