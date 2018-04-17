; docformat = 'rst'
;
; NAME:
;    mms_edi_amb_anodes
;
; PURPOSE:
;+
;   Determine the anode number for each channel and GDU.
;
;   NOTES:
;     The active anodes for each channel are provided in this document:
;
;       edi-ambient-mode-azimuthuth-angles-2016-09-02.pdf --- Hans Vaith
;
;     In survey mode, when only one channel is reported, the active anode is
;     indicated by N. To apply the same burst formulas to survey mode, we add
;     a constant value to the offset indicated such that
;
;       (N + OFFSET + CHANNEL) = N     (GDU1)
;       (N + OFFSET + CHANNEL) = 16-N  (GDU2)
;
;     when CHANNEL = 1. This is so that data can be stored in a general fashion
;     as an array with dimensions [time, channel]. In survey mode, the only
;     active channel is channel 1 and it will be stored in the first index location.
;     In burst mode, channels will be stored at index (CHANNEL-1).
;
; :Params:
;       PHI:            in, required, type=fltarr
;                       Azimuth angle of reference channel
;       BITMASK:        in, required, type=struct
;                       A bitmask indicate the operational mode.
;       PITCH_GDU1:     in, required, type=bytarr
;                       Pitch angle mode of GDU1
;       PITCH_GDU2:     in, required, type=bytarr
;                       Pitch angle mode of GDU2
;
; :Keywords:
;       BRST:           in, optional, type=boolean, default=0
;                       If set, return 4 channels per GDU. In survey mode, data
;                           from one channel per GDU is returned.
;
; :Returns:
;       ANODE:      A structure with the following tags:
;                        N_GDU1  -  [time, channel] Anode # corresponding to each channel of GDU1
;                        N_GDU2  -  [time, channel] Anode # corresponding to each channel of GDU2
;
; :See Also:
;   mms_edi_amb_l1a_read.pro
;   mms_edi_amb_ops_bitmask.pro
;   MrStruct_RemoveTags.pro
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
;       2016/09/14  -   Written by Matthew Argall
;       2016/09/17  -   Channels for like GDUs are contatenated into single array. - MRA
;-
function mms_edi_amb_anodes, phi, bitmask, pitch_gdu1, pitch_gdu2, $
BRST=brst
	compile_opt idl2
	on_error, 2
	
	;Check Inputs
	nPhi    = n_elements(phi)
	tf_brst = keyword_set(brst)
	if n_elements(bitmask)    ne nPhi then message, 'BITMASK has incorrect number of elements.'
	if n_elements(pitch_gdu1) ne nPhi then message, 'PITCH_GDU1 has incorrect number of elements.'
	if n_elements(pitch_gdu2) ne nPhi then message, 'PITCH_GDU2 has incorrect number of elements.'
	
	;Find unique modes
	iUniq = uniq(bitmask, sort(bitmask))
	nUniq = n_elements(iUniq)

	;Allocate memory
	;   - Initialize to the CDF fillvalue for byte values
	fillval   = 255B
	nChannels = tf_brst ? 4 : 1
	gdu1      = make_array(nPhi, nChannels, VALUE=fillval)
	gdu2      = make_array(nPhi, nChannels, VALUE=fillval)
	
	;Number for detector azimuth (0-31)
	;   - Each anode is 11.25 degrees wide
	N = fix(phi / 11.25, TYPE=1)
	
