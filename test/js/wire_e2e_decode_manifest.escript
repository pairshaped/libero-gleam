%% Generates the base64-encoded ETF decode manifest consumed by
%% wire_e2e_decode_test.mjs. Each entry maps a case name to a
%% base64-encoded response term of shape {ok, {ok, Value}} that the
%% JS decoder will unpack.
%%
%% Called from wire_e2e_setup.sh with libero ebins on the path:
%%   erl -noshell -pa <ebin_dirs> -eval "$(cat decode_manifest.erl)" > manifest.json
%%
%% User-type values are in wire-shape (hashed atoms) via the generated
%% wire transformers, matching what the dispatch handler would send.

generated@rpc_atoms:ensure(),

%% Wire transformer aliases for user types
EncItem = fun(V) -> 'generated@rpc_wire':encode_shared_types__item(V) end,
EncStatus = fun(V) -> 'generated@rpc_wire':encode_shared_types__status(V) end,
EncTree = fun(V) -> 'generated@rpc_wire':encode_shared_types__tree(V) end,
EncItemError = fun(V) -> 'generated@rpc_wire':encode_shared_types__item_error(V) end,
EncWithFloats = fun(V) -> 'generated@rpc_wire':encode_shared_types__with_floats(V) end,
EncNested = fun(V) -> 'generated@rpc_wire':encode_shared_types__nested_record(V) end,
EncItemListData = fun(V) -> 'generated@rpc_wire':encode_shared_types__item_list_data(V) end,
EncItemSummaryData = fun(V) -> 'generated@rpc_wire':encode_shared_types__item_summary_data(V) end,
EncFormPrefill = fun(V) -> 'generated@rpc_wire':encode_shared_types__form_prefill(V) end,
EncNestedEnvelope = fun(V) -> 'generated@rpc_wire':encode_shared_types__nested_envelope(V) end,
EncDictAndList = fun(V) -> 'generated@rpc_wire':encode_shared_types__dict_and_list_envelope(V) end,

Encode = fun(Term) -> binary_to_list(base64:encode(libero_ffi:encode(Term))) end,

