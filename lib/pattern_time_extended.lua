--- timed pattern event recorder/player
-- additional features added by @andrew
-- @module lib.pattern

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new()
  local i = {}
  setmetatable(i, pattern)
  i.rec = 0
  i.play = 0
  i.overdub = 0
  i.prev_time = 0
  i.step = 0
  i.time_factor = 1
  i.reverse = false
  i.loop = true
  i.event = {}
  i.time = {}
  i.count = 0
  
  i.metro = metro.init(function() i:next_event() end,1,1)

  i.process = function(_) print("event") end

  i.start_callback       = function() end
  i.step_callback        = function() end
  i.end_of_loop_callback = function() end
  i.end_of_rec_callback  = function() end
  i.end_callback         = function() end
  i.start_of_record_callback = function() end
  i.clear_callback = function() end

  return i
end

--- clear this pattern
function pattern:clear(silent)
  if not silent then self.clear_callback() end

  self.metro:stop()
  self.rec = 0
  self.play = 0
  self.overdub = 0
  self.prev_time = 0
  self.event = {}
  self.time = {}
  self.count = 0
  self.step = 0
  self.time_factor = 1
  self.reverse = false
  self.loop = true
end

--- adjust the time factor of this pattern.
-- @tparam number f time factor
function pattern:set_time_factor(f)
  self.time_factor = f or 1
end

--- adjust the direction of this pattern.
-- @tparam boolean reverse
function pattern:set_reverse(reverse)
  self.reverse = reverse
end

--- set to false to disable looping of this pattern. default true
-- @tparam boolean reverse
function pattern:set_loop(loop)
  self.loop = loop
end

--- start recording
function pattern:rec_start(silent)
  print("pattern rec start")
  self.rec = 1
  
  if not silent then self.start_of_record_callback() end
end

--- stop recording
function pattern:rec_stop(silent)
  if self.rec == 1 then
    if not silent then self.end_of_rec_callback() end

    self.rec = 0
    if self.count ~= 0 then
      --print("count "..self.data.count)
      local t = self.prev_time
      self.prev_time = util.time()
      self.time[self.count] = self.prev_time - t
      --tab.print(self.data.time)
    else
      --print("pattern_time: no events recorded")
    end 
  --else print("pattern_time: not recording")
  end
end

--- watch
function pattern:watch(e)
  if self.rec == 1 then
    self:rec_event(e)
  elseif self.overdub == 1 then
    self:overdub_event(e)
  end
end

--- record event
function pattern:rec_event(e)
  local c = self.count + 1
  if c == 1 then
    self.prev_time = util.time()
  else
    local t = self.prev_time
    self.prev_time = util.time()
    self.time[c-1] = self.prev_time - t
  end
  self.count = c
  self.event[c] = e
end

-- TODO: fix behavior for reverse playing pattern
-- add overdub event
function pattern:overdub_event(e)
  local c = self.step + 1
  local t = self.prev_time
  self.prev_time = util.time()
  local a = self.time[c-1]
  self.time[c-1] = self.prev_time - t
  table.insert(self.time, c, a - self.time[c-1])
  table.insert(self.event, c, e)
  self.step = self.step + 1
  self.count = self.count + 1
end

--- start this pattern
function pattern:start()
  if self.count > 0 then
    if not silent then self.start_callback() end

    --print("start pattern ")
    self.prev_time = util.time()
    self.process(self.event[1])
    self.play = 1
    self.step = 1
    self.metro.time = self.time[1] * self.time_factor
    self.metro:start()
  end
end

--- resume this pattern in the last position after stopping
function pattern:resume(silent)
    if self.count > 0 then
        if not silent then self.start_callback() end

        self.prev_time = util.time()
        self.step = util.wrap(self.step, 1, self.count)
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

--- process next event
function pattern:next_event()
  local next_step = self.step + (self.reverse and -1 or 1)

  if self.loop then 
    next_step = util.wrap(next_step, 1, self.count) 
  end

  self.step = next_step

  if self.step <= self.count and self.step > 0 then
    self.prev_time = util.time()

    self.process(self.event[self.step])
    self.metro.time = self.time[self.step] * self.time_factor

    self.metro:start()
  end
  
  if (not self.loop) and (self.step == self.count or next_step == 1) then
    -- self:stop()
    self.metro:stop()
    self.step = self.step + 1
  end
end

--- stop this pattern
function pattern:stop(silent)
  if self.play == 1 then
    self.play = 0
    self.overdub = 0
    self.metro:stop()

    if not silent then self.end_callback() end
  --else print("pattern_time: not playing") end
  end
end

--- set overdub
function pattern:set_overdub(s, silent)
  if s==1 and self.play == 1 and self.rec == 0 then
    self.overdub = 1
    if not silent then self.start_of_record_callback() end
  else
    if not silent then self.end_of_rec_callback() end
    self.overdub = 0
  end
end

return pattern
