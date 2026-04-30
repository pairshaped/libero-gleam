import gleam/list
import gleam/option
import gleeunit
import gleeunit/should
import handler
import handler_context
import shared/types.{
  DatabaseError, ItemParams, NotFound, SignInResult, TitleRequired,
  UserAlreadyExists, UserNotFound,
}
import sqlight

pub fn main() {
  gleeunit.main()
}

fn setup_db() {
  let assert Ok(db) = sqlight.open(":memory:")
  let assert Ok(_) =
    sqlight.exec(
      "CREATE TABLE users (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         username TEXT NOT NULL UNIQUE
       );
       CREATE TABLE sessions (
         token TEXT PRIMARY KEY,
         user_id INTEGER NOT NULL REFERENCES users(id),
         created_at TEXT NOT NULL DEFAULT (datetime('now'))
       );
       CREATE TABLE items (
         id INTEGER PRIMARY KEY AUTOINCREMENT,
         user_id INTEGER NOT NULL REFERENCES users(id),
         title TEXT NOT NULL,
         completed BOOLEAN NOT NULL DEFAULT 0
       );",
      on: db,
    )
  db
}

fn sign_up_user(db, username) {
  let ctx = handler_context.new(db:)
  let #(result, new_ctx) = handler.sign_up(username:, handler_ctx: ctx)
  let assert Ok(SignInResult(user:, token: _)) = result
  #(user, new_ctx)
}

pub fn sign_up_creates_user_test() {
  let db = setup_db()
  let ctx = handler_context.new(db:)
  let #(result, _) = handler.sign_up(username: "alice", handler_ctx: ctx)
  case result {
    Ok(SignInResult(user:, token:)) -> {
      should.equal(user.username, "alice")
      should.not_equal(token, "")
    }
    _ -> should.fail()
  }
}

pub fn sign_up_duplicate_username_fails_test() {
  let db = setup_db()
  let ctx = handler_context.new(db:)
  let #(_, ctx2) = handler.sign_up(username: "alice", handler_ctx: ctx)
  let #(result, _) = handler.sign_up(username: "alice", handler_ctx: ctx2)
  case result {
    Error(UserAlreadyExists) -> Nil
    _ -> should.fail()
  }
}

pub fn sign_in_valid_user_succeeds_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "bob")
  let #(_, ctx2) = handler.sign_out(handler_ctx: ctx)
  let #(result, _) = handler.sign_in(username: "bob", handler_ctx: ctx2)
  case result {
    Ok(SignInResult(user:, token:)) -> {
      should.equal(user.username, "bob")
      should.not_equal(token, "")
    }
    _ -> should.fail()
  }
}

pub fn sign_in_unknown_user_fails_test() {
  let db = setup_db()
  let ctx = handler_context.new(db:)
  let #(result, _) = handler.sign_in(username: "nobody", handler_ctx: ctx)
  case result {
    Error(UserNotFound) -> Nil
    _ -> should.fail()
  }
}

pub fn sign_out_clears_session_user_test() {
  let db = setup_db()
  let #(user, ctx) = sign_up_user(db, "alice")
  let assert option.Some(_) = ctx.session_user
  let #(result, ctx2) = handler.sign_out(handler_ctx: ctx)
  case result {
    Ok(Nil) -> should.equal(ctx2.session_user, option.None)
    _ -> should.fail()
  }
}

pub fn me_returns_session_user_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "alice")
  let result = handler.me(handler_ctx: ctx)
  case result {
    Ok(option.Some(u)) -> should.equal(u.username, "alice")
    _ -> should.fail()
  }
}

pub fn create_item_requires_auth_test() {
  let db = setup_db()
  let ctx = handler_context.new(db:)
  let result =
    handler.create_item(params: ItemParams(title: "test"), handler_ctx: ctx)
  case result {
    Error(DatabaseError) -> Nil
    _ -> should.fail()
  }
}

pub fn create_item_with_user_works_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "alice")
  let result =
    handler.create_item(params: ItemParams(title: "Buy milk"), handler_ctx: ctx)
  case result {
    Ok(item) -> {
      should.equal(item.title, "Buy milk")
      should.equal(item.completed, False)
    }
    _ -> should.fail()
  }
}

pub fn create_item_empty_title_fails_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "alice")
  let result =
    handler.create_item(params: ItemParams(title: ""), handler_ctx: ctx)
  case result {
    Error(TitleRequired) -> Nil
    _ -> should.fail()
  }
}

pub fn get_items_returns_only_own_items_test() {
  let db = setup_db()
  let #(_user_a, ctx_a) = sign_up_user(db, "alice")
  let assert Ok(_) =
    handler.create_item(
      params: ItemParams(title: "Alice item"),
      handler_ctx: ctx_a,
    )
  let #(_user_b, ctx_b) = sign_up_user(db, "bob")
  let assert Ok(_) =
    handler.create_item(
      params: ItemParams(title: "Bob item"),
      handler_ctx: ctx_b,
    )
  let result = handler.get_items(handler_ctx: ctx_a)
  case result {
    Ok(items) -> should.equal(list.length(items), 1)
    _ -> should.fail()
  }
}

pub fn toggle_item_works_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "alice")
  let assert Ok(item) =
    handler.create_item(params: ItemParams(title: "test"), handler_ctx: ctx)
  let result = handler.toggle_item(id: item.id, handler_ctx: ctx)
  case result {
    Ok(toggled) -> should.equal(toggled.completed, True)
    _ -> should.fail()
  }
}

pub fn toggle_nonexistent_item_fails_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "alice")
  let result = handler.toggle_item(id: 999, handler_ctx: ctx)
  case result {
    Error(NotFound) -> Nil
    _ -> should.fail()
  }
}

pub fn delete_item_works_test() {
  let db = setup_db()
  let #(_user, ctx) = sign_up_user(db, "alice")
  let assert Ok(item) =
    handler.create_item(params: ItemParams(title: "test"), handler_ctx: ctx)
  let result = handler.delete_item(id: item.id, handler_ctx: ctx)
  case result {
    Ok(id) -> should.equal(id, item.id)
    _ -> should.fail()
  }
}
