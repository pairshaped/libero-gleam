// Gleam runtime type shim: gleam_stdlib/gleam.mjs

export class CustomType {}

export class Empty {}
export class NonEmpty {
  constructor(head, tail) {
    this.head = head;
    this.tail = tail;
  }
}

export class Ok {
  constructor(value) {
    this[0] = value;
  }
}

export class Error {
  constructor(detail) {
    this[0] = detail;
  }
}
