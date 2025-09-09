--!strict

-- Minimal test harness
local failures = 0
local checks = 0
local function expectEqual(a: any, b: any, msg: string?)
    checks += 1
    if a ~= b then
        failures += 1
        print("FAIL: " .. (msg or "values not equal") .. string.format("\n  got:   %s\n  want:  %s", tostring(a), tostring(b)))
    else
        print("PASS: " .. (msg or "values equal"))
    end
end

local function expectError(fn: () -> (), msg: string?, contains: string?)
    checks += 1
    local ok, err = pcall(fn)
    if ok then
        failures += 1
        print("FAIL: " .. (msg or "expected error but succeeded"))
        return
    end
    if contains and not tostring(err):find(contains, 1, true) then
        failures += 1
        print("FAIL: error mismatch\n  got:   " .. tostring(err) .. "\n  want:  contains '" .. contains .. "'")
        return
    end
    print("PASS: " .. (msg or "got expected error"))
end

-- Load module (support multiple environments)
local Base64
do
    local ok, mod = pcall(require, "./src")
    if ok and type(mod) == "table" then
        Base64 = mod
    else
        ok, mod = pcall(require, "./src.luau")
        if ok and type(mod) == "table" then
            Base64 = mod
        else
            print(ok, mod)
            error("Unable to load module src.luau")
        end
    end
end

-- Helpers
local function onlyBase64Chars(s: string): boolean
    for i = 1, #s do
        local c = string.byte(s, i)
        local isUpper = (c >= 65 and c <= 90)
        local isLower = (c >= 97 and c <= 122)
        local isDigit = (c >= 48 and c <= 57)
        local isPlus  = (c == 43)
        local isSlash = (c == 47)
        local isEq    = (c == 61)
        if not (isUpper or isLower or isDigit or isPlus or isSlash or isEq) then
            return false
        end
    end
    return true
end

