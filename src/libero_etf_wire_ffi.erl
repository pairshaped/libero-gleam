-module(libero_etf_wire_ffi).
-export([decode_request/1, decode_response_frame/1, decode_push_frame/1]).

%% Decode an ETF binary, validate it's a {Binary, Integer, Value} request envelope,
%% and return a Gleam-shaped Result: {ok, {Name, RequestId, Value}} or
%% {error, {decode_error, Message}}.
%%
%% The wire envelope is {module_name_binary, request_id, payload} -
%% a 3-tuple where the first element is a UTF-8 binary carrying the wire
%% envelope, the second is an integer request ID, and the third is the
%% framework-owned request payload. The request ID lets the client correlate
%% responses to calls.
%%
%% Note: binary_to_term/2 is called with [safe, used] to prevent atom
%% exhaustion attacks and reject trailing bytes. All legitimate constructor
%% atoms must be pre-registered (via binary_to_atom) before the first transport
%% arrives. Libero's codegen generates an libero_atoms module that handles this.
decode_request(Bin) when is_binary(Bin) ->
    try
        Term = decode_binary_term(Bin),
        %% Strict non-executable term validation is opt-in because it
        %% double-walks every legitimate request before generated typed
        %% decoding walks it again.
        ok = libero_etf_ffi:maybe_validate_data_term(Term),
        case Term of
            {Module, RequestId, Value}
                    when is_binary(Module), is_integer(RequestId),
                         RequestId >= 0, RequestId =< 4294967295 ->
                {ok, {Module, RequestId, Value}};
            _ ->
                {error, {decode_error, <<"invalid request envelope: expected {binary, integer, value} tuple">>}}
        end
    catch
        _:_ ->
            {error, {decode_error, <<"invalid ETF binary">>}}
    end;
decode_request(_) ->
    {error, {decode_error, <<"expected a binary (BitArray)">>}}.

decode_binary_term(Bin) ->
    Size = byte_size(Bin),
    case erlang:binary_to_term(Bin, [safe, used]) of
        {Term, Size} ->
            Term;
        {_Term, Used} ->
            error({trailing_bytes, Used, Size})
    end.

%% Decode a response frame: tag byte 0, 32-bit request ID, ETF payload.
%% Routes through libero_etf_ffi:decode_safe so the configured wire module's
%% decode_term transform is applied, reversing the encode_term transform
%% that encode_response applies via libero_etf_ffi:encode.
%% Returns {ok, {RequestId, Value}} or {error, {decode_error, Message}}.
decode_response_frame(Bin) when is_binary(Bin) ->
    try
        <<0, RequestId:32, Payload/binary>> = Bin,
        case libero_etf_ffi:decode_safe(Payload) of
            {ok, Term} -> {ok, {RequestId, Term}};
            {error, _} = E -> E
        end
    catch
        _:_ ->
            {error, {decode_error, <<"invalid response frame">>}}
    end;
decode_response_frame(_) ->
    {error, {decode_error, <<"expected a binary (BitArray)">>}}.

%% Decode a push frame: tag byte 1, ETF payload ({Module, Value} tuple).
%% Routes through libero_etf_ffi:decode_safe for wire-module transform
%% consistency with encode_push. Validates that the module is a binary.
%% Returns {ok, {Module, Value}} or {error, {decode_error, Message}}.
decode_push_frame(Bin) when is_binary(Bin) ->
    try
        <<1, Payload/binary>> = Bin,
        case libero_etf_ffi:decode_safe(Payload) of
            {ok, {Module, Value}} when is_binary(Module) ->
                {ok, {Module, Value}};
            {ok, _} ->
                {error, {decode_error, <<"invalid push frame payload: expected {binary, value} tuple">>}};
            {error, _} = E -> E
        end
    catch
        _:_ ->
            {error, {decode_error, <<"invalid push frame">>}}
    end;
decode_push_frame(_) ->
    {error, {decode_error, <<"expected a binary (BitArray)">>}}.
