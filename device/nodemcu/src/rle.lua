
local function encode(getter, writer)
    local current = nil
    local len = 0
    local function flush()
        if len == 0 then
            -- Nothing to do
        elseif len == 1 and current ~= 255 then
            writer(string.char(current))
        else
            writer(string.char(255, len, current))
        end
        len = 0
        current = nil
    end

    while true do
        local ch = getter()
        if ch == nil then
            flush()
            break
        end
        if current == nil then
            current = ch
            len = 1
        elseif ch == current and len < 255 then
            len = len + 1
        else
            flush()
            current = ch
            len = 1
        end
    end
end

local function beginDecode(getter)
    local ctx = {
        getter = getter,
        current = nil,
        len = 0
    }
    return ctx
end

local function getByte(ctx)
    if ctx.len > 0 then
        ctx.len = ctx.len - 1
        return ctx.current
    end
    local b = ctx.getter()
    if b == nil then
        return nil
    elseif b == 255 then
        ctx.len = ctx.getter() - 1 -- as we are going to take a byte immediately
        ctx.current = ctx.getter()
        return ctx.current
    else
        return b
    end
end

local function decode(getter, writer)
    local ctx = beginDecode(getter)
    while true do
        local b = getByte(ctx)
        if b == nil then break end
        writer(string.char(b))
    end
end

local function skip(ctx, numBytes)
    for i = 1, numBytes do
        getByte(ctx)
    end
end

local function processFile(input, output, fn)
    local f = assert(io.open(input, "rb"))
    local outf = assert(io.open(output, "wb"))

    local function read()
        local ch = f:read(1)
        if ch then
            return string.byte(ch)
        else
            return nil
        end
    end
    local function write(s)
        outf:write(s)
    end
    fn(read, write)
    outf:close()
    f:close()
end

local function encodeFile(input, output)
    processFile(input, output, encode)
end

local function decodeFile(input, output)
    processFile(input, output, decode)
end

if arg then
    if arg[1] == "-d" then
        decodeFile(arg[2], arg[3])
    else
        encodeFile(arg[1], arg[2])
    end
else
    return {
        beginDecode = beginDecode,
        getByte = getByte,
        skip = skip,
    }
end
