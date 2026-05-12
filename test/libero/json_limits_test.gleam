import gleeunit/should
import libero/json/limits

pub fn default_limits_are_sane_test() {
  let l = limits.default_limits()
  should.be_true(l.max_input_bytes > 0)
  should.be_true(l.max_nesting_depth > 0)
  should.be_true(l.max_string_length > 0)
}
