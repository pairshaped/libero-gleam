import gleam/option
import gleam/string
import libero

pub fn client_output_dir_uses_env_value_test() {
  let assert option.Some("custom/generated/libero") =
    libero.client_output_dir_from_env(option.Some("custom/generated/libero"))
}

pub fn client_output_dir_is_disabled_without_env_test() {
  let assert option.None = libero.client_output_dir_from_env(option.None)
}

pub fn client_output_dir_is_disabled_for_blank_env_test() {
  let assert option.None = libero.client_output_dir_from_env(option.Some("   "))
}

pub fn config_from_toml_defaults_without_libero_table_test() {
  let assert Ok(libero.LiberoConfig(gen_etf: False, client_out_dir: option.None)) =
    libero.config_from_toml("name = \"app\"")
}

pub fn config_from_toml_reads_libero_table_test() {
  let toml =
    "
[tools.libero]
gen_etf = true
client_out_dir = \"../clients/web/src/generated/libero\"
"
  let assert Ok(libero.LiberoConfig(
    gen_etf: True,
    client_out_dir: option.Some("../clients/web/src/generated/libero"),
  )) = libero.config_from_toml(toml)
}

pub fn config_from_toml_trims_blank_client_out_dir_test() {
  let toml =
    "
[tools.libero]
client_out_dir = \"   \"
"
  let assert Ok(libero.LiberoConfig(gen_etf: False, client_out_dir: option.None)) =
    libero.config_from_toml(toml)
}

pub fn config_from_toml_rejects_wrong_gen_etf_type_test() {
  let toml =
    "
[tools.libero]
gen_etf = \"true\"
"
  let assert Error(message) = libero.config_from_toml(toml)
  let assert True = string.contains(message, "tools.libero.gen_etf")
  let assert True = string.contains(message, "Bool")
}

pub fn env_gen_etf_overrides_toml_config_test() {
  let config = libero.LiberoConfig(gen_etf: True, client_out_dir: option.None)
  let assert False = libero.resolve_gen_etf(config, option.Some("0"))
  let assert True = libero.resolve_gen_etf(config, option.None)
}

pub fn env_client_output_overrides_toml_config_test() {
  let config =
    libero.LiberoConfig(
      gen_etf: False,
      client_out_dir: option.Some("from/toml"),
    )

  let assert option.Some("from/env") =
    libero.resolve_client_output_dir(config, option.Some("from/env"))
  let assert option.Some("from/toml") =
    libero.resolve_client_output_dir(config, option.None)
}
