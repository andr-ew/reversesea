-- reversible polyphonic 
-- pattern instrument demo
--
-- 0.2.0 @andrew
--
-- grid: play notes
-- K2: record pattern
-- K3: play/pause pattern
-- E2: set direction

g = grid.connect()

local polysub = require 'polysub'
engine.name = 'PolySub'

local pattern_time = include 'lib/pattern_time_extended'
pat = pattern_time.new()

--grid info 
local width = 16
local height = 8
local count = width * height

--on/off key states for the grid. indexed 1 - 128, values stored as 1/0 (nil assumed 0)
--    the value at this table variable should NEVER be mutated, ONLY replaced with a new table
grid_state = {}

--conversion between x/y coordinates & the 1-128 index used for grid_state
function xy_to_table_index(x, y)
    return (height - y) * width + x
end
function table_index_to_xy(index)
    return ((index - 1) % width) + 1, height - ((index - 1) // width)
end

--update grid state, and play notes *based on the change of state*
function process_grid_state(new_state)
    local old_state = grid_state

    for i = 1, count do
        local new = new_state[i] or 0
        local old = old_state[i] or 0

        if new==1 and old==0 then note_on(i)
        elseif new==0 and old==1 then note_off(i) end
    end
    
    grid_state = new_state

    grid_is_dirty = true
end

--this function is the callback for the pattern recorder
pat.process = process_grid_state

--watch & process new state
function set_grid_state(new_state)
    pat:watch(new_state)
    process_grid_state(new_state)
end

--clear the grid & turn off playing notes, simply by setting it to a blank table
function clear_grid_state()
    process_grid_state({})
end

--insert a snapshot of the current state into the pattern, if neccesary
function insert_snapshot()
    local has_keys = false
    for i = 1, count do if (grid_state[i] or 0) > 0 then  
        has_keys = true; break
    end end

    if has_keys then set_grid_state(grid_state) end
end

--set callbacks to remove stuck notes & snapshot current held state
pat.clear_callback = clear_grid_state
pat.start_of_record_callback = insert_snapshot
pat.end_of_rec_callback = insert_snapshot
pat.end_callback = clear_grid_state

--grid input
function g.key(x, y, z)
    local old_state = grid_state
     
    --the grid_state table is copied for every input, this means the old state can be stored in the pattern without modification
    local new_state = {}
    for k,v in pairs(old_state) do new_state[k] = v end

    --update the new state only with input
    new_state[xy_to_table_index(x, y)] = z
    
    --set the grid state to the new state
    set_grid_state(new_state)
end

-- grid drawing & render loop
function grid_redraw()
    g:all(0)

    --render every key from grid_state
    for i = 1,count do
        local x, y = table_index_to_xy(i)
        local lvl = (grid_state[i] or 0) * 15
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

--playing notes(based on table index)
function note_on(id)
    local x, y = table_index_to_xy(id)     
    local column, row = x, (height - y) + 1

    local oct = ((column - 1)//#scale) + row
    local deg = ((column - 1) % #scale) + 1
    local ratio = scale[deg]
    local hz = 110 * 2^(oct - 5) * ratio

    engine.start(id, hz)
end
function note_off(id)
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
play_text = 'playing'
dir_text = '>>>'

function redraw()
    screen.clear()

    screen.move(pos.k.x[2], pos.k.y[2])
    screen.text(rec_text)
    
    if pat.count > 0 and pat.rec == 0 then
        screen.move(pos.k.x[3], pos.k.y[3])
        screen.text(play_text)
    
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
                    rec_text = 'clear'
                end
            end
        elseif n == 3 then
            if pat.play > 0 then
                pat:stop()
                play_text = 'pausing'
            else
                pat:resume()
                play_text = 'playing'
            end
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

