const path = require("@std/path")

const tint = require("@pkg/tint")
const ANSI_RESET = tint.reset("")

const utils = require("./utils")
const options = require("./options")

export type ReportType = "header" | "content"
export type Status = "pass" | "resolve" | "fail" | "err" | "skip" | "unknown"
export type ToolType = "stylua" | "selene" | "asphalt" | "rojo" | "pesde" | "darklua" | "unknown"

type ReportStyle = { ansi: tint.style }
type StatusStyle = { label: string, ansi: tint.style }

const REPORT_STYLE: { header: ReportStyle, content: ReportStyle } = {
    header = { ansi = tint.gray },
    content = { ansi = tint.reset },
}

const STATUS_STYLE: { [Status]: StatusStyle } = {
    pass = { label = "SUCCEED", ansi = tint.bright_green },
    resolve = { label = "RESOLVED", ansi = tint.green },
    fail = { label = "FAILED", ansi = tint.red },
    err = { label = "ERROR", ansi = tint.bright_red },
    skip = { label = "SKIPPED", ansi = tint.blue },
    unknown = { label = "UNKNOWN", ansi = tint.bg_white.black },
}

export type HeaderReport = {
    type: "header",
    detail: string,
    children: { Report },
}
export type ContentReport = {
    type: "content",
    status: Status,
    tool: ToolType,
    file: path.Path,
    subFile: path.Path?,
    detail: string?,
}
export type Report = HeaderReport | ContentReport

const function header(detail: string): HeaderReport
    return {
        type = "header",
        detail = detail,
        children = {},
    }
end

const function content(
    status: Status,
    tool: ToolType,
    file: path.Path,
    subFile: path.Path?,
    detail: string?
): ContentReport
    return {
        type = "content",
        status = status,
        tool = tool,
        file = file,
        subFile = subFile,
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

function Collector.record(self: Collector, report: Report, parent: HeaderReport?)
    if parent then
        table.insert(parent.children, report)
    else
        table.insert(self.reports, report)
    end

    if report.type == "content" then
        if report.status == "fail" or report.status == "err" or report.status == "unknown" then
            table.insert(self.failedReports, report)
        elseif report.status == "skip" then
            table.insert(self.skippedReports, report)
        end
    end
end

function Collector.renderReports(self: Collector): string
    local res = ""

    for index, report in self.reports do
        res ..= self:render(report) .. "\n"
        if index < #self.reports then
            res ..= "\n"
        end
    end

    return res
end

function Collector.render(self: Collector, report: Report, padding: number?): string
    if report.type == "header" then
        return self:renderHeader(report, padding)
    elseif report.type == "content" then
        return self:renderContent(report, padding)
    else
        return ""
    end
end

const function getPadding(padding: number): string
    local res = (" "):rep(padding - 1)
    if padding > 0 then
        res ..= ANSI_RESET .. REPORT_STYLE.header.ansi("└ ") .. ANSI_RESET
    end

    return res
end

function Collector.renderHeader(self: Collector, report: HeaderReport, padding: number?): string
    local res = getPadding(padding or 0)
    res ..= ANSI_RESET .. REPORT_STYLE.header.ansi(report.detail) .. ANSI_RESET

    for _, child in report.children do
        res ..= "\n" .. self:render(child, (padding or 0) + 1 + if padding == nil then 0 else 1)
    end

    return res
end

function Collector.renderContent(_: Collector, report: ContentReport, padding: number?): string
    local res = getPadding(padding or 0)
    res ..= ANSI_RESET .. STATUS_STYLE[report.status].ansi(STATUS_STYLE[report.status].label) .. ANSI_RESET
    res ..= " " .. ANSI_RESET .. tint.gray(utils.toRelative(report.file)) .. ANSI_RESET

    if report.subFile then
        res ..= " " .. ANSI_RESET .. tint.gray(`({utils.toRelative(report.subFile)})`) .. ANSI_RESET
    end

    if options.options.printResults and report.detail then
        res ..= " " .. ANSI_RESET .. REPORT_STYLE.content.ansi(report.detail) .. ANSI_RESET
    end

    return res
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
