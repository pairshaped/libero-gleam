import birdie
import gleam/option
import gleam/string
import libero/codegen_decoders
import libero/field_type
import libero/scanner
import libero/walker
import libero/wire_identity

fn sample_status_enum() -> List(walker.DiscoveredType) {
  [
    walker.DiscoveredType(
      module_path: "shared/line_item",
      type_name: "Status",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/line_item",
          variant_name: "Pending",
          atom_name: "pending",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/line_item",
          variant_name: "Paid",
          atom_name: "paid",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
  ]
}

fn sample_record_type() -> List(walker.DiscoveredType) {
  [
    walker.DiscoveredType(
      module_path: "shared/item",
      type_name: "Item",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/item",
          variant_name: "Item",
          atom_name: "item",
          float_field_indices: [],
          field_labels: [option.None, option.None, option.None],
          fields: [
            field_type.StringField,
            field_type.IntField,
            field_type.BoolField,
          ],
        ),
      ],
    ),
  ]
}

fn sample_notification_type() -> List(walker.DiscoveredType) {
  [
    walker.DiscoveredType(
      module_path: "shared/notification",
      type_name: "Notification",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/notification",
          variant_name: "ItemsLoaded",
          atom_name: "items_loaded",
          float_field_indices: [],
          field_labels: [option.None],
          fields: [
            field_type.ListOf(
              field_type.UserType(
                module_path: "shared/item",
                type_name: "Item",
                args: [],
              ),
            ),
          ],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/notification",
          variant_name: "StatusChanged",
          atom_name: "status_changed",
          float_field_indices: [],
          field_labels: [option.None],
          fields: [field_type.StringField],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/notification",
          variant_name: "Disconnected",
          atom_name: "disconnected",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/notification",
          variant_name: "Refreshed",
          atom_name: "refreshed",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
  ]
}

pub fn enum_snapshot_test() {
  let js = codegen_decoders.emit_typed_decoders(sample_status_enum())
  birdie.snap(js, title: "enum typed decoder")
}

pub fn record_snapshot_test() {
  let js = codegen_decoders.emit_typed_decoders(sample_record_type())
  birdie.snap(js, title: "record typed decoder")
}

pub fn tagged_union_snapshot_test() {
  let js = codegen_decoders.emit_typed_decoders(sample_notification_type())
  birdie.snap(js, title: "tagged union typed decoder")
}

pub fn result_field_snapshot_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/result_type",
      type_name: "Wrapper",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/result_type",
          variant_name: "Wrapper",
          atom_name: "wrapper",
          float_field_indices: [],
          field_labels: [option.None],
          fields: [
            field_type.ResultOf(
              ok: field_type.StringField,
              err: field_type.IntField,
            ),
          ],
        ),
      ],
    ),
  ]
  let js = codegen_decoders.emit_typed_decoders(types)
  birdie.snap(js, title: "result field typed decoder")
}

pub fn option_field_snapshot_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/opt_type",
      type_name: "OptWrapper",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/opt_type",
          variant_name: "OptWrapper",
          atom_name: "opt_wrapper",
          float_field_indices: [],
          field_labels: [option.None],
          fields: [field_type.OptionOf(field_type.StringField)],
        ),
      ],
    ),
  ]
  let js = codegen_decoders.emit_typed_decoders(types)
  birdie.snap(js, title: "option field typed decoder")
}

pub fn dict_and_tuple_field_snapshot_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/compound",
      type_name: "Compound",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/compound",
          variant_name: "Compound",
          atom_name: "compound",
          float_field_indices: [],
          field_labels: [option.None, option.None],
          fields: [
            field_type.DictOf(
              key: field_type.StringField,
              value: field_type.IntField,
            ),
            field_type.TupleOf([field_type.StringField, field_type.BoolField]),
          ],
        ),
      ],
    ),
  ]
  let js = codegen_decoders.emit_typed_decoders(types)
  birdie.snap(js, title: "dict tuple field typed decoder")
}

