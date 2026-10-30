--[[
================================================================================
 DeoX Console v2 — desofuscador de triagem para executor Roblox
================================================================================

 O QUE ESTE SCRIPT FAZ
   1. Lê o script ofuscado (clipboard, DEOX_SOURCE, ou deox_input.lua).
   2. Identifica o ofuscador por assinatura + heurística estrutural.
   3. Decodifica tabelas de strings base64 (padrão e alfabeto customizado).
   4. Para Prometheus/WeAreDevs: corre um TRACER em ambiente falso que regista
      GetService, chamadas, atribuições, print, callbacks, loadstring, getfenv.
   5. Traduz o trace para LUAU LEGÍVEL (não é o source original — é o que o
      script FAZ, reconstruído como código).
   6. Para Luraph/Hercules/IronBrew/MoonSec: extrai strings e reformata o
      código, marcando o que NÃO foi revertido (VM intacta).
   7. Barra 0-100%. Ao 100%, imprime o resultado em partes no console.

 O QUE ESTE SCRIPT NÃO FAZ
   - Não devirtualiza Luraph v15, IronBrew2, MoonSec V3 nem Hercules. Esses
     exigem emulador de bytecode escrito em Python/Node/C#, fora do executor.
   - Não carrega repos do GitHub via loadstring. Nenhum desses repos é Lua:
       Prometheus/WeAreDevs  -> hutaoshusband/Prometheus-WeAre-Devs-Dumper (Python)
       Prometheus/MoonSec    -> 0x251/Prometheus-DeobfuscatorV2 (Lua 5.1)
       Luraph v14.7-v15.1    -> caomod2077/Deobfuscator-Luraph-V15 (Node+Python)
       Luraph v14.7-v15.1    -> larpcorrupt/luraph-v15-v14.x-deobfuscator (Python)
       IronBrew2             -> pirateware/IronbrewDeobfuscator (C# .NET)
       MoonSec V3            -> tupsutumppu/MoonsecDeobfuscator (C# .NET)
   - Não é sandbox 100%. O ambiente falso é tabela com metatables; se o script
     escapar via debug/rawget, pode tocar no executor. Só analisa o que queres.

 COMO USAR
   1. Copia o script ofuscado (Ctrl+A, Ctrl+C).
   2. Executa este ficheiro no executor. Se tiver getclipboard(), pega sozinho.
      Senão, cola dentro de DEOX_SOURCE abaixo.
   3. Vê a barra 0-100%. Ao 100%, o resultado sai em partes no console.
   4. Copia as partes NA ORDEM para um editor (VS Code, Notepad++).

================================================================================
]]

-- ============================================================================
-- 0) CONFIGURAÇÃO
-- ============================================================================
local DEOX_SOURCE = [==[
-- cole aqui o script ofuscado se o executor não tiver getclipboard()
]==]

local CFG = {
  MAX_OPS          = 250000,
  MAX_LINES        = 6000,
  MAX_TRACE_FUNCS  = 60,
  CHUNK_CHARS      = 1800,
  PROGRESS_BARW    = 30,
  HIDE_CAMELCASE   = false,
  DECODER_SHOW_MAX = 80,
  TRACE_SHOW_MAX   = 400,
  BEAUTIFY_MAX     = 120000,
}

-- ============================================================================
-- 1) CONSOLE / PROGRESSO
-- ============================================================================
local Console = {}
function Console.line(ch, n) print(string.rep(ch or "-", n or 64)) end
function Console.title(s)
  Console.line("=", 64)
  print("  " .. s)
  Console.line("=", 64)
end

local Progress = { stage = "", pct = 0, last = -1 }
function Progress.bar(pct)
  pct = math.clamp(pct, 0, 100)
  local filled = math.floor(CFG.PROGRESS_BARW * pct / 100)
  return "[" .. string.rep("#", filled) .. string.rep("-", CFG.PROGRESS_BARW - filled)
         .. string.format("] %3d%%", pct)
end
function Progress.set(stage, pct)
  pct = math.floor(math.clamp(pct, 0, 100))
  Progress.stage, Progress.pct = stage, pct
  if pct ~= Progress.last then
    Progress.last = pct
    print(("DeoX  %s  %s"):format(Progress.bar(pct), stage))
  end
end
function Progress.sweep(stage, from, to, steps)
  steps = steps or 5
  for i = 1, steps do
    local p = from + (to - from) * (i / steps)
    Progress.set(stage, p)
    if task and task.wait then task.wait(0.02) elseif wait then wait(0.02) end
  end
