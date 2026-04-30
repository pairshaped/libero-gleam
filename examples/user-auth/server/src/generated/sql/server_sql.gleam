import gleam/dynamic/decode
import gleam/option.{type Option}
import sqlight

pub type DeletedRow {
  DeletedRow(id: Int)
}

pub type DeletedSessionRow {
  DeletedSessionRow(token: Option(String))
}

pub type ItemRow {
  ItemRow(id: Int, title: String, completed: Bool)
}

pub type SessionRow {
  SessionRow(token: Option(String), user_id: Int)
}

pub type UserRow {
  UserRow(id: Int, username: String)
}

fn deleted_row_decoder() -> decode.Decoder(DeletedRow) {
  use id <- decode.field(0, decode.int)
  decode.success(DeletedRow(id:))
}

fn deleted_session_row_decoder() -> decode.Decoder(DeletedSessionRow) {
  use token <- decode.field(0, decode.optional(decode.string))
  decode.success(DeletedSessionRow(token:))
}

fn item_row_decoder() -> decode.Decoder(ItemRow) {
  use id <- decode.field(0, decode.int)
  use title <- decode.field(1, decode.string)
  use completed <- decode.field(2, sqlight.decode_bool())
  decode.success(ItemRow(id:, title:, completed:))
}

fn session_row_decoder() -> decode.Decoder(SessionRow) {
  use token <- decode.field(0, decode.optional(decode.string))
  use user_id <- decode.field(1, decode.int)
  decode.success(SessionRow(token:, user_id:))
}

fn user_row_decoder() -> decode.Decoder(UserRow) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  decode.success(UserRow(id:, username:))
}

pub fn create_item(
  db db: sqlight.Connection,
  user_id user_id: Int,
  title title: String,
) -> Result(List(ItemRow), sqlight.Error) {
  sqlight.query(
    "INSERT INTO items (user_id, title, completed) VALUES (@user_id, @title, 0) RETURNING id, title, completed",
    on: db,
    with: [sqlight.int(user_id), sqlight.text(title)],
    expecting: item_row_decoder(),
  )
}

pub fn create_user(
  db db: sqlight.Connection,
  username username: String,
) -> Result(List(UserRow), sqlight.Error) {
  sqlight.query(
    "INSERT INTO users (username) VALUES (@username) RETURNING id, username",
    on: db,
    with: [sqlight.text(username)],
    expecting: user_row_decoder(),
  )
}

pub fn delete_item(
  db db: sqlight.Connection,
  id id: Int,
  user_id user_id: Int,
) -> Result(List(DeletedRow), sqlight.Error) {
  sqlight.query(
    "DELETE FROM items WHERE id = @id AND user_id = @user_id RETURNING id",
    on: db,
    with: [sqlight.int(id), sqlight.int(user_id)],
    expecting: deleted_row_decoder(),
  )
}

pub fn delete_session(
  db db: sqlight.Connection,
  token token: Option(String),
) -> Result(List(DeletedSessionRow), sqlight.Error) {
  sqlight.query(
    "DELETE FROM sessions WHERE token = @token RETURNING token",
    on: db,
    with: [sqlight.nullable(sqlight.text, token)],
    expecting: deleted_session_row_decoder(),
  )
}

pub fn find_session(
  db db: sqlight.Connection,
  token token: Option(String),
) -> Result(List(SessionRow), sqlight.Error) {
  sqlight.query(
    "SELECT token, user_id FROM sessions WHERE token = @token",
    on: db,
    with: [sqlight.nullable(sqlight.text, token)],
    expecting: session_row_decoder(),
  )
}

pub fn find_user_by_id(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(UserRow), sqlight.Error) {
  sqlight.query(
    "SELECT id, username FROM users WHERE id = @id",
    on: db,
    with: [sqlight.int(id)],
    expecting: user_row_decoder(),
  )
}

pub fn find_user_by_username(
  db db: sqlight.Connection,
  username username: String,
) -> Result(List(UserRow), sqlight.Error) {
  sqlight.query(
    "SELECT id, username FROM users WHERE username = @username",
    on: db,
    with: [sqlight.text(username)],
    expecting: user_row_decoder(),
  )
}

pub fn insert_session(
  db db: sqlight.Connection,
  token token: Option(String),
  user_id user_id: Int,
) -> Result(List(SessionRow), sqlight.Error) {
  sqlight.query(
    "INSERT INTO sessions (token, user_id) VALUES (@token, @user_id) RETURNING token, user_id",
    on: db,
    with: [sqlight.nullable(sqlight.text, token), sqlight.int(user_id)],
    expecting: session_row_decoder(),
  )
}

pub fn list_items(
  db db: sqlight.Connection,
  user_id user_id: Int,
) -> Result(List(ItemRow), sqlight.Error) {
  sqlight.query(
    "SELECT id, title, completed FROM items WHERE user_id = @user_id ORDER BY id",
    on: db,
    with: [sqlight.int(user_id)],
    expecting: item_row_decoder(),
  )
}

pub fn toggle_item(
  db db: sqlight.Connection,
  id id: Int,
  user_id user_id: Int,
) -> Result(List(ItemRow), sqlight.Error) {
  sqlight.query(
    "UPDATE items SET completed = NOT completed WHERE id = @id AND user_id = @user_id RETURNING id, title, completed",
    on: db,
    with: [sqlight.int(id), sqlight.int(user_id)],
    expecting: item_row_decoder(),
  )
}
