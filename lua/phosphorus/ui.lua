local Snacks = require("snacks")

local data = require("phosphorus.data")
local git = require("phosphorus.git")
local validation = require("phosphorus.validation")

local function repo_text()
    local repo_lines = {}
    local repos = data.get_repos()
    local text = ""
    local sorted_repos = {}
    for repo, _ in pairs(repos) do
        table.insert(sorted_repos, repo)
    end
    table.sort(sorted_repos)

    for repo, _ in pairs(repos) do
        local repo_data = data.load_repo_data(repo)
        text = text .. repo .. ":\n"
        table.insert(repo_lines, false)
        for _, branch in pairs(repo_data.branches) do
            text = text .. "  " .. branch .. "\n"
            local branch_data = {
                repo = repo,
                branch = branch,
            }
            table.insert(repo_lines, branch_data)
        end
    end

    return text, repo_lines
end

local ui = { lines = {} }

function ui.rerender_text(self)
    local text, repo_lines = repo_text()
    ui.lines = repo_lines
    local text_split = vim.split(text, "\n")
    vim.api.nvim_set_option_value("modifiable", true, { buf = self.buf })
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, text_split)
    vim.api.nvim_set_option_value("modifiable", false, { buf = self.buf })
end

function ui.show(saved_cursor)
    local text, repo_lines = repo_text()
    ui.lines = repo_lines

    local layout_instance

    local main_win = Snacks.win({
        text = text,
        wo = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
        },
        bo = {
            modifiable = false,
        },
        keys = {
            q = function()
                layout_instance:close()
            end,
            a = function(self)
                Snacks.input({ prompt = "enter a valid github repo (<user>/<repo>)" }, function(repo)
                    if not repo then
                        Snacks.notifier("did not enter a repo", "error")
                        return
                    end

                    if not validation.is_valid_github_repo(repo) then
                        Snacks.notifier("not a valid github repo", "error")
                        return
                    end

                    git.add_repo(repo)
                    data.add_repo(repo)
                    local cursor = vim.api.nvim_win_get_cursor(self.win)
                    layout_instance:close()
                    ui.show(cursor)
                end)
            end,
            d = function(self)
                local cursor = vim.api.nvim_win_get_cursor(self.win)
                local line_num = cursor[1]

                local line_content = vim.api.nvim_buf_get_lines(self.buf, line_num - 1, line_num, false)[1]
                line_content = string.gsub(line_content, "%s+", "")
                line_content = string.gsub(line_content, ":", "")

                local line_data = ui.lines[line_num]
                -- if line_data does not exist, then its a repo name, and we want to delete it
                if not line_data then
                    git.delete_repo(line_content)
                    data.delete_repo(line_content)
                    ui.rerender_text(self)
                end
            end,
            b = function(self)
                local cursor = vim.api.nvim_win_get_cursor(self.win)
                local line_num = cursor[1]

                local line_content = vim.api.nvim_buf_get_lines(self.buf, line_num - 1, line_num, false)[1]
                line_content = string.gsub(line_content, "%s+", "")

                local line_data = ui.lines[line_num]
                -- if line_data does not exist, then its a repo name, and we want to delete it
                if not line_data then
                    local repo_name = string.gsub(line_content, ":", "")
                    Snacks.input({ prompt = "enter a branch name" }, function(branch)
                        if not branch then
                            Snacks.notifier("did not enter a branch name", "error")
                            return
                        end

                        git.add_branch(repo_name, branch)
                        data.add_branch(repo_name, branch)
                        ui.rerender_text(self)
                        Snacks.notifier("added branch " .. branch, "info")
                    end)
                end
            end,
            ["<CR>"] = function(self)
                local cursor = vim.api.nvim_win_get_cursor(self.win)
                local line_num = cursor[1]

                local line_content = vim.api.nvim_buf_get_lines(self.buf, line_num - 1, line_num, false)[1]
                line_content = string.gsub(line_content, "%s+", "")

                local line_data = ui.lines[line_num]
                if line_data then
                    git.cd_to_repo(line_data.repo, line_data.branch)
                    Snacks.notifier("opened " .. line_data.repo .. "/" .. line_data.branch, "info")
                    layout_instance:close()
                end
            end,
        },
    })

    local footer_win = Snacks.win({
        height = 1,
        text = " a to Add Repo | d to Delete Repo/Branch | b to Branch | <CR> to Open | q to Quit ",
        wo = {
            spell = false,
            wrap = false,
        },
        bo = {
            modifiable = false,
        },
    })

    -- Create layout
    layout_instance = Snacks.layout.new({
        wins = {
            footer = footer_win,
            main = main_win,
        },
        layout = {
            box = "vertical",
            border = "rounded",
            title = "Phosphorus Todo",
            width = 0.8,
            height = 0.9,
            { win = "main" },
            { win = "footer", height = 1 },
        },
    })

    -- Show layout
    layout_instance:show()
    main_win:focus()

    if saved_cursor ~= nil then
        vim.api.nvim_win_set_cursor(main_win.win, saved_cursor)
    end
end

return ui
