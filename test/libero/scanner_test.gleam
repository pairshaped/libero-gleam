import gleam/list
import gleam/option
import libero/field_type
import libero/gen_error
import libero/scanner
import simplifile

const fixture_root = "build/.test_scanner"

pub fn exclude_param_types_strips_identity_and_restores_msg_type_test() {
  let root = fixture_root <> "/exclude_params"
  let src = root <> "/src"
  let pages_dir = src <> "/pages"
  let assert Ok(Nil) = simplifile.create_directory_all(pages_dir)

  let assert Ok(Nil) =
    simplifile.write(
      src <> "/auth.gleam",
      "pub type Identity { Admin Unauthenticated }
",
    )

  let assert Ok(Nil) =
    simplifile.write(
      pages_dir <> "/dashboard.gleam",
      "import auth.{type Identity}

pub type Ctx { Ctx }
pub type ServerLoadData { ServerLoadData(year: Int) }

pub fn server_load_data(
  msg msg: ServerLoadData,
  ctx ctx: Ctx,
  identity _identity: Identity,
) -> Result(Int, String) {
  Ok(msg.year)
}
",
    )

  // Without exclusion: identity stays in params, msg_type is None
  let assert Ok(endpoints_raw) =
    scanner.scan(src_dir: src, context_type_name: "Ctx")
  let assert [ep_raw] = endpoints_raw
  let assert True = option.is_none(ep_raw.msg_type)
  let assert True = list.any(ep_raw.params, fn(p) { p.0 == "identity" })

  // With exclusion: identity stripped, msg_type resolves
  let assert Ok(endpoints) =
    scanner.scan_excluding(
      src_dir: src,
      context_type_name: "Ctx",
      exclude_param_types: [#("auth", "Identity")],
    )
  let assert [ep] = endpoints
  let assert option.Some(#("pages/dashboard", "ServerLoadData")) = ep.msg_type
  let assert False = list.any(ep.params, fn(p) { p.0 == "identity" })
  let assert [#("year", field_type.IntField)] = ep.params

  let assert Ok(Nil) = simplifile.delete_all([root])
}

pub fn exclude_param_types_does_not_strip_unmatched_params_test() {
  let root = fixture_root <> "/exclude_no_match"
  let src = root <> "/src"
  let assert Ok(Nil) = simplifile.create_directory_all(src)

  let assert Ok(Nil) =
    simplifile.write(
      src <> "/page.gleam",
      "pub type Ctx { Ctx }

pub fn server_greet(name name: String, ctx ctx: Ctx) -> Result(String, String) {
  Ok(name)
}
",
    )

  let assert Ok(endpoints) =
    scanner.scan_excluding(
      src_dir: src,
      context_type_name: "Ctx",
      exclude_param_types: [#("some/module", "SomeType")],
    )
  let assert [ep] = endpoints
  let assert [#("name", field_type.StringField)] = ep.params

  let assert Ok(Nil) = simplifile.delete_all([root])
}

pub fn unparseable_file_fails_entire_scan_test() {
  let dir = fixture_root <> "/unparseable/src/server"
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  let assert Ok(Nil) =
    simplifile.write(
      dir <> "/valid.gleam",
      "import gleam/option.{type Option}

pub type Ctx {
  Ctx
}

pub fn get_items(ctx: Ctx) -> Option(Int) {
  option.None
}
",
    )
  let assert Ok(Nil) =
    simplifile.write(dir <> "/broken.gleam", "pub fn oops( {")

  let assert Error(errors) =
    scanner.scan(src_dir: dir, context_type_name: "Ctx")
  let assert True = case errors {
    [gen_error.ParseFailed(path: p, ..)] -> p == dir <> "/broken.gleam"
    _ -> False
  }

  let assert Ok(Nil) = simplifile.delete_all([fixture_root <> "/unparseable"])
}
