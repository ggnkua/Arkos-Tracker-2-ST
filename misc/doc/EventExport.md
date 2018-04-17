# Event Export 

If a user wants to use its custom format, or the AKY or Lightweight format and still use events or digidrums, it is possible to export the events as a source file.



## Format

The format is very simple. Events are encoded this way:

```
dw wait + 1 (0 = end. May be 1, in which case the event must be executed immediately)

if not end:
	db event (>0 normally, or 0 if no event (see below))
else 
    dw address to go to (for looping). Reads the wait.
```

After all the events are encoded, a last event (wait = 0, marking the end) is encoded to "finish" the song: you will need the full duration of the song in the events. This last event is followed by an address used for looping the song/events. Note that since the song may not start at the beginning, this address may point anywhere in the file.



In the very very unlikely event that a song lasts more than 21 mns (at 50Hz) without any event and that an event is performed after, the 16 bits counter won't be enough. To handle this case, several "wait" can be encoded (with the maximum value of 0xfffe) and the event 0 is encoded, meaning "no event".



A 0 event can also be encoded on the loop point: a waiting can be "cut in two" for the loop to join.



