 **HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  covid_contact_tracing_003b.do
    //  project:				        
    //  analysts:				  	  Ian HAMBLETON
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
    log using "`logpath'\covid_contact_tracing_003b", replace
** HEADER -----------------------------------------------------


** BARBADOS AS EXAMPLE 
** COMMON TO ALL SCENARIOS
** 59% reduction in tourism arrivals per country 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

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
tempfile 2020
save `2020'  // creates dates for 2021
drop if month > 6
replace year=2021
append using `2020'
gen fdate = mdy(month, day, year) 
format fdate %td
keep if fdate >d(01aug2020)
keep fdate darr 
rename fdate date 
order date darr 
replace darr = 0 if date<d(1aug2020) 
save "`datapath'/version01\2-working/brb_arrivals", replace 


** Draw historical CT data from:
** -covid_contact_tracing_001.do-
use "`datapath'/version01\2-working/covid_daily_surveillance_1Aug2020", clear  
keep if iso=="BRB"

** APPEND FUTURE ARRIVALS (from 01-Aug2020) 
append using "`datapath'/version01\2-working/brb_arrivals"
sort date

** NO ARRIVALS IN COVID LOCKDOWN ERA 
replace darr = 0 if darr==. 

** Reduction of 85% arrivals from Aug 2020 CHANGE AS NEEDED BASED ON ARRIVAL REDUCTIONS
gen darr_red = darr * 0.15 if date>=d(01aug2020) 

***A Macro to separate time to August 1 and after August 5
global S1_DATE = "01aug2020"
global S2_DATE = "05aug2020"

***Calculating numbers of high risk cases arrivals
**This contributes to cases that need mandatory following
gen darr_hr = darr_red*0.8 


** FUTURE SCENARIO 1

** Then 95% arriving with negative tests
** Of the 5% without negative tests - estimating that 0.5% will test positive on arrival and 0.5% of all arrivals retest positive. 
** Of these newly arrived cases we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

preserve 
** Arriving with no test (5%) 
gen darr_notest = darr_red * 0.05  // CHANGE AS NEEDED


** 0.5% without a test will be positive, plus 0.5% of ALL ARRIVALS 
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d(01aug2020)
gen darr_pos = ceil((darr_notest * 0.005) + (darr_red * 0.005)) if random>=0.5 // CHANGE AS NEEDED
replace darr_pos = floor((darr_notest * 0.005) + (darr_red * 0.005)) if random<0.5 // CHANGE AS NEEDED 
drop random 

** Now calculate the same NUMBERS as for historical data 
replace new_cases = darr_pos if date>=d(01aug2020) & date<=d(30jun2021) // UPDATE TO JUNE 2012
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
keep country country_order iso iso_num pop date new_cases days maxel darr_red
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
gen cts_fuhra = darr_red/($ctfup) if date <  d($S1_DATE)
gen cts_fuhrb = darr_red/($ctfup) if date >= d($S2_DATE)
replace cts_fuhra = 0 if cts_fuhrb == .
replace cts_fuhrb = 0 if cts_fuhrb == .
tab cts_fuhrb

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(ctsa_av5)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(ctsb_av5)



