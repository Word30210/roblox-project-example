const fs = require("@std/fs")
const path = require("@std/path")
const process = require("@std/process")

const tint = require("@pkg/tint")

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
    const header = Collector.header("[STYLUA CHECK]")
    collector:record(header)

    for _, luauFile in luauFiles do
        const configFile = utils.findUp(luauFile, "stylua.toml")
        const report = Collector.content("unknown", tool, luauFile, configFile, nil, header)

        if configFile then
            const ok, res = pcall(process.run, {
                "stylua",
                utils.toRelative(luauFile),
                "--check",
                "--config-path",
                utils.toRelative(configFile),
            }, nil)

            if not ok then
                report.status = "err"
                report.detail = (res :: any) :: string
                continue
            end

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
                        report.status = "resolve"
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

        collector:record(report, header)
    end
end

const function checkSelene()
    const tool = "selene"
    const header = Collector.header("[SELENE CHECK]")
    collector:record(header)

    for _, luauFile in luauFiles do
        const configFile = utils.findUp(luauFile, "selene.toml")
        const report = Collector.content("unknown", tool, luauFile, configFile, nil, header)

        if configFile then
            const ok, res = pcall(
                process.run,
                { "selene", utils.toRelative(luauFile), "--config", utils.toRelative(configFile) },
                nil
            )

            if not ok then
                report.status = "err"
                report.detail = (res :: any) :: string
                continue
            end

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

        collector:record(report, header)
    end
end

const function buildWithRojo()
    type StepOptions = {
        header: Collector.HeaderReport,
        tool: Collector.ToolType,
        location: path.Path,
        skip: boolean,
        runArgs: { string },
        runOptions: process.ProcessRunOptions?,
    }

    const function runStep(stepOptions: StepOptions): StepOptions
        const report = Collector.content("unknown", stepOptions.tool, stepOptions.location)

        if not stepOptions.skip then
            const ok, res = pcall(process.run, stepOptions.runArgs, stepOptions.runOptions)

            if not ok then
                report.status = "err"
                report.detail = (res :: any) :: string

                stepOptions.skip = true
                return stepOptions
            elseif res.exitcode >= 1 then
                report.status = "err"
                report.detail = res.stderr
            else
                report.status = "pass"
                report.detail = "successfully completed."
            end
        else
            report.status = "skip"
            report.detail = "skipped due before step wasn't successfully completed."

            stepOptions.skip = true
            return stepOptions
        end

        collector:record(report, stepOptions.header)
        return stepOptions
    end

    const header = Collector.header("[BUILD VERIFICATION]")
    collector:record(header)

    -- packages
    const packageHeader = Collector.header("[PREPARE PACKAGES]")
    collector:record(packageHeader, header)

    const packagePesdeHeader = Collector.header("[INSTALL DEPENDENCIES]")
    collector:record(packagePesdeHeader, packageHeader)

    const packageDarkluaHeader = Collector.header("[PROCESS WITH DARKLUA]")
    collector:record(packageDarkluaHeader, packageHeader)

    for _, package in fs.listDirectory("packages") do
        const full = path.join("packages", package.name)
        local stepOptions: StepOptions = {
            header = packagePesdeHeader,
            tool = "pesde",
            location = full,
            skip = false,
            runArgs = { "pesde", "install", "--locked" },
            runOptions = { cwd = utils.toRelative(full) },
        }

        -- pesde
        stepOptions = runStep(stepOptions)

        -- darklua
        stepOptions.header = packageDarkluaHeader
        stepOptions.tool = "darklua"
        stepOptions.runArgs = { "darklua", "process", "src", "dist" }
        stepOptions = runStep(stepOptions)
    end

    -- places
    const placeHeader = Collector.header("[PREPARE PACKAGES]")
    collector:record(placeHeader, header)

    const placePesdeHeader = Collector.header("[INSTALL DEPENDENCIES]")
    collector:record(placePesdeHeader, placeHeader)

    const placeSourcemapHeader = Collector.header("[GENERATE SOURCEMAP WITH ROJO]")
    collector:record(placeSourcemapHeader, placeHeader)

    const placeDarkluaHeader = Collector.header("[PROCESS WITH DARKLUA]")
    collector:record(placeDarkluaHeader, placeHeader)

    const placeBuildHeader = Collector.header("[BUILD WITH ROJO]")
    collector:record(placeBuildHeader, placeHeader)

    for _, place in fs.listDirectory("places") do
        const full = path.join("places", place.name)
        local stepOptions: StepOptions = {
            header = placePesdeHeader,
            tool = "pesde",
            location = full,
            skip = false,
            runArgs = { "pesde", "install", "--locked" },
            runOptions = { cwd = utils.toRelative(full) },
        }

        -- pesde
        stepOptions = runStep(stepOptions)

        -- sourcemap
        stepOptions.header = placeSourcemapHeader
        stepOptions.tool = "rojo"
        stepOptions.runArgs = { "rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json" }
        stepOptions = runStep(stepOptions)

        -- darklua
        stepOptions.header = placeDarkluaHeader
        stepOptions.tool = "darklua"
        stepOptions.runArgs = { "darklua", "process", "src", "dist" }
        stepOptions = runStep(stepOptions)

        -- build with rojo
        stepOptions.header = placeBuildHeader
        stepOptions.tool = "rojo"
        stepOptions.runArgs = { "rojo", "build", "build.project.json", "-o", `{place.name}.rbxl` }
        stepOptions = runStep(stepOptions)

        -- remove build output (if the option is turned on)
        if optionHashmap.noBuildOutput then
            pcall(fs.remove, path.join(full, `{place.name}.rbxl`))
        end
    end
end

if optionHashmap.help then
    options.showOptions()
    return
end

if not optionHashmap.noStylua then
    checkStylua()
end
if not optionHashmap.noSelene then
    checkSelene()
end
if optionHashmap.doBuild then
    buildWithRojo()
end

print(collector:renderReports())

if collector:hasFailure() then
    print(tint.red.bold("QUALITY IS BAD"))
    process.exit(1)
else
    print(tint.green.bold("QUALITY IS GOOD"))
    process.exit(0)
end
