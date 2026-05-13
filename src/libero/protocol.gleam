import gleam/string

pub type Protocol {
  Etf
  Json
}

pub fn to_string(protocol: Protocol) -> String {
  case protocol {
    Etf -> "etf"
    Json -> "json"
  }
}

pub fn from_string(value: String) -> Result(Protocol, String) {
  case string.lowercase(value) {
    "etf" -> Ok(Etf)
    "json" -> Ok(Json)
    other -> Error("unknown protocol: " <> other)
  }
}