Item = {item, 7, <<"wrench">>, 12.5, true},
Item2 = {item, 8, <<"bolt">>, 1.25, false},
DeepLeftTree = {node, 1, {node, 2, {node, 3, leaf, leaf}, leaf}, leaf},
DeepTree = {node, 1, {node, 2, leaf, leaf}, {node, 3, leaf, {node, 4, leaf, leaf}}},
Nested = {nested_record, [Item, Item2], {some, Item}, [pending, active, cancelled], #{<<"one">> => Item, <<"two">> => Item2}},
%% v3-style envelope shapes
ItemListData = {item_list_data, [Item, Item2]},
ItemListEmpty = {item_list_data, []},
ItemSummary = {item_summary_data, [Item, Item2], 100, 1},
FormPrefillSome = {form_prefill, {some, Item}, active},
FormPrefillNone = {form_prefill, none, pending},
NestedEnv = {nested_envelope, ItemListData, {some, <<"hello">>}},
NestedEnvNone = {nested_envelope, ItemListEmpty, none},
DictAndList = {dict_and_list_envelope, #{<<"a">> => Item, <<"b">> => Item2}, [Item, Item2]},

Cases = [
  {"echo_int/positive", {ok, {ok, 5}}},
  {"echo_int/zero", {ok, {ok, 0}}},
  {"echo_int/negative", {ok, {ok, -7}}},
  {"echo_float/fractional", {ok, {ok, 3.5}}},
  {"echo_float/negative", {ok, {ok, -1.5}}},
  {"echo_float/whole", {ok, {ok, 2.0}}},
  {"echo_string/ascii", {ok, {ok, <<"hello">>}}},
  {"echo_string/empty", {ok, {ok, <<>>}}},
  {"echo_string/null_byte", {ok, {ok, <<97, 0, 98>>}}},
  {"echo_string/utf8_cafe", {ok, {ok, <<"caf", 195, 169>>}}},
  {"echo_string/cjk", {ok, {ok, unicode:characters_to_binary([28450, 23383])}}},
  {"echo_bool/true", {ok, {ok, true}}},
  {"echo_bool/false", {ok, {ok, false}}},
  {"echo_bit_array/bytes", {ok, {ok, <<1, 2, 3>>}}},
  {"echo_bit_array/empty", {ok, {ok, <<>>}}},
  {"echo_bit_array/single", {ok, {ok, <<255>>}}},
  {"echo_unit/nil", {ok, {ok, nil}}},
  {"echo_list_int/many", {ok, {ok, [1, 2, 3]}}},
  {"echo_list_int/empty", {ok, {ok, []}}},
  {"echo_list_int/single", {ok, {ok, [42]}}},
  {"echo_option_string/some", {ok, {ok, {some, <<"hello">>}}}},
  {"echo_option_string/none", {ok, {ok, none}}},
  {"echo_result_int_string/ok", {ok, {ok, {ok, 7}}}},
  {"echo_result_int_string/error", {ok, {ok, {error, <<"bad">>}}}},
  {"echo_dict_string_int/pairs", {ok, {ok, #{<<"one">> => 1, <<"two">> => 2}}}},
  {"echo_dict_string_int/empty", {ok, {ok, #{}}}},
  {"echo_tuple_int_string/pair", {ok, {ok, {9, <<"nine">>}}}},
  {"echo_status/active", {ok, {ok, EncStatus(active)}}},
  {"echo_status/pending", {ok, {ok, EncStatus(pending)}}},
  {"echo_status/cancelled", {ok, {ok, EncStatus(cancelled)}}},
  {"echo_item/basic", {ok, {ok, EncItem(Item)}}},
  {"echo_tree/leaf", {ok, {ok, EncTree(leaf)}}},
  {"echo_tree/deep", {ok, {ok, EncTree(DeepTree)}}},
  {"echo_tree/deep_left", {ok, {ok, EncTree(DeepLeftTree)}}},
  {"echo_item_error/not_found", {ok, {ok, EncItemError(not_found)}}},
  {"echo_item_error/validation_failed", {ok, {ok, EncItemError({validation_failed, <<"name">>, <<"required">>})}}},
  {"echo_with_floats/whole", {ok, {ok, EncWithFloats({with_floats, 2.0, 3.0, <<"whole">>})}}},
  {"echo_list_of_items/many", {ok, {ok, [EncItem(Item), EncItem(Item2)]}}},
  {"echo_option_item/some", {ok, {ok, {some, EncItem(Item)}}}},
  {"echo_option_item/none", {ok, {ok, none}}},
  {"echo_dict_string_item/pairs", {ok, {ok, #{<<"one">> => EncItem(Item), <<"two">> => EncItem(Item2)}}}},
  {"echo_dict_string_item/empty", {ok, {ok, #{}}}},
  {"echo_nested_record/basic", {ok, {ok, EncNested(Nested)}}},
  {"echo_typed_err/validation_failed", {ok, {error, EncItemError({validation_failed, <<"name">>, <<"required">>})}}},
  %% v3-style envelope coverage
  {"echo_item_list_data/basic", {ok, {ok, EncItemListData(ItemListData)}}},
  {"echo_item_list_data/empty", {ok, {ok, EncItemListData(ItemListEmpty)}}},
  {"echo_item_summary_data/basic", {ok, {ok, EncItemSummaryData(ItemSummary)}}},
  {"echo_form_prefill/with_item", {ok, {ok, EncFormPrefill(FormPrefillSome)}}},
  {"echo_form_prefill/without_item", {ok, {ok, EncFormPrefill(FormPrefillNone)}}},
  {"echo_nested_envelope/with_message", {ok, {ok, EncNestedEnvelope(NestedEnv)}}},
  {"echo_nested_envelope/no_message", {ok, {ok, EncNestedEnvelope(NestedEnvNone)}}},
  {"echo_dict_and_list_envelope/basic", {ok, {ok, EncDictAndList(DictAndList)}}}
],

Print = fun
  Print([], _) -> ok;
  Print([{Name, Term}], Prefix) ->
    io:format("~s\"~s\": \"~s\"~n", [Prefix, Name, Encode(Term)]);
  Print([{Name, Term} | Rest], Prefix) ->
    io:format("~s\"~s\": \"~s\",~n", [Prefix, Name, Encode(Term)]),
    Print(Rest, Prefix)
end,

io:format("{~n"),
Print(Cases, "  "),
io:format("}~n"),
halt().
