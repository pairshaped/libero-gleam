// Gleam compiled type shim: libero/frame.mjs

import { CustomType } from "./json_wire_shim.mjs";

export class Response extends CustomType {
  constructor(request_id, value) {
    super();
    this.request_id = request_id;
    this.value = value;
  }
}

export class Push extends CustomType {
  constructor(module, value) {
    super();
    this.module = module;
    this.value = value;
  }
}

export class Error extends CustomType {
  constructor(request_id, errors) {
    super();
    this.request_id = request_id;
    this.errors = errors;
  }
}
