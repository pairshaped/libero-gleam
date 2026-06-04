-module(bench_time_ffi).
-export([now_ns/0]).

now_ns() ->
    erlang:monotonic_time(nanosecond).
