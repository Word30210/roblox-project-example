const path = require("@std/path")

const tint = require("@pkg/tint")
const utils = require("./utils")
const options = require("./options")

export type Status = "pass" | "resolved" | "fail" | "err" | "skipped"
export type ToolType = "stylua" | "selene" | "rojo" | "pesde" | "darklua"

export type HeaderReport = {
    kind: "header",
    detail: string,
}
export type ContentReport = {
    kind: "content",
    header: HeaderReport?,
    status: Status,
    tool: ToolType,
    target: path.Path,
    config: path.Path?,
    detail: string?,
}
export type Report = HeaderReport | ContentReport

const REPORT_STYLE = {
    header = { ansi = tint.gray },
    content = { ansi = tint.reset },
}

const STATUS_STYLE = {
    pass = { label = "SUCCEED", ansi = tint.bright_green },
    resolved = { label = "RESOLVED", ansi = tint.green },
    fail = { label = "FAILED", ansi = tint.red },
    err = { label = "ERROR", ansi = tint.bright_red },
    skipped = { label = "SKIPPED", ansi = tint.blue },
}

const function header(detail: string): HeaderReport
    return {
        kind = "header",
        detail = detail,
    }
end

const function content(
    status: Status,
    tool: ToolType,
    target: path.Path,
    config: path.Path?,
    detail: string?,
    header: HeaderReport?
): ContentReport
    return {
        kind = "content",
        header = header,
        status = status,
        tool = tool,
        target = target,
        config = config,
        detail = detail,
    }
end

const Collector = {}
const CollectorPrototype = table.freeze({
    __index = Collector,
})

export type Collector = setmetatable<{
    reports: { Report },
    failedReports: { Report },
    skippedReports: { Report },
}, typeof(CollectorPrototype)>

const function new(): Collector
    return setmetatable({
        reports = {},
        failedReports = {},
        skippedReports = {},
    }, CollectorPrototype)
end

const function printReport(report: Report)
    if report.kind == "header" then
        print(REPORT_STYLE.header.ansi(report.detail))
    elseif report.kind == "content" then
        const header = report.header
        if header then
            const headerAnsi = REPORT_STYLE.header.ansi
            const contentAnsi = REPORT_STYLE.content.ansi
            const statusLabel: string = STATUS_STYLE[report.status].label
            const statusAnsi: tint.style = STATUS_STYLE[report.status].ansi
            print(
                headerAnsi(
                    "└",
                    statusAnsi(statusLabel),
                    tint.gray(utils.toRelative(report.target)),
                    if report.config then tint.gray(`({utils.toRelative(report.config)})`) else "",
                    if options.options.printResults and report.detail then contentAnsi(report.detail) else ""
                )
            )
        else
            const contentAnsi = REPORT_STYLE.content.ansi
            const statusLabel: string = STATUS_STYLE[report.status].label
            const statusAnsi: tint.style = STATUS_STYLE[report.status].ansi
            print(
                statusAnsi(
                    statusLabel,
                    tint.gray(utils.toRelative(report.target)),
                    if report.config then tint.gray(`({utils.toRelative(report.config)})`) else "",
                    if options.options.printResults and report.detail then contentAnsi(report.detail) else ""
                )
            )
        end
    end
end

function Collector.record(self: Collector, report: Report)
    table.insert(self.reports, report)
    if report.kind == "content" then
        if report.status == "fail" or report.status == "err" then
            table.insert(self.failedReports, report)
        elseif report.status == "skipped" then
            table.insert(self.skippedReports, report)
        end
    end
    printReport(report)
end

function Collector.hasFailure(self: Collector): boolean
    return #self.failedReports > 0
end

function Collector.hasSkipped(self: Collector): boolean
    return #self.skippedReports > 0
end

return table.freeze({
    new = new,
    header = header,
    content = content,
})
