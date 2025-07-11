---@alias PhosOptions {base_dir: string}

local ui = require("phosphorus.ui")
local data = require("phosphorus.data")

local augroup = vim.api.nvim_create_augroup("phos", { clear = true })

---@param options PhosOptions
local function main(options)
    data.load(options.base_dir)
end

---@param options PhosOptions
local function setup(options)
    vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup,
        desc = "load phosphorus on vim start",
        once = true,
        callback = function()
            main(options)
        end,
    })

    vim.api.nvim_create_user_command("PhosShow", function() ui.show() end, { nargs = 0 })
    vim.keymap.set("n", "<leader>ps", ":PhosShow<CR>", { desc = "phosphorus show" })
end

return { setup = setup }
