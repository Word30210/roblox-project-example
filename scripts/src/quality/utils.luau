const fs = require("@std/fs")
const path = require("@std/path")

const utils = {}

utils.CWD = path.resolve(".")

function utils.toRelative(p: path.Pathlike): string
    const abs = path.resolve(p)
    return path.format(path.relative(utils.CWD, abs))
end

function utils.isGit(full: path.Path): boolean
    const subject = path.format(full):gsub("\\", "/")
    return subject:match(".git") ~= nil
end

function utils.getPaths(filter: (path.Path) -> boolean): { path.Path }
    const results: { path.Path } = {}
    const stack: { path.Path } = { path.resolve(".") }
    while #stack > 0 do
        const current = table.remove(stack, 1) :: path.Path
        for _, entry in fs.listDirectory(current) do
            const full = path.join(current, entry.name)
            if not utils.isGit(full) and filter(full) then
                table.insert(results, full)
            end

            if entry.type == "dir" then
                table.insert(stack, 1, full)
            end
        end
    end

    return results
end

function utils.findUp(from: path.Path, match: string): path.Path?
    local current = from
    if fs.exists(current) and fs.type(current) ~= "dir" then
        current = path.parse(path.dirname(current))
    end
    current = path.relative(utils.CWD, current)

    while true do
        const candidate = path.join(current, match)
        if fs.exists(candidate) then
            return path.relative(utils.CWD, candidate)
        end

        const parent = path.resolve(current, "..")
        if parent == current then
            break
        end
        current = parent
    end

    return nil
end

return utils
