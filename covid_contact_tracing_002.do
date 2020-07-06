** HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  covid_contact_tracing_001.do
    //  project:				        
    //  analysts:				  	  Ian HAMBLETON
    // 	date last modified	          24-June-2020
    //  algorithm task			      Run DO file batch

    ** General algorithm set-up
    version 16
    clear all
    macro drop _all
    set more 1
    set linesize 80

    ** Set working directories: this is for DATASET and LOGFILE import and export
    ** DATASETS to encrypted SharePoint folder
    local datapath "X:\The University of the West Indies\DataGroup - repo_data\data_p154"
    ** LOGFILES to unencrypted OneDrive folder
    local logpath151 "X:\OneDrive - The University of the West Indies\repo_datagroup\repo_p151"
    local logpath "X:\OneDrive - The University of the West Indies\repo_datagroup\repo_p154"
    ** Reports and Other outputs
    local outputpath "X:\The University of the West Indies\DataGroup - DG_Projects\PROJECT_p154"

    ** Close any open log file and open a new log file
    capture log close
    log using "`logpath'\covid_contact_tracing_001", replace
** HEADER -----------------------------------------------------


** Draw historical CT data from:
** -covid_contact_tracing_001.do-
use "`datapath'/version01\2-working/ct_history", clear 

** BARBADOS AS EXAMPLE 
** FUTURE SCENARIO 1
** 75% reduction in tourism arrivals per country 
** Then 90% arriving with negative tests
** Of the 10% without negative tests - estimating that 1% will test positive. 
** Of these 1% we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate only 5 contacts- airport officials, taxi, hotel officials. 


