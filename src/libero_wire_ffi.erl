%% Compatibility wrapper for the old ETF wire FFI module name.

-module(libero_wire_ffi).
-export([decode_request/1, variant_tag/1, decode_response_frame/1, decode_push_frame/1]).

decode_request(Bin) ->
    libero_etf_wire_ffi:decode_request(Bin).

variant_tag(Value) ->
    libero_etf_wire_ffi:variant_tag(Value).

decode_response_frame(Bin) ->
    libero_etf_wire_ffi:decode_response_frame(Bin).

decode_push_frame(Bin) ->
    libero_etf_wire_ffi:decode_push_frame(Bin).
