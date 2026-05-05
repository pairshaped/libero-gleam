%% Libero RPC panic-catching FFI.
%%
%% try_call(F) runs the zero-arg function F and returns {ok, Result}
%% on success, or {error, ReasonBinary} if the function panics or
%% throws. The reason is stringified so the caller can log it
%% alongside a trace_id without pattern-matching on arbitrary
%% Erlang term shapes.

-module(libero_ffi).
-export([try_call/1, encode/1, decode/1, decode_safe/1, identity/1, unique_id/0,
         run_executable_capturing/2, find_executable/1, get_env/1]).

identity(X) -> X.

encode(Term) ->
    erlang:term_to_binary(Term).

decode(Bin) ->
    erlang:binary_to_term(Bin, [safe]).

decode_safe(Bin) ->
    try erlang:binary_to_term(Bin, [safe]) of
        Term -> {ok, Term}
    catch
        _:Reason ->
            Msg = erlang:iolist_to_binary(
                io_lib:format("~p", [Reason])
            ),
            {error, {decode_error, Msg}}
    end.

try_call(F) ->
    try F() of
        Result -> {ok, Result}
    catch
        Class:Reason:Stacktrace ->
            Message = io_lib:format(
                "~p: ~p~nstacktrace: ~p",
                [Class, Reason, Stacktrace]
            ),
            {error, erlang:iolist_to_binary(Message)}
    end.

%% Return a short unique hex string for trace IDs and temp file names.
unique_id() ->
    Int = erlang:unique_integer([positive, monotonic]),
    Time = erlang:system_time(millisecond),
    erlang:iolist_to_binary(io_lib:format("~.16b-~.16b", [Time, Int])).

run_executable_capturing(Path, Args) ->
    Port = erlang:open_port(
        {spawn_executable, unicode:characters_to_list(Path)},
        [{args, [unicode:characters_to_list(A) || A <- Args]},
         exit_status, stderr_to_stdout, binary]
    ),
    wait_for_port_capturing(Port, []).

wait_for_port_capturing(Port, Acc) ->
    receive
        {Port, {exit_status, Status}} ->
            Output = iolist_to_binary(lists:reverse(Acc)),
            {Status, Output};
        {Port, {data, Data}} ->
            wait_for_port_capturing(Port, [Data | Acc])
    end.

find_executable(Name) ->
    case os:find_executable(unicode:characters_to_list(Name)) of
        false -> none;
        Path -> {some, unicode:characters_to_binary(Path)}
    end.

get_env(Name) ->
    case os:getenv(unicode:characters_to_list(Name)) of
        false -> none;
        Value -> {some, unicode:characters_to_binary(Value)}
    end.
