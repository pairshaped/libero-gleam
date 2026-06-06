import gleam/option
import gleam/string
import libero

pub fn mirrored_output_dir_uses_env_value_test() {
  let assert option.Some("custom/generated/libero") =
    libero.mirrored_output_dir_from_env(option.Some("custom/generated/libero"))
}

pub fn mirrored_output_dir_is_disabled_without_env_test() {
  let assert option.None = libero.mirrored_output_dir_from_env(option.None)
}

pub fn mirrored_output_dir_is_disabled_for_blank_env_test() {
  let assert option.None =
    libero.mirrored_output_dir_from_env(option.Some("   "))
}

pub fn config_from_toml_defaults_without_libero_table_test() {
  let assert Ok(libero.LiberoConfig(
    use_json: False,
    erlang_output_dir: "src/generated/libero",
    mirrored_output_dir: option.None,
    type_seeds: [],
  )) = libero.config_from_toml("name = \"app\"")
}

pub fn config_from_toml_reads_libero_table_test() {
  let toml =
    "
[tools.libero]
use_json = true
erlang_output_dir = \"src/server/generated\"
mirrored_output_dir = \"../clients/web/src/generated/libero\"
"
  let assert Ok(libero.LiberoConfig(
    use_json: True,
    erlang_output_dir: "src/server/generated",
    mirrored_output_dir: option.Some("../clients/web/src/generated/libero"),
    type_seeds: [],
  )) = libero.config_from_toml(toml)
}

pub fn config_from_toml_reads_mirrored_output_dir_test() {
  let toml =
    "
[tools.libero]
mirrored_output_dir = \"../clients/web/src/generated/libero\"
"
  let assert Ok(libero.LiberoConfig(
    use_json: False,
    erlang_output_dir: "src/generated/libero",
    mirrored_output_dir: option.Some("../clients/web/src/generated/libero"),
    type_seeds: [],
  )) = libero.config_from_toml(toml)
}

pub fn config_from_toml_ignores_removed_js_output_dir_test() {
  let toml =
    "
[tools.libero]
js_output_dir = \"legacy/generated/libero\"
"
  let assert Ok(config) = libero.config_from_toml(toml)
  let assert option.None = config.mirrored_output_dir
}

pub fn config_from_toml_rejects_wrong_mirrored_output_dir_type_test() {
  let toml =
    "
[tools.libero]
mirrored_output_dir = true
"
  let assert Error(message) = libero.config_from_toml(toml)
  let assert True = string.contains(message, "tools.libero.mirrored_output_dir")
  let assert True = string.contains(message, "String")
}

pub fn config_from_toml_reads_type_seeds_test() {
  let toml =
    "
[tools.libero]
type_seeds = [
  \"admin/pages/games.ServerMsg\",
  \"admin/pages/games.LoadResult\",
  \"broadcasts.Event\",
]
"
  let assert Ok(config) = libero.config_from_toml(toml)
  let assert [
    #("admin/pages/games", "ServerMsg"),
    #("admin/pages/games", "LoadResult"),
    #("broadcasts", "Event"),
  ] = config.type_seeds
}

pub fn config_from_toml_defaults_blank_output_dirs_test() {
  let toml =
    "
[tools.libero]
erlang_output_dir = \"   \"
mirrored_output_dir = \"   \"
"
  let assert Ok(libero.LiberoConfig(
    use_json: False,
    erlang_output_dir: "src/generated/libero",
    mirrored_output_dir: option.None,
    type_seeds: [],
  )) = libero.config_from_toml(toml)
}

pub fn config_from_toml_does_not_keep_client_out_dir_alias_test() {
  let toml =
    "
[tools.libero]
client_out_dir = \"../clients/web/src/generated/libero\"
"
  let assert Ok(libero.LiberoConfig(
    use_json: False,
    erlang_output_dir: "src/generated/libero",
    mirrored_output_dir: option.None,
    type_seeds: [],
  )) = libero.config_from_toml(toml)
}

pub fn config_from_toml_does_not_keep_gen_etf_alias_test() {
  let toml =
    "
[tools.libero]
gen_etf = true
"
  let assert Ok(libero.LiberoConfig(
    use_json: False,
    erlang_output_dir: "src/generated/libero",
    mirrored_output_dir: option.None,
    type_seeds: [],
  )) = libero.config_from_toml(toml)
}

pub fn config_from_toml_rejects_wrong_use_json_type_test() {
  let toml =
    "
[tools.libero]
use_json = \"true\"
"
  let assert Error(message) = libero.config_from_toml(toml)
  let assert True = string.contains(message, "tools.libero.use_json")
  let assert True = string.contains(message, "Bool")
}

pub fn env_use_json_overrides_toml_config_test() {
  let config =
    libero.LiberoConfig(
      use_json: True,
      erlang_output_dir: "src/generated/libero",
      mirrored_output_dir: option.None,
      type_seeds: [],
    )
  let assert False = libero.resolve_use_json(config, option.Some("0"))
  let assert True = libero.resolve_use_json(config, option.None)
}

pub fn env_mirrored_output_overrides_toml_config_test() {
  let config =
    libero.LiberoConfig(
      use_json: False,
      erlang_output_dir: "src/generated/libero",
      mirrored_output_dir: option.Some("from/toml"),
      type_seeds: [],
    )

  let assert option.Some("from/env") =
    libero.resolve_mirrored_output_dir(config, option.Some("from/env"))
  let assert option.Some("from/toml") =
    libero.resolve_mirrored_output_dir(config, option.None)
}
