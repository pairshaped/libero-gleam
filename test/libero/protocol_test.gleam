import gleeunit/should
import libero/protocol

pub fn protocol_to_string_test() {
  protocol.to_string(protocol.Etf) |> should.equal("etf")
  protocol.to_string(protocol.Json) |> should.equal("json")
}

pub fn protocol_from_string_test() {
  protocol.from_string("etf") |> should.equal(Ok(protocol.Etf))
  protocol.from_string("json") |> should.equal(Ok(protocol.Json))
  protocol.from_string("xml") |> should.equal(Error("unknown protocol: xml"))
}