pub fn qualified_atoms_prevent_collision_in_registry_test() {
  // Two types in different modules with the same variant name must
  // produce different atom names so the atom→decoder reverse mapping
  // doesn't collide.
  let types = [
    walker.DiscoveredType(
      module_path: "pages/discounts",
      type_name: "Discount",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "pages/discounts",
          variant_name: "Discount",
          atom_name: "pages_discounts__discount",
          float_field_indices: [],
          field_labels: [option.None],
          fields: [field_type.IntField],
        ),
      ],
    ),
    walker.DiscoveredType(
      module_path: "pages/admin_discounts",
      type_name: "Discount",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "pages/admin_discounts",
          variant_name: "Discount",
          atom_name: "pages_admin_discounts__discount",
          float_field_indices: [],
          field_labels: [option.None, option.None],
          fields: [field_type.IntField, field_type.StringField],
        ),
      ],
    ),
  ]
  let js = codegen_decoders.emit_typed_decoders(types)

  // Wire identity is hash-based; same-named types in different modules
  // produce distinct hashes (different module_path component of the
  // canonical signature). The test verifies both that the hashes are
  // registered AND that they differ — non-collision is the headline
  // property of the wire-identity work.
  let #(_sig_a, hash_a) =
    wire_identity.wire_identity(
      module_path: "pages/discounts",
      constructor_name: "Discount",
      fields: [field_type.IntField],
    )
  let #(_sig_b, hash_b) =
    wire_identity.wire_identity(
      module_path: "pages/admin_discounts",
      constructor_name: "Discount",
      fields: [field_type.IntField, field_type.StringField],
    )
  let assert True = hash_a != hash_b
  let assert True =
    string.contains(js, "registerAtomDecoder(\"" <> hash_a <> "\"")
  let assert True =
    string.contains(js, "registerAtomDecoder(\"" <> hash_b <> "\"")
  let assert True = string.contains(js, "term[0] !== \"" <> hash_a <> "\"")
  let assert True = string.contains(js, "term[0] !== \"" <> hash_b <> "\"")
}

pub fn decode_typed_dispatch_in_output_test() {
  let js = codegen_decoders.emit_typed_decoders(sample_record_type())

  // Registration calls populate etf/wire_ffi.mjs's atom→decoder reverse
  // mapping so the ETF decoder can reconstruct custom types in non-raw
  // mode. Under the wire-identity scheme the atom is the variant's
  // hash; the decoder function name still embeds the source module +
  // type name for readability.
  let #(_sig, hash) =
    wire_identity.wire_identity(
      module_path: "shared/item",
      constructor_name: "Item",
      fields: [
        field_type.StringField,
        field_type.IntField,
        field_type.BoolField,
      ],
    )
  let assert True =
    string.contains(js, "registerAtomDecoder(\"" <> hash <> "\"")
  let assert True = string.contains(js, "\"decode_shared_item_item\"")
}

pub fn float_type_hint_registration_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/measurements",
      type_name: "Measurements",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/measurements",
          variant_name: "Measurements",
          atom_name: "measurements",
          float_field_indices: [],
          field_labels: [option.None, option.None],
          fields: [
            field_type.ListOf(field_type.FloatField),
            field_type.OptionOf(field_type.FloatField),
          ],
        ),
      ],
    ),
  ]
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "record_measurements",
      return_ok: field_type.NilField,
      return_err: field_type.NilField,
      params: [
        #("values", field_type.ListOf(field_type.FloatField)),
        #(
          "pair",
          field_type.TupleOf([field_type.IntField, field_type.FloatField]),
        ),
      ],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]

  let js =
    codegen_decoders.generate_decoders_ffi(
      discovered: types,
      endpoints: endpoints,
      relpath_prefix: "../../../",
      package: "myapp",
    )

  // Float hints now ride on the variant class as `__fieldTypes`. The
  // encoder reads them off `value.constructor.__fieldTypes` instead
  // of looking up by qualified atom. The structural hint shapes
  // (list/option/tuple wrappers) are unchanged.
  let assert True =
    string.contains(
      js,
      "_m_shared_measurements.Measurements.__fieldTypes = [{ kind: \"list\", element: \"float\" }, { kind: \"option\", inner: \"float\" }];",
    )
  let assert True =
    string.contains(js, "_m_shared_measurements.Measurements.__wireAtom")
  // Endpoint-side field hints (for ClientMsg variants) are not yet
  // wired up under the new scheme; that lands when dispatch codegen
  // gains its own class-statics emission. Endpoint floats still flow
  // through the encoder's hint argument when a typed decoder calls
  // back into the encoder, so user-type fields stay correct.
}

pub fn decoder_codegen_imports_shared_modules_from_shared_package_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/collision",
      type_name: "Tag",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/collision",
          variant_name: "Tag",
          atom_name: "shared_collision__tag",
          float_field_indices: [],
          field_labels: [option.None],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let js =
    codegen_decoders.generate_decoders_ffi(
      discovered: types,
      endpoints: [],
      relpath_prefix: "../../../",
      package: "server",
    )

  let assert True =
    string.contains(js, "from \"../../../shared/shared/collision.mjs\";")
  let assert False =
    string.contains(js, "from \"../../../server/shared/collision.mjs\";")
}
