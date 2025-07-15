local Popup = require("nui.popup")
local Layout = require("nui.layout")
local Input = require("nui.input")

local data = require("phosphorus.data")
local git = require("phosphorus.git")
local validation = require("phosphorus.validation")

local function pad_string(str, width, align)
    align = align or "left"
    local len = string.len(str)
    if len >= width then
        return string.sub(str, 1, width)
    end

    local padding = width - len
    if align == "center" then
        local left_pad = math.floor(padding / 2)
        local right_pad = padding - left_pad
        return string.rep(" ", left_pad) .. str .. string.rep(" ", right_pad)
    elseif align == "right" then
        return string.rep(" ", padding) .. str
    else
        return str .. string.rep(" ", padding)
    end
end

local function get_unstaged_changes(repo, branch)
    local changes = git.unstaged_changes(repo, branch)
    return tostring(changes)
end

local function calculate_column_widths(repos)
    local max_repo = string.len("Repository")
    local max_branch = string.len("Branch")
    local max_changes = string.len("Unstaged")

    for repo, _ in pairs(repos) do
        max_repo = math.max(max_repo, string.len(repo))
        local repo_data = data.load_repo_data(repo)
        for _, branch in pairs(repo_data.branches) do
            max_branch = math.max(max_branch, string.len(branch))
            local unstaged = get_unstaged_changes(repo, branch)
            max_changes = math.max(max_changes, string.len(unstaged))
        end
    end

    return {
        repo = math.min(max_repo + 2, 40),      -- Cap at 40 chars
        branch = math.min(max_branch + 2, 25),  -- Cap at 25 chars
        changes = math.max(max_changes + 2, 10) -- Min 10 chars
    }
end

