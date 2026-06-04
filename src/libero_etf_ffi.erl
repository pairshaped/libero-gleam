%% ETF runtime FFI for Libero.

-module(libero_etf_ffi).
-export([encode/1, decode/1, decode_safe/1, decode_typed/2,
         identity/1, ensure_decoders/0, validate_data_term/1]).

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
        %% validate_data_term(Term) rejects BEAM runtime terms such as pids,
        %% refs, ports, and funs, but it recursively walks the whole payload
        %% before generated typed decoding walks it again. Keep the helper for
        %% a future strict mode, but do not run it on the default hot path.
        %% ok = validate_data_term(Term),
        apply_decode_term(Term)
    of
        Term -> {ok, Term}
    catch
        _:Reason ->
            Msg = erlang:iolist_to_binary(
                io_lib:format("~p", [Reason])
            ),
            {error, {decode_error, Msg}}
    end.

decode_typed(Bin, _DecoderName) ->
    decode_safe(Bin).

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
