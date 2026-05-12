pub type JsonLimits {
  JsonLimits(
    max_input_bytes: Int,
    max_nesting_depth: Int,
    max_string_length: Int,
    max_array_length: Int,
    max_object_entries: Int,
    max_base64_decoded_bytes: Int,
  )
}

/// Conservative defaults. Generated facades use these; callers can override
/// for specific decode paths.
pub fn default_limits() -> JsonLimits {
  JsonLimits(
    max_input_bytes: 1_048_576,
    // 1 MB
    max_nesting_depth: 32,
    max_string_length: 65_536,
    // 64 KB
    max_array_length: 10_000,
    max_object_entries: 1000,
    max_base64_decoded_bytes: 1_048_576,
  )
}
