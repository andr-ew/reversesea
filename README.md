# reversesea
```
-- reversible polyphonic 
-- pattern instrument demo
--
-- 0.2.0 @andrew
--
-- grid: play notes
-- K2: record pattern
-- K3: play/pause pattern
-- E2: set direction
```

a reduction of [ash/earthsea](https://llllllll.co/t/ash-a-small-collection/21349) to demo a few proposed feature additions for `lib/pattern_time`:
- `pattern:set_reverse()`
- `pattern:resume()`
- a callback system, mirroring + extending `lib/reflection`:
  - `start_callback`
  - `step_callback`
  - `end_of_loop_callback`
  - `end_of_rec_callback`
  - `end_callback`
  - `start_of_record_callback`
  - `clear_callback`
 
compared to [ash/earthsea](https://llllllll.co/t/ash-a-small-collection/21349), the demonstrated pattern logic uses a simple immutable state system with a few advantages:
- ability to reverse playback direction
- notes held at the end of a recording are not stuck
- notes held at the beginning of a recording are included in the pattern

a possible con is performance: a new table copy is created for every grid input
