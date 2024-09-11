local lua_ppm = {}

local function make_header(width,height,depth)
    return ("P6\n# Encoded with LuaPPM\n%s %s %s\n"):format(
        width,height,depth
    )
end

local string_char  = string.char
local table_concat = table.concat
function lua_ppm.encode(data,width,height,depth,output_file)
    local output_str = ""

    width  = width  or #data[#data[1]]
    height = height or #data[1]
    depth  = depth  or 255

    output_str = output_str .. make_header(
        width,height,depth
    )

    local scanlines = {}

    local pixel_type = type(data[height][width])

    local red_rshift = 1/(16^4)
    local grn_rshift = 1/(16^2)

    local depth_scale = depth/255

    for current_y=1,height do
        local image_line = data[current_y]
        local scanline   = ""

        for current_x=1,width do
            local pixel = image_line[current_x]
            local scaled_r,scaled_g,scaled_b

            if pixel_type == "table" then
                scaled_r = (pixel[1] or pixel.r) * depth
                scaled_g = (pixel[2] or pixel.g) * depth
                scaled_b = (pixel[3] or pixel.b) * depth
            else
                scaled_r = (pixel*red_rshift)%256 * depth_scale
                scaled_g = (pixel*grn_rshift)%256 * depth_scale
                scaled_b = (pixel           )%256 * depth_scale
            end

            scaled_r = scaled_r - scaled_r%1
            scaled_g = scaled_g - scaled_g%1
            scaled_b = scaled_b - scaled_b%1

            scanline = scanline
                .. string_char(scaled_r)
                .. string_char(scaled_g)
                .. string_char(scaled_b)
        end

        scanlines[current_y] = scanline
    end

    output_str = output_str .. table_concat(scanlines,"")

    if output_file then
        local file_handle = fs.open(output_file,"wb")
        if file_handle then
            file_handle.write(output_str)
            file_handle.close()
        end
    end

    return output_str
end

return lua_ppm