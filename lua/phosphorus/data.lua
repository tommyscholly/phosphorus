local Path = require("plenary.path")

-- general data structure
-- a main phosphorus.json file contains a list of repositories
-- each respository has its own json file
--
-- phosphorus.json structure
--[[
    type data = {
        -- repo url -> path from base dir
        repositories: {[string]: string},
        base_dir: string,
    }
--]]

function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function table.idx(table, element)
    for idx, value in pairs(table) do
        if value == element then
            return idx
        end
    end

    return nil
end

local function write_data(path_str, data)
    local path = Path:new(path_str)
    path:write(vim.fn.json_encode(data), "w")
end

local data_path_str = string.format("%s/phosphorus", vim.fn.stdpath("data"))

local data = {
    repo_data = {}
}

function data.load(base_dir)
    local base_dir_path = Path:new(base_dir)
    if not base_dir_path:exists() then
        base_dir_path:mkdir()
    end

    local data_path = Path:new(data_path_str)

    if not data_path:exists() then
        data_path:mkdir()
    end

    local phosphorus_path_str = string.format("%s/phosphorus.json", data_path)
    local phosphorus_path = Path:new(phosphorus_path_str)
    if not phosphorus_path:exists() then
        phosphorus_path:touch()
    end

    local out_data = phosphorus_path:read()
    local phos_data
    if not out_data or out_data == "" then
        phos_data = {
            base_dir = base_dir,
            repositories = {},
        }
        write_data(phosphorus_path_str, phos_data)
    else
        phos_data = vim.fn.json_decode(vim.fn.readfile(phosphorus_path_str))
    end

    data._phos = phos_data
end

function data.load_repo_data(repo_path)
    local repo_data_path = string.format("%s/%s.json", data_path_str, repo_path)
    if data.repo_data[repo_path] ~= nil then
        return data.repo_data[repo_path]
    end

    local repo_data_str = Path:new(repo_data_path):read()
    local repo_data = vim.fn.json_decode(repo_data_str)
    data.repo_data[repo_path] = repo_data
    return repo_data
end

---@param repo_path string - <user>/<repo>
function data.add_repo(repo_path)
    if data._phos.repositories == nil then
        data._phos.repositories = {}
    elseif data._phos.repositories[repo_path] ~= nil then
        return
    end

    data._phos.repositories[repo_path] = true
    local repo_data = {
        branches = { "main" },
    }
    write_data(data_path_str .. "/phosphorus.json", data._phos)
    local user, _ = repo_path:match("^([^/]+)/(.+)$")
    local user_dir_path = string.format("%s/%s", data_path_str, user)
    if not Path:new(user_dir_path):exists() then
        Path:new(user_dir_path):mkdir()
    end
    write_data(data_path_str .. "/" .. repo_path .. ".json", repo_data)
end

function data.add_branch(repo_path, branch_name)
    local repo_data = data.load_repo_data(repo_path)
    table.insert(repo_data.branches, branch_name)
    write_data(data_path_str .. "/" .. repo_path .. ".json", repo_data)
end

function data.delete_repo(repo_path)
    data._phos.repositories[repo_path] = nil
    write_data(data_path_str .. "/phosphorus.json", data._phos)
    local user, _ = repo_path:match("^([^/]+)/(.+)$")
    Path:new(data_path_str .. "/" .. repo_path .. ".json"):rm()
    -- is there a way of doing this with plenary?
    local user_files = vim.split(vim.fn.glob(user .. "/*"), "\n", { trimempty = true })
    if #user_files == 0 then
        Path:new(data_path_str .. "/" .. user):rmdir()
    end
end

function data.delete_branch(repo_path, branch_name)
    local repo_data = data.load_repo_data(repo_path)
    local idx = table.idx(repo_data.branches, branch_name)

    if idx then
        table.remove(repo_data.branches, idx)
        write_data(data_path_str .. "/" .. repo_path .. ".json", repo_data)
    end
end

--@alias WorktreeInfo {worktree: string, head: string, branch: string}
--@alias Worktree {repo_name: string, worktrees: WorktreeInfo[]}

--@param worktree Worktree
function data.sync_worktree(worktree)
    local repo_data = data.load_repo_data(worktree.repo)
    if repo_data.worktrees == nil then
        repo_data.worktrees = {}
    end

    for _, worktree_info in pairs(worktree.worktrees) do
        local branch_name = worktree_info.branch
        branch_name = branch_name:gsub("refs/heads/", "")
        if not table.contains(repo_data.branches, branch_name) then
            data.add_branch(worktree.repo, branch_name)
        end
        repo_data.worktrees[branch_name] = worktree_info
    end

    local path = data_path_str .. "/" .. worktree.repo .. ".json"
    write_data(path, repo_data)
end

function data.base_dir()
    return data._phos.base_dir
end

function data.get_repos()
    return data._phos.repositories
end

return data
