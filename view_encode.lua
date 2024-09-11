local qoid = require("qoi_d")

local arg = select(1,...)
print(textutils.serialise(qoid.decode({file=(arg ~= "") and arg or "luaqoi/out.qoi"})))