/*
preserve
    keep if iso== "`country'" 
    local elapsed = maxel + 1

    ** Smoothing: method 2
    lowess cts_totala date , bwidth(0.2) gen(ctsa_low1) nogr
    lowess cts_totalb date , bwidth(0.2) gen(ctsb_low1) nogr

    ** GRAPHIC OF CT NEEDS OVER TIME
        #delimit ;
        gr twoway 
            (bar ctsb_av5 days if iso=="`country'" & days<=`elapsed', col("197 176 213"))
            (bar ctsa_av5 days if iso=="`country'" & days<=`elapsed', col("216 222 242"))
            (bar new_cases days if iso=="`country'" & days<=`elapsed', col("222 164 159%50"))
            (line ctsb_low1 days if iso=="`country'" & days<=`elapsed', lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 days if iso=="`country'" & days<=`elapsed', lc("55 74 131%50") lw(0.4) lp("-"))
            ,

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin)) 
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin)) 
            bgcolor(white) 
            ysize(5) xsize(14)
            
            xlab(
            , labs(6) nogrid glc(gs16) angle(0) format(%9.0f))
            xtitle("Days since first case", size(6) margin(l=2 r=2 t=2 b=2)) 
                
            ylab(
            , labs(6) notick nogrid glc(gs16) angle(0))
            yscale(fill noline) 
            ytitle("CT resources required", size(6) margin(l=2 r=2 t=2 b=2)) 
            
            ///title("(1) Cumulative cases in `country'", pos(11) ring(1) size(4))

            legend(off size(6) position(5) ring(0) bm(t=1 b=1 l=1 r=1) colf cols(1) lc(gs16)
                region(fcolor(gs16) lw(vthin) margin(l=2 r=2 t=2 b=2) lc(gs16)) 
                )
                name(ct_`country') 
                ;
        #delimit cr
        graph export "`outputpath'/04_TechDocs/ct_`country'_$S_DATE.png", replace width(3000)
      restore
}


/*

** ------------------------------------------------------
** PDF REGIONAL REPORT (COUNTS OF CONFIRMED CASES)
** ------------------------------------------------------
    putpdf begin, pagesize(letter) font("Calibri Light", 10) margin(top,0.5cm) margin(bottom,0.25cm) margin(left,0.5cm) margin(right,0.25cm)

** EXTRA SLIDE - ALL CT CURVES ON ONE SLIDES
    putpdf table intro2 = (1,1), width(100%) halign(left)    
    putpdf table intro2(.,.), border(all, nil) valign(center)
    putpdf table intro2(1,.), font("Calibri Light", 12, 000000)  
    putpdf table intro2(1,1)=("Figure: "), bold halign(left)
    putpdf table intro2(1,1)=("COVID-19 contact tracing resources needed for 20 CARICOM countries as of $S_DATE. "), halign(left) append   

** FIGURE 
    putpdf table f2 = (14,3), width(100%) border(all,nil) halign(center)
    putpdf table f2(1,1)=("Angilla"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(2,1)=image("`outputpath'/04_TechDocs/ct_AIA_$S_DATE.png")
    putpdf table f2(1,2)=("Antigua and Barbuda"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(2,2)=image("`outputpath'/04_TechDocs/ct_ATG_$S_DATE.png")
    putpdf table f2(1,3)=("The Bahamas"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(2,3)=image("`outputpath'/04_TechDocs/ct_BHS_$S_DATE.png")

    putpdf table f2(3,1)=("Barbados"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(4,1)=image("`outputpath'/04_TechDocs/ct_BRB_$S_DATE.png")
    putpdf table f2(3,2)=("Belize"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(4,2)=image("`outputpath'/04_TechDocs/ct_BLZ_$S_DATE.png")
    putpdf table f2(3,3)=("Bermuda"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(4,3)=image("`outputpath'/04_TechDocs/ct_BMU_$S_DATE.png")

    putpdf table f2(5,1)=("British Virgin Islands"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(6,1)=image("`outputpath'/04_TechDocs/ct_VGB_$S_DATE.png")
    putpdf table f2(5,2)=("Cayman Islands"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(6,2)=image("`outputpath'/04_TechDocs/ct_CYM_$S_DATE.png")
    putpdf table f2(5,3)=("Dominica"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(6,3)=image("`outputpath'/04_TechDocs/ct_DMA_$S_DATE.png")

    putpdf table f2(7,1)=("Grenada"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(8,1)=image("`outputpath'/04_TechDocs/ct_GRD_$S_DATE.png")
    putpdf table f2(7,2)=("Guyana"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(8,2)=image("`outputpath'/04_TechDocs/ct_GUY_$S_DATE.png")
    putpdf table f2(7,3)=("Haiti"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(8,3)=image("`outputpath'/04_TechDocs/ct_HTI_$S_DATE.png")

    putpdf table f2(9,1)=("Jamaica"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(10,1)=image("`outputpath'/04_TechDocs/ct_JAM_$S_DATE.png")
    putpdf table f2(9,2)=("Montserrat"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(10,2)=image("`outputpath'/04_TechDocs/ct_MSR_$S_DATE.png")
    putpdf table f2(9,3)=("St Kitts & Nevis"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(10,3)=image("`outputpath'/04_TechDocs/ct_KNA_$S_DATE.png")

    putpdf table f2(11,1)=("St Lucia"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(12,1)=image("`outputpath'/04_TechDocs/ct_LCA_$S_DATE.png")
    putpdf table f2(11,2)=("St Vincent & the Grenadines"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(12,2)=image("`outputpath'/04_TechDocs/ct_VCT_$S_DATE.png")
    putpdf table f2(11,3)=("Suriname"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(12,3)=image("`outputpath'/04_TechDocs/ct_SUR_$S_DATE.png")

    putpdf table f2(13,1)=("Trinidad & Tobago"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(14,1)=image("`outputpath'/04_TechDocs/ct_TTO_$S_DATE.png")
    putpdf table f2(13,2)=("Turks and Caicos Islands"), halign(left) font("Calibri Light", 12, 0e497c)  
    putpdf table f2(14,2)=image("`outputpath'/04_TechDocs/ct_TCA_$S_DATE.png")

** Footnote.
    putpdf paragraph ,  font("Calibri Light", 9)
    putpdf text ("Methodological Note 1. ") , bold
    putpdf text ("Each graphic presents the daily demand for contact tracers given the confirmed COVID-19 caseload. The demand assumes that contact tracers can ")
    putpdf text ("conduct 6 confirmed case interviews, 12 potential case notifications, and 32 potential case follow-ups. Case follow-up is required for up to ") 
    putpdf text ("14 days after identification. ")
    putpdf text ("Methodological Note 2. ") , bold
    putpdf text ("Blue bars assume 10 contacts per confirmed case. Purple bars assume 15 contacts per confirmed case. Dotted lines are smoothed daily contact tracer demand. ")


** Save the PDF
    local c_date = c(current_date)
    local date_string = subinstr("`c_date'", " ", "", .)
    putpdf save "`outputpath'/05_Outputs/covid19_futurect_`date_string'", replace
