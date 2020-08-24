 **HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  covid_contact_tracing_002a.do
    //  project:				        
    //  analysts:				  	  Ian HAMBLETON
    // 	date last modified	          27-July-2020
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
    log using "`logpath'\covid_contact_tracing_003", replace
** HEADER -----------------------------------------------------


** BARBADOS AS EXAMPLE 
** COMMON TO ALL SCENARIOS
** 59% reduction in tourism arrivals per country 
** we estimate 5 to 10 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

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
** And reduction of 75% in Oct, Nov, Dec 
gen darr_red = darr * 0.41 if date>=d($S_DATE) & date<=d(30sep2020)
replace darr_red = darr * 0.41 if date>=d(01oct2020) & date<=d(30nov2020)
replace darr_red = darr * 0.41 if date>=d(01dec2020) & date<=d(31dec2020)

***Calculating numbers of high risk cases arrivals assuming 20%
**This contributes to cases that need mandatory following
gen darr_hr = darr_red*0.2 


** Save scenario dataset
tempfile scenario scenario1 scenario2 scenario3 scenario4
save `scenario', replace 



** FUTURE SCENARIO 1

** Then 70% arriving with negative tests
** Of the 30% without negative tests - estimating that 0.5% will test positive. 
** Of these 0.5% we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 5 to 10 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

** Arriving with no test (30%) 
gen darr_notest = darr_red * 0.3 

** 0.5% without a test will be positive
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d($S_DATE)
gen darr_pos = ceil(darr_notest * 0.005) if random>=0.5
replace darr_pos = floor(darr_notest * 0.005) if random<0.5
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
global ctfut1 = 10 
global ctfut2 = 14 

** Daily case load: Positive case interviews
global ctint = 4

** Daily case load: Contact notification
global ctnot = 15

** Daily case load: Contact follow-up 
global ctfup = 40

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
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) if date < d($S_DATE)
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) if date < d($S_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S_DATE)

***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_hr/($ctfup) if date >= d($S_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario1a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario1b)

keep date days scenario1a scenario1b 
order date days scenario1a scenario1b 
save `scenario1', replace 





**FUTURE SCENARIO 2
** Then 70% arriving with negative tests
** Of the 30% without negative tests - estimating that 1% will test positive. 
** Of these 1% we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
use `scenario', clear 

* Arriving with no test (30%) 
gen darr_notest = darr_red * 0.3 

** 1% without a test will be positive
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d($S_DATE)
gen darr_pos = ceil(darr_notest * 0.01) if random>=0.5
replace darr_pos = floor(darr_notest * 0.01) if random<0.5
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
global ctfut1 = 10 
global ctfut2 = 14 

** Daily case load: Positive case interviews
global ctint = 4

** Daily case load: Contact notification
global ctnot = 15

** Daily case load: Contact follow-up 
global ctfup = 40

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
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) if date < d($S_DATE)
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) if date < d($S_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S_DATE)

***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_hr/($ctfup) if date >= d($S_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario2a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario2b)

keep date days scenario2a scenario2b 
order date days scenario2a scenario2b 
save `scenario2', replace 



**FUTURE SCENARIO 3
**Then 50% arriving with negative tests
** Of the 50% without negative tests - estimating that 0.5% will test positive. 
 use `scenario', clear 


** Arriving with no test (50%) 
gen darr_notest = darr_red * 0.5 

** 0.5% without a test will be positive
** With RANDOM round-down or round-up to nearest integer 
gen random = uniform() if date>=d($S_DATE)
gen darr_pos = ceil(darr_notest * 0.005) if random>=0.5
replace darr_pos = floor(darr_notest * 0.005) if random<0.5
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
global ctfut1 = 10 
global ctfut2 = 14 

** Daily case load: Positive case interviews
global ctint = 4

** Daily case load: Contact notification
global ctnot = 15

** Daily case load: Contact follow-up 
global ctfup = 40

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
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) if date < d($S_DATE)
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) if date < d($S_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S_DATE)

***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_hr/($ctfup) if date >= d($S_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario3a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario3b)

keep date days scenario3a scenario3b 
order date days scenario3a scenario3b 
save `scenario3', replace 





**FUTURE SCENARIO 4
**Then 50% arriving with negative tests
** Of the 50% without negative tests - estimating that 1% will test positive. 
use `scenario', clear 

* Arriving with no test (50%) 
gen darr_notest = darr_red * 0.5 

** 0.5% without a test will be positive
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
global ctfut1 = 10 
global ctfut2 = 14 

** Daily case load: Positive case interviews
global ctint = 4

** Daily case load: Contact notification
global ctnot = 15

** Daily case load: Contact follow-up 
global ctfup = 40

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
gen cts_nota = (new_cases * $ctnew1) / ($ctnot) if date < d($S_DATE)
gen cts_notb = (new_cases * $ctnew2) / ($ctnot) if date < d($S_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S_DATE)

***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_hr/($ctfup) if date >= d($S_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb

** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario4a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario4b)

keep date days scenario4a scenario4b 
order date days scenario4a scenario4b 
save `scenario4', replace 

use `scenario1', clear 
merge 1:1 date using `scenario2'
drop _merge 
merge 1:1 date using `scenario3'
drop _merge 
merge 1:1 date using `scenario4'
drop _merge 

** TABLE
***The absolute difference (a simple substraction) may actualy be the most appropriate measure
***Since we are trying to inform resource development/estimation.

** Monthly averages
gen month = month(date) 
keep if month>=8
label define month_ 8 "aug" 9 "sep" 10 "oct" 11 "nov" 12 "dec" 
label values month month_ 
collapse (mean) scenario1a scenario1b scenario2a scenario2b scenario3a scenario3b scenario4a scenario4b , by(month)
rename scenario1a a1
rename scenario1b b1
rename scenario2a a2
rename scenario2b b2
rename scenario3a a3
rename scenario3b b3
rename scenario4a a4
rename scenario4b b4
reshape long a b, i(month) j(scenario)
rename a c10
rename b c14 
reshape long c, i(month scenario) j(contacts)

** THE SCENARIOS
** 1A. 30% without test. Of these 0.5% positive. Cases have 5 contacts
** 1B. 30% without test. Of these 0.5% positive. Cases have 10 contacts

** 2A. 30% without test. Of these 1.0% positive. Cases have 5 contacts
** 2B. 30% without test. Of these 1.0% positive. Cases have 10 contacts

** 3A. 50% without test. Of these 0.5% positive. Cases have 5 contacts
** 3B. 50% without test. Of these 0.5% positive. Cases have 10 contacts

** 4A. 50% without test. Of these 1.0% positive. Cases have 5 contacts
** 4B. 50% without test. Of these 1.0% positive. Cases have 10 contacts

tabdisp scenario month, cellvar(c) by(contact) format(%9.2f) 
