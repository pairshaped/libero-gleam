import libero/gen_error
import libero/scanner
import simplifile

const fixture_root = "build/.test_scanner"

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
