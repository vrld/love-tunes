osc = {}
function osc.rect(f)
    return function(t)
        local t = (t * f) % 1
        if t < .5 then return -1 end
        return 1
    end
end

function osc.saw(f)
    return function(t)
        local t = (t * f) % 1
        return 2 * t - 1
    end
end

function osc.tri(f)
    return function(t)
        local t = (t * f) % 1
        if t < .5 then return 4 * t - 1 end
        return 3 - 4 * t
    end
end

function osc.sin(f)
    return function(t)
        return math.sin(2 * math.pi * t * f)
    end
end

function osc.wn()
    return function()
        return math.random() * 2 - 1
    end
end

function osc.pn()
    local val = 0
    return function()
        val = math.min(1, math.max(-1, math.random() * 2 - 1 + val))
        return val
    end
end

function makesample(osc, len, rate)
    local len, rate = len or 1, rate or 44100
    local samples = math.floor(len * rate)
    local sd = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0,samples do
        sd:setSample(i, osc(i / rate))
    end
    return sd
end

env = {}
function env.const(v)
    return function() return v end
end

function env.fall(len)
    return function(t)
        return math.max(0, 1 - t / len)
    end
end

function env.rise(len)
    return function(t)
        return math.min(1, t / len)
    end
end

function env.risefall(rise,decay, fall)
    return function(t)
        if t > rise + decay then
            return math.max(0, 1 - (t - decay - rise) / fall)
        end
        return math.min(1, t / rise)
    end
end

function envelope(f, ...)
    local envelopes = {...}
    return function(t)
        local v = f(t)
        for _, g in ipairs(envelopes) do
            v = v * g(t)
        end
        return v
    end
end

pitch = {}
function pitch.step(k)
    return math.pow(math.pow(2, 1/12), k)
end

pitch.fractions = {
    ["c"] = pitch.step(-9),
    ["c#"] = pitch.step(-8),
    ["d"] = pitch.step(-7),
    ["d#"] = pitch.step(-6),
    ["e"] = pitch.step(-5),
    ["f"] = pitch.step(-4),
    ["f#"] = pitch.step(-3),
    ["g"] = pitch.step(-2),
    ["g#"] = pitch.step(-1),
    ["a"] = 1,
    ['a#'] = pitch.step(1),
    ['b'] = pitch.step(2),
}

function pitch.base(n)
    return 440 * math.pow(2, n - 4)
end

function pitch.get(p, octave)
    local base = pitch.base(octave or 4)
    return pitch.fractions[p] * base
end

grid = {}
function love.load()
    love.graphics.setBackgroundColor(100,70,20)
    love.graphics.setFont(60)

    for i = 1,16 do
        grid[i] = {}
    end

end

local time, line, pause = 0, 1, true
function love.draw()
    for i = 1,16 do
        for k = 1,12 do
            if not grid[i][k] then
                love.graphics.setColor(40,20,0)
            elseif grid[i][k].osc == osc.sin then
                love.graphics.setColor(40,80,190)
            elseif grid[i][k].osc == osc.tri then
                love.graphics.setColor(40,190,80)
            elseif grid[i][k].osc == osc.saw then
                love.graphics.setColor(190,190,50)
            elseif grid[i][k].osc == osc.rect then
                love.graphics.setColor(190,40,40)
            end
            love.graphics.rectangle('fill', (i-1)*50 + 1, (k-1)*50+1, 48, 48)
        end
    end

    love.graphics.setColor(255,255,255,40)
    love.graphics.rectangle('fill', (line-1)*50, 0, 50, love.graphics.getHeight()-1)

    if pause then
        love.graphics.setColor(255,255,255,100)
        love.graphics.print("LOVE ON HALT", 10, 50)
    end
end

function love.update(dt)
    if pause then
        return 
    end

    time = time + dt
    if time >= .25 then
        time = time - .25
        line = line + 1
        if line > 16 then line = 1 end

        for k = 1,12 do
            if grid[line][k] then
                love.audio.play(grid[line][k].source)
            end
        end

    end
end

function love.keyreleased(key)
    if key == 'p' then
        pause = not pause
    end
end

local info = {
    [osc.sin]  = {next = osc.tri,  amp = .7, oct = 5},
    [osc.tri]  = {next = osc.saw,  amp = .6, oct = 4},
    [osc.saw]  = {next = osc.rect, amp = .3, oct = 3},
    [osc.rect] = {next = osc.sin,  amp = .2, oct = 2},
}

local pitchtable = { 'c', 'c#', 'd', 'd#', 'e', 'f', 'f#', 'g', 'g#', 'a', 'a#', 'b' }
function love.mousereleased(x,y, btn)
    local i,k = math.floor(x/50) + 1, math.floor(y/50)+1
    if btn == 'r' then
        grid[i][k] = nil
        return
    end

    if not grid[i][k] then
        grid[i][k] = { osc = osc.sin }
    else
        grid[i][k] = { osc = info[ grid[i][k].osc ].next }
    end

    local theosc = grid[i][k].osc
    grid[i][k].source = love.audio.newSource(makesample(envelope(
        theosc(pitch.get( pitchtable[13 - k], info[ theosc ].oct)),
        env.const(info[ theosc ].amp),
        env.risefall(.1,.22,.2)), .25))
end
