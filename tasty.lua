------------------------------------------------------------------------
--- Assertors

local assertors = {}

local function register_assertor (name, callback, error_message)
  assertors[name] = function (...)
    local bool = callback(...)
    if bool then
      return
    end

    local success, formatted_message =
      pcall(string.format, error_message, ...)
    if not success then
      error('assertion failed, and error message could not be formatted', 2)
    end
    error('\n' .. formatted_message or 'assertion failed!', 2)
  end
end

--- Value is truthy
local function is_truthy (x)
  return x ~= false and x ~= nil
end

--- Value is falsy
local function is_falsy (x)
  return not is_truthy(x)
end

--- Value is nil
local function is_nil (x)
  return x == nil
end

--- Values are equal
local function are_equal (x, y)
  return x == y
end

register_assertor('is_truthy', is_truthy, "expected a truthy value, got %s")
register_assertor('is_falsy', is_falsy, "expected a falsy value, got %s")
register_assertor('is_nil', is_nil, "expected nil, got %s")
register_assertor(
  'are_equal', are_equal, "expected values to be equal, got '%s' and '%s'"
)

------------------------------------------------------------------------

local ok = true

local function test_success (name)
  return {
    name = name,
    result = ok,
  }
end

local function test_failure (name, err_msg)
  return {
    name = name,
    result = err_msg,
  }
end

------------------------------------------------------------------------
-- Test definitions

local function test_case (name, callback)
  local success, err_msg = pcall(callback)
  return success
    and test_success(name)
    or  test_failure(name, err_msg)
end

local function test_group (name, tests)
  if tests == nil then
    -- let's try to curry
    return function (tests_)
      return tests_ and test_group(name, tests_) or error('no tests')
    end
  end
  return {
    name = name,
    result = tests,
  }
end

return {
  assert = assertors,
  ok = ok,
  test_case = test_case,
  test_group = test_group
}
