import birdie
import gleam/option
import gleam/string
import libero/codegen_decoders
import libero/field_type
import libero/scanner
import libero/walker

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
          fields: [],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/line_item",
          variant_name: "Paid",
          atom_name: "paid",
          float_field_indices: [],
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
          fields: [field_type.StringField],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/notification",
          variant_name: "Disconnected",
          atom_name: "disconnected",
          float_field_indices: [],
          fields: [],
        ),
        walker.DiscoveredVariant(
          module_path: "shared/notification",
          variant_name: "Refreshed",
          atom_name: "refreshed",
          float_field_indices: [],
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
      msg_type_name: option.None,
    ),
  ]

  let js =
    codegen_decoders.generate_decoders_ffi(
      discovered: types,
      endpoints: endpoints,
      relpath_prefix: "../../../",
    )

  let assert True = string.contains(js, "registerFieldTypes(\"measurements\"")
  let assert True =
    string.contains(js, "{ kind: \"list\", element: \"float\" }")
  let assert True =
    string.contains(js, "registerFieldTypes(\"server_record_measurements\"")
  let assert True =
    string.contains(js, "{ kind: \"tuple\", elements: [null, \"float\"] }")
}