**    keep if iso== "`country'" 
    local elapsed = maxel + 1

    ** Smoothing: method 2
    lowess cts_totala date , bwidth(0.2) gen(ctsa_low1) nogr
    lowess cts_totalb date , bwidth(0.2) gen(ctsb_low1) nogr

    ** GRAPHIC OF CT NEEDS OVER TIME
        #delimit ;
        gr twoway 
            (bar ctsb_av5 date if iso=="BRB" & date>=d(01dec2020), col("197 176 213"))
            (bar ctsa_av5 date if iso=="BRB" & date>=d(01dec2020), col("216 222 242"))
            (bar new_cases date if iso=="BRB" & date>=d(01dec2020), col("222 164 159%50"))
            (line ctsb_low1 date if iso=="BRB" & date>=d(01dec2020), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 date if iso=="BRB" & date>=d(01dec2020), lc("55 74 131%50") lw(0.4) lp("-"))

            ,

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin)) 
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin)) 
            bgcolor(white) 
            ysize(5) xsize(14)
            
            xlab(   

                    22250 "1 Dec"
                    22281 "1 Jan"
                    22312 "1 Feb"
                    22340 "1 Mar"
                    22371 "1 Apr"
                    22401 "1 May"
                    22432 "1 June"

            , labs(7) nogrid glc(gs16) angle(0) format(%9.0f))
            xtitle("", size(7) margin(l=2 r=2 t=2 b=2)) 
                
            ylab(0(10)60  
            , labs(7) notick nogrid glc(gs16) angle(0))
            yscale(fill noline) 
            ytitle("Frequency", size(6) margin(l=2 r=2 t=2 b=2)) 

            legend(size(3) position(1) ring(0) bm(t=1 b=1 l=1 r=1) colf cols(1) lc(gs16)
                region(fcolor(gs16) lw(vthin) margin(l=2 r=2 t=2 b=2) lc(gs16)) order(8 7 6)
                lab(1 "$ctfut2 contacts")
                lab(2 "$ctfut1 contacts")
                lab(3 "Cases")
                )
                name(scenario1) 
                ;
        #delimit cr
        graph export "`outputpath'/04_TechDocs/scenario1_$S_DATE.png", replace width(5000)
      

restore

** FUTURE SCENARIO 2

** Then 95% arriving with negative tests
** Of the 5% without negative tests - estimating that 1% will test positive on arrival, then 1% of ALL ARRIVALS retest positive. 
** Of these newly arrived cases we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

preserve
** Arriving with no test (5%) 
gen darr_notest = darr_red * 0.05


** 0.75% without a test will be positive and 75% of all arrivals will be positive
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d(01aug2020)
gen darr_pos = ceil((darr_notest * 0.0075) + (darr_red * 0.0075))  if random>=0.5
replace darr_pos = floor((darr_notest * 0.0075) + (darr_red * 0.0075)) if random<0.5
drop random 

** Now calculate the same NUMBERS as for historical data 
replace new_cases = darr_pos if date>=d(01aug2020) & date<=d(30jun2021)
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
replace ccase = new_cases if runid==1
replace ccase = ccase[_n-1] + new_cases[_n] if runid > 1   

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
gen cts_fuhrb = darr_hr/($ctfup) if date >= d($S2_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa 
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(ctsa_av5)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(ctsb_av5)


**    keep if iso== "`country'" 
    local elapsed = maxel + 1

    ** Smoothing: method 2
    lowess cts_totala date , bwidth(0.2) gen(ctsa_low1) nogr
    lowess cts_totalb date , bwidth(0.2) gen(ctsb_low1) nogr

    ** GRAPHIC OF CT NEEDS OVER TIME
        #delimit ;
        gr twoway 
            (bar ctsb_av5 date if iso=="BRB" & date>=d(01dec2020), col("197 176 213"))
            (bar ctsa_av5 date if iso=="BRB" & date>=d(01dec2020), col("216 222 242"))
            (bar new_cases date if iso=="BRB" & date>=d(01dec2020), col("222 164 159%50"))
            (line ctsb_low1 date if iso=="BRB" & date>=d(01dec2020), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 date if iso=="BRB" & date>=d(01dec2020), lc("55 74 131%50") lw(0.4) lp("-"))

            ,

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin)) 
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin)) 
            bgcolor(white) 
            ysize(5) xsize(14)
            
            xlab(   

                    22250 "1 Dec"
                    22281 "1 Jan"
                    22312 "1 Feb"
                    22340 "1 Mar"
                    22371 "1 Apr"
                    22401 "1 May"
                    22432 "1 June"

            , labs(7) nogrid glc(gs16) angle(0) format(%9.0f))
            xtitle("", size(7) margin(l=2 r=2 t=2 b=2)) 
                
            ylab(0(10)60  
            , labs(7) notick nogrid glc(gs16) angle(0))
            yscale(fill noline) 
            ytitle("Frequency", size(6) margin(l=2 r=2 t=2 b=2)) 

            legend(size(3) position(1) ring(0) bm(t=1 b=1 l=1 r=1) colf cols(1) lc(gs16)
                region(fcolor(gs16) lw(vthin) margin(l=2 r=2 t=2 b=2) lc(gs16)) order(8 7 6)
                lab(1 "$ctfut2 contacts")
                lab(2 "$ctfut1 contacts")
                lab(3 "Cases")
                )
                name(scenario2) 
                ;
        #delimit cr
        graph export "`outputpath'/04_TechDocs/scenario2_$S_DATE.png", replace width(5000)
      

