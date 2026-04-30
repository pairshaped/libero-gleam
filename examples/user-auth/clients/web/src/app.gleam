import client_context
import generated/messages as rpc
import generated/ssr.{read_flags}
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option
import gleam/uri.{type Uri}
import libero/remote_data.{type RpcData, Success}
import libero/ssr as libero_ssr
import lustre
import lustre/effect.{type Effect}
import lustre/element
import modem
import shared/router
import shared/types.{
  type AuthError, type Item, type ItemError, type SignInResult, ItemParams,
}
import shared/views

pub type Model {
  Model(ctx: client_context.Model, page: views.Model)
}

pub type ClientMsg {
  ViewMsg(views.Msg)
  GotItems(RpcData(List(Item), ItemError))
  GotCreated(RpcData(Item, ItemError))
  GotToggled(RpcData(Item, ItemError))
  GotDeleted(RpcData(Int, ItemError))
  GotSignedUp(RpcData(SignInResult, AuthError))
  GotSignedIn(RpcData(SignInResult, AuthError))
  GotSignedOut(RpcData(Nil, AuthError))
}

@external(javascript, "globalThis", "setCookie")
pub fn set_cookie(name: String, value: String, path: String) -> Nil

@external(javascript, "globalThis", "clearCookie")
pub fn clear_cookie(name: String, path: String) -> Nil

pub fn main() {
  let app = lustre.application(init, update, view_wrap)
  let assert Ok(_) = lustre.start(app, "#app", read_flags())
  Nil
}

fn init(flags: Dynamic) -> #(Model, Effect(ClientMsg)) {
  let page_model: views.Model = case libero_ssr.decode_flags(flags) {
    Ok(m) -> m
    Error(_) ->
      panic as "failed to decode SSR flags. Was ssr.boot_script called on the server?"
  }
  let ctx = client_context.init_from_ssr(page_model.session_user)
  #(Model(ctx:, page: page_model), modem.init(on_url_change))
}

fn on_url_change(uri: Uri) -> ClientMsg {
  case router.parse_route(uri) {
    Ok(route) -> ViewMsg(views.NavigateTo(route))
    Error(_) -> ViewMsg(views.NoOp)
  }
}

fn update(model: Model, msg: ClientMsg) -> #(Model, Effect(ClientMsg)) {
  case msg {
    ViewMsg(views.NavigateTo(route)) -> #(
      Model(..model, page: views.Model(..model.page, route:)),
      effect.none(),
    )
    ViewMsg(views.NoOp) -> #(model, effect.none())
    ViewMsg(views.UserTypedUsername(value)) -> #(
      Model(..model, page: views.Model(..model.page, username_input: value)),
      effect.none(),
    )
    ViewMsg(views.UserTypedTitle(value)) -> #(
      Model(..model, page: views.Model(..model.page, input: value)),
      effect.none(),
    )
    ViewMsg(views.UserSubmittedTitle) ->
      case model.page.input {
        "" -> #(model, effect.none())
        title -> #(
          Model(..model, page: views.Model(..model.page, input: "")),
          rpc.create_item(params: ItemParams(title:), on_response: GotCreated),
        )
      }
    ViewMsg(views.UserToggled(id)) -> #(
      model,
      rpc.toggle_item(id:, on_response: GotToggled),
    )
    ViewMsg(views.UserDeleted(id)) -> #(
      model,
      rpc.delete_item(id:, on_response: GotDeleted),
    )
    ViewMsg(views.UserClickedSignUp) -> #(
      model,
      rpc.sign_up(username: model.page.username_input, on_response: GotSignedUp),
    )
    ViewMsg(views.UserClickedSignIn) -> #(
      model,
      rpc.sign_in(username: model.page.username_input, on_response: GotSignedIn),
    )
    ViewMsg(views.UserClickedSignOut) -> #(
      model,
      rpc.sign_out(on_response: GotSignedOut),
    )
    GotItems(rd) -> #(
      Model(..model, page: views.Model(..model.page, items: rd)),
      effect.none(),
    )
    GotCreated(Success(item)) -> #(
      Model(
        ..model,
        page: views.Model(
          ..model.page,
          items: remote_data.map(data: model.page.items, transform: fn(items) {
            list.append(items, [item])
          }),
        ),
      ),
      effect.none(),
    )
    GotToggled(Success(updated)) -> #(
      Model(
        ..model,
        page: views.Model(
          ..model.page,
          items: remote_data.map(data: model.page.items, transform: fn(items) {
            list.map(items, fn(it) {
              case it.id == updated.id {
                True -> updated
                False -> it
              }
            })
          }),
        ),
      ),
      effect.none(),
    )
    GotDeleted(Success(id)) -> #(
      Model(
        ..model,
        page: views.Model(
          ..model.page,
          items: remote_data.map(data: model.page.items, transform: fn(items) {
            list.filter(items, fn(it) { it.id != id })
          }),
        ),
      ),
      effect.none(),
    )
    GotSignedUp(Success(result)) -> #(
      Model(
        ..model,
        ctx: client_context.update(
          model.ctx,
          client_context.SignIn(user: result.user, token: result.token),
        ),
        page: views.Model(
          ..model.page,
          session_user: option.Some(result.user),
          items: remote_data.Loading,
          route: router.Home,
        ),
      ),
      effect.batch([
        effect.from(fn(_) { set_cookie("session_token", result.token, "/") }),
        rpc.get_items(on_response: GotItems),
      ]),
    )
    GotSignedIn(Success(result)) -> #(
      Model(
        ..model,
        ctx: client_context.update(
          model.ctx,
          client_context.SignIn(user: result.user, token: result.token),
        ),
        page: views.Model(
          ..model.page,
          session_user: option.Some(result.user),
          items: remote_data.Loading,
          route: router.Home,
        ),
      ),
      effect.batch([
        effect.from(fn(_) { set_cookie("session_token", result.token, "/") }),
        rpc.get_items(on_response: GotItems),
      ]),
    )
    GotSignedOut(Success(_)) -> #(
      Model(
        ..model,
        ctx: client_context.update(model.ctx, client_context.SignOut),
        page: views.Model(
          ..model.page,
          session_user: option.None,
          items: remote_data.NotAsked,
          route: router.Home,
        ),
      ),
      effect.from(fn(_) { clear_cookie("session_token", "/") }),
    )
    GotCreated(_) -> #(model, effect.none())
    GotToggled(_) -> #(model, effect.none())
    GotDeleted(_) -> #(model, effect.none())
    GotSignedUp(_) -> #(model, effect.none())
    GotSignedIn(_) -> #(model, effect.none())
    GotSignedOut(_) -> #(model, effect.none())
  }
}

fn view_wrap(model: Model) -> element.Element(ClientMsg) {
  views.view(model.page) |> element.map(ViewMsg)
}
