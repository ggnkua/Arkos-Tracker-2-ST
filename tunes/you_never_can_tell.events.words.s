; Events generated by Arkos Tracker 2.

	; 0

Events:
	dc.w 1	; Wait for 0 frames.
	dc.w 240

	dc.w 10	; Wait for 9 frames.
	dc.w 242

	dc.w 28	; Wait for 27 frames.
	dc.w 0

Events_Loop:
	dc.w 172	; Wait for 171 frames.
	dc.w 240

	dc.w 105	; Wait for 104 frames.
	dc.w 242

	dc.w 199	; Wait for 198 frames.
	dc.w 240

	dc.w 105	; Wait for 104 frames.
	dc.w 242

	dc.w 199	; Wait for 198 frames.
	dc.w 240

	dc.w 105	; Wait for 104 frames.
	dc.w 242

	dc.w 199	; Wait for 198 frames.
	dc.w 240

	dc.w 128	; Wait for 127 frames.
	dc.w 242

	dc.w 5	; Wait for 4 frames.
	dc.w 0

	dc.w 0	; End of sequence.
	dc.l Events_Loop	; Loops here.