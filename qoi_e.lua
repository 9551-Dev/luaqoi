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

-- chunks,id,get_pix,color_hash,max_id
local function chunk_qoi_run_enc(chunks,id,etc)
    local run_length = 0

    while true do
        local is_identical = last_pixel_r == current_r
            and last_pixel_g == current_g
            and last_pixel_b == current_b
            and last_pixel_a == current_a

        if not is_identical or run_length >= 62 then
            --id = id - 1

            break
        else
            run_length = run_length + 1
        end

        id = id + 1

        if id > etc.pixel_count then
            break
        end

        etc.get_pixel(id)
    end

    print("QOI_OP_RLE:",run_length)

    if run_length > 0 then
        chunks[#chunks+1] = string_char(QOI_OP_RUN + (run_length-1))
    end

    return run_length > 0,id
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

    print("QOI_OP_INDEX:",color_hash,is_matching)
    if is_matching then
        chunks[#chunks+1] = string_char(QOI_OP_INDEX + byte_hash)
    end

    return is_matching,id
end

local function chunk_qoi_diff_enc(chunks,id)
    if current_a ~= last_pixel_a then
        print("QOI_OP_DIFF: false")

        return false,id
    end

    local delta_r = current_r - last_pixel_r
    local delta_g = current_g - last_pixel_g
    local delta_b = current_b - last_pixel_b

    if delta_r >=  254 then delta_r = delta_r-256 end
    if delta_g >=  254 then delta_g = delta_g-256 end
    if delta_b >=  254 then delta_b = delta_b-256 end
    if delta_r <= -254 then delta_r = delta_r+256 end
    if delta_g <= -254 then delta_g = delta_g+256 end
    if delta_b <= -254 then delta_b = delta_b+256 end

    local diff_viable = delta_r >= -2 and delta_r <= 1
        and delta_g >= -2 and delta_g <= 1
        and delta_b >= -2 and delta_b <= 1

    print("QOI_OP_DIFF:",delta_r,delta_g,delta_b,diff_viable)

    if diff_viable then
        local encoded_diffs =
            (delta_r+2) * 2^4 +
            (delta_g+2) * 2^2 +
            delta_b+2

        chunks[#chunks+1] = string_char(QOI_OP_DIFF + encoded_diffs)
    end

    return diff_viable,id
end

local function chunk_qoi_luma_enc(chunks,id)
    if current_a ~= last_pixel_a then
        print("QOI_OP_LUMA: false")

        return false,id
    end

    local delta_r = current_r - last_pixel_r
    local delta_g = current_g - last_pixel_g
    local delta_b = current_b - last_pixel_b

    local delta_rg = delta_r - delta_g
    local delta_bg = delta_b - delta_g

    if delta_g >=  224 then delta_g = delta_g - 286 end
    if delta_g <= -224 then delta_g = delta_g + 286 end

    if delta_rg >= 248 then delta_rg = delta_rg - 262 end
    if delta_bg >= 248 then delta_bg = delta_bg - 262 end

    local luma_viable = delta_g >= -32 and delta_g <= 31
        and delta_rg >= -8 and delta_rg <= 7
        and delta_bg >= -8 and delta_bg <= 7

    print("QOI_OP_LUMA:",delta_rg,delta_g,delta_bg,luma_viable)

    if luma_viable then
        chunks[#chunks+1] = string_char(QOI_OP_LUMA + delta_g + 32)
            .. string_char(
                delta_bg + 8 +
                bit_lib.lshift(delta_rg + 8,4)
            )
    end

    return luma_viable,id
end

local function chunk_qoi_rgb_enc(chunks,id)
    print("QOI_OP_RGB:",current_a == last_pixel_a)

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
    print("QOI_OP_RGBA: define")

    chunks[#chunks+1] = string_char(QOI_OP_RGBA)
        .. string_char(current_r)
        .. string_char(current_g)
        .. string_char(current_b)
        .. string_char(current_a)

    return true,id
end

local function chunk_qoi_invalid()
    error("Impossible to encode",2)
end

function lua_qoi.encode(image_data,width,height,alpha_channel,output_file)
    local output_stream = ""

    local image_width  = width  or #image_data[#image_data[1]]
    local image_height = height or #image_data[1]

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
        local color_hash = 4 * ((
            r*3 +
            g*5 +
            b*7 +
            a*11
        )%64)

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

    local pixel_type = type(image_data[1][1])
    local math_ceil  = math.ceil
    local function get_pixel(pixel_id)
        local pixel_y = math_ceil(pixel_id/image_width)
        local pixel_x = (pixel_id-1)%image_width+1

        local pixel_info = image_data[pixel_y][pixel_x]

        last_pixel_r,last_pixel_g,last_pixel_b,last_pixel_a =
            current_r,current_g,current_b,current_a

        if pixel_type == "number" then
            current_r,current_g,current_b,current_a =
                math.floor(pixel_info*red_shift_rgb) % byte_band,
                math.floor(pixel_info*grn_shift_rgb) % byte_band,
                math.floor(pixel_info*blu_shift_rgb) % byte_band,
                math.floor(alpha_channel and ((pixel_info*alp_shift_rgb) % byte_band) or 255)
        elseif pixel_type == "table" then
            local scaled_r =  pixel_info[1]       * 255
            local scaled_g =  pixel_info[2]       * 255
            local scaled_b =  pixel_info[3]       * 255
            local scaled_a = (pixel_info[4] or 1) * 255

            current_r,current_g,current_b,current_a =
                scaled_r - scaled_r%1,
                scaled_g - scaled_g%1,
                scaled_b - scaled_b%1,
                alpha_channel and (scaled_a - scaled_a%1) or 255
        end

        print("Getting pixel:",pixel_y,pixel_x,("r:%s g:%s b:%s a:%s"):format(
            current_r,current_g,current_b,current_a
        ))

        write_hashmap(
            current_r,current_g,current_b,current_a
        )
    end

    local qoi_chunk_types = {
        chunk_qoi_run_enc,
        chunk_qoi_index_enc,
        chunk_qoi_diff_enc,
        chunk_qoi_luma_enc,
        chunk_qoi_rgb_enc,
        chunk_qoi_rgba_enc,
        chunk_qoi_invalid
    }

    local chunk_type_cnt = #qoi_chunk_types

    local chunk_encode_args = {
        get_pixel     = get_pixel,
        pixel_hashmap = pixel_hashmap,
        pixel_count   = pixel_count,
    }

    print()
    while current_pixel <= pixel_count do
        get_pixel(current_pixel)

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

        print()

        current_pixel = current_pixel + 1
    end

    output_stream = output_stream .. table.concat(qoi_byte_chunks,"")

    output_stream = encode_qoi_header(
        image_width,image_height,
        alpha_channel and "RGBA" or "RGB",
        "SRGB_LINEAR"
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