local qoie = require("qoi_e")
local qoid = require("qoi_d")

local data = qoid.decode({file="luaqoi/tmp.qoi"},true)
qoie.encode(data.pixels,data.width,data.height,false,"luaqoi/retmp.qoi")