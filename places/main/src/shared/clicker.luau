export type Clicker = {
    read score: number,
    read clickValue: number,
}

const Clicker = {}

function Clicker.new(initial: Clicker?): Clicker
    return table.freeze({
        score = if initial then initial.score else 0,
        clickValue = if initial then initial.clickValue else 1,
    })
end

function Clicker.click(clicker: Clicker): Clicker
    if clicker.clickValue <= 0 then
        error(`.clickValue must be positive, got {clicker.clickValue}`)
    end

    return table.freeze({
        score = clicker.score + clicker.clickValue,
        clickValue = clicker.clickValue,
    })
end

function Clicker.applyAuthoritative(clicker: Clicker, authoritative: number): Clicker
    return table.freeze({
        score = authoritative,
        clickValue = clicker.clickValue,
    })
end

return table.freeze(Clicker)
