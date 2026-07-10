const io = require("@std/io")
const fs = require("@std/fs")
const task = require("@std/task")
const path = require("@std/path")
const process = require("@std/process")
const stringext = require("@std/stringext")

const tint = require("@pkg/tint")

const noStylua = table.find(process.args, "--no-check") or table.find(process.args, "--no-stylua")
const noSelene = table.find(process.args, "--no-lint") or table.find(process.args, "--no-selene")
const resolveFormat = table.find(process.args, "--resolve-format") or table.find(process.args, "--resolve-stylua")
const printResults = table.find(process.args, "--print-results")
const verboseMode = table.find(process.args, "-v") or table.find(process.args, "--verbose")

type ToolType = "StyLua" | "selene"

local qualityFailed = false
local failedStack = ""
local resolvedFiles: { path.Path } = {}
local toolFails: { [ToolType]: number } = {}

const CWD = process.cwd()

const function toRelative(target: path.Pathlike): string
    const abs = path.resolve(target)
    return path.format(path.relative(CWD, abs))
end

const function pushFailed(file: path.Path, type: ToolType, content: string)
    const header = tint.gray(`[{type}]`, "\n", `{toRelative(file)}`, tint.reset("\n"))
    if not qualityFailed then
        qualityFailed = true
        failedStack ..= header .. content
    else
        failedStack ..= header .. "\n\n" .. content
    end

    toolFails[type] = toolFails[type] or 0
    toolFails[type] += 1
end

const function getSrcLuaus(): { path.Path }
    const results: { path.Path } = {}

    const function accept(full: path.Path): boolean
        const subject = (path.format(full):gsub("\\", "/"))
        const matched = subject:match("/src/[^/]+%.luau?$") ~= nil

        if matched and toRelative(full) == "packages/assets/src/assets.luau" then
            return false
        end

        return matched
    end

    const stack: { path.Path } = { CWD }
    while #stack > 0 do
        const current = table.remove(stack) :: path.Path
        for _, entry in fs.listDirectory(current) do
            const full = path.join(current, entry.name)
            if accept(full) then
                table.insert(results, full)
            end

            if entry.type == "dir" then
                table.insert(stack, full)
            end
        end
    end

    return results
end

local function getToml(from: path.Path, tomlName: string): path.Path?
    local current = path.format(from)
    local srcDir: string? = nil

    while true do
        const base = path.basename(current)
        if base == nil then
            break
        end
        if base == "src" then
            srcDir = current
            break
        end

        const parent = path.dirname(current)
        if parent == current then
            break
        end
        current = parent
    end

    if srcDir == nil then
        return nil
    end

    const baseDir = path.dirname(srcDir)
    const tomlPath = path.join(baseDir, `{tomlName}.toml`)

    return if fs.exists(tomlPath) then tomlPath else nil
end

const function runTool(args: { string }): (number, string?)
    const res = process.run(args)

    if res.exitcode == 2 then
        return 2, stringext.trim(res.stderr)
    elseif res.exitcode == 1 then
        return 1, stringext.trim(res.stdout)
    else
        return 0, nil
    end
end

const function verbose<T>(value: T): T?
    return if verboseMode then value else nil
end

const function found(n: number)
    print(tint.green("FOUND", tint.reset(`found {n} luau files`)))
end

const function succeed(file: path.Path, toml: path.Path?)
    io.write(tint.green("SUCCEED", tint.reset(`{toRelative(file)}`)))
    if toml then
        io.write(tint.reset.dim(` ({toRelative(toml)})`))
    end
    io.write(tint.reset("\n"))
end

const function resolved(file: path.Path, toml: path.Path?)
    io.write(tint.green("RESOLVED", tint.reset(`{toRelative(file)}`)))
    if toml then
        io.write(tint.reset.dim(` ({toRelative(toml)})`))
    end
    io.write(tint.reset("\n"))
end

