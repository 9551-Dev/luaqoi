local qoie = require("qoi_e")

local data = {
    {0xFF0000FF,0xFF0200FF},
    {0x000000FF,0x000000FF}
}

qoie.encode(data,2,2,true,"luaqoi/out.qoi")