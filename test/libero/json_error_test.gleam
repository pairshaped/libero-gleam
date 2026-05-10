import gleeunit/should
import libero/json/error

pub fn json_error_at_test() {
  let e = error.at("fields.slug", "expected String, got Null")
  e.path |> should.equal("fields.slug")
  e.message |> should.equal("expected String, got Null")
}

pub fn json_error_to_frame_test() {
  let errors = [
    error.at("fields.slug", "expected String, got Null"),
    error.at("fields.title", "expected String, got Int"),
  ]
  let frame_errors = error.to_frame_errors(errors)
  frame_errors
  |> should.equal([
    #("fields.slug", "expected String, got Null"),
    #("fields.title", "expected String, got Int"),
  ])
}

pub fn json_error_prefix_test() {
  let errors = [
    error.at("slug", "expected String"),
    error.at("title", "expected String"),
  ]
  let prefixed = error.prefix(errors, "fields")
  prefixed
  |> should.equal([
    error.at("fields.slug", "expected String"),
    error.at("fields.title", "expected String"),
  ])
}
