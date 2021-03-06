; docformat = 'rst'
;
; NAME:
;       mms_fig_fields.pro
;
;*****************************************************************************************
;   Copyright (c) 2014, Matthew Argall                                                   ;
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
;       * Neither the name of the <ORGANIZATION> nor the names of its contributors may   ;
;         be used to endorse or promote products derived from this software without      ;
;         specific prior written permission.                                             ;
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
;   Create a plot of FIELDS data
;       1) DFG Magnetic Field
;       2) EDP Electric Field
;       3) EDP Spacecraft Potential
;       4) EDI 0-degree ambient counts
;       5) EDI 180-degree ambient counts
;       6) EDI Anisotropy (0/180 counts)
;
; :Params:
;       SC:                 in, required, type=string/strarr
;                           Spacecraft for which data is to be plotted.
;       TSTART:             in, required, type=string
;                           Start time of the data interval to read, as an ISO-8601 string.
;       TEND:               in, required, type=string
;                           End time of the data interval to read, as an ISO-8601 string.
;
; :Keywords:
;       EIGVECS:        out, optional, type=3x3 float
;                       Rotation matrix (into the minimum variance coordinate system).
;-
function mms_fig_fsm_psd, sc, mode, tstart, tend, $
EIGVECS=eigvecs
	compile_opt strictarr

	;Catch errors
	catch, the_error
	if the_error ne 0 then begin
		catch, /cancel
		if n_elements(win) gt 0 then obj_destroy, win
		MrPrintF, 'LogErr'
		return, !Null
	endif

;-----------------------------------------------------
; Find Data Files \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;FSM Magnetic Field
	fsmopt   = 'fsm-split'
	fsm_mode = mode eq 'brst' ? mode : 'srvy'
	mms_fsm_l2plus_read, sc, fsm_mode, fsmopt, tstart, tend, $
	                     B_GSE = b_fsm, $
	                     TIME  = t_fsm
	
	;FGM Magnetic Field
	fgm_mode = mode eq 'brst' ? mode : 'srvy'
	mms_fgm_ql_read, sc, 'dfg', fgm_mode, 'l2pre', tstart, tend, $
	                 B_GSE = b_fgm, $
	                 TIME  = t_fgm
	
	;SCM Magnetic Field
	scopt = 'sc' + strmid(mode, 0, 1)
	scm_fname = mms_find_file(sc, 'scm', mode, 'l2', $
	                          DIRECTORY = '/nfs/fsm/scm/', $
	                          OPTDESC   = scopt + '-2s', $
	                          SEARCHSTR = str, $
	                          TSTART    = tstart, $
	                          TEND      = tend)
	if scm_fname[0] eq '' then message, 'Cannot find SCM file: "' + scm_fname[0] + '".'
	oscm = MrCDF_File(scm_fname)
	b_scm = oscm -> Read(sc + '_scm_b_gse', DEPEND_0=t_scm, REC_START=tstart, REC_END=tend)
	obj_destroy, oscm
	
;	b_scm = mms_cdf_read(scopt + '_123', sc, 'scm', mode, 'l1a', tstart, tend, scopt, DEPEND_0=t_scm)


	;Separate |B|
	bmag  = b_fgm[3,*]
	b_fgm = b_fgm[0:2,*]

;-----------------------------------------------------
; Power Spectral Density \\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------
	;Convert time to seconds
	t0        = t_fsm[0]
	t_fsm_ssm = MrCDF_epoch2ssm( temporary(t_fsm), t0)
	t_fgm_ssm = MrCDF_epoch2ssm( temporary(t_fgm), t0)
	t_scm_ssm = MrCDF_epoch2ssm( temporary(t_scm), t0)
	
	nfft   = 1024
	nshift = nfft / 4.0
	
	;FSM
;	b_fsm_psd = MrPSD( b_fsm_dmpa, n_elements(t_fsm_ssm), 1.0/32.0, 0, $
;	                   DIMENSION   = 2, $
;	                   FMAX        = 8, $
;	                   FREQUENCIES = f_fsm, $
;	                   T0          = t_fsm_ssm[0], $
;	                   TIME        = t_fsm_psd )
	
	;FGM
;	b_fgm_psd = MrPSD( b_fgm_dmpa, n_elements(t_fgm_ssm), 1.0/16.0, 0, $
;	                   DIMENSION   = 2, $
;	                   FREQUENCIES = f_fgm, $
;	                   T0          = t_fgm_ssm[0], $
;	                   TIME        = t_fgm_psd )

	;Remove leading dimension
