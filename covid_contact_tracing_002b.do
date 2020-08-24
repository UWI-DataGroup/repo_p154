** HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  covid_contact_tracing_002b.do
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
    log using "`logpath'\covid_contact_tracing_002b", replace
** HEADER -----------------------------------------------------


** BARBADOS AS EXAMPLE 
** FUTURE SCENARIO 1
** 75% reduction in tourism arrivals per country 
** Then 90% arriving with negative tests
** Of the 10% without negative tests - estimating that 1% will test positive. 
** Of these 1% we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate only 5 contacts- airport officials, taxi, hotel officials. 

** TEMP tourism data for Barbados
input year month days arrivals
2017    1   31  62486
2018    1   31  66188
2019    1   31  70197
2017    2   28  63684
2018    2   28  67206
2019    2   28  68877
2017    3   31  66221
2018    3   31  70923
2019    3   31  71214
2017    4   30  60843
2018    4   30  57066
2019    4   30  63495
2017    5   31  48650
2018    5   31  50261
2019    5   31  50720
2017    6   30  44965
2018    6   30  46346
2019    6   30  50161
2017    7   31  54861
2018    7   31  55626
2019    7   31  60249
2017    8   31  51942
2018    8   31  52001
2019    8   31  50759
2017    9   30  34416
2018    9   30  35766
2019    9   30  36863
2016    10   31  43043
2017    10   31  45228
2018    10   31  46528
2016    11   30  62899
2017    11   30  57710
2018    11   30  59689
2016    12   31  67854
2017    12   31  72505
2018    12   31  72669
end 
collapse (mean) arrivals, by(month days)
gen darr = arrivals/days 
expand days 
drop arrivals days 
bysort month : gen day = _n
gen year = 2020 
gen fdate = mdy(month, day, year) 
format fdate %td
keep if fdate >d($S_DATE)
keep fdate darr 
rename fdate date 
order date darr 
replace darr = 0 if date<d(1aug2020) 
save "`datapath'/version01\2-working/brb_arrivals", replace 


** Draw historical CT data from:
** -covid_contact_tracing_001.do-
use "`datapath'/version01\2-working/ct_history", clear 
keep if iso=="BRB"

** APPEND FUTURE ARRIVALS (from 01-Aug2020) 
append using "`datapath'/version01\2-working/brb_arrivals"

** NO ARRIVALS IN COVID LOCKDOWN ERA 
replace darr = 0 if darr==. 

** Reduction of 75% arrivals in Aug and Sep
** And reduction of 50% in Oct & Nov 
gen darr_red = darr * 0.25 if date>=d($S_DATE) & date<=d(30sep2020)
replace darr_red = darr * 0.5 if date>=d(01oct2020) & date<=d(30nov2020)
replace darr_red = darr * 0.5 if date>=d(01dec2020) & date<=d(31dec2020)

** Arriving with no test (10%) 
gen darr_notest = darr_red * 0.1 

** 1% without a test will be positive
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d($S_DATE)
gen darr_pos = ceil(darr_notest * 0.02) if random>=0.5
replace darr_pos = floor(darr_notest * 0.02) if random<0.5
drop random 

** Now calculaate the same NUMBERS as for historical data 
replace new_cases = darr_pos if date>=d($S_DATE) & date<=d(30dec2020)
drop maxel days runid ccase ccase_lag14 case14 cts_* ctsa_* ctsb_*
replace darr_red = 0 if darr_red==.
replace darr_notest = 0 if darr_notest==.
replace darr_pos = 0 if darr_pos==.
replace country="Barbados" if country=="" 
replace iso="BRB" if iso=="" 
replace country_order = 4 if country_order==. 
replace iso_num = 4 if iso_num==. 
replace pop = 287371 if pop==. 

** Calculate contact tracing demand 

** (A) ASSUMPTIONS: BASELINE VALUES

** Minimum # contact tracers per 100,000
global ctmin = 15 

** Contacts per new positive case
global ctnew1 = 8
global ctnew2 = 12
global ctfut1 = 8 
global ctfut2 = 12 

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
gen elapsed = _n - 1 
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
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) if date < d($S_DATE)
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) if date < d($S_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S_DATE)

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(ctsa_av5)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(ctsb_av5)



preserve
**    keep if iso== "`country'" 
    local elapsed = maxel + 1

    ** Smoothing: method 2
    lowess cts_totala date , bwidth(0.2) gen(ctsa_low1) nogr
    lowess cts_totalb date , bwidth(0.2) gen(ctsb_low1) nogr

    ** GRAPHIC OF CT NEEDS OVER TIME
        #delimit ;
        gr twoway 
            (bar ctsb_av5 days if iso=="BRB" & date<d($S_DATE), col("197 176 213"))
            (bar ctsa_av5 days if iso=="BRB" & date<d($S_DATE), col("216 222 242"))
            (bar new_cases days if iso=="BRB" & date<d($S_DATE), col("222 164 159%50"))
            (line ctsb_low1 days if iso=="BRB" & date<d($S_DATE), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 days if iso=="BRB" & date<d($S_DATE), lc("55 74 131%50") lw(0.4) lp("-"))

            (bar ctsb_av5 days if iso=="BRB" & date>=d(1aug2020), col("197 176 213"))
            (bar ctsa_av5 days if iso=="BRB" & date>=d(1aug2020), col("216 222 242"))
            (bar new_cases days if iso=="BRB" & date>=d(1aug2020), col("222 164 159%50"))
            (line ctsb_low1 days if iso=="BRB" & date>=d(1aug2020), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 days if iso=="BRB" & date>=d(1aug2020), lc("55 74 131%50") lw(0.4) lp("-"))

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
            text(24 140 "Predictions", place(se) size(6) col(gs4))
            text(21 140 "10% without test, 2% of those test positive", place(se) size(5) col(gs10))
            text(19 140 "8 contacts (blue), 12 contacts (purple)", place(se) size(5) col(gs10))

            legend(off size(6) position(5) ring(0) bm(t=1 b=1 l=1 r=1) colf cols(1) lc(gs16)
                region(fcolor(gs16) lw(vthin) margin(l=2 r=2 t=2 b=2) lc(gs16)) 
                )
                name(ct_BRB) 
                ;
        #delimit cr
        ** graph export "`outputpath'/04_TechDocs/ct_`country'_$S_DATE.png", replace width(3000)
      restore



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
