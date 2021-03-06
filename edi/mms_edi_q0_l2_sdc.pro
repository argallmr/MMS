; docformat = 'rst'
;
; NAME:
;    mms_edi_q0_l2_sdc
;
; PURPOSE:
;+
;   Process EDI quality zero (Q0) beam data when EDI is in electric field mode.
;
; :Categories:
;    MMS, EDI, L2, Q0
;
; :Params:
;       SC:                 in, required, type=string
;                           Spacecraft ID of the data to be processed. Choices are:
;                               'mms1', 'mms2', 'mms3', 'mms4'
;       MODE:               in, required, type=string
;                           Data rate mode of the data to be processd. Choices are:
;                               'slow', 'fast', 'srvy', 'brst'
;       TSTART:             in, required, type=string
;                           Start time of the file(s) to be processed, formatted as
;                               'YYYYMMDDhhmmss' for burst mode and 'YYYYMMDD' otherwise.
;                               TSTART must match the start time in the file names to
;                               be processed.
;
; :Keywords:
;       DATA_PATH_ROOT:     in, optional, type=string, default=!mms_init.data_path
;                           Root of the SDC-like directory structure where data files
;                               find their final resting place. If not present, the
;                               default is taken from the DATA_PATH_ROOT environment
;                               variable.
;       DROPBOX_ROOT:       in, optional, type=string, default=!mms_init.dropbox
;                           Directory into which data files are initially saved. If
;                               not present, the default is taken from the DROPBOX_ROOT
;                               environment variable.
;       FILE_OUT:           out, optional, type=string
;                           Named variable to receive the name of the output file.
;       HK_ROOT:            in, optional, type=string, default=!mms_init.hk_root
;                           Root of the SDC-like directory structure where housekeeping
;                               files are stored. If not present, the default is taken
;                               from the HK_ROOT environment variable.
;       LOG_PATH_ROOT:      in, optional, type=string, default=!mms_init.log_path
;                           Root directory into which log files are saved. If not
;                               present, the default is taken from the LOG_PATH_ROOT
;                               environment variable.
;       NO_LOG:             in, optional, type=string, default=0
;                           If set, no log file will be created and messages will be
;                               output to the command window.
;
; :Returns:
;       STATUS:             out, required, type=byte
;                           An error code. Values are:::
;                               OK      = 0
;                               Warning = 1-99
;                               Error   = 100-255
;
; :Author:
;    Matthew Argall::
;        University of New Hampshire
;        Morse Hall Room 348
;        8 College Road
;        Durham, NH 03824
;        matthew.argall@unh.edu
;
; :History:
;    Modification History::
;       2015/02/17  -   Written by Matthew Argall
;-
function mms_edi_q0_l2_sdc, sc, mode, tstart, $
DATA_PATH_ROOT=data_path_root, $
DROPTBOX_ROOT=dropbox_root, $
FILE_OUT=file_out, $
HK_ROOT=hk_root, $
LOG_PATH_ROOT=log_path_root, $
NO_LOG=no_log
	compile_opt idl2
	
	;Error handler
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		
		;Write error
		MrPrintF, 'LogErr'
		
		;Close log file
		log = MrStdLog(-2)
		
		;Unexpected trapped error
		file_out = ''
		if n_elements(status) eq 0 || status eq 0 $
			then status  = 100
		
		;Return error status
		return, status
	endif
	
	;Start timer
	t0 = systime(1)

	;Initialize
	;   - Setup directory structure
	unh_edi_init
	status = 0

