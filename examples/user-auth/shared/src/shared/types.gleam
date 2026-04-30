pub type User {
  User(id: Int, username: String)
}

pub type Item {
  Item(id: Int, title: String, completed: Bool)
}

pub type ItemParams {
  ItemParams(title: String)
}

pub type AuthError {
  UserAlreadyExists
  UserNotFound
  SessionExpired
}

pub type ItemError {
  NotFound
  TitleRequired
  DatabaseError
}