restore


** FUTURE SCENARIO 3

** Then 95% arriving with negative tests
** Of the 5% without negative tests - estimating that 0.5% will test positive on arrival and 0.06% of all arrivals retest positive. 
** Of these newly arrived cases we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

preserve 
** Arriving with no test (5%) 
gen darr_notest = darr_red * 0.05


** 0.00025% without a test will be positive, plus 0.00025% of ALL ARRIVALS
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d(01aug2020)
gen darr_pos = ceil((darr_notest * 0.00025) + (darr_red * 0.00025)) if random>=0.5
replace darr_pos = floor((darr_notest * 0.00025) + (darr_red * 0.00025)) if random<0.5
drop random 

** Now calculate the same NUMBERS as for historical data 
replace new_cases = darr_pos if date>=d(01aug2020) & date<=d(30jun2021)
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
replace ccase = new_cases if runid==1
replace ccase = ccase[_n-1] + new_cases[_n] if runid > 1   

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
gen cts_fuhrb = darr_hr/($ctfup) if date >= d($S2_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa 
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(ctsa_av5)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(ctsb_av5)



**    keep if iso== "`country'" 
    local elapsed = maxel + 1

    ** Smoothing: method 2
    lowess cts_totala date , bwidth(0.2) gen(ctsa_low1) nogr
    lowess cts_totalb date , bwidth(0.2) gen(ctsb_low1) nogr

    ** GRAPHIC OF CT NEEDS OVER TIME
        #delimit ;
        gr twoway 
            (bar ctsb_av5 date if iso=="BRB" & date>=d(01dec2020), col("197 176 213"))
            (bar ctsa_av5 date if iso=="BRB" & date>=d(01dec2020), col("216 222 242"))
            (bar new_cases date if iso=="BRB" & date>=d(01dec2020), col("222 164 159%50"))
            (line ctsb_low1 date if iso=="BRB" & date>=d(01dec2020), lc("104 43 134%50") lw(0.4) lp("-"))
            (line ctsa_low1 date if iso=="BRB" & date>=d(01dec2020), lc("55 74 131%50") lw(0.4) lp("-"))

            ,

            plotregion(c(gs16) ic(gs16) ilw(thin) lw(thin)) 
            graphregion(color(gs16) ic(gs16) ilw(thin) lw(thin)) 
            bgcolor(white) 
            ysize(5) xsize(14)
            
            xlab(   

                    22250 "1 Dec"
                    22281 "1 Jan"
                    22312 "1 Feb"
                    22340 "1 Mar"
                    22371 "1 Apr"
                    22401 "1 May"
                    22432 "1 June"

            , labs(7) nogrid glc(gs16) angle(0) format(%9.0f))
            xtitle("", size(7) margin(l=2 r=2 t=2 b=2)) 
                
            ylab(0(10)60  
            , labs(7) notick nogrid glc(gs16) angle(0))
            yscale(fill noline) 
            ytitle("Frequency", size(6) margin(l=2 r=2 t=2 b=2)) 

            legend(size(3) position(1) ring(0) bm(t=1 b=1 l=1 r=1) colf cols(1) lc(gs16)
                region(fcolor(gs16) lw(vthin) margin(l=2 r=2 t=2 b=2) lc(gs16)) order(8 7 6)
                lab(1 "$ctfut2 contacts")
                lab(2 "$ctfut1 contacts")
                lab(3 "Cases")
                )
                name(scenario3) 
                ;
        #delimit cr
        graph export "`outputpath'/04_TechDocs/scenario3_$S_DATE.png", replace width(5000)
      

restore


** ------------------------------------------------------
** PDF REGIONAL REPORT (COUNTS OF CONFIRMED CASES)
** ------------------------------------------------------
    putpdf begin, pagesize(letter) font("Calibri Light", 10) margin(top,0.5cm) margin(bottom,0.25cm) margin(left,0.5cm) margin(right,0.25cm)

** EXTRA SLIDE - ALL CT CURVES ON ONE SLIDES
    **putpdf table intro2 = (1,1), width(100%) halign(left)    
    **putpdf table intro2(.,.), border(all, nil) valign(center)
    **putpdf table intro2(1,.), font("Calibri Light", 12, 000000)  
    **putpdf table intro2(1,1)=("Figure 1: "), bold halign(left)
    **putpdf table intro2(1,1)=("Estimations of Contact Tracing Workforce Needs, given 4 possible scenarios for SARS-COV2 prevalence ") , halign(left) append 
    **putpdf table intro2(1,1)=("and PCR status (positive/negative)"), halign(left) append   

** FIGURE 
    putpdf table f2 = (8,1), width(70%) border(all,nil) halign(center)
    putpdf table f2(1,1)=("Scenario 1. 5% without test, 0.5% of those test positive on first test and 0.5% on retest, 10 contacts (blue), 14 contacts (purple)"), halign(left) font("Calibri Light", 9, 0e497c)  
    putpdf table f2(2,1)=image("`outputpath'/04_TechDocs/scenario1_$S_DATE.png")
    putpdf table f2(4,1)=("Scenario 2. 5% without test, 0.75% of those test positive on first test and 0.75% on retest, 10 contacts (blue), 14 contacts (purple)"), halign(left) font("Calibri Light", 9, 0e497c)  
    putpdf table f2(5,1)=image("`outputpath'/04_TechDocs/scenario2_$S_DATE.png")
    putpdf table f2(7,1)=("Scenario 3. 5% without test, 0.025% of those test positive on first test and 0.025% on retest, 10 contacts (blue), 14 contacts (purple)"), halign(left) font("Calibri Light", 9, 0e497c)  
    putpdf table f2(8,1)=image("`outputpath'/04_TechDocs/scenario3_$S_DATE.png")
    **putpdf table f2(7,1)=("Scenario 4. 1% without test, 1% of those test positive on first test and 1% on retest, 10 contacts (blue), 14 contacts (purple)"), halign(left) font("Calibri Light", 9, 0e497c)  
    **putpdf table f2(8,1)=image("`outputpath'/04_TechDocs/scenario4_$S_DATE.png")

** Footnote.
    **putpdf paragraph ,  font("Calibri Light", 9)
    **putpdf text ("Methodological Note 1. ") , bold
    **putpdf text ("Each graphic presents the daily demand for contact tracers given the confirmed COVID-19 caseload. The demand assumes that contact tracers can ")
    **putpdf text ("conduct 6 confirmed case interviews, 12 potential case notifications, and 32 potential case follow-ups. Case follow-up is required for up to ") 
    **putpdf text ("14 days after identification. ")
    **putpdf text ("Methodological Note 2. ") , bold
    **putpdf text ("Blue bars assume 10 contacts per confirmed case. Purple bars assume 15 contacts per confirmed case. Dotted lines are smoothed daily contact tracer demand. ")

** Save the PDF
    local c_date = c(current_date)
    local date_string = subinstr("`c_date'", " ", "", .)
    putpdf save "`outputpath'/05_Outputs/brb_scenarios_`date_string'", replace
