local lua_qoi = {}

local bit_lib     = _G.bit32 or _G.bit
local string_char = string.char

local QOI_OP_RGB  = tonumber("11111110",2)
local QOI_OP_RGBA = tonumber("11111111",2)

local QOI_OP_INDEX = tonumber("00000000",2)
local QOI_OP_DIFF  = tonumber("01000000",2)
local QOI_OP_LUMA  = tonumber("10000000",2)
local QOI_OP_RUN   = tonumber("11000000",2)

local function encode_qoi_header(width,height,channels,colorspace)
    local header_stream = "qoif"

    local width_bytes = string_char(bit_lib.band(0xFF,bit_lib.rshift(width,8*3)))
        .. string_char(bit_lib.band(0xFF,bit_lib.rshift(width,8*2)))
        .. string_char(bit_lib.band(0xFF,bit_lib.rshift(width,8*1)))
        .. string_char(bit_lib.band(0xFF,width))

    local height_bytes = string_char(bit_lib.band(0xFF,bit_lib.rshift(height,8*3)))
        .. string_char(bit_lib.band(0xFF,bit_lib.rshift(height,8*2)))
        .. string_char(bit_lib.band(0xFF,bit_lib.rshift(height,8*1)))
        .. string_char(bit_lib.band(0xFF,height))

    return header_stream
        .. width_bytes
        .. height_bytes
        .. string_char(channels   == "RGB"         and 3 or 4)
        .. string_char(colorspace == "SRGB_LINEAR" and 1 or 0)
end

local last_pixel_r
local last_pixel_g
local last_pixel_b
local last_pixel_a

local current_r
local current_g
local current_b
local current_a

