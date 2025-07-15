---@alias PhosOptions {base_dir: string}

local ui = require("phosphorus.ui")
local data = require("phosphorus.data")
local git = require("phosphorus.git")

local augroup = vim.api.nvim_create_augroup("phos", { clear = true })

---@param options PhosOptions
local function main(options)
    data.load(options.base_dir)
    for repo, _ in pairs(data.get_repos()) do
        git.sync_worktree(repo)
    end
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

    vim.api.nvim_create_user_command("PhosShow", function()
        ui.show()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PhosAddRepo", function()
        ui.add_repo()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PhosAddBranch", function()
        ui.add_branch()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PhosDeleteRepo", function()
        ui.delete_repo()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PhosDeleteBranch", function()
        ui.delete_branch()
    end, { nargs = 0 })
end

return { setup = setup }
