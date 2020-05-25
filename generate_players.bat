@echo off

bin\rmac -l*player.lst -DUNROLLED_CODE=0 -DSID_VOICES=0 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=0 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player.s

bin\rmac -l*player.lst -DUNROLLED_CODE=1 -DSID_VOICES=0 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=0 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_unrolled.s

bin\rmac -l*player.lst -DUNROLLED_CODE=0 -DSID_VOICES=1 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=0 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_sid.s

bin\rmac -l*player.lst -DUNROLLED_CODE=1 -DSID_VOICES=1 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=0 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_unrolled_sid.s

bin\rmac -l*player.lst -DUNROLLED_CODE=0 -DSID_VOICES=1 -DPC_REL_CODE=1 -DAVOID_SMC=1 -DUSE_EVENTS=0 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_sid_pcrel_nosmc.s

bin\rmac -l*player.lst -DUNROLLED_CODE=0 -DSID_VOICES=0 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=1 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_events.s

bin\rmac -l*player.lst -DUNROLLED_CODE=1 -DSID_VOICES=0 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=1 -DUSE_SID_EVENTS=0 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_unrolled_events.s

bin\rmac -l*player.lst -DUNROLLED_CODE=0 -DSID_VOICES=1 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=1 -DUSE_SID_EVENTS=1 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call:strip_listing generated_players\player_sid_events_sidevents.s
rem not sure why this line needs to be here. If not, the bat file complains on windows 10 O_o

bin\rmac -l*player.lst -DUNROLLED_CODE=1 -DSID_VOICES=1 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=1 -DUSE_SID_EVENTS=1 -DDUMP_SONG=0 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call:strip_listing generated_players\player_unrolled_sid_events_sidevents.s

bin\rmac -l*player.lst -DUNROLLED_CODE=0 -DSID_VOICES=0 -DPC_REL_CODE=0 -DAVOID_SMC=0 -DUSE_EVENTS=0 -DUSE_SID_EVENTS=0 -DDUMP_SONG=1 -D_RMAC_=1 -D_VASM_=0 PlayerAky.s >NUL
call :strip_listing generated_players\player_dump.s

del PlayerAky.o

exit /b

:strip_listing
bin\sed -e "s/^......................................\...*//gI" -e "s/^......................................-..*//gI" -e "s/.*endif.*//gI" -e "s/.*  if.*//gI" -e "s/.*else.*//gI" -e"s/.*movex.*//gI" -e "s/.*readregs.*//gI" -e "s/.*  a   .*//gI" -e "s/.*  t   .*//gI" -e "s/^........................................//gI" -e "s/undefined.*//gI" -e "/^\s*$/d" Player.lst > %1
del player.lst
exit /b