local function chunk_qoi_run_enc(chunks,id,etc)
    local run_length  = 0
    local original_id = id

    local rle_r,rle_g,rle_b,rle_a
        = current_r,current_g,current_b,current_a

    while true do
        local is_identical = last_pixel_r == rle_r
            and last_pixel_g == rle_g
            and last_pixel_b == rle_b
            and last_pixel_a == rle_a

        if not is_identical or run_length >= 62 then
            break
        else
            run_length = run_length + 1
        end

        id = id + 1

        if id > etc.pixel_count then
            break
        end

        rle_r,rle_g,rle_b,rle_a = etc.get_pixel(id)
    end

    if run_length > 0 then
        chunks[#chunks+1] = string_char(QOI_OP_RUN + (run_length-1))
    end

    if run_length > 1 then
        return true,original_id+run_length-1
    else
        return run_length > 0,original_id
    end
end

local function chunk_qoi_index_enc(chunks,id,etc)
    local byte_hash = (
        current_r*3 +
        current_g*5 +
        current_b*7 +
        current_a*11
    ) % 64

    local color_hash = 4*(byte_hash+1)

    local hash_list = etc.pixel_hashmap

    local is_matching = hash_list[color_hash-3] == current_r
        and hash_list[color_hash-2] == current_g
        and hash_list[color_hash-1] == current_b
        and hash_list[color_hash  ] == current_a

    if is_matching then
        chunks[#chunks+1] = string_char(QOI_OP_INDEX + byte_hash)
    end

    return is_matching,id
end

local function chunk_qoi_diff_enc(chunks, id)
    if current_a ~= last_pixel_a then
        return false, id
    end

    local delta_r = (current_r - last_pixel_r) % 256
    local delta_g = (current_g - last_pixel_g) % 256
    local delta_b = (current_b - last_pixel_b) % 256

    delta_r = (delta_r + 2) % 256
    delta_g = (delta_g + 2) % 256
    delta_b = (delta_b + 2) % 256

    local diff_viable = delta_r >= 0 and delta_r <= 3
        and delta_g >= 0 and delta_g <= 3
        and delta_b >= 0 and delta_b <= 3

    if diff_viable then
        local encoded_diffs =
            (delta_r * 2^4) +
            (delta_g * 2^2) +
            delta_b

        chunks[#chunks+1] = string_char(QOI_OP_DIFF + encoded_diffs)
    end

    return diff_viable,id
end

local function chunk_qoi_luma_enc(chunks, id)
    if current_a ~= last_pixel_a then
        return false, id
    end

    local delta_r = (current_r - last_pixel_r + 256) % 256
    local delta_g = (current_g - last_pixel_g + 256) % 256
    local delta_b = (current_b - last_pixel_b + 256) % 256

    if delta_r > 127 then delta_r = delta_r - 256 end
    if delta_g > 127 then delta_g = delta_g - 256 end
    if delta_b > 127 then delta_b = delta_b - 256 end


    local delta_rg = delta_r - delta_g
    local delta_bg = delta_b - delta_g

    local luma_viable = delta_g >= -32 and delta_g <= 31
        and delta_rg >= -8 and delta_rg <= 7
        and delta_bg >= -8 and delta_bg <= 7

    if luma_viable then

        local byte1 = (delta_g + 32) + QOI_OP_LUMA
        local byte2 = (delta_rg + 8) * 16 + (delta_bg + 8)

        chunks[#chunks+1] = string_char(byte1,byte2)
    end

    return luma_viable,id
end

local function chunk_qoi_rgb_enc(chunks,id)
    if current_a ~= last_pixel_a then
        return false,id
    end

    chunks[#chunks+1] = string_char(QOI_OP_RGB)
        .. string_char(current_r)
        .. string_char(current_g)
        .. string_char(current_b)

    return true,id
end

local function chunk_qoi_rgba_enc(chunks,id)
    chunks[#chunks+1] = string_char(QOI_OP_RGBA)
        .. string_char(current_r)
        .. string_char(current_g)
        .. string_char(current_b)
        .. string_char(current_a)

    return true,id
end

function lua_qoi.encode(image_data,width,height,alpha_channel,output_file,colorspace)
    local output_stream = ""

    local image_width  = width  or #image_data[1]
    local image_height = height or #image_data

    last_pixel_r,current_r = 0,0
    last_pixel_g,current_g = 0,0
    last_pixel_b,current_b = 0,0
    last_pixel_a,current_a = 255,255

    local pixel_hashmap = {}
    for i=1,64*4 do
        pixel_hashmap[i] = 0
    end

    local qoi_byte_chunks = {}

    local current_pixel = 1

    local function write_hashmap(r,g,b,a)
        local byte_hash = (
            r*3 +
            g*5 +
            b*7 +
            a*11
        ) % 64

        local color_hash = 4*(byte_hash+1)

        pixel_hashmap[color_hash-3] = r
        pixel_hashmap[color_hash-2] = g
        pixel_hashmap[color_hash-1] = b
        pixel_hashmap[color_hash  ] = a
    end

    local byte_band = 2^8

    local red_shift_rgb = alpha_channel and 1/(16^6) or 1/(16^4)
    local grn_shift_rgb = alpha_channel and 1/(16^4) or 1/(16^2)
    local blu_shift_rgb = alpha_channel and 1/(16^2) or 1/(1)
    local alp_shift_rgb = alpha_channel and 1/(1)    or 0

    local pixel_count = image_width*image_height

    local pixel_type  = type(image_data[1][1])
    local math_ceil   = math.ceil
    local math_floor  = math.floor
    local function get_pixel(pixel_id)
        local pixel_y = math_ceil(pixel_id/image_width)
        local pixel_x = (pixel_id-1)%image_width+1

        local pixel_info = image_data[pixel_y][pixel_x]

        local pixel_r,pixel_g,pixel_b,pixel_a
        if pixel_type == "number" then
            local shifted_r = pixel_info*red_shift_rgb
            local shifted_g = pixel_info*grn_shift_rgb
            local shifted_b = pixel_info*blu_shift_rgb
            local shifted_a = pixel_info*alp_shift_rgb

            shifted_r = shifted_r - shifted_r%1
            shifted_g = shifted_g - shifted_g%1
            shifted_b = shifted_b - shifted_b%1
            shifted_a = shifted_a - shifted_a%1

            pixel_r,pixel_g,pixel_b,pixel_a =
                shifted_r % byte_band,
                shifted_g % byte_band,
                shifted_b % byte_band,
                alpha_channel and (shifted_a % byte_band) or 255
        elseif pixel_type == "table" then
            local scaled_r =  pixel_info[1]       * 255
            local scaled_g =  pixel_info[2]       * 255
            local scaled_b =  pixel_info[3]       * 255
            local scaled_a = (pixel_info[4] or 1) * 255

            pixel_r,pixel_g,pixel_b,pixel_a =
                scaled_r - scaled_r%1,
                scaled_g - scaled_g%1,
                scaled_b - scaled_b%1,
                alpha_channel and (scaled_a - scaled_a%1) or 255
        end

        return pixel_r,pixel_g,pixel_b,pixel_a
    end

    local qoi_chunk_types = {
        chunk_qoi_run_enc,
        chunk_qoi_index_enc,
        chunk_qoi_diff_enc,
        chunk_qoi_luma_enc,
        chunk_qoi_rgb_enc,
        chunk_qoi_rgba_enc,
    }

    local chunk_type_cnt = #qoi_chunk_types

    local chunk_encode_args = {
        get_pixel     = get_pixel,
        pixel_hashmap = pixel_hashmap,
        pixel_count   = pixel_count,
    }

    while current_pixel <= pixel_count do
        current_r,current_g,current_b,current_a = get_pixel(
            current_pixel
        )

        for chunk=1,chunk_type_cnt do
            local encoded,next_pixel = qoi_chunk_types[chunk](
                qoi_byte_chunks,
                current_pixel,chunk_encode_args
            )

            if encoded then
                current_pixel = next_pixel

                break
            end
        end

        last_pixel_r,last_pixel_g,last_pixel_b,last_pixel_a =
            current_r,current_g,current_b,current_a

        write_hashmap(
            current_r,current_g,current_b,current_a
        )

        if (current_pixel%100000 == 0) and os.queueEvent then
            os.queueEvent("qoi_encode_yield")
            os.pullEvent ("qoi_encode_yield")
        end

        current_pixel = current_pixel + 1
    end

    output_stream = output_stream .. table.concat(qoi_byte_chunks,"")
        .. "\0\0\0\0\0\0\0\1"

    output_stream = encode_qoi_header(
        image_width,image_height,
        alpha_channel and "RGBA" or "RGB",
        colorspace or "SRGB_LINEAR_ALPHA"
    ) .. output_stream

    if output_file then
        local file_handle = fs.open(output_file,"wb")
        if file_handle then
            file_handle.write(output_stream)
            file_handle.close()
        end
    end

    return output_stream
end

return lua_qoi