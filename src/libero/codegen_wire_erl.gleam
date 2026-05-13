//// Compatibility wrapper for the old ETF codegen module path.

import libero/etf/codegen_erl
import libero/gen_error.{type GenError}
import libero/scanner
import libero/walker.{type DiscoveredType}

pub type PushDispatch =
  codegen_erl.PushDispatch

pub fn generate(
  module_name module_name: String,
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(scanner.HandlerEndpoint),
  push_dispatches push_dispatches: List(PushDispatch),
) -> Result(String, GenError) {
  codegen_erl.generate(module_name:, discovered:, endpoints:, push_dispatches:)
}
