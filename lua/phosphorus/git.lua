local Path = require("plenary.path")

local data = require("phosphorus.data")

local function get_dir_path(repo_path)
    local user, _ = repo_path:match("^([^/]+)/(.+)$")
    local user_dir_path = string.format("%s/%s", data.base_dir(), user)
    return user_dir_path
end

local function git_clone_with_progress(repo_url, target_dir)
    local cmd = { "git", "clone", "--progress", repo_url, target_dir }

    vim.notify("Cloning " .. repo_url, vim.log.levels.INFO)

    vim.fn.jobstart(cmd, {
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                vim.notify("Clone completed!", vim.log.levels.INFO)
            else
                vim.notify("Clone failed!", vim.log.levels.ERROR)
            end
        end,
        on_stderr = function(_, errdata)
            -- git outputs progress to stderr
            for _, line in ipairs(errdata) do
                if line:match("%%") then
                    vim.notify(line, vim.log.levels.INFO)
                end
            end
        end,
    })
end

local git = {}

function git.add_repo(repo_path_str)
    local usr_dir_path_str = get_dir_path(repo_path_str)
    local usr_dir_path = Path:new(usr_dir_path_str)
    if not usr_dir_path:exists() then
        usr_dir_path:mkdir()
    end

    local full_repo_path_str = string.format("%s/%s", data.base_dir(), repo_path_str)
    local repo_path = Path:new(full_repo_path_str)
    if repo_path:exists() then
        -- already exists, we're gonna assume its a git repo
        -- this *shouldnt* happen?
        return
    end

    repo_path:mkdir()

    local main_branch_path = string.format("%s/main", full_repo_path_str)
    local main_branch = Path:new(main_branch_path)
    main_branch:mkdir()

    -- git clone to main
    local https_repo_path_str = string.format("https://github.com/%s", repo_path_str)
    git_clone_with_progress(https_repo_path_str, main_branch_path)
end

function git.delete_repo(repo_path_str)
    local full_repo_path_str = string.format("%s/%s", data.base_dir(), repo_path_str)
    local repo_path = Path:new(full_repo_path_str)
    if repo_path:exists() then
        local result = vim.fn.delete(full_repo_path_str, "rf")
        if result ~= 0 then
            vim.notify(string.format("Failed to delete repo %s", repo_path_str), vim.log.levels.ERROR)
        end
    else
        vim.notify(string.format("Repo %s does not exist", repo_path_str), vim.log.levels.ERROR)
    end
end

function git.cd_to_repo(repo_name, branch_name)
    local repo_path_str = string.format("%s/%s", repo_name, branch_name)
    local full_repo_path_str = string.format("%s/%s", data.base_dir(), repo_path_str)
    local repo_path = Path:new(full_repo_path_str)
    if repo_path:exists() then
        vim.cmd(string.format("cd %s", full_repo_path_str))
    else
        vim.notify(
            string.format("Repo %s does not exist, this is an error please report", repo_path_str),
            vim.log.levels.ERROR
        )
    end
end

function git.add_branch(repo_name, branch_name)
    git.cd_to_repo(repo_name, "main")

    local cmd = { "git", "worktree", "add", "../" .. branch_name }

    vim.fn.jobstart(cmd, {
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.notify("Failed to add branch!", vim.log.levels.ERROR)
            end
        end,
    })
end

--@returns WorktreeInfo[]
local function lines_to_worktree_info(info)
    local worktree_info = {}

    while #info > 0 do
        local branch_info = {}
        local worktree_line = table.remove(info, 1)
        local worktree_split = vim.split(worktree_line, " ")
        if worktree_split[1] == "worktree" then
            local worktree_path = worktree_split[2]
            branch_info.worktree = worktree_path

            local head_line = table.remove(info, 1)
            local head_split = vim.split(head_line, " ")
            if head_split[1] == "HEAD" then
                local head_path = head_split[2]
                branch_info.head = head_path
            end

            local branch_line = table.remove(info, 1)
            local branch_split = vim.split(branch_line, " ")
            if branch_split[1] == "branch" then
                local branch_path = branch_split[2]
                branch_info.branch = branch_path
            end

            table.insert(worktree_info, branch_info)
        end
    end

    return worktree_info
end


function git.sync_worktree(repo_name)
    local cwd = vim.fn.getcwd()
    git.cd_to_repo(repo_name, "main")

    local prune_cmd = { "git", "worktree", "prune" }
    vim.fn.jobstart(prune_cmd)

    local cmd = { "git", "worktree", "list", "--porcelain" }

    local worktree = {
        repo = repo_name,
        worktrees = {},
    }

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, outdata)
            local worktree_info = lines_to_worktree_info(outdata)
            worktree.worktrees = worktree_info
            data.sync_worktree(worktree)
        end
    })

    vim.cmd(string.format("cd %s", cwd))
end

function git.has_unsaved_changes(repo_name, branch_name)
    local cwd = vim.fn.getcwd()
    git.cd_to_repo(repo_name, "main")

    local cmd = { "git", "status", "--porcelain" }

    vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        on_stdout = function(_, outdata)
            local has_unsaved_changes = #outdata > 0
            data.has_unsaved_changes(repo_name, branch_name, has_unsaved_changes)
            vim.cmd(string.format("cd %s", cwd))
        end
    })
end

return git
