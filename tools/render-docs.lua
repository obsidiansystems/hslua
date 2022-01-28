local ipairs, pairs, type = ipairs, pairs, type
local debug, string, table = debug, string, table
local _G = _G

_ENV = pandoc

local get = function (fieldname)
  return function (obj) return obj[fieldname] end
end

local function read_blocks (txt)
  return read(txt, 'commonmark').blocks
end

local function read_inlines (txt)
  return utils.blocks_to_inlines(read_blocks(txt))
end

local function argslist (parameters)
  local required = List{}
  local optional = List{}
  for i, param in ipairs(parameters) do
    if param.optional then
      optional:insert(param.name)
    else
      required:extend(optional)
      required:insert(param.name)
      optional = List{}
    end
  end
  if #optional == 0 then
    return table.concat(required, ', ')
  end
  return table.concat(required, ', ')
    .. '[, ' .. table.concat(optional, '[, ') .. string.rep(']', #optional)
end

local function render_results (results)
  if type(results) == 'string' then
    return read_blocks(results)
  elseif type(results) == 'table' then
    return {BulletList(
      List(results):map(
        function (res)
          return Para(
            read_inlines(res.description)
            .. {Space()}
            .. Inlines('(' .. res.type .. ')')
          )
        end
      )
    )}
  else
    return Blocks{}
  end
end

local function render_function (doc, level, modulename)
  local name = doc.name
  level = level or 1
  local id = modulename and modulename .. '.' .. doc.name or ''
  local args = argslist(doc.parameters)
  local paramlist = DefinitionList(
    List(doc.parameters):map(
      function (p) return {{Str(p.name)}, {read_blocks(p.description)}} end
    )
  )
  return Blocks{
    Header(level, name, {id}),
    Plain{Code(string.format('%s (%s)', name, args))},
  } .. read_blocks(doc.description)
    .. List(#doc.parameters > 0 and {Header(level+1, 'Parameters')} or {})
    .. List{paramlist}
    .. List(#doc.results > 0 and {Header(level + 1, 'Returns')} or {})
    .. render_results(doc.results)
end

local function render_field (field, level, modulename)
  local id = modulename and modulename .. '.' .. field.name or ''
  return {Header(level, field.name, {id})} .. read_blocks(field.description)
end

local function render_module (doc)
  local fields = Blocks{}
  if #doc.fields then
    fields:insert(Header(2, 'Fields', {doc.name .. '-' .. 'fields'}))
    for i, fld in ipairs(doc.fields) do
      fields:extend(render_field(fld, 3, doc.name))
    end
  end

  local functions = Blocks{}
  if #doc.functions > 0 then
    functions:insert(Header(2, 'Functions', {doc.name .. '-' .. 'functions'}))
    for i, fun in ipairs(doc.functions) do
      functions:extend(render_function(fun, 3, doc.name))
    end
  end

  return Blocks{
    Header(1, doc.name, {'module-' .. doc.name})
  } .. fields .. functions
end

local documentation = function (object)
  return debug.getregistry()['HsLua docs'][object]
end

return {{
    Pandoc = function (doc)
      local target = utils.stringify(doc.meta.target or 'pandoc.path')
      local object = _G.load('return '.. target)()
      return Pandoc(render_module(documentation(object)))
    end
}}
