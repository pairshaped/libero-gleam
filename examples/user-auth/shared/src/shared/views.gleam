import gleam/list
import gleam/option.{type Option}
import libero/remote_data.{type RpcData, Failure, Loading, NotAsked, Success}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/router.{type Route, Home, SignIn, SignUp}
import shared/types.{type Item, type ItemError, type User}

pub type Model {
  Model(
    route: Route,
    session_user: Option(User),
    items: RpcData(List(Item), ItemError),
    input: String,
    username_input: String,
    auth_error: Option(String),
  )
}

pub type Msg {
  NavigateTo(Route)
  NoOp
  UserClickedSignUp
  UserClickedSignIn
  UserClickedSignOut
  UserTypedUsername(value: String)
  UserTypedTitle(value: String)
  UserSubmittedTitle
  UserToggled(id: Int)
  UserDeleted(id: Int)
}

pub fn title(model: Model) -> String {
  case model.route {
    Home -> "User Auth - Checklist"
    SignIn -> "Sign In"
    SignUp -> "Sign Up"
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model.route {
    Home -> home_view(model)
    SignIn -> sign_in_view(model)
    SignUp -> sign_up_view(model)
  }
}

fn home_view(model: Model) -> Element(Msg) {
  html.main(
    [attribute.styles([#("max-width", "32rem"), #("margin", "2rem auto"), #("font-family", "system-ui, sans-serif")])],
    [
      html.header(
        [attribute.style("display", "flex"), attribute.style("justify-content", "space-between"), attribute.style("align-items", "center")],
        [
          html.h1([], [html.text("User Auth")]),
          case model.session_user {
            option.Some(user) ->
              html.div([attribute.style("display", "flex"), attribute.style("gap", "0.5rem"), attribute.style("align-items", "center")], [
                html.span([], [html.text("Hello, " <> user.username <> "!")]),
                html.button([event.on_click(UserClickedSignOut)], [html.text("Sign Out")]),
              ])
            option.None ->
              html.nav([attribute.style("display", "flex"), attribute.style("gap", "0.5rem")], [
                html.a([attribute.href("/sign-in")], [html.text("Sign In")]),
                html.a([attribute.href("/sign-up")], [html.text("Sign Up")]),
              ])
          },
        ],
      ),
      case model.session_user {
        option.None ->
          html.p([], [html.text("Sign in to manage your checklist.")])
        option.Some(_) ->
          html.div([], [
            view_form(model.input),
            view_items(model.items),
          ])
      },
    ],
  )
}

fn sign_in_view(model: Model) -> Element(Msg) {
  html.main(
    [attribute.styles([#("max-width", "24rem"), #("margin", "2rem auto"), #("font-family", "system-ui, sans-serif")])],
    [
      html.h1([], [html.text("Sign In")]),
      html.form([event.on_submit(fn(_) { UserClickedSignIn })], [
        html.div([attribute.style("margin-bottom", "0.5rem")], [
          html.label([], [html.text("Username")]),
          html.input([attribute.type_("text"), attribute.value(model.username_input), event.on_input(UserTypedUsername)]),
        ]),
        html.button([attribute.type_("submit")], [html.text("Sign In")]),
      ]),
      view_auth_error(model),
      html.p([], [
        html.text("Don't have an account? "),
        html.a([attribute.href("/sign-up")], [html.text("Sign up")]),
      ]),
    ],
  )
}

fn sign_up_view(model: Model) -> Element(Msg) {
  html.main(
    [attribute.styles([#("max-width", "24rem"), #("margin", "2rem auto"), #("font-family", "system-ui, sans-serif")])],
    [
      html.h1([], [html.text("Sign Up")]),
      html.form([event.on_submit(fn(_) { UserClickedSignUp })], [
        html.div([attribute.style("margin-bottom", "0.5rem")], [
          html.label([], [html.text("Username")]),
          html.input([attribute.type_("text"), attribute.value(model.username_input), event.on_input(UserTypedUsername)]),
        ]),
        html.button([attribute.type_("submit")], [html.text("Sign Up")]),
      ]),
      view_auth_error(model),
      html.p([], [
        html.text("Already have an account? "),
        html.a([attribute.href("/sign-in")], [html.text("Sign in")]),
      ]),
    ],
  )
}

fn view_form(input: String) -> Element(Msg) {
  html.form(
    [event.on_submit(fn(_) { UserSubmittedTitle }), attribute.styles([#("display", "flex"), #("gap", "0.5rem")])],
    [
      html.input([attribute.type_("text"), attribute.value(input), attribute.placeholder("What needs doing?"), event.on_input(UserTypedTitle), attribute.style("flex", "1")]),
      html.button([attribute.type_("submit")], [html.text("Add")]),
    ],
  )
}

fn view_items(items: RpcData(List(Item), ItemError)) -> Element(Msg) {
  case items {
    NotAsked -> element.none()
    Loading -> html.p([], [html.text("Loading...")])
    Failure(outcome) ->
      html.p([attribute.style("color", "crimson")], [
        html.text(remote_data.format_failure(outcome:, format_domain: format_item_error)),
      ])
    Success(items) ->
      html.ul([attribute.style("padding", "0")], list.map(items, view_item))
  }
}

fn view_item(item: Item) -> Element(Msg) {
  html.li(
    [attribute.styles([#("display", "flex"), #("gap", "0.5rem"), #("align-items", "center"), #("padding", "0.5rem 0"), #("list-style", "none")])],
    [
      html.input([attribute.type_("checkbox"), attribute.checked(item.completed), event.on_check(fn(_) { UserToggled(item.id) })]),
      html.span(
        [attribute.styles([#("flex", "1"), #("text-decoration", case item.completed { True -> "line-through" False -> "none" })])],
        [html.text(item.title)],
      ),
      html.button([event.on_click(UserDeleted(item.id))], [html.text("Delete")]),
    ],
  )
}

fn view_auth_error(model: Model) -> Element(Msg) {
  case model.auth_error {
    option.Some(msg) ->
      html.p([attribute.style("color", "crimson")], [html.text(msg)])
    option.None -> element.none()
  }
}

fn format_item_error(err: ItemError) -> String {
  case err {
    types.NotFound -> "That item is gone."
    types.TitleRequired -> "Title is required."
    types.DatabaseError -> "Database error. Try again."
  }
}
