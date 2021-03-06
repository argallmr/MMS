pro runest_entry_variables_0100

; fundamental constants
c        = 2.99792458e+08;  % m/s, speed of light (SI)
deg2rad  = !pi / 180.0;
halfPi   = !pi / 2.0;
me       = 9.10938188e-31; % kg, electron mass (SI)
qe        = 1.602177e-19;   % coulomb (SI)
rad2deg  = 180.0 / !pi;
twoPi    = 2.0 * !pi;
v_1keV_electron  = 18727897.366; % m/s, 18755373. m/s relativistic: difference of 0.147%
v_500eV_electron = 13252328.354; % m/s, 13262052. m/s relativistic: difference of 0.073%
B2Tg_nTus = 35723.884068 ; convert B in nT to Tg in µs, and vice versa

; 	restore, filename='bestarg_mms_C3_2001-06-08t053000_054000_@20150306_runest_entry_variables.sav'
; 	restore, filename='bestarg_mms_C3_2001-06-08t053000_054000_@20150306_runest_L671_variables.sav'
	restore, filename='bestarg_mms_C3_2001-06-08t053000_054000_@20150306_runest_L704_variables.sav'
; 	print, n_elements (bd_bmag) ; 83515
 	stop
	nB = n_elements (bd_bmag)
	nToF = n_elements (tof)
	print, nB, nToF
	lastCorrelatorM = 0 ; it will never be zero
	lastCorrelatorN = 0
	lines = 0
; 	for i=0, nTof-1 do begin
; 		if ((mc(i) ne lastCorrelatorM) || (nc(i) ne lastCorrelatorN) || ((i mod 1000) eq 0)) then begin
; 			lastCorrelatorM = mc(i)
; 			lastCorrelatorN = nc(i)
; 			nCodeBits = 15.0
; 			if (ctype (i) eq 1) then $
; 				nCodeBits = 127.0
; 			B2Tg = B2Tg_nTus/bd_bmag(i)
; 			print, i, bd_bmag(i), bd_ct(i), nCodeBits, mc(i), nc(i), nCodeBits*0.119209289551*mc(i)*nc(i), tcode(i), ' ||', tof(i), rtof(i), rtof_tgi(i), ' ||', dist[*,i], ' ||', order(i)
; 			print, i, bd_bmag(i), B2Tg, nCodeBits, mc(i), nc(i), tcode(i), ' ||', tof(i), rtof(i), rtof_tgi(i), ' ||', dist[*,i], ' ||', order(i)
; 			print, i, bd_bmag(i), B2Tg_nTus/bd_bmag(i)
; 			print, i, bd_bmag(i), db(i)
; 			lines = lines + 1
; 		end
; 	endfor
; 	print, 'lines = ', lines

; 	plot, tof, BACKGROUND = 16777215, COLOR = 100
; 	stop
; 	plot, bd_bmag, BACKGROUND = 16777215, COLOR = 100
	plot, beam_bwidth, BACKGROUND = 16777215, COLOR = 100

	return
end

; delta1, NCLOSE, delta2, ret.db     -0.24491648       16750     0.045518547     0.528241

; where we calculate nCodeBits*0.119209289551*mc*nc, or a portion of it,
; we should consider calculating it as early as possible, and using codePeriod.

