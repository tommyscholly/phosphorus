local curl = require("plenary.curl")

local function strip_github(url)
    return string.gsub(url, "https://github.com/", "")
end

local validation = {}

function validation.is_valid_github_repo(url)
    local api_url = string.format("https://api.github.com/repos/%s", strip_github(url))
    local response = curl.get(api_url)
    return response.status == 200
end

return validation
