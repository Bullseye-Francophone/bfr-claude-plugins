local here = arg[0]:match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. here .. "../src/?.lua;" .. package.path

local helpers = require("helpers")

for _, file in ipairs(arg) do
  io.write("== ", file, "\n")
  dofile(file)
end

io.write(string.format("\n%d passed, %d failed\n", helpers.passed, helpers.failed))
os.exit(helpers.failed == 0 and 0 or 1)