;-----------------------------------------------------
; Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Check type
	if ~isa(sc,     /SCALAR, 'STRING') then message, 'SC must be a scalar string.'
	if ~isa(mode,   /SCALAR, 'STRING') then message, 'MODE must be a scalar string.'
	if ~isa(tstart, /SCALAR, 'STRING') then message, 'TSTART must be a scalar string.'
	
	;Check value
	if max(sc eq ['mms1', 'mms2', 'mms3', 'mms4']) eq 0 $
		then message, 'SC must be "mms1", "mms2", "mms3", or "mms4".'
	if max(mode eq ['brst', 'srvy']) eq 0 $
		then message, 'MODE must be "srvy" or "brst".'
	
	;Defaults
	tf_log    = ~keyword_set(no_log)
	data_path = n_elements(data_path_root) eq 0 ? !edi_init.data_path_root : data_path_root
	dropbox   = n_elements(dropbox_root)   eq 0 ? !edi_init.dropbox_root   : dropbox_root
	hk_path   = n_elements(hk_root)        eq 0 ? !edi_init.hk_root        : hk_root
	log_path  = n_elements(log_path_root)  eq 0 ? !edi_init.log_path_root  : log_path_root

	;Check permissions
	if ~file_test(log_path, /DIRECTORY, /WRITE) $
		then message, 'LOG_PATH_ROOT must exist and be writeable.'
	if ~file_test(data_path, /DIRECTORY, /READ) $
		then message, 'DATA_PATH_ROOT directory must exist and be readable.'
	if ~file_test(dropbox, /DIRECTORY, /READ, /WRITE) $
		then message, 'DROPBOX_ROOT directory must exist and be read- and writeable.'
	if ~file_test(hk_path, /DIRECTORY, /READ) $
		then message, 'HK_ROOT directory must exist and be readable.'

	;Constants for source files
	instr   = 'edi'
	level   = 'l1a'
	optdesc = 'efield'
	
	;Constants for output
	outmode    = mode
	outlevel   = 'l2'
	outoptdesc = 'q0'

;-----------------------------------------------------
; Create Log File \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Parse input time
	mms_parse_time, tstart, syr, smo, sday, shr, smin, ssec
	
	;Current time
	caldat, systime(0, /JULIAN, /UTC), month, day, year, hour, minute, second
	now = string(FORMAT='(%"%04i%02i%02i_%02i%02i%02i")', year, month, day, hour, minute, second)

	;Build log file
	fLog = strjoin([sc, instr, mode, outlevel, outoptdesc, tstart, now], '_') + '.log'
	
	;Build log directory
	;   - Create the directory if it does not exist
	;   - log_path/amb/ql/mode/year/month[/day]
	fDir = mode eq 'brst' ? filepath('', ROOT_DIR=log_path, SUBDIRECTORY=[sc, instr, mode, outlevel, outoptdesc, syr, smo, sday]) $
	                      : filepath('', ROOT_DIR=log_path, SUBDIRECTORY=[sc, instr, mode, outlevel, outoptdesc, syr, smo])
	if ~file_test(fDir, /DIRECTORY) then file_mkdir, fDir
	
	;Create the log file
	if tf_log then !Null = MrStdLog(filepath(fLog, ROOT_DIR=fDir))

;-----------------------------------------------------
; Find FAST/BRST file \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	if mode eq 'brst' || mode eq 'srvy' || mode eq 'fast' then begin
		;fast or burst?
		fmode = mode eq 'brst' ? mode : 'fast'
	
		;Search for the file
		edi_files = mms_latest_file(dropbox, sc, instr, fmode, level, tstart, $
		                            OPTDESC=optdesc, ROOT=data_path)
		
		;No FAST/BRST files found
		if edi_files eq '' then begin
			MrPrintF, 'LogText', string(sc, instr, fmode, level, optdesc, tstart, $
			                            FORMAT='(%"No %s %s %s %s %s files found for start time %s.")')
		endif
	endif
	
