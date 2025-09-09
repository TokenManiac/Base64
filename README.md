
# Base64 (Luau) — ultra‑fast, pure Luau

Lightning‑fast Base64 for Luau that runs entirely in pure Luau using the `buffer` APIs. It is built for throughput on large payloads and low overhead on small ones.

## Why is it this fast?

The module is architected to minimize interpreter work per byte by batching memory access, replacing arithmetic with table lookups, unrolling loops, and eliminating string concatenation in the hot path. Those choices, visible in `src.luau`, are precisely where most Luau Base64 implementations pay their runtime costs.

## Compared to other Luau Base64 libraries

- Fewer calls per byte: Typical implementations do per‑byte `string.byte`/`string.char` or `bit32` ops, building output via concatenation or `table.concat`. This implementation does wide `buffer.readu32`/`writeu32` with pairwise LUTs, cutting calls and branches dramatically.
- Better cache behavior: Large, contiguous buffers and sequential access minimize interpreter overhead and improve cache locality versus per‑char loops.
- Precomputation over work: Heavier one‑time tables replace repeated arithmetic in the hot path. Memory tradeoff yields much higher steady‑state throughput.
- Early validation, low overhead: Decode validates 2 chars at a time (including `=` handling) and reconstructs bytes with precomputed pieces, avoiding slow path conditionals in the body.

## API

- encode(input: `string | buffer`): `string` — Standard Base64 (A–Z, a–z, 0–9, `+`, `/`).
- decode(input: `string | buffer`): `string` — Returns the decoded bytes as a Luau string. Errors on invalid input or non‑multiples of 4.

## Usage

```luau
local Base64 = require("./base64") -- rename as needed

local s = "hello world"
local b64 = Base64.encode(s)
print(b64) -- aGVsbG8gd29ybGQ=

local raw = Base64.decode(b64)
print(raw) -- hello world

-- You can also pass buffers directly
local buf = buffer.fromstring(s)
local b64b = Base64.encode(buf)
```

## Notes

- Standard alphabet only: Uses `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/` and `=` padding. URL‑safe variants are not included (`src.luau:13`–`src.luau:18`).
- Strict decoding: Length must be a multiple of 4; invalid characters raise `"Invalid Base64"`. Whitespace and line breaks are not ignored (`src.luau:186`, `src.luau:249`–`src.luau:273`).
- Environment: Requires Luau `buffer` APIs. The hot path uses `readu32/writeu32` when available; otherwise it falls back to `u16/u8` operations with the same API (`src.luau:103`, `src.luau:226`).

## Performance model (from code)

- Encode per 3 bytes: 1× `READ_U32` + 2 LUT reads + 1× `WRITE_U32`.
- Decode per 4 chars: 1× `READ_U32` + 2 LUT reads + 3 tiny LUT reads + 3 byte stores.
- Body fully unrolled for throughput; tails are minimal and predictable.

## Implementation map

- Alphabet and tables: `src.luau:13`–`src.luau:85`.
- Encoder: `src.luau:94`–`src.luau:180`.
- Decoder: `src.luau:183`–`src.luau:277`.
- Public API exports: `src.luau:279`–`src.luau:291`.

~ GPT-5
