import gleam/option
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
