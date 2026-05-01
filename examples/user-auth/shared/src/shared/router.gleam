import gleam/uri.{type Uri}

pub type Route {
  Home
  SignIn
  SignUp
}

pub fn parse_route(uri: Uri) -> Result(Route, Nil) {
  case uri.path_segments(uri.path) {
    [] -> Ok(Home)
    ["sign-in"] -> Ok(SignIn)
    ["sign-up"] -> Ok(SignUp)
    _ -> Error(Nil)
  }
}

pub fn route_to_path(route: Route) -> String {
  case route {
    Home -> "/"
    SignIn -> "/sign-in"
    SignUp -> "/sign-up"
  }
}
