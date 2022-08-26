-- reversible polyphonic 
-- pattern instrument demo
--
-- 0.1.0 @andrew

g = grid.connect()

local polysub = require 'polysub'
engine.name = 'PolySub'

--include modified pattern_time with reverse option
local pattern_time = include 'lib/pattern_time_reverse'
pat = pattern_time.new()

--converstion between x,y coordinates (1-based) & bit index (0-based)

function xy_to_bit(x, y, width, height)
    local w = width or 8
    local h = height or 8
    return (h - y) * w + (x-1)
end
function bit_to_xy(bit, width, height)
    local w = width or 8
    local h = height or 8
    return (bit % w)+1, h - ((bit // w)+0)
end

--utility functions for working with binary data, based on the bit index
--  NOTE: these do *not* edit the data in place, as with a table. they return new data, 
--        which you can reassign to the 'grid_data' variable (see: mutablity in programming).
--
--  useful ref: https://wiki.xxiivv.com/site/binary.html

function binary_get(data, bit) --get bit
    return (data >> bit) & 1
end
function binary_set(data, bit) --set bit to 1
    return data | (1 << bit)
end
function binary_clear(data, bit) --set bit to 0
    return data & ~(1 << bit)
end
function binary_toggle(data, n, z) --not using this one, but it's a handy referece!
    return data ~ (1 << bit)
end
--compare two datasets, run a function for each bit that has changed between the two sets
function binary_difference(new_data, old_data, fn_added, fn_removed)
    local changed = new_data ~ old_data
    for bit = 0,63 do
        if binary_get(changed, bit) > 0 then
            if binary_get(new_data, bit) > 0 then
                fn_added(bit)
            else
                fn_removed(bit)
            end
        end
    end
end

--grid data structure, an integer which will be treated as binary data
--  IMPORTANT: an ineger in lua may only store 64 bits. so a key limitation of this method
--             is that only 64 keys of the grid can be stored.
--             in this script, we're only using the left half of a 128 grid
--  initialized as 0 (all keys off)
grid_data = 0

--update grid data, and play notes *based on the change of data*
function process_grid_data(new_data)
    local old_data = grid_data

    --send the indices of *changed* bits (high & low) into to note on & note off functions
    binary_difference(new_data, old_data, note_on, note_off)
    
    grid_data = new_data
    grid_is_dirty = true
end
--this function is the callback for the pattern recorder
pat.process = process_grid_data

--clear the grid data, simply by setting it to the intial value, 0
function clear_grid_data()
    process_grid_data(0)
end

--grid input
function g.key(x, y, z)
    local new_data

    --set or unset a bit in the grid data, assign it to new_data
    local bit = xy_to_bit(x, y)
    if z>0 then
        new_data = binary_set(grid_data, bit)
    else
        new_data = binary_clear(grid_data, bit)
    end
    
    --send updated grid data to pattern + process it in real time
    pat:watch(new_data)
    process_grid_data(new_data)
end

-- grid drawing & render loop

function grid_redraw()
    g:all(0)

    --render each bit as a key on the grid
    for bit = 0,127 do
        local x, y = bit_to_xy(bit)
        local lvl = binary_get(grid_data, bit) * 15
        g:led(x, y, lvl)
    end
  
    g:refresh()
end
grid_is_dirty = true
clock.run(function()
    while true do
        clock.sleep(1/30)
        if grid_is_dirty then
            grid_is_dirty = false
            grid_redraw()
        end
    end
end)

--pythagorean major pent, ref: https://en.wikipedia.org/wiki/Pythagorean_tuning 
scale = { 1/1, 9/8, 81/64, 3/2, 27/16 }

--playing notes(based on bit index)
function note_on(bit)
    local id = bit + 1
    local oct = (bit//#scale)
    local deg = (bit % #scale) + 1
    local ratio = scale[deg]
    local hz = 110 * 2^(oct - 5) * ratio

    engine.start(id, hz)
end
function note_off(bit)
    local id = bit + 1
    engine.stop(id)
end

--norns stuff

function init()
    polysub:params()
end

pos = {
    k = {
        x = { [2] = 2,        [3] = 64       },
        y = { [2] = 64 * 7/8, [3] = 64 * 7/8 },
    },
    e = {
        x = { [2] = 2,        [3] = 64       },
        y = { [2] = 64 * 5/8, [3] = 64 * 5/8 },
    },
}

rec_text = 'record'
dir_text = '>>>'

function redraw()
    screen.clear()

    screen.move(pos.k.x[2], pos.k.y[2])
    screen.text(rec_text)
    
    if pat.count > 0 then
        screen.move(pos.e.x[2], pos.e.y[2])
        screen.text(dir_text)
    end

    screen.update()
end

function key(n, z)
    if z>0 then
        if n==2 then
            if pat.rec == 0 then
                if pat.count > 0 then
                    pat:stop()
                    clear_grid_data(0)                
                    pat:clear()
                    rec_text = 'record'
                else
                    pat:rec_start()
                    rec_text = 'recording...'
                end
            elseif pat.rec == 1 then
                pat:rec_stop()

                if pat.count > 0 then
                    pat:start()
                    rec_text = 'stop'
                end
            end
        elseif n == 3 then
        end

        redraw()
    end
end

function enc(n, d)
    if n==2 and pat.count > 0 then
        if d > 0 then
            pat:set_reverse(false)
            dir_text = '>>>'
        else
            pat:set_reverse(true)
            dir_text = '<<<'
        end
        
        redraw()
    end
end

