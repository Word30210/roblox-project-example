const fs = require("@std/fs")
const path = require("@std/path")
const process = require("@std/process")

const utils = require("@self/utils")
const options = require("@self/options")
const optionHashmap = options.options

const Collector = require("@self/collector")
const collector = Collector.new()

const luauFiles = utils.getPaths(function(full)
    const subject = path.format(full):gsub("\\", "/")
    const luauMatched = subject:match("/src/.+%.luau?$") ~= nil
    const asphaltGenerated = subject:match("packages/assets/src/assets.luau") ~= nil

    return luauMatched and not asphaltGenerated
end)

const function checkStylua()
    const tool = "stylua"
    const styluaHeader = Collector.header("[STYLUA CHECK]")
    collector:record(styluaHeader)

    for _, luauFile in luauFiles do
        const configFile = utils.findUp(luauFile, "stylua.toml")
        const report = Collector.content("fail", tool, luauFile, configFile, nil, styluaHeader)

        if configFile then
            const res = process.run({
                "stylua",
                utils.toRelative(luauFile),
                "--check",
                "--config-path",
                utils.toRelative(configFile),
            })

            if res.exitcode >= 2 then
                report.status = "err"
                report.detail = res.stderr
                collector:record(report)
            elseif res.exitcode == 1 then
                if optionHashmap.resolveFormat then
                    const resolveRes = process.run({
                        "stylua",
                        utils.toRelative(luauFile),
                        "--config-path",
                        utils.toRelative(configFile),
                    })
                    if resolveRes.exitcode >= 2 then
                        report.status = "err"
                        report.detail = res.stderr
                    elseif resolveRes.exitcode == 1 then
                        report.status = "fail"
                        report.detail = resolveRes.stdout
                    else
                        report.status = "resolved"
                        report.detail = "found formatting issue(s), but resolved."
                    end
                else
                    report.status = "fail"
                    report.detail = res.stdout
                end
            else
                report.status = "pass"
                report.detail = "no formattig issues are found."
            end
        else
            report.status = "err"
            report.detail = "couldn't find 'stylua.toml'."
        end

        collector:record(report)
    end
end

const function checkSelene()
    const tool = "selene"
    const seleneHeader = Collector.header("[SELENE CHECK]")
    collector:record(seleneHeader)

    for _, luauFile in luauFiles do
        const configFile = utils.findUp(luauFile, "selene.toml")
        const report = Collector.content("fail", tool, luauFile, configFile, nil, seleneHeader)

        if configFile then
            const res = process.run({ "selene", utils.toRelative(luauFile), "--config", utils.toRelative(configFile) })

            if res.exitcode >= 2 then
                report.status = "err"
                report.detail = res.stderr
            elseif res.exitcode == 1 then
                report.status = "fail"
                report.detail = res.stdout
            else
                report.status = "pass"
                report.detail = "no linting issues are found."
            end
        else
            report.status = "err"
            report.detail = "couldn't find 'selene.toml'."
        end

        collector:record(report)
    end
end

if optionHashmap.help then
    options.showOptions()
    return
end

checkStylua()
print()
checkSelene()

if collector:hasFailure() then
    process.exit(1)
else
    process.exit(0)
end