local function repo_table()
    local repo_lines = {}
    local repos = data.get_repos()
    local lines = {}
    local sorted_repos = {}

    for repo, _ in pairs(repos) do
        table.insert(sorted_repos, repo)
    end
    table.sort(sorted_repos)

    -- Calculate optimal column widths
    local col_widths = calculate_column_widths(repos)

    -- Create header
    local header = "│ " ..
        pad_string("Repository", col_widths.repo) .. " │ " ..
        pad_string("Branch", col_widths.branch) .. " │ " ..
        pad_string("Unstaged", col_widths.changes) .. " │"

    local separator = "├" ..
        string.rep("─", col_widths.repo + 2) .. "┼" ..
        string.rep("─", col_widths.branch + 2) .. "┼" ..
        string.rep("─", col_widths.changes + 2) .. "┤"

    local top_border = "┌" ..
        string.rep("─", col_widths.repo + 2) .. "┬" ..
        string.rep("─", col_widths.branch + 2) .. "┬" ..
        string.rep("─", col_widths.changes + 2) .. "┐"

    table.insert(lines, top_border)
    table.insert(lines, header)
    table.insert(lines, separator)

    -- add placeholder entries for header and separator
    table.insert(repo_lines, false) -- top border
    table.insert(repo_lines, false) -- header
    table.insert(repo_lines, false) -- separator

    for _, repo in ipairs(sorted_repos) do
        local repo_data = data.load_repo_data(repo)
        local first_branch = true

        for _, branch in pairs(repo_data.branches) do
            local unstaged = get_unstaged_changes(repo, branch)
            local repo_display = first_branch and repo or ""

            local line = "│ " ..
                pad_string(repo_display, col_widths.repo) .. " │ " ..
                pad_string(branch, col_widths.branch) .. " │ " ..
                pad_string(unstaged, col_widths.changes, "center") .. " │"

            table.insert(lines, line)

            local branch_data = {
                repo = repo,
                branch = branch,
            }
            table.insert(repo_lines, branch_data)
            first_branch = false
        end

        if repo ~= sorted_repos[#sorted_repos] then
            table.insert(lines, separator)
            -- ddd separator between repos (except for last repo)
            table.insert(repo_lines, false)
        end
    end

    local bottom_border = "└" ..
        string.rep("─", col_widths.repo + 2) .. "┴" ..
        string.rep("─", col_widths.branch + 2) .. "┴" ..
        string.rep("─", col_widths.changes + 2) .. "┘"

    table.insert(lines, bottom_border)
    table.insert(repo_lines, false) -- bottom border

    local table_width = col_widths.repo + col_widths.branch + col_widths.changes + 8
    local table_height = #lines

    return table.concat(lines, "\n"), repo_lines, table_width, table_height
end

local ui = { lines = {} }

function ui.rerender_text(main_popup)
    local text, repo_lines = repo_table()
    ui.lines = repo_lines
    local text_split = vim.split(text, "\n")

    vim.api.nvim_set_option_value("modifiable", true, { buf = main_popup.bufnr })
    vim.api.nvim_buf_set_lines(main_popup.bufnr, 0, -1, false, text_split)
    vim.api.nvim_set_option_value("modifiable", false, { buf = main_popup.bufnr })
end

function ui.show(saved_cursor)
    local text, repo_lines, table_width, table_height = repo_table()
    ui.lines = repo_lines

    local screen_width = vim.o.columns
    local screen_height = vim.o.lines

    local window_width = math.min(table_width + 8, math.floor(screen_width * 0.9))
    local window_height = math.min(table_height + 2, math.floor(screen_height * 0.8))

    local main_popup = Popup({
        enter = true,
        focusable = true,
        border = {
            style = "single",
        },
        buf_options = {
            modifiable = false,
        },
        win_options = {
            spell = false,
            wrap = false,
            signcolumn = "yes",
            statuscolumn = " ",
            conceallevel = 3,
        },
    })

    local layout = Layout(
        {
            position = "50%",
            size = {
                width = window_width,
                height = window_height,
            },
        },
        Layout.Box({
            Layout.Box(main_popup, { size = window_height }),
        }, { dir = "col" })
    )

    vim.api.nvim_buf_set_lines(main_popup.bufnr, 0, -1, false, vim.split(text, "\n"))

    main_popup:map("n", "q", function()
        layout:unmount()
    end, { noremap = true })

    main_popup:map("n", "a", function()
        local input = Input({
            relative = "editor",
            position = {
                row = 0.05,
                col = "50%"
            },
            size = {
                width = 60,
                height = 1,
            },
            border = {
                style = "double",
                text = {
                    top = "Enter Github Repo",
                    top_align = "center"
                }
            },
            win_options = {
                winhighlight = "Normal:Normal,FloatBorder:Normal",
            },
        }, {
            prompt = "> ",
            default_value = "",
            on_submit = function(repo)
                if not repo or repo == "" then
                    return
                end

                if not validation.is_valid_github_repo(repo) then
                    vim.notify("Not a valid github repo", vim.log.levels.ERROR)
                    return
                end

                git.add_repo(repo)
                data.add_repo(repo)
                local cursor = vim.api.nvim_win_get_cursor(main_popup.winid)
                layout:unmount()
                ui.show(cursor)
            end,
        })

        input:mount()
    end, { noremap = true })

    main_popup:map("n", "d", function()
        local cursor = vim.api.nvim_win_get_cursor(main_popup.winid)
        local line_num = cursor[1]
        local line_data = ui.lines[line_num]

        if line_data then
            git.delete_branch(line_data.repo, line_data.branch)
            data.delete_branch(line_data.repo, line_data.branch)
            ui.rerender_text(main_popup)
        else
            -- try to find repo from current line or nearby lines
            local line_content = vim.api.nvim_buf_get_lines(main_popup.bufnr, line_num - 1, line_num, false)[1]
            if line_content and line_content:match("│%s*([^%s│]+)") then
                local repo_name = line_content:match("│%s*([^%s│]+)")
                if repo_name and repo_name ~= "" and repo_name ~= "Repository" then
                    git.delete_repo(repo_name)
                    data.delete_repo(repo_name)
                    ui.rerender_text(main_popup)
                end
            end
        end
    end, { noremap = true })

    main_popup:map("n", "b", function()
        local cursor = vim.api.nvim_win_get_cursor(main_popup.winid)
        local line_num = cursor[1]
        local line_data = ui.lines[line_num]

        local repo_name
        if line_data then
            repo_name = line_data.repo
        else
            for i = line_num, 1, -1 do
                local check_data = ui.lines[i]
                if check_data then
                    repo_name = check_data.repo
                    break
                end
                local line_content = vim.api.nvim_buf_get_lines(main_popup.bufnr, i - 1, i, false)[1]
                if line_content and line_content:match("│%s*([^%s│]+)") then
                    local potential_repo = line_content:match("│%s*([^%s│]+)")
                    if potential_repo and potential_repo ~= "" and potential_repo ~= "Repository" then
                        repo_name = potential_repo
                        break
                    end
                end
            end
        end

        if repo_name then
            local input = Input({
                relative = "editor",
                position = {
                    row = 0.05,
                    col = "50%"
                },
                size = {
                    width = 60,
                    height = 1,
                },
                border = {
                    style = "double",
                    text = {
                        top = "Enter Branch Name",
                        top_align = "center"
                    }
                },
                win_options = {
                    winhighlight = "Normal:Normal,FloatBorder:Normal",
                },
            }, {
                prompt = "> ",
                default_value = "",
                on_submit = function(branch)
                    if not branch or branch == "" then
                        return
                    end

                    git.add_branch(repo_name, branch)
                    data.add_branch(repo_name, branch)
                    ui.rerender_text(main_popup)
                    vim.notify("Added branch " .. branch, vim.log.levels.INFO)
                end,
            })

            input:mount()
        end
    end, { noremap = true })

    main_popup:map("n", "<CR>", function()
        local cursor = vim.api.nvim_win_get_cursor(main_popup.winid)
        local line_num = cursor[1]
        local line_data = ui.lines[line_num]

        if line_data then
            git.cd_to_repo(line_data.repo, line_data.branch)
            vim.notify("Opened " .. line_data.repo .. "/" .. line_data.branch, vim.log.levels.INFO)
            layout:unmount()
        end
    end, { noremap = true })

    layout:mount()

    if saved_cursor ~= nil then
        vim.api.nvim_win_set_cursor(main_popup.winid, saved_cursor)
    end
end

function ui.add_repo()
    local input = Input({
        relative = "editor",
        position = {
            row = 0.05,
            col = "50%"
        },
        size = {
            width = 60,
            height = 1,
        },
        border = {
            style = "double",
            text = {
                top = "Enter Github Repo",
                top_align = "center"
            }
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
        prompt = "> ",
        default_value = "",
        on_submit = function(repo)
            if not repo or repo == "" then
                return
            end

            if not validation.is_valid_github_repo(repo) then
                vim.notify("Not a valid github repo", vim.log.levels.ERROR)
                return
            end

            git.add_repo(repo)
            data.add_repo(repo)
            local cursor = vim.api.nvim_win_get_cursor(main_popup.winid)
            layout:unmount()
            ui.show(cursor)
        end,
    })

    input:mount()
end

return ui
