import gleam/option.{type Option}
import shared/types.{type User}

pub type Model {
  Model(session_user: Option(User), session_token: Option(String))
}

pub type Msg {
  SignIn(user: User, token: String)
  SignOut
}

pub fn init() -> Model {
  Model(session_user: option.None, session_token: option.None)
}

pub fn init_from_ssr(user: Option(User)) -> Model {
  Model(session_user: user, session_token: option.None)
}

pub fn update(model: Model, msg: Msg) -> Model {
  case msg {
    SignIn(user:, token:) ->
      Model(session_user: option.Some(user), session_token: option.Some(token))
    SignOut -> Model(session_user: option.None, session_token: option.None)
  }
}
