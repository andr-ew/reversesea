# reversesea
```
reversible polyphonic 
pattern instrument demo

0.1.0 @andrew

grid (left half): play notes
K2: record pattern
E2: set direction
```

a minimal reduction of [ash/earthsea](https://llllllll.co/t/ash-a-small-collection/21349) (and it's [pattern_time](https://github.com/monome/norns/blob/main/lua/lib/pattern_time.lua) library), which adds a reverse function to the pattern recorder. a change that seems simple on the surface, but is actually quite complex once you dig into the implimentation. hence: this small study : )

## problem 1

earthsea records & stores its patterns as a series of events (key on, key off), input from the grid. playing back those events in reverse won't acheive the desired results, as on & off messages will be flipped. moreover, there's a high possibility of stuck notes if each key on event is not matched with a key off.

## solution 1

rather than recording & storing **_events_** associated with the grid, the pattern recorder should record & store **_data_** assoiated with the grid – i.e. the full list of which keys are held at any given time throuout the pattern.

## problem 2

the most common way to store this kind of data in lua are tables, however tables are [mutable](https://en.wikipedia.org/wiki/Immutable_object), meaning that in order to store multiple versions of a table, you have to make a full copy of the table every time. this is sort of a hassle, and also not the most efficient use of resources.

## solution 2

since there are only two possible states of each key at any given time, we can store our data as binary (represented as a single integer variable), rather than tables. within the context of the larger script, this saves on both resources & lines of code.

## problem 3

now that the pattern recorder is storing data rather than input, how can we translate that data into the note on & note off messages used by engines or midi?

## solution 3

binary operations solve this problem nicely ! the solution is to [exlusive or](https://en.wikipedia.org/wiki/Exclusive_or) the most recent data set with the one right before it – which reveals the bits that have _changed_ between the two data sets. then, loop over each bit & run either the note on or note on function for each changed bit. see the `binary_difference` function in the script for a precise implimentation.

## problem 4

unfortunately, on norns (& most all computers), one integer variable can only store up to 64 bits of data, which only covers half of a 128 grid.

## solution 4

an exercise for the reader ;) !! this script currently limits itself to the left half of a 128 grid for demonstaration purposes, but it would be trivial to map the full grid to two integers, for the left & right sides of the grid.
