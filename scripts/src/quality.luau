const io = require("@std/io")
const fs = require("@std/fs")
const path = require("@std/path")
const process = require("@std/process")
const stringext = require("@std/stringext")

const tint = require("@pkg/tint")

const noStylua = table.find(process.args, "--no-check") or table.find(process.args, "--no-stylua")
const noSelene = table.find(process.args, "--no-lint") or table.find(process.args, "--no-selene")
const buildVerification = table.find(process.args, "--build-verification") or table.find(process.args, "--do-rojo")
const noBuildOutput = table.find(process.args, "--no-build-output") or table.find(process.args, "--no-rojo-output")
const resolveFormat = table.find(process.args, "--resolve-format") or table.find(process.args, "--resolve-stylua")
const printResults = table.find(process.args, "--print-results")
const verboseMode = table.find(process.args, "-v") or table.find(process.args, "--verbose")

type ToolType = "StyLua" | "selene" | "Rojo"

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
    const header = tint.gray(`[{type}]`, `{"\n" .. toRelative(file)}`, tint.reset("\n"))
    if not qualityFailed then
        qualityFailed = true
        failedStack ..= header .. content
    else
        failedStack ..= "\n\n" .. header .. content
    end

    toolFails[type] = toolFails[type] or 0
    toolFails[type] += 1
end

const function isGit(full: path.Path): boolean
    const subject = path.format(full):gsub("\\", "/")
    const matched = subject:match("/.git") ~= nil

    return matched
end

const function getPaths(acceptFn: (path.Path) -> boolean): { path.Path }
    const results: { path.Path } = {}
    const stack: { path.Path } = { CWD }
    while #stack > 0 do
        const current = table.remove(stack) :: path.Path
        for _, entry in fs.listDirectory(current) do
            const full = path.join(current, entry.name)
            if acceptFn(full) then
                table.insert(results, full)
            end

            if entry.type == "dir" and not isGit(full) then
                table.insert(stack, full)
            end
        end
    end

    return results
end

const function getSrcLuaus(): { path.Path }
    const function accept(full: path.Path): boolean
        const subject = path.format(full):gsub("\\", "/")
        const matched = subject:match("/src/[^/]+%.luau?$") ~= nil

        if matched and toRelative(full) == "packages/assets/src/assets.luau" then
            return false
        end

        return matched
    end

    return getPaths(accept)
end

local function getNearestToml(from: path.Path, tomlName: string): path.Path?
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

const function getBuildProjectJson()
    const function accept(full: path.Path): boolean
        const subject = path.format(full):gsub("\\", "/")
        const matched = subject:match("build.project.json$") ~= nil

        return matched
    end

    return getPaths(accept)
end

const function runTool(args: { string }, options: process.ProcessRunOptions?): (number, string?)
    const res = process.run(args, options)

    if res.exitcode == 2 then
        return 2, stringext.trim(res.stderr)
    elseif res.exitcode == 1 then
        if args[1] == "rojo" then
            return 1, stringext.trim(res.stderr)
        else
            return 1, stringext.trim(res.stdout)
        end
    else
        return 0, nil
    end
end

const function verbose<T>(value: T): T?
    return if verboseMode then value else nil
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
    io.write(tint.red("ERROR", tint.reset(`{toRelative(file)}: {message}`)))
    if toml then
        io.write(tint.reset.dim(` ({toRelative(toml)})`))
    end
    io.write(tint.reset("\n"))

    pushFailed(file, type, message)
end

const function checkStylua(luauFiles: { path.Path })
    const ty = "StyLua"
    for _, luauFile in luauFiles do
        const toml = getNearestToml(luauFile, "stylua")
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

const function checkSelene(luauFiles: { path.Path })
    const ty = "selene"
    for _, luauFile in luauFiles do
        const toml = getNearestToml(luauFile, "selene")
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

const function buildWithRojo(projects: { path.Path })
    const ty = "Rojo"
    for _, project in projects do
        const parent = path.dirname(project)
        const exitcode, res = runTool({ "rojo", "build", "build.project.json", "-o", "output.rbxl" }, { cwd = parent })
        if exitcode == 0 then
            if noBuildOutput then
                const buildOutput = path.join(parent, "output.rbxl")
                fs.remove(buildOutput)
            end

            succeed(project)
        elseif exitcode == 1 then
            failed(project, ty, res :: string)
        elseif exitcode == 2 then
            err(project, ty, res :: string)
        end
    end
end

const luauFiles = getSrcLuaus()
const numberOfLuauFiles = #luauFiles
print(tint.green("FOUND", tint.reset(`found {numberOfLuauFiles} luau files`)))

const projectsToBuild = getBuildProjectJson()
const numberOfProjectsToBuild = #projectsToBuild
print(tint.green("FOUND", tint.reset(`found {numberOfProjectsToBuild} projects to build`)))
print()

if not noStylua then
    checkStylua(luauFiles)
end
if not noSelene then
    checkSelene(luauFiles)
end
if buildVerification then
    print()
    buildWithRojo(projectsToBuild)
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

if next(toolFails) then
    print(tint.yellow.bold("\nFAILED WORKS:"))
    for toolType, fails in toolFails do
        print(tint.reset(`- [{toolType}]:`, tint.red(`{fails}`)))
    end
end

if qualityFailed then
    print(tint.red.bold("\nQUALITY IS BAD"))
    process.exit(1)
else
    print(tint.green.bold("\nQUALITY IS GOOD"))
    process.exit(0)
end
