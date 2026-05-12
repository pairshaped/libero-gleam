-module(libero_etf_wire_ffi).
-export([decode_request/1, decode_call/1, variant_tag/1, decode_response_frame/1, decode_push_frame/1]).

%% Decode an ETF binary, validate it's a {Binary, Integer, Value} request envelope,
%% and return a Gleam-shaped Result: {ok, {Name, RequestId, Value}} or
%% {error, {decode_error, Message}}.
%%
%% The wire envelope is {module_name_binary, request_id, client_msg_value} -
%% a 3-tuple where the first element is a UTF-8 binary carrying the wire
%% envelope, the second is an integer request ID, and the third is the
%% generated ClientMsg value. The request ID lets the client correlate
%% responses to calls.
%%
%% Note: binary_to_term/2 is called with [safe] to prevent atom
%% exhaustion attacks. All legitimate constructor atoms must be pre-
%% registered (via binary_to_atom) before the first RPC arrives.
%% Rally's codegen generates an rpc_atoms module that handles this.
decode_request(Bin) when is_binary(Bin) ->
    try erlang:binary_to_term(Bin, [safe]) of
        {Module, RequestId, Value} when is_binary(Module), is_integer(RequestId) ->
            {ok, {Module, RequestId, Value}};
        _ ->
            {error, {decode_error, <<"invalid request envelope: expected {binary, integer, value} tuple">>}}
    catch
        _:_ ->
            {error, {decode_error, <<"invalid ETF binary">>}}
    end;
decode_request(_) ->
    {error, {decode_error, <<"expected a binary (BitArray)">>}}.

decode_call(Bin) ->
    decode_request(Bin).

%% Extract the variant tag (constructor atom name) from a Gleam variant
%% value as it lands on Erlang. Zero-arg variants are bare atoms; n-arg
%% variants are tagged tuples whose first element is the constructor atom.
%% Used by generated dispatch to detect unrecognized variants before
%% performing the unwitnessed coerce + structural pattern match.
variant_tag(Value) when is_atom(Value) ->
    {ok, atom_to_binary(Value, utf8)};
variant_tag(Value) when is_tuple(Value), tuple_size(Value) >= 1 ->
    Tag = element(1, Value),
    case is_atom(Tag) of
        true -> {ok, atom_to_binary(Tag, utf8)};
        false -> {error, nil}
    end;
variant_tag(_) ->
    {error, nil}.

%% Decode a response frame: tag byte 0, 32-bit request ID, ETF payload.
%% Routes through libero_ffi:decode_safe so the configured wire module's
%% decode_term transform is applied, reversing the encode_term transform
%% that encode_response applies via libero_ffi:encode.
%% Returns {ok, {RequestId, Value}} or {error, {decode_error, Message}}.
decode_response_frame(Bin) when is_binary(Bin) ->
    try
        <<0, RequestId:32, Payload/binary>> = Bin,
        case libero_ffi:decode_safe(Payload) of
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
%% Routes through libero_ffi:decode_safe for wire-module transform
%% consistency with encode_push. Validates that the module is a binary.
%% Returns {ok, {Module, Value}} or {error, {decode_error, Message}}.
decode_push_frame(Bin) when is_binary(Bin) ->
    try
        <<1, Payload/binary>> = Bin,
        case libero_ffi:decode_safe(Payload) of
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
