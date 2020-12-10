 **HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  covid_contact_tracing_003c.do
    //  project:				        
    //  analysts:				  	  Ian HAMBLETON
    //  algorithm task			      This do file utilises actual number of cases between April and November to validate model

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
    log using "`logpath'\covid_contact_tracing_003c", replace
** HEADER -----------------------------------------------------


** BARBADOS AS EXAMPLE 
** COMMON TO ALL SCENARIOS
** 59% reduction in tourism arrivals per country 
** we estimate 8 to 12 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

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
*keep if fdate >d($S_DATE)
keep if fdate >d(18mar2020)
keep if fdate <d(01dec2020)
keep fdate darr 
rename fdate date 
order date darr 
replace darr = 0 if date<d(1aug2020) 
save "`datapath'/version01\2-working/brb_arrivals2", replace  


** Draw historical CT data from:
** -covid_contact_tracing_001.do-
use "`datapath'/version01\2-working/covid_daily_surveillance_1dec2020", clear  
keep if iso=="BRB"

** APPEND FUTURE ARRIVALS (from 01-Aug2020) 
append using "`datapath'/version01\2-working/brb_arrivals2"
sort date

** NO ARRIVALS IN COVID LOCKDOWN ERA 
replace darr = 0 if darr==. 

** Reduction of 59% arrivals from Aug 2020 CHANGE AS NEEDED BASED ON ARRIVAL REDUCTIONS
gen darr_red = darr * 0.41 if date>=d(01aug2020) 

***A Macro to separate time to August 1 and after August 5
global S1_DATE = "01aug2020"
global S2_DATE = "05aug2020"

***Calculating numbers of high risk cases arrivals assuming 20%
**This contributes to cases that need mandatory following
gen darr_hr = darr_red*0.2 


**Tidy up dataset
replace country="Barbados" if country=="" 
replace iso="BRB" if iso=="" 
replace country_order = 4 if country_order==. 
replace iso_num = 4 if iso_num==. 
replace pop = 287371 if pop==. 

** Calculate contact tracing demand 

** (A) ASSUMPTIONS: BASELINE VALUES

** Minimum # contact tracers per 100,000
global ctmin = 15 

** Contacts per new positive case CHANGE AS NEEDED
global ctnew1 = 10
global ctnew2 = 14
global ctfut1 = 10
global ctfut2 = 14 

** Daily case load: Positive case interviews
global ctint = 4

** Daily case load: Contact notification
global ctnot = 12

** Daily case load: Contact follow-up 
global ctfup = 20

** Contact supervision
global ctsup = 10

** Working days 
global wdays  = 5 

** MAX elapsed days 
replace elapsed = _n - 1 
bysort iso : egen maxel = max(elapsed)



** (B) Calculate the CT needs based on confirmed case identification
** keep if iso=="`country'" 
gen days = elapsed+1 
drop elapsed 
keep country country_order iso iso_num pop date new_cases days maxel darr_hr
bysort iso : gen runid = _n 
gen ccase = 0

** Cumulative count of cases
sort iso date 
*replace ccase = new_cases if runid==1
*replace ccase = ccase[_n-1] + new_cases[_n] if runid > 1   
tempfile ct1
save `ct1'
import excel "`datapath'\version01\2-working\ccase_new.xlsx", sheet("Sheet1") firstrow clear  
merge 1:1 runid using `ct1'
drop _merge


** Cumulative cases in past 14 days 
gen ccase_lag14 = ccase[_n-14] if runid>14
replace ccase_lag14 = 0 if ccase_lag14==. 
gen case14 = ccase - ccase_lag14 

** Running total of CT-staff for positive case interviews 
gen cts_int = new_cases / ($ctint)

** Running total of CT-staff for contact notification 
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) if date < d($S1_DATE)
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) if date < d($S1_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S2_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S2_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S1_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S1_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S2_DATE)

***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = new_cases/($ctfup) if date >= d($S2_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa 
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
bysort iso : asrol cts_totala , stat(mean) window(date 5) gen(ctsa_av5)
bysort iso : asrol cts_totalb , stat(mean) window(date 5) gen(ctsb_av5)



**    keep if iso== "`country'" 
    local elapsed = maxel + 1

    ** Smoothing: method 2
    lowess cts_totala date , bwidth(0.2) gen(ctsa_low1) nogr
    lowess cts_totalb date , bwidth(0.2) gen(ctsb_low1) nogr

    ** GRAPHIC OF CT NEEDS OVER TIME
        #delimit ;
        gr twoway 
            (bar ctsb_av5 date if iso=="BRB" & date<d($S1_DATE), col("197 176 213"))
            (bar ctsa_av5 date if iso=="BRB" & date<d($S1_DATE), col("216 222 242"))
            (bar new_cases date if iso=="BRB" & date<d($S1_DATE), col("222 164 159%50"))
            (line ctsb_low1 date if iso=="BRB" & date<d($S1_DATE), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 date if iso=="BRB" & date<d($S1_DATE), lc("55 74 131%50") lw(0.4) lp("-"))

            (bar ctsb_av5 date if iso=="BRB" & date>=d(5aug2020), col("197 176 213"))
            (bar ctsa_av5 date if iso=="BRB" & date>=d(5aug2020), col("216 222 242"))
            (bar new_cases date if iso=="BRB" & date>=d(5aug2020), col("222 164 159%50"))
            (line ctsb_low1 date if iso=="BRB" & date>=d(5aug2020), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 date if iso=="BRB" & date>=d(5aug2020), lc("55 74 131%50") lw(0.4) lp("-"))

            ,

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin)) 
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin)) 
            bgcolor(white) 
            ysize(5) xsize(14)
            
            xlab(   
                    22006 "1 Apr"
                    22036 "1 May"
                    22067 "1 Jun"
                    22097 "1 Jul"
                    22128 "1 Aug"
                    22159 "1 Sep"
                    22189 "1 Oct"
                    22220 "1 Nov"
                 

            , labs(7) nogrid glc(gs16) angle(0) format(%9.0f))
            xtitle("", size(7) margin(l=2 r=2 t=2 b=2)) 
                
            ylab(0(20)120  
            , labs(7) notick nogrid glc(gs16) angle(0))
            yscale(fill noline) 
            ytitle("Frequency", size(7) margin(l=2 r=2 t=2 b=2)) 

                       legend(size(5) position(1) ring(0) bm(t=1 b=1 l=1 r=1) colf cols(1) lc(gs16)
                region(fcolor(gs16) lw(vthin) margin(l=2 r=2 t=2 b=2) lc(gs16)) order(8 7 6)
                lab(6 "$ctfut2 contacts")
                lab(7 "$ctfut1 contacts")
                lab(8 "Cases")

                       )
                name(scenario_real) 
                ;
        #delimit cr
        graph export "`outputpath'/04_TechDocs/scenario_real_$S_DATE.png", replace width(5000)
      


