//// Compatibility wrapper for the old ETF codegen module path.

import gleam/list
import libero/etf/codegen_erl
import libero/gen_error.{type GenError}
import libero/scanner
import libero/walker.{type DiscoveredType}

pub type PushDispatch {
  PushDispatch(page_tag: String, type_atom: String)
}

pub fn generate(
  module_name module_name: String,
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(scanner.HandlerEndpoint),
  push_dispatches push_dispatches: List(PushDispatch),
) -> Result(String, GenError) {
  let push_dispatches =
    list.map(push_dispatches, fn(dispatch) {
      codegen_erl.PushDispatch(
        page_tag: dispatch.page_tag,
        type_atom: dispatch.type_atom,
      )
    })

  codegen_erl.generate(module_name:, discovered:, endpoints:, push_dispatches:)
}
