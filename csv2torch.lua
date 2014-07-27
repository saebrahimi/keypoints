require 'dok'

csv = {}

function csv.open(...)
   local _, filename = dok.unpack(
      {...},
      'csv.open',
      [=[

Opens csv file <filename> reads and returns an anonymous function
which can be called to step line by line thorugh the file.

USAGE:
   local csvg = csv.open(fname)
   local firstline = csvg()
   
Returns nil at EOF.

      ]=],
      {arg='filename', type='string',
       help='filename of csv to open', req=true}
   )
   local f = assert(io.open(filename, 'r'))
   return function()
             local line = f:read("*line")
             if line then
                local ml = false
                line = string.gsub(line, "'", "\\'") .. ','         -- ending comma
                local row = {}             -- table to collect fields
                local f_start = 1
                repeat
                   -- multiline field
                   if ml then
                      line = line .. string.gsub(f:read("*line"), "'", "\\'") .. ','
                      local i  = f_start
                      repeat
                         -- find closing quote; chew accross escaped quotes
                         a, i, c = string.find(line, '(\\?)"', i+1)
                      until c ~= '\\'    -- not an escaped quote?
                      if i then
                         local f = string.sub(line, f_start+1, i-1)
                         table.insert(row, (string.gsub(f, '\\"', '"')))
                         f_start = string.find(line, ',', i) + 1
                         ml = false
                      end
                   end

                   -- next field is quoted? (start with `"'?)
                   if string.find(line, '^"', f_start) then
                      local a, c
                      local i  = f_start
                      repeat
                         -- find closing quote; chew accross escaped quotes
                         a, i, c = string.find(line, '(\\?)"', i+1)
                      until c ~= '\\'    -- not an escaped quote?
                      if not i then
                         -- error('unmatched "')
                         line = string.gsub(line, '\\,$', '\n')
                         ml = true
                      else
                         local f = string.sub(line, f_start+1, i-1)
                         table.insert(row, (string.gsub(f, '\\"', '"')))
                         f_start = string.find(line, ',', i) + 1
                      end
                   else                 -- unquoted; find next comma
                      local nexti = string.find(line, ',', f_start)
                      table.insert(row, string.sub(line, f_start, nexti-1))
                      f_start = nexti + 1
                   end
                until f_start > string.len(line)

                return row
             else
                f:close()
             end
          end
end


function csv.make_reverse_table (...)
   local _, row = dok.unpack(
      {...},
      'csv.make_reverse_table',
      [=[
Simplifies access to a named column in the csv file by hashing column name to the column number

EXAMPLE:

t7> csvg    = csv.open(fname)
t7> header  = csvg()
t7> =header
{[1] = string : "bbx"
 [2] = string : "bby"
 [3] = string : "bbw"
 [4] = string : "bbh"}
> rheader = csv.make_reverse_table(header)
t7> =rheader
{[bbx]            = 1
 [bby]            = 2
 [bbw]            = 3
 [bbh]            = 4}
      ]=],
      {arg='row', type='table',
       help='parsed header of csv', req=true}
   )
   rv = {} 
   for i = 1,#row do 
      rv[row[i]] = i 
   end
   return rv
end

function csv.open_with_header (...)
   local _, filename = dok.unpack(
      {...},
      'csv.open_with_header',
      [=[
Opens csv file <filename> reads and returns an anonymous function
which can be called to step line by line thorugh the file. The
anonymous function returns nil at EOF.

Parses the first header line to make access of named columns easier

EXAMPLE:

t7> csvg, header,rheader = csv.open_with_header(fname)
t7> =header
{[1] = string : "bbx"
 [2] = string : "bby"
 [3] = string : "bbw"
 [4] = string : "bbh"}
t7> =rheader
{[bbx]            = 1
 [bby]            = 2
 [bbw]            = 3
 [bbh]            = 4}
t7> line = csvg()
t7> =line[rheader["bbx"]]
34398
      ]=],
      {arg='filename', type='string',
       help='filename of csv to open', req=true}
   )
   local csvg    = csv.open(filename)
   local header  = csvg()
   local rheader = csv.make_reverse_table(header)
   return csvg, header, rheader
end

require 'dp'

cmd = torch.CmdLine()
cmd:option('--csvfile', '', 'location of the csv file')
cmd:option('--th7file', '', 'location of the th7 file')
cmd:text()
opt = cmd:parse(arg or {})

csvg, header, rheader = csv.open_with_header(opt.csvfile)

local data = {}

local line
while line do
   line = csvg()
   local row = {}
   local row = _.map(_.split(line[2], ' '), function(k,v) 
      return tonumber(v) 
   end)
   table.insert(row, tonumber(line[1]), 1)
   table.insert(data, torch.FloatTensor(row))
end

local tensor = torch.FloatTensor(#ids, #keypoints[1] + 1)

for i,row in ipairs(data) do
   tensor[i]:copy(row)
end

torch.save(opt.th7file, tensor)

