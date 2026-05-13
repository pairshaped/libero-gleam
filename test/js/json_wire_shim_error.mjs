// Gleam compiled type shim: libero/json/error.mjs

import { CustomType } from "./json_wire_shim.mjs";

export class JsonError extends CustomType {
  constructor(path, message) {
    super();
    this.path = path;
    this.message = message;
  }
}
