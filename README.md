# LuaQOI

Lua libary for decoding an encoding [.qoi](https://qoiformat.org) images on a similar level to FFMPEG/GIMP/IM.

#### Decoder arguments:
`qoid.decode(data_source,[no_alpha])` -> `[table]`
- data_source`[table]` list in some way representing data given to the decoder, can have 3 entries
    - `data`: raw binary string of image data
    - `file`: path to an image file
    - `handle`: binary file handle (QOI_D closes this handle)
- no_alpha`[boolean]`: if an image has an alpha channel, this strips it (useful for easier handling of hexadecimal output data), defaults to `false`
#### Decoder result `[table]`
- width`[u32]`: Width of the decoded image
- height`[u32]`: Height of the decoded image
- pixels`[table]`: 2D array[y][x] storing all the pixel colors encoded as hex
- channels`[string]`: Either `"RGB"` or `"RGBA"`
- colorspace`[string]`: Either `"SRGB_LINEAR_ALPHA"` or `"SRGB_LINEAR"`

---

#### Encoder arguments:
`qoie.encode(image_data,[width],[height],[alpha_channel],[output_file],[colorspace])` -> `[string]`
- image_data`[table]`: 2D array[y][x] containing all the pixels we want to encode into the QOI (either as hex or 3/4 entry tables, 4 entries used for alpha/transparency)
- width`[u32]`: Desired width of the encoded image, defaults to the length of the first image row (`#image_data[1]`)
- height`[u32]`: Desired height of the encoded image, defualts to the row count of image_data (`#image_data`)
- alpha_channel`[boolean]`: Enables alpha channel encoding on the image, hex format: `0xRRGGBBAA`, defaults to `false`
- output_file`[string]`: Automatically saves the resulting binary string to a file given a path, defaults to no file saving.
- colorspace`[string]`: QOI image colorspace, defaults to SRGB_LINEAR_ALPHA.

#### Encoder result `[string]`
- A binary string containing all of the image data, can be saved to a file via binary file handle.

### Example [decoder](./qoi_d.lua) usage:
```lua
local img_src = select(1,...)
local pixel_x = tonumber(select(2,...))
local pixel_y = tonumber(select(3,...))

local qoid = require("qoi_d")

local decoded = qoid.decode({file=img_src})

local color_hex = decoded.pixels[pixel_y][pixel_x]

print(("Pixel at %s:%s is #%x"):format(
    pixel_x,pixel_y,
    color_hex
))
```

### Example [encoder](./qoi_e.lua) usage
```lua
local qoie = require("qoi_e")

local data = {
    {0xFF0000,0x0000FF},
    {0x00FFFF,0xFFFF00}
}

local dat = qoie.encode(data)
```
or something like this
```lua
local qoie = require("qoi_e")

local data = {
    {0xFF0000,0x0000FF},
    {0x00FFFF,0xFFFF00},
    {0x0000FF,0xFF0000}
}

qoie.encode(data,2,3,false,"epic_output.ppm")
```