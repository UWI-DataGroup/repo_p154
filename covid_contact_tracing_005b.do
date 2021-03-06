 **HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  covid_contact_tracing_005b.do
    //  project:				        
    //  analysts:				  	  Ian HAMBLETON
    //  algorithm task			      This do file creates the scenarios, but adding an app

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
    log using "`logpath'\covid_contact_tracing_005b", replace
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

***Calculating numbers of high risk cases arrivals assuming 20%
**This contributes to cases that need mandatory following
*gen darr_hr = darr_red*0.2   DECIDED TO DITCH AFTER SPEAKING TO NATASHA ON 11-DEC-2020


** Save scenario dataset
tempfile scenario scenario1 scenario2 scenario3 scenario4 scencomb
save `scenario', replace 


** FUTURE SCENARIO 1

** Then 95% arriving with negative tests
** Of the 5% without negative tests - estimating that 0.5% will test positive on arrival and 0.5% of all arrivals retest positive. 
** Of these newly arrived cases we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements
 
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
global ctnew3 = 12
global ctfut1 = 10
global ctfut2 = 14 
global ctfut3 = 12

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
gen cts_notc = (new_cases * $ctnew3) / ($ctnot) if date < d($S1_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S2_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S2_DATE)
replace cts_notc = (new_cases * $ctfut3) / ($ctnot) if date >= d($S2_DATE)


** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S1_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S1_DATE)
gen cts_fupc = (case14 * $ctnew3) / ($ctfup) if date < d($S1_DATE)
replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupc = (case14 * $ctfut3) / ($ctfup) if date >= d($S2_DATE)


***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_red/($ctfup) if date >= d($S2_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa 
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb
gen cts_totalc = cts_int + cts_notc + cts_fupc 


** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario1a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario1b)
by iso : asrol cts_totalc , stat(mean) window(date 5) gen(scenario1c)

keep date days scenario1a scenario1b scenario1c
order date days scenario1a scenario1b scenario1c 
save `scenario1', replace 



** FUTURE SCENARIO 2

** Then 95% arriving with negative tests
** Of the 5% without negative tests - estimating that 1% will test positive on arrival, then 1% of ALL ARRIVALS retest positive. 
** Of these newly arrived cases we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

use `scenario', replace 

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
global ctnew3 = 12
global ctfut1 = 10
global ctfut2 = 14 
global ctfut3 = 12 

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
gen cts_notc = (new_cases * $ctnew3) / ($ctnot) if date < d($S1_DATE)
replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S2_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S2_DATE)
replace cts_notc = (new_cases * $ctfut3) / ($ctnot) if date >= d($S2_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S1_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S1_DATE)
gen cts_fupc = (case14 * $ctnew3) / ($ctfup) if date < d($S1_DATE)

replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupc = (case14 * $ctfut3) / ($ctfup) if date >= d($S2_DATE)

***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_red/($ctfup) if date >= d($S2_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa 
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb
gen cts_totalc = cts_int + cts_notc + cts_fupc


** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario2a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario2b)
by iso : asrol cts_totalc , stat(mean) window(date 5) gen(scenario2c)


keep date days scenario2a scenario2b scenario2c
order date days scenario2a scenario2b scenario2c
save `scenario2', replace 


** FUTURE SCENARIO 3

** Then 95% arriving with negative tests
** Of the 5% without negative tests - estimating that 0.5% will test positive on arrival and 0.06% of all arrivals retest positive. 
** Of these newly arrived cases we assume quarantine measures in place between arrival and confirmation of diagnosis for those without tests 
** we estimate 10 to 14 contacts- airport officials, taxi, hotel officials and aircraft seating arrangements

