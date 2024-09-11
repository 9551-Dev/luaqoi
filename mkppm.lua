local qoid = require("qoi_d")
local ppme = require("ppm_e")

local data = qoid.decode({file="/luaqoi/testpics/testcard_rgba.qoi"},true)

ppme.encode(data.pixels,data.width,data.height,nil,"thingy.ppm")