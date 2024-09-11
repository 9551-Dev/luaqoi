local lua_qoi = {}

local QOI_OP_RGB  = tonumber("11111110",2)
local QOI_OP_RGBA = tonumber("11111111",2)

local QOI_OP_INDEX = tonumber("00",2)
local QOI_OP_DIFF  = tonumber("01",2)
local QOI_OP_LUMA  = tonumber("10",2)
local QOI_OP_RUN   = tonumber("11",2)

local bit_lib = _G.bit32 or bit

local function read_bytes(stream,count,as_string)
    local seek = stream.head

    if as_string then
        local result_str = stream.data:sub(seek,seek+count-1)

        stream.head = seek+count

        return result_str
    else
        local bytes_read = {}

        local stream_data = stream.data

        for i=1,count do
            bytes_read[i] = stream_data:byte(seek)

            seek = seek + 1
        end

        stream.head = seek

        return bytes_read
    end
end

local function read_byte(stream)
    local seek_head = stream.head

    stream.head = seek_head + 1
    return stream.data:byte(seek_head,seek_head)
end

local function multibyte_number(bytes)
    local n = 0

    local byte_count = #bytes

    for i=1,byte_count do
        local shift = 8*(byte_count-i)
        n = n + bit_lib.lshift(bytes[i],shift)
    end

    return n
end

local header_lookup = {
    channels = {
        [3] = "RGB",
        [4] = "RGBA"
    },
    colspace = {
        [0] = "SRGB_LINEAR_ALPHA",
        [1] = "SRGB_LINEAR"
    }
}

local function parse_qoi_header(stream)
    local magic_id = read_bytes(stream,4,true)

    if magic_id ~= "qoif" then
        error("Not a QOI file.",3)
    end

    local width_bytes  = read_bytes(stream,4)
    local height_bytes = read_bytes(stream,4)
    local channel_byte = read_bytes(stream,1)
    local space_byte   = read_bytes(stream,1)

    return {
        width      = multibyte_number(width_bytes),
        height     = multibyte_number(height_bytes),
        channels   = header_lookup.channels[channel_byte[1]],
        colorspace = header_lookup.colspace[space_byte  [1]]
    }
end

local last_pixel_r
local last_pixel_g
local last_pixel_b
local last_pixel_a

local function chunk_qoi_luma_dec(cur_byte,stream)
    local next_byte = read_byte(stream)

    local delta_grn = bit_lib.extract(cur_byte, 0,6) - 32
    local delta_red = bit_lib.extract(next_byte,4,4) - 8
    local delta_blu = bit_lib.extract(next_byte,0,4) - 8

    return  (last_pixel_r + delta_red + delta_grn)%256,
            (last_pixel_g + delta_grn)            %256,
            (last_pixel_b + delta_blu + delta_grn)%256,
            last_pixel_a
end

local function chunk_qoi_diff_dec(byte)
    local delta_red = bit_lib.extract(byte,4,2) - 2
    local delta_grn = bit_lib.extract(byte,2,2) - 2
    local delta_blu = bit_lib.extract(byte,0,2) - 2

    return  (last_pixel_r + delta_red)%256,
            (last_pixel_g + delta_grn)%256,
            (last_pixel_b + delta_blu)%256,
            last_pixel_a
end

local function chunk_qoi_run_dec(byte,write_pixel)
    local run_length = bit_lib.extract(byte,0,6) + 1

    for run_id=1,run_length do
        write_pixel(
            last_pixel_r,
            last_pixel_g,
            last_pixel_b,
            last_pixel_a
        )
    end
end

local function chunk_qoi_index_dec(byte,color_array)
    local color_index = 4 * (
        bit_lib.extract(byte,0,6) + 1
    )

    return  color_array[color_index - 3],
            color_array[color_index - 2],
            color_array[color_index - 1],
            color_array[color_index]
end

local function chunk_qoi_rgb_dec(stream)
    return  read_byte(stream),
            read_byte(stream),
            read_byte(stream),
            last_pixel_a
end

local function chunk_qoi_rgba_dec(stream)
    return  read_byte(stream),
            read_byte(stream),
            read_byte(stream),
            read_byte(stream)
