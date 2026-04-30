//// Client-side SSR flag decoder.
////
//// Provides `decode_flags` for Lustre `init` functions without pulling
//// in the server-side dependencies (mist, gramps, gleam_crypto) that
//// `libero/ssr` needs for `handle_request` and `boot_script`.

import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/result
import libero/wire

pub type SsrDecodeError {
  BadFlags
}

/// Decode flags from a Dynamic value (base64 ETF string).
/// Use this in a Lustre init function to decode server-embedded flags.
pub fn decode_flags(flags: Dynamic) -> Result(a, SsrDecodeError) {
  case decode.run(flags, decode.string) {
    Error(_) -> Error(BadFlags)
    Ok(encoded) ->
      bit_array.base64_decode(encoded)
      |> result.replace_error(BadFlags)
      |> result.try(fn(bytes) {
        wire.decode_safe(bytes)
        |> result.replace_error(BadFlags)
      })
  }
}
