import gleam/option.{type Option}
import sqlight
import shared/types.{type User}

pub type HandlerContext {
  HandlerContext(db: sqlight.Connection, session_user: Option(User))
}

pub fn new(db db: sqlight.Connection) -> HandlerContext {
  HandlerContext(db:, session_user: option.None)
}