end

function lua_qoi.decode(data_source,no_alpha)
    local stream = {head=1}
    if data_source.data then
        stream.data = data_source.data
    elseif data_source.handle then
        stream.data = data_source.handle.readAll()
        data_source.handle.close()
    elseif data_source.file then
        local file_handle = fs.open(data_source.file,"rb")

        if file_handle then
            stream.data = file_handle.readAll()
            file_handle.close()
        end
    end

    local image_result  = parse_qoi_header(stream)
    local image_pixels  = {}
    image_result.pixels = image_pixels

    local pixel_count = 0

    local pixel_hashmap = {}
    for i=1,64*4 do
        pixel_hashmap[i] = 0
    end

    last_pixel_r = 0
    last_pixel_g = 0
    last_pixel_b = 0
    last_pixel_a = 255

    local image_width  = image_result.width

    local is_rgba = (no_alpha ~= true) and image_result.channels == "RGBA"
    image_result.has_alpha = is_rgba

    local red_shift_rgb = is_rgba and 16^6 or 16^4
    local grn_shift_rgb = is_rgba and 16^4 or 16^2
    local blu_shift_rgb = is_rgba and 16^2 or 1
    local alp_shift_rgb = is_rgba and 1    or 0

    local math_ceil = math.ceil
    local function write_pixel(pix_r,pix_g,pix_b,pix_a)
        if not pix_r then error("missing pix",2) end

        last_pixel_r = pix_r
        last_pixel_g = pix_g
        last_pixel_b = pix_b
        last_pixel_a = pix_a

        pixel_count = pixel_count + 1

        local pixel_x = (pixel_count-1)%image_width+1
        local pixel_y = math_ceil(pixel_count/image_width)

        if not image_pixels[pixel_y] then image_pixels[pixel_y] = {} end

        local hex_coded_pixel =
            pix_r * red_shift_rgb +
            pix_g * grn_shift_rgb +
            pix_b * blu_shift_rgb +
            pix_a * alp_shift_rgb

        image_pixels[pixel_y][pixel_x] = hex_coded_pixel

        local color_hash = 4 * ((
            pix_r*3 +
            pix_g*5 +
            pix_b*7 +
            pix_a*11
        )%64 + 1)

        pixel_hashmap[color_hash-3] = pix_r
        pixel_hashmap[color_hash-2] = pix_g
        pixel_hashmap[color_hash-1] = pix_b
        pixel_hashmap[color_hash  ] = pix_a
    end

    local expected_pixels = image_result.width*image_result.height

    while pixel_count < expected_pixels do
        local byte = read_byte(stream)

        local chunk_type = bit_lib.rshift(byte,6)

        if byte == QOI_OP_RGB then
            print("QOI_OP_RGB")

            write_pixel(
                chunk_qoi_rgb_dec(
                    stream
                )
            )
        elseif byte == QOI_OP_RGBA then
            print("QOI_OP_RGBA")

            write_pixel(
                chunk_qoi_rgba_dec(stream)
            )
        elseif chunk_type == QOI_OP_INDEX then
            print("QOI_OP_INDEX")

            write_pixel(
                chunk_qoi_index_dec(
                    byte,pixel_hashmap
                )
            )
        elseif chunk_type == QOI_OP_DIFF then
            print("QOI_OP_DIFF")

            write_pixel(
                chunk_qoi_diff_dec(
                    byte
                )
            )
        elseif chunk_type == QOI_OP_LUMA then
            print("QOI_OP_LUMA")

            write_pixel(
                chunk_qoi_luma_dec(
                    byte,stream
                )
            )
        elseif chunk_type == QOI_OP_RUN then
            print("QOI_OP_RUN")

            chunk_qoi_run_dec(byte,write_pixel)
        else
            error("Invalid QOI chunk.",2)
        end

        if (pixel_count%100000 == 0) and os.queueEvent then
            os.queueEvent("qoi_decode_yield")
            os.pullEvent ("qoi_decode_yield")
        end
    end

    return image_result
end

return lua_qoi