use `scenario', replace 

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
global ctnew3 = 12
global ctfut1 = 10
global ctfut2 = 14 
global ctfut3 = 12 

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
gen cts_notc = (new_cases * $ctnew3) / ($ctnot) if date < d($S1_DATE)

replace cts_nota = (new_cases * $ctfut1) / ($ctnot) if date >= d($S2_DATE)
replace cts_notb = (new_cases * $ctfut2) / ($ctnot) if date >= d($S2_DATE)
replace cts_notc = (new_cases * $ctfut3) / ($ctnot) if date >= d($S2_DATE)

** Running total of CT-staff for contact follow-up  
gen cts_fupa = (case14 * $ctnew1) / ($ctfup) if date < d($S1_DATE)
gen cts_fupb = (case14 * $ctnew2) / ($ctfup) if date < d($S1_DATE)
gen cts_fupc = (case14 * $ctnew3) / ($ctfup) if date < d($S1_DATE)

replace cts_fupa = (case14 * $ctfut1) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupb = (case14 * $ctfut2) / ($ctfup) if date >= d($S2_DATE)
replace cts_fupc = (case14 * $ctfut2) / ($ctfup) if date >= d($S2_DATE)


***Running total of CT-staff for mandatory quarantine follow-up
gen cts_fuhrb = darr_red/($ctfup) if date >= d($S2_DATE)
replace cts_fuhrb = 0 if cts_fuhrb == .

** Total CT staffing needed per week 
gen cts_totala = cts_int + cts_nota + cts_fupa 
gen cts_totalb = cts_int + cts_notb + cts_fupb + cts_fuhrb
gen cts_totalc = cts_int + cts_notc + cts_fupc 


** Smoothing: method 1
by iso : asrol cts_totala , stat(mean) window(date 5) gen(scenario3a)
by iso : asrol cts_totalb , stat(mean) window(date 5) gen(scenario3b)
by iso : asrol cts_totalc , stat(mean) window(date 5) gen(scenario3c)


keep date days scenario3a scenario3b scenario3c
order date days scenario3a scenario3b scenario3c
save `scenario3', replace 



use `scenario1', clear 
merge 1:1 date using `scenario2'
drop _merge 
merge 1:1 date using `scenario3'
drop _merge 
save `scencomb', replace

** TABLE
***The absolute difference (a simple substraction) may actualy be the most appropriate measure
***Since we are trying to inform resource development/estimation.

** Monthly averages
gen year = year(date)
gen month = month(date)
gen tmonth = ym(year, month)
keep if tmonth>726
label define tmonth 727 "Aug 2020" 728 "Sep 2020" 729 "Oct 2020" 730 "Nov 2020" 731 "Dec 2020" 732 "Jan 2021" 733 "Feb 2021" 734 "Mar 2021" 735 "Apr 2021" 736 "May 2021" 737 "Jun 2021"
label values tmonth tmonth



collapse (mean) scenario1a scenario1b scenario1c scenario2a scenario2b scenario2c scenario3a scenario3b scenario3c, by(tmonth)
/*rename scenario1a a1
rename scenario1b b1
rename scenario2a a2
rename scenario2b b2
rename scenario3a a3
rename scenario3b b3
rename scenario4a a4
rename scenario4b b4
reshape long a b, i(tmonth) j(scenario)
rename a c8
rename b c12 
reshape long c, i(tmonth scenario) j(contacts)

** THE SCENARIOS
** 1A. 5% arriving without test. Of these 0.5% positive from first + 0.5% of all those entering retest positive. Cases have 10 contacts
** 1B. 5% arriving without test. Of these 0.5% positive from first + 0.5% of all those entering retest positive. Cases have 14 contacts

** 2A. 5% arriving without test. Of these 0.75% positive + 0.75% of all those entering retest positive. Cases have 10 contacts
** 2B. 5% arriving without test. Of these 0.75% positive + 0.75% of all those entering retest positive. Cases have 14 contacts

** 3A. 5% arriving without test. Of these 0.025% positive + 0.025% positive on retest. Cases have 10 contacts
** 3B. 5% arriving without test. Of these 0.025% positive + 0.025% positive on retest. Cases have 14 contacts

tabdisp scenario tmonth, cellvar(c) by(contact) format(%9.2f) 