;-----------------------------------------------------
; Step Through Each Mode \\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	for i = 0, nUniq - 1 do begin
		theBit = bitmask[iUniq[i]]
		idx    = where(bitmask eq theBit, nIdx)
	
	;-----------------------------------------------------
	; AMB-ALT-OOB \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;AMB-ALT-OOB
		;   - pitch    = alternating     = bit 2
		;   - [0,180]  = one-sided       = bit 5
		;   - 90       = one-sided       = bit 6
		;   - 90       = bi-directional  = bit 7
		if array_equal( MrBitGet( theBit, [2,5,6,7] ), 1)  then begin
			ch_fa_gdu1 = indgen(1,nChannels) + 1S
			ch_fa_gdu2 = indgen(1,nChannels) + 1S
			ch_90_gdu1 = indgen(1,nChannels) + 1S
			ch_90_gdu2 = -(indgen(1,nChannels) + 1S)
			
			;BRST
			;   - 0,180, GDU1: N - 1 + ch
			;   - 0,180, GDU2: 14 - N + ch
			;   - 90, GDU1: N - 1 + ch
			;   - 90, GDU2: 16 - N - ch
			if tf_brst then begin
				offset_fa_gdu1 = -1
				offset_fa_gdu2 = 14
				offset_90_gdu1 = -1
				offset_90_gdu2 = 16
				
			;SRVY
			endif else begin
				offset_fa_gdu1 = -1  ;(N + offset + 1) = N     -->  offset = -1
				offset_fa_gdu2 = 15  ;(offset - N + 1) = 16-N  -->  offset = 15
				offset_90_gdu1 = -1  ;(N + offset + 1) = N     -->  offset = -1
				offset_90_gdu2 = 17  ;(offset - N - 1) = 16-N  -->  offset = 17
			endelse

	;-----------------------------------------------------
	; AMB-ALT-OOM \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;AMB-ALT-OOM
		;   - pitch    = alternating       = bit 2
		;   - [0,180]  = one-sided         = bit 5
		;   - 90       = one-sided         = bit 6
		;   - 90       = moni-directional  = bit -
		endif else if array_equal( MrBitGet( theBit, [2,5,6] ), 1)  then begin
			ch_fa_gdu1 = indgen(1,nChannels) + 1S
			ch_fa_gdu2 = indgen(1,nChannels) + 1S
			ch_90_gdu1 = indgen(1,nChannels) + 1S
			ch_90_gdu2 = indgen(1,nChannels) + 1S
			
			;BRST
			if tf_brst then begin
				offset_fa_gdu1 = -1
				offset_fa_gdu2 = 14
				offset_90_gdu1 = -1
				offset_90_gdu2 = 14
				
			;SRVY
			endif else begin
				offset_fa_gdu1 = -1  ;(offset + N + 1) = N
				offset_fa_gdu2 = 15  ;(offset - N + 1) = 16-N
				offset_90_gdu1 = -1
				offset_90_gdu2 = 15
			endelse

	;-----------------------------------------------------
	; AMB-ALT-OC \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;AMB-ALT-OC
		;   - pitch    = alternating = bit 2
		;   - [0,180]  = one-sided   = bit 5
		;   - 90       = centered    = bit -
		endif else if array_equal( MrBitGet( theBit, [2,5] ), 1) then begin
			ch_fa_gdu1 = indgen(1,nChannels) + 1S
			ch_fa_gdu2 = indgen(1,nChannels) + 1S
			ch_90_gdu1 = indgen(1,nChannels) + 1S
			ch_90_gdu2 = indgen(1,nChannels) + 1S
			
			;BRST
			if tf_brst then begin
				offset_fa_gdu1 = -1
				offset_fa_gdu2 = 14
				offset_90_gdu1 = -3
				offset_90_gdu2 = 13
				
			;SRVY
			endif else begin
				offset_fa_gdu1 = -1  ;(offset + N + 1) = N
				offset_fa_gdu2 = 15  ;(offset - N + 1) = 16-N
				offset_90_gdu1 = -1
				offset_90_gdu2 = 15
			endelse
		
	;-----------------------------------------------------
	; AMB-ALT-CC \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;AMB-ALT-CC
		;   - pitch    = alternating = bit 2
		;   - [0,180]  = centered    = bit 4
		;   - 90       = centered    = bit -
		endif else if array_equal( MrBitGet( theBit, [2,4] ), 1) then begin
			ch_fa_gdu1 = indgen(1,nChannels) + 1S
			ch_fa_gdu2 = indgen(1,nChannels) + 1S
			ch_90_gdu1 = indgen(1,nChannels) + 1S
			ch_90_gdu2 = indgen(1,nChannels) + 1S
			
			;BRST
			if tf_brst then begin
				offset_fa_gdu1 = -3
				offset_fa_gdu2 = 13
				offset_90_gdu1 = -3
				offset_90_gdu2 = 13
				
			;SRVY
			endif else begin
				offset_fa_gdu1 = -1  ;(offset + N + 1) = N
				offset_fa_gdu2 = 15  ;(offset - N + 1) = 16-N
				offset_90_gdu1 = -1
				offset_90_gdu2 = 15
			endelse

	;-----------------------------------------------------
	; AMB \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;AMB
		;   - pitch   = field-aligned = bit 1
		;   - [0,180] = centered      = bit 4
		endif else if array_equal( MrBitGet( theBit, [1,4] ), 1) then begin
			ch_fa_gdu1 = indgen(1,nChannels) + 1S
			ch_fa_gdu2 = indgen(1,nChannels) + 1S
			
			;BRST
			if tf_brst then begin
				offset_fa_gdu1 = -3
				offset_fa_gdu2 = 13
				
			;SRVY
			endif else begin
				offset_fa_gdu1 = -1  ;(offset + N + 1) = N
				offset_fa_gdu2 = 15  ;(offset - N + 1) = 16-N
			endelse

	;-----------------------------------------------------
	; AMB-PM2 \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		;AMB-PM2
		;   - pitch   = field-aligned = bit 1
		;   - [0,180] = one-sided     = bit 5
		endif else if array_equal( MrBitGet( theBit, [1,5] ), 1) then begin
			ch_fa_gdu1 = indgen(1,nChannels) + 1S
			ch_fa_gdu2 = indgen(1,nChannels) + 1S
			
			;BRST
			if tf_brst then begin
				offset_fa_gdu1 = -1
				offset_fa_gdu2 = 14
				
			;SRVY
			endif else begin
				offset_fa_gdu1 = -1  ;(offset + N + 1) = N
				offset_fa_gdu2 = 15  ;(offset - N + 1) = 16-N
			endelse

	;-----------------------------------------------------
	; ???? \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		endif else begin
			message, 'Unknown operational mode (' + strtrim(theBit, 2) + ').'
		endelse

	;-----------------------------------------------------
	; Field-Aligned Channels \\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		if n_elements(offset_fa_gdu1 gt 0) then begin
			;Indices of field-aligned anodes
			iGDU1 = where( pitch_gdu1[idx] eq 0 or pitch_gdu1[idx] eq 180, nGDU1)
			iGDU2 = where( pitch_gdu2[idx] eq 0 or pitch_gdu2[idx] eq 180, nGDU2)
		
			;Anode # for each channel
			
			;GDU1
			if nGDU1 gt 0 then gdu1[idx[iGDU1],*] = rebin(N[idx[iGDU1]], nGDU1, nChannels) + $
			                                        offset_fa_gdu1                         + $
			                                        rebin(ch_fa_gdu1, nGDU1, nChannels)
			;GDU2
			if nGDU2 gt 0 then gdu2[idx[iGDU2],*] = offset_fa_gdu2                         - $
			                                        rebin(N[idx[iGDU2]], nGDU2, nChannels) + $
			                                        rebin(ch_fa_gdu2, nGDU2, nChannels)
		endif

	;-----------------------------------------------------
	; Perpendicular Channels \\\\\\\\\\\\\\\\\\\\\\\\\\\\\
	;-----------------------------------------------------
		if n_elements(offset_90_gdu1 gt 0) then begin
			;Indices of perpendicular anodes
			iGDU1 = where( pitch_gdu1[idx] eq 90, nGDU1)
			iGDU2 = where( pitch_gdu2[idx] eq 90, nGDU2)
		
			;Anode # for each channel
			
			;GDU1
			if nGDU1 gt 0 then gdu1[idx[iGDU1],*] = rebin(N[idx[iGDU1]], nGDU1, nChannels) + $
			                                        offset_90_gdu1                         + $
			                                        rebin(ch_90_gdu1, nGDU1, nChannels)
			
			;GDU2
			if nGDU2 gt 0 then gdu2[idx[iGDU2],*] = offset_90_gdu2                         - $
			                                        rebin(N[idx[iGDU2]], nGDU2, nChannels) + $
			                                        rebin(ch_90_gdu2, nGDU2, nChannels)
		endif
	endfor

;-----------------------------------------------------
; Tidy Up Results \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Force into range [0,31]
;	iGood1 = where(gdu1 ne fillval, nGood1)
;	iGood2 = where(gdu2 ne fillval, nGood2)
;	if nGood2 gt 0 then gdu1[iGood1] = (gdu1[iGood1] + (gdu1[iGood1] lt 0)*32) mod 32
;	if nGood2 gt 0 then gdu2[iGood2] = (gdu2[iGood2] + (gdu2[iGood2] lt 0)*32) mod 32
	gdu1 = (gdu1 + (gdu1 lt 0)*32) mod 32
	gdu2 = (gdu2 + (gdu2 lt 0)*32) mod 32
	
	;Return
	return, { n_gdu1: byte(temporary(gdu1)), n_gdu2: byte(temporary(gdu2)) }
end
