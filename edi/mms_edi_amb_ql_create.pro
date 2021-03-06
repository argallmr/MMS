; docformat = 'rst'
;
; NAME:
;    mms_edi_amb_create
;
; PURPOSE:
;+
;   Process EDI AMB L1A data, sorting counts by pitch angle instead of GDU and,
;   for burst data, calculate the pitch angle of each anode.
;
;   Calling Sequences:
;       fname = mms_edi_ql_amb_create( amb_files )
;       fname = mms_edi_ql_amb_create( ..., tstart, tend )
;
; :Categories:
;    MMS, EDI
;
; :Params:
;       AMB_FILES:  in, required, type=string/strarr
;                   Names of the EDI L1A AMB data files to be processd.
;       TSTART:     in, optional, types=string
;                   An ISO-8601 string indicating the start time of the interval to process.
;       TEND:       in, optional, types=string
;                   An ISO-8601 string indicating the end time of the interval to process.
;
; :Keywords:
;       OUTDIR:     in, optional, type=string, default='/nfs/edi/amb/'
;                   Directory in which to save data.
;       STATUS:     out, required, type=byte
;                   An error code. Values are:::
;                       OK      = 0
;                       Warning = 1-99
;                       Error   = 100-255
;                           100      -  Unexpected trapped error
;
; :Returns:
;       EDI_OUT:    Structure of processed data. Fields are::
;                       TT2000_0    - TT2000 time tags for 0-pitch angle sorted data
;                       TT2000_180  - TT2000 time tags for 180-pitch angle sorted data
;                       TT2000_TT   - TT2000 time tags for packet-resolution data
;                       ENERGY_GDU1 - Electron energy for GDU1
;                       ENERGY_GDU2 - Electron energy for GDU2
;                       PACK_MODE   - Packing mode
;                       COUNTS1_0   - Counts1 data sorted by 0-degree pitch mode
;                       COUNTS1_180 - Counts1 data sorted by 180-degree pitch mode
;                       COUNTS2_0   - Counts2 data sorted by 0-degree pitch mode (brst only)
;                       COUNTS2_180 - Counts2 data sorted by 180-degree pitch mode (brst only)
;                       COUNTS3_0   - Counts3 data sorted by 0-degree pitch mode (brst only)
;                       COUNTS3_180 - Counts3 data sorted by 180-degree pitch mode (brst only)
;                       COUNTS4_0   - Counts4 data sorted by 0-degree pitch mode (brst only)
;                       COUNTS4_180 - Counts4 data sorted by 180-degree pitch mode (brst only)
;                       PA1_0       - Pitch angle associated with COUNTS1_0 (L2 only)
;                       PA1_180     - Pitch angle associated with COUNTS1_180 (L2 only)
;                       PA2_0       - Pitch angle associated with COUNTS2_0 (L2 only)
;                       PA2_180     - Pitch angle associated with COUNTS2_180 (L2 only)
;                       PA3_0       - Pitch angle associated with COUNTS3_0 (L2 only)
;                       PA3_180     - Pitch angle associated with COUNTS3_180 (L2 only)
;                       PA4_0       - Pitch angle associated with COUNTS4_0 (L2 only)
;                       PA4_180     - Pitch angle associated with COUNTS4_180 (L2 only)
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
;       2015/10/27  -   Written by Matthew Argall
;       2015/11/04  -   Calculate pitch angle for ambient data. - MRA
;       2016/01/29  -   Split the QL and L2 processes into separate programs. Removed
;                           helper functions to separate files. - MRA
;       2016/02/01  -   Split the QL and L2 processes into separate programs. Removed
;                           helper functions to separate files. - MRA
;       2016/09/18  -   Restructured to accommodate new data products. - MRA
;-
function mms_edi_amb_ql_create, amb_files, tstart, tend, $
CAL_FILE=cal_file, $
STATUS=status
	compile_opt idl2
	
	catch, the_error
	if the_error ne 0 then begin
		catch, /CANCEL
		
		;TODO: Give error codes to specific errors.
		if n_elements(status) eq 0 || status eq 0 then status = 100

		MrPrintF, 'LogErr'
		return, !Null
	endif
	
	;Everything is ok
	status = 0
	
;-----------------------------------------------------
; Check Inputs \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Total number of files given
	nEDI = n_elements(amb_files)
	nCal = n_elements(cal_file)
	
	;Check if files exist and are readable
	if nEDI eq 0 then message, 'No EDI files given'
	if nCal eq 0 then message, 'No EDI calibration file given.'
	if min(file_test(amb_files, /READ, /REGULAR)) eq 0 $
		then message, 'EDI files must exist and be readable.'
	
	;Burst mode flag
	tf_brst = stregex(amb_files[0], 'brst', /BOOLEAN)

;-----------------------------------------------------
; Read EDI Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Read Data
	;   - Automatically combines slow and fast survey data
	;   - Will check sc, instr, mode, level, optdesc
	;   - Expand AZIMUTH and POLAR angles to COUNTS time resolution
	edi = mms_edi_amb_l1a_read(amb_files, tstart, tend, /EXPAND_ANGLES, STATUS=status)
	if status ge 100 then message, 'Error reading file.'

	;Read calibration file
	cals = mms_edi_amb_cal_read(cal_file)
	
	;Number of elements.
	ncts = n_elements(edi.epoch_gdu1)
	ntt  = n_elements(edi.epoch_timetag)
	
	;Search for fill values and when the energy is 0
	ibad = where(edi.energy_gdu1 ne 500 and edi.energy_gdu1 ne 1000, nbad)
	if nbad gt 0 then MrPrintF, 'LogWarn', nbad, nbad/float(ntt)*100.0, FORMAT='(%"energy_gdu1 has %i (%0.2f\%) bad values")'
	ibad = where(edi.energy_gdu2 ne 500 and edi.energy_gdu2 ne 1000, nbad)
	if nbad gt 0 then MrPrintF, 'LogWarn', nbad, nbad/float(ntt)*100.0, FORMAT='(%"energy_gdu2 has %i (%0.2f\%) bad values")'

;-----------------------------------------------------
; Operations Bitmask \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	
	;Create an operations bitmask
	bitmask = mms_edi_amb_ops_bitmask(edi)

	;Update the EDI structure
	edi = MrStruct_RemoveTags(edi, ['PITCH_MODE',   'PACK_MODE', $
	                                'PERP_ONESIDE', 'PERP_BIDIR'])
	
;-----------------------------------------------------
; Apply Calibrations \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Annode assocated with each channel
	anodes = mms_edi_amb_anodes(edi.azimuth, bitmask, edi.pitch_gdu1, edi.pitch_gdu2, BRST=tf_brst)

	;Read Calibration File
	cal_cnts = mms_edi_amb_calibrate( edi, cals, temporary(anodes), bitmask, $
	                                  ABSCAL = tf_abscal )

	;Remove uncalibrated data
	edi = MrStruct_RemoveTags(edi, ['COUNTS_GDU1', 'COUNTS_GDU2'])

	;Append calibrated data
	edi = create_struct(edi, temporary(cal_cnts))

;-----------------------------------------------------
; Sort Results by Mode and Pitch Angle \\\\\\\\\\\\\\\
;-----------------------------------------------------
	results = mms_edi_amb_sort( temporary(edi), temporary(bitmask) )

	return, results
end