import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{None}
import handler_context.{type HandlerContext}
import libero/remote_data.{NotAsked}
import libero/ssr
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import mist.{type Connection, type ResponseData}
import shared/router.{type Route}
import shared/views.{type Model, type Msg, Model, title, view}

/// SSR always renders the signed-out state. Auth lives entirely on the
/// client via ClientContext and the WebSocket RPC handler_ctx. A
/// full-page reload loses the session — sign in again to continue.
pub fn load_page(
  _req: Request(Connection),
  route: Route,
  _handler_ctx: HandlerContext,
) -> Result(Model, Response(ResponseData)) {
  Ok(Model(
    route:,
    session_user: None,
    items: NotAsked,
    input: "",
    username_input: "",
    auth_error: None,
  ))
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
