---@diagnostic disable: unused-local

local cthulhu = require("cthulhu")
local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("cotton.collector", "info")
local listlib = require("infra.listlib")
local subprocess = require("infra.subprocess")

local api = vim.api
local uv = vim.uv

---@class cotton.Collector
---@field ns integer
local Collector = {}
do
  Collector.__index = Collector

  ---@param outfile string
  ---@return string,string[] @bin, args
  function Collector:cmd(outfile) error("not implemented") end

  ---@param plains string[]
  ---@return any[]
  function Collector:populate_checks(plains) error("not implemented") end

  ---@param check any
  ---@return vim.Diagnostic
  function Collector:check_to_diagnostic(bufnr, check) error("not implemented") end

  ---@param bufnr integer
  function Collector:__call(bufnr)
    assert(bufnr ~= nil and bufnr ~= 0)
    local outfile = os.tmpname()
    assert(cthulhu.nvim.dump_buffer(bufnr, outfile))

    local stdout_closed = false
    local chunks = {}

    ---@param data? string
    local function on_stdout(data)
      if data ~= nil then return table.insert(chunks, data) end
      stdout_closed = true
    end

    ---@param rc integer
    local function on_exit(rc)
      assert(stdout_closed)

      local checks
      if rc == 0 then
        checks = {}
      else
        assert(rc == 1) --NB: not all linters follow this convention
        checks = self:populate_checks(chunks)
      end

      uv.fs_unlink(outfile)

      vim.schedule(function()
        local digs = itertools.tolist(itertools.map(function(check) return self:check_to_diagnostic(bufnr, check) end, checks))
        jelly.debug("feed %d diagnostics to nvim", #digs)
        vim.diagnostic.set(self.ns, bufnr, digs)
      end)
    end

    local bin, args = self:cmd(outfile)
    subprocess.spawn(bin, { args = args }, on_stdout, on_exit)
  end
end

---@overload fun(bufnr: integer)
return Collector
