import gleam/option.{type Option}
import shared/types.{type User}
import sqlight

pub type HandlerContext {
  HandlerContext(db: sqlight.Connection, session_user: Option(User))
}

pub fn new(db db: sqlight.Connection) -> HandlerContext {
  HandlerContext(db:, session_user: option.None)
}
