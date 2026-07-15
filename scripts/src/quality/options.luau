const process = require("@std/process")

const tint = require("@pkg/tint")

export type Options = {
    aliases: { string },
    description: string,
}

const options: { Options } = {}
const module = {}

const function register(optionAliases: { string }, description: string): boolean
    table.insert(options, {
        aliases = optionAliases,
        description = description,
    })

    for _, option in optionAliases do
        option = "--" .. option:gsub(" ", "-")
        if table.find(process.args, option) then
            return true
        end
    end

    return false
end

function module.showOptions()
    print("Usage: lute run scripts/src/quality [options]\n")
    print("Options:")

    const function joinOptions(optionAliases: { string }): string
        local res = ""
        for _, option in optionAliases do
            option = "--" .. option:gsub(" ", "-")
            if #res > 0 then
                res ..= ", "
            end
            res ..= tint.green(option) .. tint.reset("")
        end
        return res
    end

    for _, option in options do
        print(`    {joinOptions(option.aliases)}`)
        print(`        {option.description}`)
        print()
    end
end

module.options = table.freeze({
    help = register({ "help" }, "Shows usages."),
    noStylua = register({ "no stylua", "no format" }, "Skip running StyLua; source files are left unformatted."),
    resolveFormat = register(
        { "resolve format", "resolve with stylua" },
        "Let StyLua rewrite files in place to resolve formatting differences."
    ),
    noSelene = register({ "no selene", "no lint" }, "Skip running selene; no static analysis is performed."),
    doBuild = register({ "build", "do build", "rojo", "do rojo" }, "Run the Rojo build step to produce place files."),
    noBuildOutput = register(
        { "no build output", "no rojo output" },
        "Suppress Rojo's build output; the build still runs, just quietly."
    ),
    printResults = register(
        { "verbose", "print results" },
        "Print detailed results for each step instead of a summary."
    ),
})

return module
