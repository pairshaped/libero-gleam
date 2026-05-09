%% Generates the base64-encoded dispatch manifest consumed by
%% wire_e2e_dispatch_test.mjs. Each entry maps a case name to the
%% base64-encoded response frame produced by generated@libero@dispatch:handle/2.
%%
%% Called from wire_e2e_setup.sh:
%%   erl -noshell -pa <ebin_dirs> -eval "$(cat dispatch_manifest.erl)" > manifest.json
%%
%% User-type values are encoded in wire-shape (hashed atoms) via the
%% generated wire transformers, matching what a JS client would send.

W = fun(F) -> fun(V) -> F(V) end end,
Enc = W(fun 'generated@rpc_wire':encode_shared_types__item/1),
EncStatus = W(fun 'generated@rpc_wire':encode_shared_types__status/1),
EncTree = W(fun 'generated@rpc_wire':encode_shared_types__tree/1),
EncItemError = W(fun 'generated@rpc_wire':encode_shared_types__item_error/1),
EncWithFloats = W(fun 'generated@rpc_wire':encode_shared_types__with_floats/1),
EncNested = W(fun 'generated@rpc_wire':encode_shared_types__nested_record/1),
EncItemListData = W(fun 'generated@rpc_wire':encode_shared_types__item_list_data/1),
EncItemSummaryData = W(fun 'generated@rpc_wire':encode_shared_types__item_summary_data/1),
EncFormPrefill = W(fun 'generated@rpc_wire':encode_shared_types__form_prefill/1),
EncNestedEnvelope = W(fun 'generated@rpc_wire':encode_shared_types__nested_envelope/1),
EncDictAndList = W(fun 'generated@rpc_wire':encode_shared_types__dict_and_list_envelope/1),
EncTypesTag = W(fun 'generated@rpc_wire':encode_shared_types__tag/1),
EncCollisionTag = W(fun 'generated@rpc_wire':encode_shared_collision__tag/1),

EncodeCall = fun(RequestId, Msg) ->
  libero_ffi:encode({<<"rpc">>, RequestId, Msg})
end,
EncodeFrame = fun(Frame) -> binary_to_list(base64:encode(Frame)) end,