end

-- ============================================================================
-- 2) ENTRADA
-- ============================================================================
local function get_source()
  local ok, clip = pcall(function() return getclipboard and getclipboard() end)
  if ok and clip and #clip > 20 and not clip:match("^%-%-%s*cole aqui") then
    return clip, "clipboard"
  end
  if DEOX_SOURCE and #DEOX_SOURCE:gsub("%s+", "") > 20
     and not DEOX_SOURCE:match("^%-%-%s*cole aqui") then
    return DEOX_SOURCE, "DEOX_SOURCE"
  end
  local ok2, data = pcall(function()
    return readfile and readfile("deox_input.lua")
  end)
  if ok2 and data and #data > 20 then
    return data, "deox_input.lua"
  end
  return nil, nil
end

-- ============================================================================
-- 3) DETECÇÃO DO OFUSCADOR
-- ============================================================================
local Signatures = {
  { name = "Luraph v15",             pat = "Luraph Obfuscator v15" },
  { name = "Luraph v14.9",           pat = "Luraph Obfuscator v14%.9" },
  { name = "Luraph v14.8",           pat = "Luraph Obfuscator v14%.8" },
  { name = "Luraph v14.7",           pat = "Luraph Obfuscator v14%.7" },
  { name = "Luraph (sem banner)",    pat = "^%s*local init = %(function%(%.%.%." },
  { name = "Hercules",               pat = "Obfuscated by Hercules" },
  { name = "Ironveil",               pat = "ronveil" },
  { name = "IronBrew",               pat = "IronBrew" },
  { name = "Prometheus/WeAreDevs",   pat = "wearedevs%.net/obfuscator" },
  { name = "MoonSec",                pat = "MoonSec" },
}

local function detect(src)
  local head = src:sub(1, 4000)
  local tail = src:sub(-4000)
  for _, s in ipairs(Signatures) do
    if head:find(s.pat) or tail:find(s.pat) then return s.name, "assinatura" end
  end
  if tail:find("getfenv and getfenv%(%)%s*or%s*_ENV") then
    return "Prometheus/WeAreDevs", "estrutural"
  end
  if head:match("^%s*local%s+init%s*=%s*%(%s*function") then
    return "Luraph (sem cabeçalho)", "estrutural"
  end
  if head:find("\\27Lua") or head:find("LuaQ") or head:find("LuaS") then
    return "IronBrew (provável)", "heurística"
  end
  return "desconhecido / genérico", "nenhuma"
end

