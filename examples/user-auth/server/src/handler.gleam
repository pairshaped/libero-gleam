import generated/sql/server_sql
import gleam/list
import gleam/option.{type Option, None, Some}
import handler_context.{type HandlerContext}
import shared/types.{
  type AuthError, type Item, type ItemError, type ItemParams, type User,
  DatabaseError, Item, NotFound, SessionExpired, TitleRequired,
  UserAlreadyExists, UserNotFound, User,
}

fn resolve_user(ctx: HandlerContext) -> Result(Int, AuthError) {
  case ctx.session_user {
    Some(user) -> Ok(user.id)
    None -> Error(SessionExpired)
  }
}

pub fn sign_up(
  username username: String,
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(User, AuthError), HandlerContext) {
  case server_sql.find_user_by_username(db: handler_ctx.db, username:) {
    Ok([_, ..]) -> #(Error(UserAlreadyExists), handler_ctx)
    _ ->
      case server_sql.create_user(db: handler_ctx.db, username:) {
        Ok([row]) -> {
          let user = User(id: row.id, username: row.username)
          let new_ctx =
            handler_context.HandlerContext(..handler_ctx, session_user: Some(user))
          #(Ok(user), new_ctx)
        }
        _ -> #(Error(UserNotFound), handler_ctx)
      }
  }
}

pub fn sign_in(
  username username: String,
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(User, AuthError), HandlerContext) {
  case server_sql.find_user_by_username(db: handler_ctx.db, username:) {
    Ok([row]) -> {
      let user = User(id: row.id, username: row.username)
      let new_ctx =
        handler_context.HandlerContext(..handler_ctx, session_user: Some(user))
      #(Ok(user), new_ctx)
    }
    _ -> #(Error(UserNotFound), handler_ctx)
  }
}

pub fn sign_out(
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Nil, AuthError), HandlerContext) {
  let new_ctx = handler_context.HandlerContext(..handler_ctx, session_user: None)
  #(Ok(Nil), new_ctx)
}

pub fn me(
  handler_ctx handler_ctx: HandlerContext,
) -> Result(Option(User), AuthError) {
  Ok(handler_ctx.session_user)
}

pub fn get_items(
  handler_ctx handler_ctx: HandlerContext,
) -> Result(List(Item), ItemError) {
  case resolve_user(handler_ctx) {
    Error(_) -> Error(DatabaseError)
    Ok(user_id) ->
      case server_sql.list_items(db: handler_ctx.db, user_id:) {
        Ok(rows) -> Ok(list.map(rows, row_to_item))
        Error(_) -> Error(DatabaseError)
      }
  }
}

pub fn create_item(
  params params: ItemParams,
  handler_ctx handler_ctx: HandlerContext,
) -> Result(Item, ItemError) {
  case params.title {
    "" -> Error(TitleRequired)
    title ->
      case resolve_user(handler_ctx) {
        Error(_) -> Error(DatabaseError)
        Ok(user_id) ->
          case server_sql.create_item(db: handler_ctx.db, user_id:, title:) {
            Ok([row]) -> Ok(row_to_item(row))
            _ -> Error(DatabaseError)
          }
      }
  }
}

pub fn toggle_item(
  id id: Int,
  handler_ctx handler_ctx: HandlerContext,
) -> Result(Item, ItemError) {
  case resolve_user(handler_ctx) {
    Error(_) -> Error(DatabaseError)
    Ok(user_id) ->
      case server_sql.toggle_item(db: handler_ctx.db, id:, user_id:) {
        Ok([row]) -> Ok(row_to_item(row))
        Ok([]) -> Error(NotFound)
        _ -> Error(DatabaseError)
      }
  }
}

pub fn delete_item(
  id id: Int,
  handler_ctx handler_ctx: HandlerContext,
) -> Result(Int, ItemError) {
  case resolve_user(handler_ctx) {
    Error(_) -> Error(DatabaseError)
    Ok(user_id) ->
      case server_sql.delete_item(db: handler_ctx.db, id:, user_id:) {
        Ok([row]) -> Ok(row.id)
        Ok([]) -> Error(NotFound)
        _ -> Error(DatabaseError)
      }
  }
}

fn row_to_item(row: server_sql.ItemRow) -> Item {
  Item(id: row.id, title: row.title, completed: row.completed)
}