;-----------------------------------------------------
; Find SLOW Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;No "slow" files if we are searching for "brst"
	if mode eq 'srvy' || mode eq 'slow' then begin
		slow_file = mms_latest_file(dropbox, sc, instr, 'slow', level, tstart, $
		                            OPTDESC=optdesc, ROOT=data_path)
		
		;No SLOW files found
		if slow_file eq '' then begin
			MrPrintF, 'LogText', string(sc, instr, 'slow', level, optdesc, tstart, $
			                            FORMAT='(%"No %s %s %s %s %s files found for start time %s.")')
		endif
		
		;Combine slow and fast
		if mode eq 'srvy' && edi_files ne '' then begin
			if slow_file ne '' then edi_files = [slow_file, edi_files]
		endif else begin
			edi_files = slow_file
		endelse
	endif

	;Zero files found
	if edi_files[0] eq '' then begin
		status = 103
		message, 'No EDI files found.'
	endif
	
;-----------------------------------------------------
; Find SunPulse Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	hk_tstart = mode eq 'brst' ? strmid(tstart, 0, 8) : tstart
	dss_file = mms_latest_file(dropbox, sc, 'fields', 'hk', 'l1b', hk_tstart, $
	                           OPTDESC='101', ROOT=hk_path)
	
	;No file found
	if dss_file eq '' then begin
		status = 103
		message, 'No DSS file found.'
	endif
	
;-----------------------------------------------------
; Find DEFATT Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	defatt_file = mms_anc_search(dropbox, sc, 'defatt', tstart, $
	                             COUNT = count, $
	                             ROOT  = data_path)
	
	;No file found
	if count eq 0 then begin
		status = 103
		message, 'No DEFATT files found.'
	endif

;-----------------------------------------------------
; Process Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Write parents to log file
	MrPrintF, 'LogText', ''
	MrPrintF, 'LogText', '---------------------------------'
	MrPrintF, 'LogText', '| Parent Files                  |'
	MrPrintF, 'LogText', '---------------------------------'
	MrPrintF, 'LogText', edi_files
	MrPrintF, 'LogText', dss_file
	MrPrintF, 'LogText', defatt_file
	MrPrintF, 'LogText', '---------------------------------'
	MrPrintF, 'LogText', ''

	;Process data
	edi_q0 = mms_edi_q0_l2_create(edi_files, dss_file, defatt_file, STATUS=status)
	if status ne 0 && status ne 102 then message, 'Unable to create L2 Q0 data.'

;-----------------------------------------------------
; Write Data to File \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	parents = file_basename([edi_files, dss_file, defatt_file])

	;If the parent was empty, so to is the output
	empty_file = 0B
	if status eq 102 then begin
		status     = 1B
		empty_file = 1B
	endif

	;Create the file
	file_out = mms_edi_q0_l2_mkfile(sc, mode, tstart, $
	                                DROPBOX_ROOT   = dropbox, $
	                                DATA_PATH_ROOT = data_path, $
	                                EMPTY_FILE     = empty_file, $
	                                OPTDESC        = outoptdesc, $
	                                PARENTS        = parents, $
	                                STATUS         = status)
	if file_out eq '' then message, 'Error creating L2 file.'
	
	;Write the data
	if ~empty_file then status = mms_edi_q0_l2_write(file_out, temporary(edi_q0))
	
	;Delete empty file if error occurs
	if status ge 100 then begin
		if file_test(file_out) then begin
			file_delete, file_out
			file_out = ''
		endif
		message, 'Error writing to L2 file.'
	endif

;-----------------------------------------------------
; Status Report \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Time elapsed
	dt     = systime(1) - t0
	dt_hr  = floor((dt) / 3600.0)
	dt_min = floor( (dt mod 3600.0) / 60.0 )
	dt_sec = dt mod 60
	
	;Write destination to log file
	MrPrintF, 'LogText', file_out, FORMAT='(%"File written to:    \"%s\".")'
	MrPrintF, 'LogText', dt_hr, dt_min, dt_sec, FORMAT='(%"Total process time: %ihr %imin %0.3fs")'
	
	;Close the log file by returning output to stderr.
	!Null = MrStdLog('stderr')
	
	;Return STATUS: 0 => everything OK
	return, status
end