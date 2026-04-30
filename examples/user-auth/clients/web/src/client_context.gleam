import gleam/option.{type Option}
import shared/types.{type User}

/// Auth state that survives client-side page navigations via modem.
/// Hydrated from SSR flags on full-page loads, then updated via its
/// own update function as the user signs in/out.
///
/// On a full-page reload the server has no session to restore, so SSR
/// always renders the signed-out state. Client-side navigations preserve
/// auth through the Lustre runtime.
///
/// Pattern: define Model, Msg, init, and update in a self-contained
/// module. The main app delegates auth state transitions to
/// client_context.update rather than inlining them. As the app grows,
/// more cross-page state (theme, notifications, etc.) can live here.

pub type Model {
  Model(session_user: Option(User))
}

pub type Msg {
  SignIn(user: User)
  SignOut
}

pub fn init() -> Model {
  Model(session_user: option.None)
}

pub fn init_from_ssr(user: Option(User)) -> Model {
  Model(session_user: user)
}

pub fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SignIn(user:) -> Model(session_user: option.Some(user))
    SignOut -> Model(session_user: option.None)
  }
}
