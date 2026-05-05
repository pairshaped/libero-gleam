//// Libero: RPC plumbing library for Gleam.
////
//// Provides handler scanning, dispatch codegen, ETF wire protocol,
//// and decoder generation. Consumed as a dependency by framework
//// packages (e.g. lando).

import libero/codegen_decoders
import libero/codegen_dispatch
import libero/scanner
import libero/walker

pub const scan = scanner.scan

pub const collect_seeds = scanner.collect_seeds

pub const walk = walker.walk

pub const generate_dispatch = codegen_dispatch.generate

pub const generate_decoders_ffi = codegen_decoders.generate_decoders_ffi

pub const generate_decoders_gleam = codegen_decoders.generate_decoders_gleam
