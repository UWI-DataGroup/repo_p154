 **HEADER -----------------------------------------------------
**  DO-FILE METADATA
    //  algorithm name				  moh_tourist_cases.do
    //  project:				        
    //  analysts:				  	  Ian HAMBLETON, Christina Howitt and Natasha Sobers
    //  algorithm task			      This do file creates the graphics requested by the Ministry of Health to estimate numbers
    //                                of cases generated by tourist arrivals
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
    log using "`logpath'\moh_tourist_cases", replace
** HEADER -----------------------------------------------------


** BARBADOS AS EXAMPLE 
** COMMON TO ALL SCENARIOS
** 90% reduction in tourism arrivals per country 
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
gen year = 2021 
gen fdate = mdy(month, day, year) 
format fdate %td
keep if fdate >d(31mar2021) & fdate<d(01jul2021)
keep fdate darr 
rename fdate date 
order date darr 
replace darr = 0 if date<d(1apr2021) 
save "`datapath'/version01\2-working/brb_arrivals", replace 

** Reduction of 50% arrivals 
gen darr_red = darr * 0.25

** FUTURE SCENARIO 1

** Everyone has a test before boarding the plane
** At retest 5 days after arrival, 0.2% test positive (we used prevalence in the UK to estimate this)
** Of these newly arrived cases, we assume they will move freely for 5 days and to estimate cases arising, the SIR model applies

*preserve 

gen new_cases1 = (darr_red * 0.0000575)

gen new_cases2 = (darr_red * 0.00014375)

gen new_cases3 = (darr_red * 0.001846163)

gen month = month(date)

collapse (sum) new_cases1 new_cases2 new_cases3, by (month)      