;	b_fsm_psd = reform(b_fsm_psd, /OVERWRITE)
;	b_fgm_psd = reform(b_fgm_psd, /OVERWRITE)

	;Median sampling interval
	dt_fsm = median( t_fsm_ssm[1:*] - t_fsm_ssm )
	dt_fgm = median( t_fgm_ssm[1:*] - t_fgm_ssm )
	dt_scm = median( t_scm_ssm[1:*] - t_scm_ssm )

	;
	;Compute the power spectral density
	;

	;FSM
	bx_fsm_psd = fft_powerspectrum(b_fsm[0,*], dt_fsm, FREQ=f_fsm)
	by_fsm_psd = fft_powerspectrum(b_fsm[1,*], dt_fsm)
	bz_fsm_psd = fft_powerspectrum(b_fsm[2,*], dt_fsm)
	
	;FGM
	bx_fgm_psd = fft_powerspectrum(b_fgm[0,*], dt_fgm, FREQ=f_fgm)
	by_fgm_psd = fft_powerspectrum(b_fgm[1,*], dt_fgm)
	bz_fgm_psd = fft_powerspectrum(b_fgm[2,*], dt_fgm)
	
	;SCM
	bx_scm_psd = fft_powerspectrum(b_scm[0,*], dt_scm, FREQ=f_scm)
	by_scm_psd = fft_powerspectrum(b_scm[1,*], dt_scm)
	bz_scm_psd = fft_powerspectrum(b_scm[2,*], dt_scm)

;-----------------------------------------------------
; Plot Data \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------

	;Create the window
	win = MrWindow(LAYOUT=[1,3], XSIZE=600, XGAP=0.5, YGAP=0.5, YSIZE=650, REFRESH=0)

	;Bx FSM
	px_scm = MrPlot(f_scm, bx_scm_psd, $
	                /CURRENT, $
	                /XLOG, $
	                /YLOG, $
	                LAYOUT      = [1,3,1], $
	                NAME        = 'Bx PSD', $
	                TITLE       = 'FSM, FGM & SCM PSD', $
	                XRANGE      = xrange, $
	                XTICKFORMAT = '(a1)', $
	                YTITLE      = 'Bx PSD!C(nT^2/Hz)')

	;By FSM
	py_scm = MrPlot(f_scm, by_scm_psd, $
	                /CURRENT, $
	                /XLOG, $
	                /YLOG, $
	                LAYOUT      = [1,3,2], $
	                NAME        = 'By PSD', $
	                XRANGE      = xrange, $
	                XTICKFORMAT = '(a1)', $
	                YTITLE      = 'By PSD!C(nT^2/Hz)')

	;Bz scm
	pz_scm = MrPlot(f_scm, bz_scm_psd, $
	                /CURRENT, $
	                /XLOG, $
	                /YLOG, $
	                LAYOUT      = [1,3,3], $
	                NAME        = 'Bz PSD', $
	                XRANGE      = xrange, $
	                XTITLE      = 'f (Hz)', $
	                YTITLE      = 'Bz PSD!C(nT^2/Hz)')

	;Bx FGM
	px_fgm = MrPlot(f_fgm, bx_fgm_psd, $
	                /XLOG, $
	                /YLOG, $
	                COLOR       = 'Blue', $
	                NAME        = 'Bx FGM PSD', $
	                OVERPLOT    = px_scm)

	;By FGM
	py_fgm = MrPlot(f_fgm, by_fgm_psd, $
	                /YLOG, $
	                COLOR       = 'Blue', $
	                NAME        = 'By FGM PSD', $
	                OVERPLOT    = py_scm)

	;Bz FGM
	pz_fgm = MrPlot(f_fgm, bz_fgm_psd, $
	                /YLOG, $
	                COLOR       = 'Blue', $
	                NAME        = 'Bz FGM PSD', $
	                OVERPLOT    = pz_scm)

	;Bx SCM
	px_fsm = MrPlot(f_fsm, bx_fsm_psd, $
	                /XLOG, $
	                /YLOG, $
	                COLOR       = 'Red', $
	                NAME        = 'Bx FSM PSD', $
	                OVERPLOT    = px_scm)

	;By fsm
	py_fsm = MrPlot(f_fsm, by_fsm_psd, $
	                /YLOG, $
	                COLOR       = 'Red', $
	                NAME        = 'By FSM PSD', $
	                OVERPLOT    = py_scm)

	;Bz fsm
	pz_fsm = MrPlot(f_fsm, bz_fsm_psd, $
	                /YLOG, $
	                COLOR       = 'Red', $
	                NAME        = 'Bz FSM PSD', $
	                OVERPLOT    = pz_scm)

	;Legend
	lb = MrLegend(ALIGNMENT = 'NE', $
	              POSITION  = [1.0, 1.0], $
	              /RELATIVE, $
	              SAMPLE_WIDTH = 0, $
	              TEXT_COLOR   = ['Black', 'Blue', 'Red'], $
	              LABEL        = ['SCM', 'DFG', 'FSM'], $
	              TARGET       = [px_scm, px_fgm, px_fsm])

	win -> Refresh
	return, win
end