// Gleam runtime type shim: gleam_stdlib/gleam/option.mjs

export class Some {
  constructor(value) {
    this[0] = value;
  }
}
export class None {}