local function encLen(n: number): number
    return ((n + 2) // 3) * 4
end

local function decLenFromB64(s: string): number
    local n = #s
    local pad = 0
    if n >= 1 and string.byte(s, n) == 61 then
        pad = 1
        if n >= 2 and string.byte(s, n - 1) == 61 then pad = 2 end
    end
    return (n // 4) * 3 - pad
end

-- Known vectors (RFC 4648)
local vectors = {
    { "", "" },
    { "f", "Zg==" },
    { "fo", "Zm8=" },
    { "foo", "Zm9v" },
    { "foob", "Zm9vYg==" },
    { "fooba", "Zm9vYmE=" },
    { "foobar", "Zm9vYmFy" },
}

for _, v in ipairs(vectors) do
    local raw, b64 = v[1], v[2]
    print(raw, b64)
    local enc = Base64.encode(raw)
    expectEqual(enc, b64, "encode vector for '" .. raw .. "'")
    local dec = Base64.decode(b64)
    expectEqual(dec, raw, "decode vector for '" .. raw .. "'")
end

-- Additional canonical vectors
do
    local more = {
        { "Man", "TWFu" },
        { "any carnal pleasure.", "YW55IGNhcm5hbCBwbGVhc3VyZS4=" },
        { "any carnal pleasure",  "YW55IGNhcm5hbCBwbGVhc3VyZQ==" },
        { "any carnal pleasur",   "YW55IGNhcm5hbCBwbGVhc3Vy" },
    }
    for _, v in ipairs(more) do
        local raw, b64 = v[1], v[2]
        expectEqual(Base64.encode(raw), b64, "encode canonical '" .. raw .. "'")
        expectEqual(Base64.decode(b64), raw, "decode canonical '" .. raw .. "'")
    end
end

-- Buffer inputs
do
    local raw = "hello world"
    local buf = buffer.fromstring(raw)
    local b64_from_buf = Base64.encode(buf)
    expectEqual(b64_from_buf, "aGVsbG8gd29ybGQ=", "encode buffer input")

    local dec_buf = Base64.decode(buffer.fromstring("aGVsbG8gd29ybGQ="))
    expectEqual(dec_buf, raw, "decode buffer input")
end

-- Null bytes & binary roundtrip
do
    local raw = string.char(0,1,2,3,250,251,252,253,254,255)
    local b64 = Base64.encode(raw)
    local back = Base64.decode(b64)
    expectEqual(back, raw, "roundtrip binary bytes")
end

-- All 256 single-byte values
do
    for b = 0, 255 do
        local s = string.char(b)
        local e = Base64.encode(s)
        expectEqual(#e, encLen(1), "encoded length for 1 byte")
        if not onlyBase64Chars(e) then
            failures += 1; print("FAIL: non-base64 char in single-byte encode for b=" .. b)
        end
        expectEqual(Base64.decode(e), s, "single-byte roundtrip value=" .. b)
    end
end

-- Roundtrip for many small lengths (0..128)
do
    local function makeBytes(n: number): string
        local buf = buffer.create(n)
        for i = 0, n - 1 do buffer.writeu8(buf, i, i % 256) end
        return buffer.tostring(buf)
    end
    for n = 0, 128 do
        local raw = makeBytes(n)
        local enc = Base64.encode(raw)
        local dec = Base64.decode(enc)
        expectEqual(#dec, #raw, "length preserved for n=" .. n)
        expectEqual(dec, raw, "roundtrip for n=" .. n)
        expectEqual(#enc, encLen(#raw), "encoded length matches formula for n=" .. n)
        if not onlyBase64Chars(enc) then
            failures += 1; print("FAIL: non-base64 char for n=" .. n)
        end
    end
end

-- Randomized-like roundtrips for varied sizes (deterministic fill)
do
    local function mk(n: number): string
        local buf = buffer.create(n)
        local WRITE_U32 = buffer.writeu32
        local i = 0
        if WRITE_U32 ~= nil then
            local word = 0xA5A5A5A5
            local limit = n - (n % 4)
            while i < limit do WRITE_U32(buf, i, word); i += 4 end
        end
        while i < n do buffer.writeu8(buf, i, (i * 31) % 256); i += 1 end
        return buffer.tostring(buf)
    end
    local sizes = { 1, 2, 3, 4, 5, 7, 8, 15, 16, 31, 32, 63, 64, 65, 127, 128, 255, 256, 511, 512, 1023, 1024, 4095, 4096 }
    for _, n in ipairs(sizes) do
        local raw = mk(n)
        local encS = Base64.encode(raw)
        local encB = Base64.encode(buffer.fromstring(raw))
        expectEqual(encS, encB, "encode parity string vs buffer size=" .. n)
        local decS = Base64.decode(encS)
        local decB = Base64.decode(buffer.fromstring(encS))
        expectEqual(decS, raw, "roundtrip string path size=" .. n)
        expectEqual(decB, raw, "roundtrip buffer path size=" .. n)
        expectEqual(#encS, encLen(#raw), "length formula size=" .. n)
    end
end

-- Larger roundtrip (256 KiB) to exercise unrolled paths
do
    local n = 256 * 1024
    local buf = buffer.create(n)
    local WRITE_U32 = buffer.writeu32
    local i = 0
    if WRITE_U32 ~= nil then
        local word = 0x01020304
        local limit = n - (n % 4)
        while i < limit do WRITE_U32(buf, i, word); i += 4 end
    end
    while i < n do buffer.writeu8(buf, i, (i % 256)); i += 1 end
    local raw = buffer.tostring(buf)
    local enc = Base64.encode(raw)
    local dec = Base64.decode(enc)
    expectEqual(#dec, #raw, "large length preserved")
    expectEqual(dec, raw, "large roundtrip 256KiB")
end

-- Strict decoding rules
expectError(function()
    Base64.decode("A") -- not multiple of 4
end, "reject non-multiple-of-4 length", "Invalid Base64 length")

expectError(function()
    Base64.decode("****") -- invalid chars
end, "reject invalid characters", "Invalid Base64")

expectError(function()
    Base64.decode("aGVz\nZA==") -- newline not allowed
end, "reject whitespace/newlines", "Invalid Base64")

expectError(function()
    Base64.decode("A===") -- bad padding
end, "reject bad padding pattern", "Invalid Base64")

-- Known valid padding cases
do
    expectEqual(Base64.decode("TWE="), "Ma", "valid single '=' padding")
    expectEqual(Base64.decode("QQ=="), "A", "valid '==' padding")
end

-- More invalid patterns
expectError(function()
    Base64.decode("Zg=") -- bad length and bad padding position
end, "reject short with bad padding")

expectError(function()
    Base64.decode("=AAA") -- '=' cannot appear first in body
end, "reject leading '=' in quartet")

expectError(function()
    Base64.decode("AA=A") -- '=' cannot appear in positions 0..2 in body
end, "reject mid '=' in quartet")

-- Invalid high-ASCII bytes in input (>=128)
expectError(function()
    local bad = string.char(200,200,200,200)
    Base64.decode(bad)
end, "reject high ASCII input", "Invalid Base64")

-- Inject invalid characters into a valid string
do
    local valid = Base64.encode("test data")
    local invalids = { " ", "\n", "\t", "-", "_", "?", "*", "%" }
    for _, ch in ipairs(invalids) do
        local pos = 2 -- inject near the start, not in padding
        local mutated = string.sub(valid, 1, pos - 1) .. ch .. string.sub(valid, pos + 1)
        expectError(function() Base64.decode(mutated) end, "reject invalid char '" .. ch .. "'", "Invalid Base64")
    end
end

-- Repeated encode determinism
do
    local raw = "determinism-check-1234567890"
    local e1 = Base64.encode(raw)
    local e2 = Base64.encode(raw)
    expectEqual(e1, e2, "encode deterministic for same input")
end

if failures == 0 then
    print(string.format("OK: all tests passed (%d checks)", checks))
else
    error(string.format("Tests failed: %d of %d checks", failures, checks))
end