-- ============================================================================
-- 4) DECODER BASE64
-- ============================================================================
local Decoder = {}
local STD_ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64_decode(data, alphabet)
  alphabet = alphabet or STD_ALPHA
  local rev = {}
  for i = 1, #alphabet do rev[alphabet:sub(i, i)] = i - 1 end
  data = data:gsub("[^" .. alphabet:gsub("%W", "%%%1") .. "=]", "")
  local out = {}
  for i = 1, #data, 4 do
    local a, b, c, d = data:sub(i, i), data:sub(i+1, i+1), data:sub(i+2, i+2), data:sub(i+3, i+3)
    local va, vb = rev[a], rev[b]
    if not va or not vb then break end
    local vc, vd = rev[c], rev[d]
    local n = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
    local c1 = math.floor(n / 65536) % 256
    local c2 = math.floor(n / 256) % 256
    local c3 = n % 256
    out[#out+1] = string.char(c1)
    if c ~= "=" and c ~= "" then out[#out+1] = string.char(c2) end
    if d ~= "=" and d ~= "" then out[#out+1] = string.char(c3) end
  end
  return table.concat(out)
end

local function printable_ratio(s)
  if #s == 0 then return 0 end
  local good = 0
  for i = 1, #s do
    local b = s:byte(i)
    if (b >= 32 and b < 127) or b == 9 or b == 10 or b == 13 then good = good + 1 end
  end
  return good / #s
end

local function find_b64_candidates(src)
  local out, seen = {}, {}
  for s in src:gmatch('"([A-Za-z0-9+/=]+)"') do
    if #s >= 16 and not seen[s] then seen[s] = true; out[#out+1] = s end
  end
  for s in src:gmatch("'([A-Za-z0-9+/=]+)'") do
    if #s >= 16 and not seen[s] then seen[s] = true; out[#out+1] = s end
  end
  return out
end

local function find_custom_alphabets(src)
  local out = {}
  for s in src:gmatch('"([^"\n]+)"') do
    if #s == 64 or #s == 65 then
      local set, ok = {}, true
      for i = 1, #s do
        local c = s:sub(i, i)
        if set[c] then ok = false; break end
        set[c] = true
      end
      if ok then out[#out+1] = s end
    end
  end
  return out
end

function Decoder.run(src)
  local report = {}
  local cands = find_b64_candidates(src)
  local alphabets = find_custom_alphabets(src)
  table.insert(alphabets, 1, STD_ALPHA)
  local shown, hits = 0, 0
  for _, cand in ipairs(cands) do
    if shown >= CFG.DECODER_SHOW_MAX then break end
    local best, bestAlpha, bestScore = nil, nil, -1
    for _, alpha in ipairs(alphabets) do
      local ok, dec = pcall(b64_decode, cand, alpha)
      if ok and #dec > 0 then
        local score = printable_ratio(dec)
        if score > bestScore then best, bestAlpha, bestScore = dec, alpha, score end
      end
    end
    if best and bestScore > 0.85 then
      hits = hits + 1; shown = shown + 1
      local preview = best:gsub("[\r\n]", " "):sub(1, 110)
      local which = (bestAlpha == STD_ALPHA) and "b64" or "b64-custom"
      report[#report+1] = string.format("  [%s] %q", which, preview)
    end
  end
  return report, #cands, hits
end

-- ============================================================================
-- 5) BEAUTIFY — sem goto/labels (Lua 5.1 safe)
-- ============================================================================
local Beautify = {}
local OPEN_KW  = { ["do"]=1, ["then"]=1, ["else"]=1, ["repeat"]=1, ["function"]=1 }
local CLOSE_KW = { ["end"]=1, ["until"]=1 }
local MID_KW   = { ["elseif"]=1, ["else"]=1 }

function Beautify.run(src)
  if #src > CFG.BEAUTIFY_MAX then
    return src:sub(1, CFG.BEAUTIFY_MAX) .. "\n-- ...[truncado: " .. (#src - CFG.BEAUTIFY_MAX) .. " chars]"
  end
  local out, i, n = {}, 1, #src
  local indent = 0
  local function put(s) out[#out+1] = s end
  local function nl() put("\n" .. string.rep("  ", math.max(indent, 0))) end

  while i <= n do
    local c = src:sub(i, i)
    local advanced = false

    local lcs = src:match("^%-%-%[(=*)%[", i)
    if lcs then
      local closePat = "%]" .. lcs .. "%]"
      local s, e = src:find(closePat, i)
      put(src:sub(i, e or n)); i = (e or n) + 1
      advanced = true
    end

    if not advanced and src:sub(i, i+1) == "--" then
      local e = src:find("\n", i) or (n + 1)
      put(src:sub(i, e - 1)); i = e
      advanced = true
    end

    if not advanced then
      local lss = src:match("^%[(=*)%[", i)
      if lss and not src:sub(math.max(1, i-1), i-1):match("[%w_]") then
        local closePat = "%]" .. lss .. "%]"
        local s, e = src:find(closePat, i)
        put(src:sub(i, e or n)); i = (e or n) + 1
        advanced = true
      end
    end

    if not advanced and (c == '"' or c == "'") then
      local q, j, buf = c, i + 1, { c }
      while j <= n do
        local cj = src:sub(j, j)
        buf[#buf+1] = cj
        if cj == "\\" then j = j + 1; buf[#buf+1] = src:sub(j, j)
        elseif cj == q then j = j + 1; break end
        j = j + 1
      end
      put(table.concat(buf)); i = j
      advanced = true
    end

    if not advanced then
      local word = src:match("^[%a_][%w_]*", i)
      if word then
        if CLOSE_KW[word] or MID_KW[word] then indent = math.max(indent - 1, 0) end
        put(word); i = i + #word
        if OPEN_KW[word] and word ~= "function" then
          indent = indent + 1; nl()
        elseif word == "function" then
          indent = indent + 1
        elseif CLOSE_KW[word] or MID_KW[word] then
          if MID_KW[word] then indent = indent + 1 end
          nl()
        end
        advanced = true
      end
    end

    if not advanced then
      if c == ";" then
        put(";"); i = i + 1; nl()
      else
        put(c); i = i + 1
      end
    end
  end

  local text = table.concat(out)
  text = text:gsub("[ \t]+\n", "\n"):gsub("\n\n\n+", "\n\n")
  return text
end

-- ============================================================================
-- 6) TRACER — ambiente falso
-- ============================================================================
local Tracer = {}

function Tracer.run(src)
  local OUT, REP, BLOCK = {}, {}, {}
  local indent = ""
  local ops = 0
  local BUDGET = setmetatable({}, { __tostring = function() return "limite do tracer" end })

  local function tick()
    ops = ops + 1
    if ops > CFG.MAX_OPS then error(BUDGET, 0) end
    if ops % 5000 == 0 then
      Progress.set("rastreando comportamento...", math.min(95, 45 + math.floor(ops / CFG.MAX_OPS * 45)))
    end
  end

  local function collapse()
    local total = #OUT
    for p = 1, 4 do
      if total >= 3 * p then
        local same = true
        for k = 0, p - 1 do
          if OUT[total-k] ~= OUT[total-p-k] or OUT[total-p-k] ~= OUT[total-2*p-k] then
            same = false; break
          end
        end
        if same then
          for k = 0, p - 1 do OUT[total-k] = nil end
          local e = total - p
          REP[e] = (REP[e] or 0) + 1
          BLOCK[e] = p
          return e
        end
      end
    end
  end

  local function log(s)
    if #OUT >= CFG.MAX_LINES then error(BUDGET, 0) end
    OUT[#OUT+1] = indent .. s
    return collapse() or #OUT
  end

  local KEYWORDS = {}
  for w in ("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"):gmatch("%a+") do
    KEYWORDS[w] = true
  end
  local function isident(k)
    return type(k) == "string" and k:match("^[%a_][%w_]*$") and not KEYWORDS[k]
  end

  local reg = setmetatable({}, { __mode = "k" })
  local mt = {}
  local nvar = 0
  local expr

  local function fmtv(v, seen)
    local t = type(v)
    if t == "string" then
      local s = v
      if #s > 1500 then s = s:sub(1, 1500) .. "...[+" .. (#v - 1500) .. "b]" end
      return string.format("%q", s)
    elseif t == "number" or t == "boolean" or t == "nil" then
      return tostring(v)
    elseif t == "function" then
      return "function(...) end"
    elseif t == "table" then
      if reg[v] then return expr(v) end
      seen = seen or {}
      if seen[v] then return "{...}" end
      seen[v] = true
      local parts, count = {}, 0
      for k2, v2 in pairs(v) do
        count = count + 1
        if count > 8 then parts[#parts+1] = "..."; break end
        local ks = isident(k2) and k2 or ("[" .. fmtv(k2, seen) .. "]")
        parts[#parts+1] = ks .. "=" .. fmtv(v2, seen)
      end
      seen[v] = nil
      return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
  end

  expr = function(p)
    local info = reg[p]
    if info.name then return info.name end
    if info.root then return info.root end
    if info.line then
      nvar = nvar + 1
      info.name = "v" .. nvar
      if OUT[info.line] then
        OUT[info.line] = OUT[info.line]:gsub("^(%s*)", "%1local " .. info.name .. " = ", 1)
      end
      return info.name
    end
    local base = expr(info.parent)
    if isident(info.key) then return base .. "." .. info.key end
    return base .. "[" .. fmtv(info.key) .. "]"
  end

  local function newp(info)
    local p = setmetatable({}, mt)
    reg[p] = info
    return p
  end

  local cbcount, depth = 0, 0
  local function runcb(f, label)
    if cbcount >= CFG.MAX_TRACE_FUNCS or depth >= 4 then return end
    cbcount = cbcount + 1
    log("-- [callback] " .. label)
    indent = indent .. "  "; depth = depth + 1
    local ok, err = pcall(f, newp({ root = "a1" }), newp({ root = "a2" }), newp({ root = "a3" }))
    depth = depth - 1; indent = indent:sub(1, -3)
    if not ok and err ~= BUDGET then
      log("-- (erro no callback: " .. tostring(err):sub(1, 150) .. ")")
    elseif not ok then error(BUDGET, 0) end
    log("-- [/callback]")
  end

  mt.__index = function(self, k)
    tick()
    if k == nil then return nil end
    local info = reg[self]
    info.kids = info.kids or {}
    if info.kids[k] ~= nil then return info.kids[k] end
    local c = newp({ parent = self, key = k })
    info.kids[k] = c
    return c
  end
  mt.__newindex = function(self, k, v)
    tick()
    local base = expr(self)
    log((isident(k) and (base .. "." .. k) or (base .. "[" .. fmtv(k) .. "]")) .. " = " .. fmtv(v))
    local info = reg[self]
    info.kids = info.kids or {}
    info.kids[k] = v
  end
  mt.__call = function(self, ...)
    tick()
    local info = reg[self]
    local args, n2 = { ... }, select("#", ...)
    local callee, first = nil, 1
    if info.parent and n2 >= 1 and args[1] == info.parent and isident(info.key) then
      callee, first = expr(info.parent) .. ":" .. info.key, 2
    else
      callee = expr(self)
    end
    local parts, cbs = {}, {}
    for i2 = first, n2 do
      local a = args[i2]
      if type(a) == "function" then
        cbs[#cbs+1] = a
        parts[#parts+1] = "function(...) --[[cb#" .. #cbs .. "]] end"
      else
        parts[#parts+1] = fmtv(a)
      end
    end
    local idx = log(callee .. "(" .. table.concat(parts, ", ") .. ")")
    for ci, f in ipairs(cbs) do runcb(f, callee .. " cb#" .. ci) end
    return newp({ line = idx })
  end

  local function binop(sym)
    return function(a, b) return newp({ root = "(" .. fmtv(a) .. sym .. fmtv(b) .. ")" }) end
  end
  mt.__add, mt.__sub, mt.__mul, mt.__div = binop("+"), binop("-"), binop("*"), binop("/")
  mt.__concat, mt.__lt, mt.__le = binop(".."), function() return false end, function() return false end

  local E = {}
  local function copy(t) local r = {}; if t then for k2, v2 in pairs(t) do r[k2] = v2 end end; return r end
  for _, nm in ipairs({ "assert", "error", "ipairs", "next", "pairs", "rawequal", "rawget", "rawset",
    "select", "setmetatable", "getmetatable", "tonumber", "tostring", "type" }) do
    E[nm] = _G[nm]
  end
  E.unpack = table.unpack or unpack
  for _, nm in ipairs({ "string", "table", "math" }) do E[nm] = copy(_G[nm]) end
  E._VERSION, E._G = _VERSION, E
  E.pcall = function(f, ...)
    local r = { pcall(f, ...) }
    if r[1] == false and r[2] == BUDGET then error(BUDGET, 0) end
    return E.unpack(r)
  end
  E.print = function(...)
    tick()
    local parts = {}
    for i2 = 1, select("#", ...) do parts[#parts+1] = fmtv((select(i2, ...))) end
    log("print(" .. table.concat(parts, ", ") .. ")")
  end
  E.warn = E.print
  E.getfenv = function() return E end
  E.setfenv = function(f) return f end
  E.loadstring = function(code, name)
    tick()
    log("loadstring(" .. fmtv((code or ""):sub(1, 200)) .. ")")
    return function() end
  end
  E.load = E.loadstring
  local function randomlike(k)
    if not CFG.HIDE_CAMELCASE then return false end
    if type(k) ~= "string" then return false end
    return (k:match("%l") and k:match("%u") and (#k >= 6)) and true or false
  end
  local NILS = { newproxy = true, bit32 = true, bit = true, utf8 = true, jit = true }
  setmetatable(E, {
    __index = function(_, k)
      tick()
      if NILS[k] or k == nil or randomlike(k) then return nil end
      local p = newp({ root = tostring(k) })
      rawset(E, k, p)
      return p
    end,
    __newindex = function(t, k, v)
      if not randomlike(k) then log(tostring(k) .. " = " .. fmtv(v)) end
      rawset(t, k, v)
    end,
  })

  local fn, cerr
  if setfenv then
    fn, cerr = loadstring(src, "=script")
    if fn then setfenv(fn, E) end
  else
    fn, cerr = load(src, "=script", "t", E)
  end
  if not fn then
    return nil, "o script não compila: " .. tostring(cerr)
  end
  Progress.set("executando em ambiente falso...", 50)
  local ok, e = pcall(fn)
  local status = "concluído"
  if not ok then
    status = (e == BUDGET) and "interrompido (limite de ops — possível loop)"
            or ("terminou com erro: " .. tostring(e):sub(1, 200))
  end

  local lines = {}
  for idx, l in ipairs(OUT) do
    lines[#lines+1] = l
    if REP[idx] then
      lines[#lines+1] = "-- ^ (as " .. BLOCK[idx] .. " linha(s) acima repetiram mais " .. REP[idx] .. "x)"
    end
  end
  return table.concat(lines, "\n"), status
end

-- ============================================================================
-- 7) BUILDER — monta o Luau final
-- ============================================================================
local Builder = {}

function Builder.for_prometheus(trace, status, kind)
  return table.concat({
    "-- DeoX Console v2 · Luau reconstruído a partir de trace",
    "-- ofuscador: " .. kind,
    "-- status: " .. status,
    "-- NOTA: isto é o COMPORTAMENTO do script, não o source original.",
    "--       A VM do Prometheus/WeAreDevs não foi revertida; o que segue é",
    "--       o que o script FAZ quando executado em ambiente falso.",
    "",
    "local function trace()",
    trace,
    "end",
    "",
    "return trace",
  }, "\n")
end

function Builder.for_static(pretty, kind, decodedReport, hits)
  local parts = {
    "-- DeoX Console v2 · código reformatado (" .. kind .. ")",
    "-- NOTA: a VM não foi revertida. Isto é o código original reformatado.",
    "--       Para devirtualização real, usa ferramenta externa (ver cabeçalho).",
    "",
  }
  if hits > 0 then
    parts[#parts+1] = "-- Strings decodificadas (" .. hits .. " de um total de candidatos):"
    for _, l in ipairs(decodedReport) do parts[#parts+1] = l end
    parts[#parts+1] = ""
  end
  parts[#parts+1] = pretty
  return table.concat(parts, "\n")
end

-- ============================================================================
-- 8) SAÍDA EM PARTES
-- ============================================================================
local function print_chunks(text, label)
  Console.title(label .. " — " .. #text .. " caracteres")
  local total = math.ceil(#text / CFG.CHUNK_CHARS)
  for i = 1, total do
    local s = (i - 1) * CFG.CHUNK_CHARS + 1
    local chunk = text:sub(s, s + CFG.CHUNK_CHARS - 1)
    print(("--==[ PARTE %d/%d ]==--"):format(i, total))
    print(chunk)
  end
  Console.line("=", 64)
  print(("Pronto. Copia as %d partes, NA ORDEM, para um editor."):format(total))
end

-- ============================================================================
-- 9) PROGRAMA PRINCIPAL
-- ============================================================================
local function main()
  Console.title("DeoX Console v2 — triagem, tracing e reconstrução Luau")
  Progress.set("lendo entrada...", 2)

  local src, from = get_source()
  if not src then
    print("Nenhum script encontrado.")
    print("→ Usa getclipboard(), cola em DEOX_SOURCE, ou põe deox_input.lua na raiz.")
    return
  end
  print(("Lido de: %s (%d caracteres)"):format(from, #src))
  Progress.sweep("lendo entrada...", 2, 8, 3)

  Progress.set("identificando ofuscador...", 10)
  local kind, how = detect(src)
  print(("Tipo: %s  (detetado por %s)"):format(kind, how))
  Progress.sweep("identificando ofuscador...", 10, 20, 3)

  Progress.set("procurando strings base64...", 22)
  local decRep, totalCand, hits = Decoder.run(src)
  Progress.sweep("procurando strings base64...", 22, 38, 4)
  print(("Strings candidatas: %d · decodificadas: %d"):format(totalCand, hits))

  local finalText, statusMsg

  if kind == "Prometheus/WeAreDevs" then
    Progress.set("rastreando comportamento...", 42)
    local trace, status = Tracer.run(src)
    Progress.sweep("rastreando comportamento...", 42, 90, 6)
    if trace then
      finalText = Builder.for_prometheus(trace, status, kind)
      statusMsg = status
    else
      print("Tracer falhou: " .. tostring(status))
    end
  end

  if not finalText then
    Progress.set("formatando código...", 55)
    local ok, pretty = pcall(Beautify.run, src)
    Progress.sweep("formatando código...", 55, 95, 6)
    if ok then
      finalText = Builder.for_static(pretty, kind, decRep, hits)
      statusMsg = "reformatado"
    else
      finalText = src
      statusMsg = "original (beautify falhou: " .. tostring(pretty) .. ")"
    end
  end

  Progress.set("concluído", 100)
  print(("Resultado: %s"):format(statusMsg))
  print(("Tamanho final: %d caracteres"):format(#finalText))

  local saved = false
  pcall(function()
    if writefile then
      writefile("deox_output.lua", finalText)
      saved = true
    end
  end)
  if saved then print("Guardado também em deox_output.lua") end

  print_chunks(finalText, "LUAU FINAL")
end

local ok, err = pcall(main)
if not ok then
  print("DeoX Console v2: erro inesperado — " .. tostring(err))
end
