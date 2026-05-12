%% ETF runtime FFI for Libero.

-module(libero_etf_ffi).
-export([encode/1, decode/1, decode_safe/1, decode_typed/2,
         identity/1, ensure_decoders/0]).

identity(X) -> X.

encode(Term) ->
    Term2 = case persistent_term:get({libero, wire_module}, undefined) of
        undefined -> Term;
        Mod -> Mod:encode_term(Term)
    end,
    erlang:term_to_binary(Term2).

decode(Bin) ->
    apply_decode_term(erlang:binary_to_term(Bin, [safe])).

decode_safe(Bin) ->
    try apply_decode_term(erlang:binary_to_term(Bin, [safe])) of
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

apply_decode_term(Term) ->
    case persistent_term:get({libero, wire_module}, undefined) of
        undefined -> Term;
        Mod -> Mod:decode_term(Term)
    end.

ensure_decoders() ->
    true.