State0 = server_context:new(),
Item = {item, 7, <<"wrench">>, 12.5, true},
Item2 = {item, 8, <<"bolt">>, 1.25, false},
DeepTree = {node, 1, {node, 2, leaf, leaf}, {node, 3, leaf, {node, 4, leaf, leaf}}},
Nested = {nested_record, [Item, Item2], {some, Item}, [pending, active, cancelled], #{<<"one">> => Item, <<"two">> => Item2}},

Cases = [
  {"echo_int/positive", 41, {server_echo_int, 5}},
  {"echo_int_negated/positive", 42, {server_echo_int_negated, 5}},
  {"echo_float/fractional", 43, {server_echo_float, 3.5}},
  {"echo_string/utf8_cafe", 44, {server_echo_string, <<"caf", 195, 169>>}},
  {"echo_string/cjk", 45, {server_echo_string, unicode:characters_to_binary([28450, 23383])}},
  {"echo_bool/true", 46, {server_echo_bool, true}},
  {"echo_bit_array/bytes", 47, {server_echo_bit_array, <<1, 2, 3>>}},
  {"echo_unit/nil", 48, server_echo_unit},
  {"echo_list_int/many", 49, {server_echo_list_int, [1, 2, 3]}},
  {"echo_option_string/some", 50, {server_echo_option_string, {some, <<"hello">>}}},
  {"echo_result_int_string/error", 51, {server_echo_result_int_string, {error, <<"bad">>}}},
  {"echo_dict_string_int/pairs", 52, {server_echo_dict_string_int, #{<<"one">> => 1, <<"two">> => 2}}},
  {"echo_tuple_int_string/pair", 53, {server_echo_tuple_int_string, {9, <<"nine">>}}},
  {"echo_status/active", 54, {server_echo_status, EncStatus(active)}},
  {"echo_item/basic", 55, {server_echo_item, Enc(Item)}},
  {"echo_tree/deep", 56, {server_echo_tree, EncTree(DeepTree)}},
  {"echo_item_error/validation_failed", 57, {server_echo_item_error, EncItemError({validation_failed, <<"name">>, <<"required">>})}},
  {"echo_with_floats/whole", 58, {server_echo_with_floats, EncWithFloats({with_floats, 2.0, 3.0, <<"whole">>})}},
  {"echo_list_of_items/many", 59, {server_echo_list_of_items, [Enc(Item), Enc(Item2)]}},
  {"echo_option_item/some", 60, {server_echo_option_item, {some, Enc(Item)}}},
  {"echo_dict_string_item/pairs", 61, {server_echo_dict_string_item, #{<<"one">> => Enc(Item), <<"two">> => Enc(Item2)}}},
  {"echo_nested_record/basic", 62, {server_echo_nested_record, EncNested(Nested)}},
  {"echo_typed_err/validation_failed", 63, {server_echo_typed_err, Enc(Item)}},
  {"echo_item_list_data/basic", 71, {server_echo_item_list_data, EncItemListData({item_list_data, [Item, Item2]})}},
  {"echo_item_summary_data/basic", 72, {server_echo_item_summary_data, EncItemSummaryData({item_summary_data, [Item], 42, 1})}},
  {"echo_form_prefill/basic", 73, {server_echo_form_prefill, EncFormPrefill({form_prefill, {some, Item}, pending})}},
  {"echo_nested_envelope/basic", 74, {server_echo_nested_envelope, EncNestedEnvelope({nested_envelope, {item_list_data, [Item]}, {some, <<"hello">>}})}},
  {"echo_dict_and_list_envelope/basic", 75, {server_echo_dict_and_list_envelope, EncDictAndList({dict_and_list_envelope, #{<<"one">> => Item}, [Item2]})}},
  {"echo_types_tag/basic", 76, {server_echo_types_tag, EncTypesTag({tag, <<"sale">>, <<"red">>})}},
  {"echo_collision_tag/basic", 77, {server_echo_collision_tag, EncCollisionTag({tag, <<"promo">>})}},
  {"dispatch/unknown_module", 64, {<<"other/module">>, 64, {server_echo_int, 5}}},
  {"dispatch/malformed_envelope", 0, malformed},
  {"dispatch/handler_panic", 65, {server_echo_panic, 0}},
  {"dispatch/unknown_variant", 66, {bogus_function, 5}},
  {"dispatch/malformed_known_tag_wrong_arity", 81, server_echo_int}
],

Run = fun
  ({"dispatch/unknown_module", _Id, Envelope}, State) ->
    generated@libero@dispatch:handle(State, libero_ffi:encode(Envelope));
  ({"dispatch/malformed_envelope", _Id, malformed}, State) ->
    generated@libero@dispatch:handle(State, <<131, 104, 1, 97, 1>>);
  ({_Name, Id, Msg}, State) ->
    generated@libero@dispatch:handle(State, EncodeCall(Id, Msg))
end,

{Entries, _StateN} = lists:foldl(fun(Case, {Acc, State}) ->
  {Name, _Id, _Msg} = Case,
  {Resp, NewState} = Run(Case, State),
  {[{Name, Resp} | Acc], NewState}
end, {[], State0}, Cases),

Print = fun
  Print([], _) -> ok;
  Print([{Name, Frame}], Prefix) ->
    io:format("~s\"~s\": \"~s\"~n", [Prefix, Name, EncodeFrame(Frame)]);
  Print([{Name, Frame} | Rest], Prefix) ->
    io:format("~s\"~s\": \"~s\",~n", [Prefix, Name, EncodeFrame(Frame)]),
    Print(Rest, Prefix)
end,

io:format("{~n"),
Print(lists:reverse(Entries), "  "),
io:format("}~n"),
halt().
