import generated/sql/server_sql
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import handler
import handler_context.{type HandlerContext}
import libero/remote_data.{DomainError, Failure, NotAsked, Success}
import libero/ssr
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mist.{type Connection, type ResponseData}
import shared/router.{type Route}
import shared/types.{User}
import shared/views.{type Model, type Msg, Model, title, view}

fn get_cookie(req: Request(Connection), name: String) -> Option(String) {
  case req.headers |> list.find(fn(h) { string.lowercase(h.0) == "cookie" }) {
    Ok(#(_, cookie_header)) -> {
      let candidates =
        cookie_header
        |> string.split(";")
        |> list.filter_map(fn(part) {
          let trimmed = string.trim(part)
          case string.split_once(trimmed, "=") {
            Ok(#(k, v)) if k == name -> Ok(v)
            _ -> Error(Nil)
          }
        })
      case candidates |> list.first {
        Ok(v) -> Some(v)
        Error(Nil) -> None
      }
    }
    Error(Nil) -> None
  }
}

pub fn load_page(
  req: Request(Connection),
  route: Route,
  handler_ctx: HandlerContext,
) -> Result(Model, Response(ResponseData)) {
  let session_user = case get_cookie(req, "session_token") {
    Some(token) ->
      case server_sql.find_session(db: handler_ctx.db, token: Some(token)) {
        Ok([row]) ->
          case server_sql.find_user_by_id(db: handler_ctx.db, id: row.user_id) {
            Ok([u]) -> Some(User(id: u.id, username: u.username))
            _ -> None
          }
        _ -> None
      }
    None -> None
  }

  let ctx = handler_context.HandlerContext(..handler_ctx, session_user:)

  let items = case session_user {
    None -> NotAsked
    Some(_) ->
      case handler.get_items(handler_ctx: ctx) {
        Ok(items) -> Success(items)
        Error(err) -> Failure(DomainError(err))
      }
  }

  Ok(Model(route:, session_user:, items:, input: "", username_input: ""))
}

pub fn render_page(_route: Route, model: Model) -> Element(Msg) {
  html.html([attribute.attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.title([], title(model)),
    ]),
    html.body([], [
      html.div([attribute.id("app")], [view(model)]),
      ssr.boot_script(client_module: "/web/web/app.mjs", flags: model),
    ]),
  ])
}