;     i bd_bmag(i) B2Tg       nCodeBits mc(i) nc(i) tcode(i) ' ||' tof(i) rtof(i)    rtof_tgi(i) ' ||' dist[*i]                                                                   ' ||' order(i)
;     0 241.255    148.075    127       16 4        968.933    || 147.104 147.10414  147.10414     ||     0.350555     -146.403     -293.157     -439.910      382.269      235.516 || 1
;  1000 242.579    147.267    127       16 4        968.933    || 142.574 142.57420  142.57420     ||    -0.695186     -143.965     -287.234     -430.503      395.160      251.891 || 1
;  2000 244.019    146.398    127       16 4        968.933    || 138.283 138.28267  138.28267     ||     0.118116     -138.046     -276.211     -414.376      416.393      278.228 || 1
;  3000 245.422    145.561    127       16 4        968.933    || 133.037 133.03746  133.03746     ||    -0.195027     -133.428     -266.660     -399.892      435.808      302.576 || 1
;  4000 246.613    144.858    127       16 4        968.933    || 129.700 129.69960  129.69960     ||      1.51176     -126.676     -254.864     -383.052      457.694      329.506 || 1
;  5000 248.182    143.942    127       16 4        968.933    || 124.216 124.21598  124.21598     ||    -0.088738     -124.393     -248.698     -373.003      471.625      347.321 || 1
;  6000 249.485    143.191    127       16 4        968.933    || 120.640 120.63970  120.63970     ||    -0.202308     -121.044     -241.886     -362.728     -483.570      364.521 || 1
;  7000 250.733    142.478    127       16 4        968.933    || 118.494 118.49394  118.49394     ||     0.104673     -118.285     -236.674     -355.063     -473.452      377.091 || 1
;  8000 252.104    141.703    127       16 4        968.933    || 115.633 115.63292  115.63292     ||     0.680805     -114.271     -229.223     -344.176     -459.128      394.853 || 1
;  9000 253.560    140.889    127       16 4        968.933    || 111.818 111.81822  111.81822     ||    -0.542229     -112.903     -225.263     -337.624     -449.984      406.589 || 1
; 10000 254.943    140.125    127       16 4        968.933    || 109.196 109.19563  109.19563     ||    -0.439438     -110.075     -219.710     -329.345     -438.980      420.318 || 1
; 11000 256.327    139.368    127       16 4        968.933    || 108.004 108.00353  108.00353     ||     0.330877     -107.342     -215.014     -322.687     -430.360      430.901 || 1
; 11655 257.372    138.802    127       16 2        484.467    || 106.215 106.21539  106.21539     ||    0.0565859     -106.102     -212.261      166.047      59.8879     -46.2709 || 1
; 11656 257.360    138.809    127       16 4        968.933    || 105.619 105.61935  105.61935     ||    -0.495110     -106.610     -212.724     -318.838     -424.953      437.866 || 1
; 11668 257.357    138.811    127       16 2        484.467    || 106.096 106.09618  106.09618     ||    -0.004816     -106.106     -212.207      166.159      60.0577     -46.0433 || 1
; 11670 257.366    138.806    127       16 4        968.933    || 105.381 105.38093  105.38093     ||    -0.764266     -106.909     -213.055     -319.200     -425.345      437.443 || 1
; 11676 257.323    138.829    127       16 2        484.467    || 106.454 106.45381  106.45381     ||     0.330882     -105.792     -211.915      166.429      60.3057     -45.8172 || 1
; 11688 257.332    138.824    127       16 4        968.933    || 105.858 105.85777  105.85777     ||    -0.172760     -106.203     -212.234     -318.264     -424.295      438.608 || 1
; 11696 257.345    138.817    127       16 2        484.467    || 106.454 106.45381  106.45381     ||     0.437992     -105.578     -211.594      166.857      60.8413     -45.1746 || 1
; 11702 257.358    138.810    127       16 4        968.933    || 106.335 106.33460  106.33460     ||     0.250438     -105.834     -211.918     -318.002     -424.086      438.763 || 1
; 11705 257.387    138.795    127       16 2        484.467    || 105.739 105.73856  105.73856     ||    -0.275732     -106.290     -212.304      166.148      60.1337     -45.8806 || 1
; 11732 257.352    138.813    127       16 4        968.933    || 105.619 105.61935  105.61935     ||    -0.256526     -106.132     -212.008     -317.884     -423.760      439.297 || 1
; 11733 257.365    138.806    127       16 2        484.467    || 106.335 106.33460  106.33460     ||     0.465365     -105.404     -211.273      167.324      61.4550     -44.4143 || 1
; 12000 257.688    138.632    127       16 2        484.467    || 105.023 105.02330  105.02330     ||    -0.141012     -105.305     -210.470      168.833      63.6683     -41.4960 || 1
; 13000 259.210    137.818    127       16 2        484.467    || 102.162 102.16228  102.16228     ||    -0.142672     -102.448     -204.753      177.409      75.1041     -27.2009 || 1
; 14000 260.745    137.007    127       16 2        484.467    || 100.136 100.13573  100.13573     ||    -0.159593     -100.455     -200.750      183.421      83.1257     -17.1696 || 1
; 15000 262.030    136.335    127       16 2        484.467    || 98.3476 98.347588  98.347588     ||     0.138580     -98.0704     -196.279      189.978      91.7691     -6.43991 || 1
; 16000 263.410    135.621    127       16 2        484.467    || 94.7713 94.771309  94.771309     ||     0.312139     -94.1470     -188.606      201.401      106.942      12.4828 || 1
