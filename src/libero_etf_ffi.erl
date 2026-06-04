%% ETF runtime FFI for Libero.

-module(libero_etf_ffi).
-export([encode/1, decode/1, decode_safe/1, decode_typed/2,
         identity/1, ensure_decoders/0, validate_data_term/1,
         validate_data_term_fast/1, maybe_validate_data_term/1,
         set_strict_data_terms/1, strict_data_terms_enabled/0,
         set_js_term_depth_limit/1, js_term_depth_limit/0]).

-define(STRICT_DATA_TERMS_KEY, {libero, etf_strict_data_terms}).

identity(X) -> X.

encode(Term) ->
    Term2 = case persistent_term:get({libero, wire_module}, undefined) of
        undefined -> Term;
        Mod -> Mod:encode_term(Term)
    end,
    erlang:term_to_binary(Term2).

decode(Bin) ->
    apply_decode_term(decode_binary_term(Bin)).

decode_safe(Bin) ->
    try
        Term = decode_binary_term(Bin),
        ok = maybe_validate_data_term(Term),
        apply_decode_term(Term)
    of
        Decoded -> {ok, Decoded}
    catch
        _:Reason ->
            Msg = erlang:iolist_to_binary(
                io_lib:format("~p", [Reason])
            ),
            {error, {decode_error, Msg}}
    end.

decode_typed(Bin, _DecoderName) ->
    decode_safe(Bin).

set_strict_data_terms(Enabled) when is_boolean(Enabled) ->
    persistent_term:put(?STRICT_DATA_TERMS_KEY, Enabled),
    nil.

strict_data_terms_enabled() ->
    persistent_term:get(?STRICT_DATA_TERMS_KEY, false).

maybe_validate_data_term(Term) ->
    case strict_data_terms_enabled() of
        true -> validate_data_term_fast(Term);
        false -> ok
    end.

set_js_term_depth_limit(_Limit) ->
    nil.

js_term_depth_limit() ->
    0.

decode_binary_term(Bin) ->
    Size = byte_size(Bin),
    case erlang:binary_to_term(Bin, [safe, used]) of
        {Term, Size} ->
            Term;
        {_Term, Used} ->
            error({trailing_bytes, Used, Size})
    end.

apply_decode_term(Term) ->
    case persistent_term:get({libero, wire_module}, undefined) of
        undefined -> Term;
        Mod -> Mod:decode_term(Term)
    end.

validate_data_term(Term) ->
    validate_data_term(Term, <<"$">>, 0).

validate_data_term_fast(Term)
        when is_integer(Term); is_float(Term); is_atom(Term); is_bitstring(Term) ->
    ok;
validate_data_term_fast(Term) when is_pid(Term) ->
    error({non_executable_term, pid});
validate_data_term_fast(Term) when is_reference(Term) ->
    error({non_executable_term, reference});
validate_data_term_fast(Term) when is_port(Term) ->
    error({non_executable_term, port});
validate_data_term_fast(Term) when is_function(Term) ->
    error({non_executable_term, function});
validate_data_term_fast(Term) when is_tuple(Term) ->
    validate_tuple_fast(Term, 1, tuple_size(Term));
validate_data_term_fast(Term) when is_list(Term) ->
    validate_list_fast(Term);
validate_data_term_fast(Term) when is_map(Term) ->
    maps:fold(
        fun(K, V, ok) ->
            ok = validate_data_term_fast(K),
            validate_data_term_fast(V)
        end,
        ok,
        Term
    );
validate_data_term_fast(_Term) ->
    error(unsupported_term).

validate_tuple_fast(_Term, Index, Size) when Index > Size ->
    ok;
validate_tuple_fast(Term, Index, Size) ->
    ok = validate_data_term_fast(element(Index, Term)),
    validate_tuple_fast(Term, Index + 1, Size).

validate_list_fast([]) ->
    ok;
validate_list_fast([Head | Tail]) ->
    ok = validate_data_term_fast(Head),
    validate_list_fast(Tail);
validate_list_fast(Tail) ->
    validate_data_term_fast(Tail).

validate_data_term(Term, _Path, _Depth)
        when is_integer(Term); is_float(Term); is_atom(Term); is_bitstring(Term) ->
    ok;
validate_data_term(Term, Path, _Depth) when is_pid(Term) ->
    error({non_executable_term, pid, Path});
validate_data_term(Term, Path, _Depth) when is_reference(Term) ->
    error({non_executable_term, reference, Path});
validate_data_term(Term, Path, _Depth) when is_port(Term) ->
    error({non_executable_term, port, Path});
validate_data_term(Term, Path, _Depth) when is_function(Term) ->
    error({non_executable_term, function, Path});
validate_data_term(Term, Path, Depth) when is_tuple(Term) ->
    validate_tuple(Term, Path, Depth, 1, tuple_size(Term));
validate_data_term(Term, Path, Depth) when is_list(Term) ->
    validate_list(Term, Path, Depth, 0);
validate_data_term(Term, Path, Depth) when is_map(Term) ->
    maps:fold(
        fun(K, V, ok) ->
            KeyPath = path_segment(Path, <<"{}key">>),
            ValuePath = path_segment(Path, <<"{}value">>),
            ok = validate_data_term(K, KeyPath, Depth + 1),
            validate_data_term(V, ValuePath, Depth + 1)
        end,
        ok,
        Term
    );
validate_data_term(_Term, Path, _Depth) ->
    error({unsupported_term, Path}).

validate_tuple(_Term, _Path, _Depth, Index, Size) when Index > Size ->
    ok;
validate_tuple(Term, Path, Depth, Index, Size) ->
    ok = validate_data_term(element(Index, Term), path_index(Path, Index), Depth + 1),
    validate_tuple(Term, Path, Depth, Index + 1, Size).

validate_list([], _Path, _Depth, _Index) ->
    ok;
validate_list([Head | Tail], Path, Depth, Index) ->
    ok = validate_data_term(Head, path_index(Path, Index), Depth + 1),
    validate_list(Tail, Path, Depth, Index + 1);
validate_list(Tail, Path, Depth, Index) ->
    TailPath = path_segment(path_index(Path, Index), <<"tail">>),
    validate_data_term(Tail, TailPath, Depth + 1).

path_index(Path, Index) ->
    iolist_to_binary([Path, <<"[">>, integer_to_binary(Index), <<"]">>]).

path_segment(Path, Segment) ->
    iolist_to_binary([Path, <<".">>, Segment]).

ensure_decoders() ->
    true.