const function failed(file: path.Path, type: ToolType, content: string, toml: path.Path?)
    io.write(tint.red("FAILED", tint.reset(`{toRelative(file)}`)))
    if toml then
        io.write(tint.reset.dim(` ({toRelative(toml)})`))
    end
    io.write(tint.reset("\n"))

    pushFailed(file, type, content)
end

const function err(file: path.Path, type: ToolType, message: string, toml: path.Path?)
    io.write(tint.red("FAILED", tint.reset(`{toRelative(file)}: {message}`)))
    if toml then
        io.write(tint.reset.dim(` ({toRelative(toml)})`))
    end
    io.write(tint.reset("\n"))

    pushFailed(file, type, message)
end

const function checkStylua(luauFiles: { path.Path })
    const ty = "StyLua"
    for _, luauFile in luauFiles do
        const toml = getToml(luauFile, "stylua")
        if toml then
            const exitcode, res =
                runTool({ "stylua", toRelative(luauFile), "--check", "--config-path", toRelative(toml) })
            if exitcode == 0 then
                succeed(luauFile, verbose(toml))
            elseif exitcode == 1 then
                if resolveFormat then
                    const rexitcode, rres =
                        runTool({ "stylua", toRelative(luauFile), "--config-path", toRelative(toml) })
                    if rexitcode == 0 then
                        resolved(luauFile, verbose(toml))
                        table.insert(resolvedFiles, luauFile)
                    elseif rexitcode == 1 then
                        failed(luauFile, ty, rres :: string, verbose(toml))
                    elseif rexitcode == 2 then
                        err(luauFile, ty, rres :: string, verbose(toml))
                    end
                else
                    failed(luauFile, ty, res :: string, verbose(toml))
                end
            elseif exitcode == 2 then
                err(luauFile, ty, res :: string, verbose(toml))
            end
        else
            err(luauFile, ty, "config file not found.")
        end
    end
end

const function checkSelene (luauFiles: { path.Path })
    const ty = "selene"
    for _, luauFile in luauFiles do
        const toml = getToml(luauFile, "selene")
        if toml then
            const exitcode, res = runTool({ "selene", toRelative(luauFile), "--config", toRelative(toml) })
            if exitcode == 0 then
                succeed(luauFile, verbose(toml))
            elseif exitcode == 1 then
                failed(luauFile, ty, res :: string, verbose(toml))
            elseif exitcode == 2 then
                err(luauFile, ty, res :: string, verbose(toml))
            end
        else
            err(luauFile, ty, "config file not found.")
        end
    end
end

const luauFiles = getSrcLuaus()
const numberOfLuauFiles = #luauFiles
found(numberOfLuauFiles)
if not noStylua then
    checkStylua(luauFiles)
end
if not noSelene then
    checkSelene(luauFiles)
end

if qualityFailed and printResults then
    print("\n" .. failedStack)
end

if printResults and next(resolvedFiles) then
    print(tint.blue.bold("\nRESOLVED BY STYLUA:"))
    for _, luauFile in resolvedFiles do
        print(tint.reset.dim(`- {toRelative(luauFile)}`))
    end
end

print(tint.blue.bold("\nSUCCEED CHECKS:"))
for toolType, fails in toolFails do
    io.write(tint.reset(`- [{toolType}]: `))
    if fails == 0 then
        print(tint.green(`{numberOfLuauFiles - fails}/{numberOfLuauFiles}`))
    elseif fails >= numberOfLuauFiles then
        print(tint.red(`{numberOfLuauFiles - fails}/{numberOfLuauFiles}`))
    else
        print(tint.yellow(`{numberOfLuauFiles - fails}/{numberOfLuauFiles}`))
    end
end

if qualityFailed then
    print(tint.red.bold("\nQUALITY IS BAD"))
    process.exit(1)
else
    print(tint.green.bold("\nQUALITY IS GOOD"))
    process.exit(0)
end
