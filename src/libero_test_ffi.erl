%% Test-only FFI helpers for libero codegen tests.

-module(libero_test_ffi).
-export([apply2/4]).

apply2(Mod, Fun, Arg1, Arg2) ->
    erlang:apply(Mod, Fun, [Arg1, Arg2]).
