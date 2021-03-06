; docformat = 'rst'
;
; NAME:
;       mms_dss_read_sunpulse
;
;*****************************************************************************************
;   Copyright (c) 2015, University of New Hampshire                                      ;
;   All rights reserved.                                                                 ;
;                                                                                        ;
;   Redistribution and use in source and binary forms, with or without modification,     ;
;   are permitted provided that the following conditions are met:                        ;
;                                                                                        ;
;       * Redistributions of source code must retain the above copyright notice,         ;
;         this list of conditions and the following disclaimer.                          ;
;       * Redistributions in binary form must reproduce the above copyright notice,      ;
;         this list of conditions and the following disclaimer in the documentation      ;
;         and/or other materials provided with the distribution.                         ;
;       * Neither the name of the University of New Hampshire nor the names of its       ;
;         contributors may  be used to endorse or promote products derived from this     ;
;         software without specific prior written permission.                            ;
;                                                                                        ;
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY  ;
;   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES ;
;   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT  ;
;   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,       ;
;   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED ;
;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR   ;
;   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     ;
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN   ;
;   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  ;
;   DAMAGE.                                                                              ;
;*****************************************************************************************
;
; PURPOSE:
;+
;   Read DSS housekeeping files (HK 0x101)
;
; :Categories:
;   MMS, DSS
;
; :Params:
;       FILENAMES:          in, required, type=string
;                           Name(s) of the sunpulse data files to read.
;       TSTART:             in, optional, type=string
;                           Start time of the data interval to read, as an ISO-8601 string.
;       TEND:               in, optional, type=string
;                           End time of the data interval to read, as an ISO-8601 string.
;
; :Keywords:
;       UNIQ_PACKETS:       out, optional, type=struct, default=false
;                           Select only the unique packets.
;       UNIQ_PULSE:         out, optional, type=struct, default=false
;                           Select only uniq sunpulse information. Setting this keyword
;                               automatically sets `UNIQ_PACKETS` to true.
;
; :Returns:
;       HK_STRUCT:       Structure of sun pulse information. Tags are::
;                           'hk_epoch' - TT2000 epoch times of each packet
;                           'sunpulse' - TT2000 epoch times of each sun pulse
;                           'flag'     - Period flags
;                                          0: s/c sun pulse
;                                          1: s/c pseudo sun pulse
;                                          2: s/c CIDP generated speudo sun pulse
;                           'period'   - Period (micro-sec) of revolution. Only
;                                        returned when FLAG=0 and only on the second and
;                                        subsequent received sun pulses from the s/c.
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 348
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@unh.edu
;
; :History:
;   Modification History::
;       2015/02/15  -   Written by Matthew Argall
;       2015/05/28  -   Take file names as input instead of searching for files. - MRA
;       2015/08/22  -   TSTART and TEND are prameters, not keywords. - MRA
;-
function mms_dss_read_sunpulse, filenames, tstart, tend, $
UNIQ_PACKETS=uniq_packets, $
UNIQ_PULSE=uniq_pulse
	compile_opt idl2
	on_error, 2

	uniq_pulse   = keyword_set(uniq_pulse)
	uniq_packets = keyword_set(uniq_packets) || uniq_pulse

;-----------------------------------------------------
; Check Input Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Number of files given
	nFiles = n_elements(filenames)

	;Dissect the file name
	mms_dissect_filename, filenames, $
	                      INSTR   = instr, $
	                      LEVEL   = level, $
	                      MODE    = mode, $
	                      OPTDESC = optdesc, $
	                      SC      = sc
	
	;Do files exist?
	if min(file_test(filenames, /READ)) eq 0 then message, 'Files must exist and be readable.'
	
	;Level, Mode
	if min(instr eq 'fields') eq 0 then message, 'Only "fields" files are allowed.'
	if min(mode  eq 'hk')     eq 0 then message, 'All files must be housekeeping (HK) files.'
	if min(level eq 'l1b')    eq 0 then message, 'Only L1B files are allowed.'

	;We now know all the files match, so keep on the the first value.
	if nFiles gt 1 then begin
		sc      = sc[0]
		instr   = instr[0]
		mode    = mode[0]
		level   = level[0]
		optdesc = optdesc[0]
	endif

;-----------------------------------------------------
; Varialble Names \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Create the variable names
	sunpulse_name = mms_construct_varname(sc, '101', 'sunpulse')
	flag_name     = mms_construct_varname(sc, '101', 'sunssps')
	period_name   = mms_construct_varname(sc, '101', 'iifsunper')

;-----------------------------------------------------
; Read the Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Read the data
	sunpulse = MrCDF_nRead(filenames, sunpulse_name, $
	                       DEPEND_0 = hk_epoch, $
	                       TSTART   = tstart, $
	                       TEND     = tend)
	period = MrCDF_nRead(filenames, period_name, TSTART=tstart, TEND=tend)
	flag   = MrCDF_nRead(filenames, flag_name,   TSTART=tstart, TEND=tend)

;-----------------------------------------------------
; Unique Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if uniq_packets then begin
		iUniq    = MrUniq(hk_epoch, /SORT)
		hk_epoch = hk_epoch[iUniq]
		sunpulse = sunpulse[iUniq]
		period   = period[iUniq]
		flag     = flag[iUniq]
	endif
	
	if uniq_pulse then begin
		iUniq    = MrUniq(sunpulse, /SORT)
		sunpulse = sunpulse[iUniq]
		period   = period[iUniq]
		flag     = flag[iUniq]
	endif

	;Return a structure
	hk_struct = { epoch:    hk_epoch, $
	              sunpulse: sunpulse, $
	              flag:     flag, $
	              period:   period }

	return, hk_struct
end
