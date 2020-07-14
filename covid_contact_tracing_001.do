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

** 24-JUN-2020
** We might in time bring this over to P154 to separate the algorithm developments 
** IMPORT the data from P151 --> The covid surveillance folder 
** do "`logpath151'\covidprofiles_003_metrics_v5"

** 12-JUL-2020
** Partial separation of p151 and p154
** p151 --> C:\Sync\OneDrive - The University of the West Indies\repo_datagroup\repo_p151\covidprofiles_003_metrics_v5.do
** Saves dataset to p154 
local c_date = c(current_date)
local date_string = subinstr("`c_date'", " ", "", .)
use "`datapath'\version01\2-working\covid_daily_surveillance_`date_string'", clear 

** We have data on 20 CARICOM countries for the length of the COVID outbreak
** We want to do the following
**
** A. Calculate Baseline CT needs
** B. Document changing CT needs given certain assumptions + actual cases confirmed
** C. Then explore future needs based on future tourist projections


** (A) ASSUMPTIONS: BASELINE VALUES

** Minimum # contact tracers per 100,000
global ctmin = 15 

** Contacts per new positive case
global ctnew1 = 10
global ctnew2 = 15

** Daily case load: Positive case interviews
global ctint = 6

** Daily case load: Contact notification
global ctnot = 12

** Daily case load: Contact follow-up 
global ctfup = 32

** Contact supervision
global ctsup = 10

** Working days 
global wdays  = 5 

** MAX elapsed days 
bysort iso : egen maxel = max(elapsed)



** (B) Calculate the CT needs based on confirmed case identification
** keep if iso=="`country'" 
gen days = elapsed+1 
drop elapsed 
keep country country_order iso iso_num pop date new_cases days maxel
bysort iso : gen runid = _n 
gen ccase = 0

** Cumulative count of cases
sort iso date 
replace ccase = new_cases if runid==1
replace ccase = ccase[_n-1] + new_cases[_n] if runid > 1   

** Cumulative cases in past 14 days 
gen ccase_lag14 = ccase[_n-14] if runid>14
replace ccase_lag14 = 0 if ccase_lag14==. 
gen case14 = ccase - ccase_lag14 

** Running total of CT-staff for positive case interviews 
gen cts_int = new_cases / ($ctint)

** Running total of CT-staff for contact notification 
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) 
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) 

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) 
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) 


** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(ctsa_av5)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(ctsb_av5)


** Save a file for future scenarios
save "`datapath'/version01\2-working/ct_history", replace 




** GRAPHICS FOR FIRST FIGURE
** To DATE --> CT needs across the 20 CARICOM countries

local clist "AIA ATG BHS BLZ BMU BRB CYM DMA GRD GUY HTI JAM KNA LCA MSR SUR TCA TTO VCT VGB"
** local clist "JAM"
foreach country of local clist {

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
    putpdf save "`outputpath'/05_Outputs/covid19_ct1_`date_string'", replace
