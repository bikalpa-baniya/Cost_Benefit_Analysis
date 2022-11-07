
/*
Economics Analysis for Nai Manzil Project
By: Bikalpa Baniya
June 28th, 2021

The following code calculates the wage increments by age group for the Nai Manzil project. It uses the NSS 75th round surveys
(specifically nss75_sch25_2_4.dta and nss75_sch25_2_1.dta) and the Mott MacDonlad Sample Surveys. The final table is the wage 
increments by age. 
*/


//Location of the files.
global data "/Users/bikalpabaniya/Desktop/World Bank/Input"


*******************
***** Merging *****
*******************

use "$data/nss75_sch25_2_1.dta", clear


keep hhid state_reg state district sector hhwt
 
merge 1:m hhid using "$data/nss75_sch25_2_4.dta"




//Keeping only the age groups that match the Nai Manzil sample 

keep hhid state_reg state sector district hhwt sex age edugen tech_training enrol_status yrs_complete indid class_complete edutech
 
drop if class_complete == 99 | class_complete <4 | class_complete >9

keep if age <36 & age >16



//Calcuating the number of observation for each groups

gen number = 1  

tabstat age, by(class_complete) statistics(N mean sd median Min Max)

gen female_dummy =1 if sex ==2 //Where 2 meant female
replace female_dummy=0 if sex!=2


bysort sex class_complete : generate group_total = _N


collapse group_total (count) number, by(female_dummy class_complete  age)

//Proportion of population for each gender, age and grade
gen prop = number / group_total

tempfile NSS75th
save `NSS75th'


//Saving the proportion into local macros
loc num_obs = _N
forval i = 1/`num_obs'{
	
	loc sex_name = female_dummy[`i']
	loc age_name = age[`i']
	loc edu_comp = class_complete[`i']

	loc sex_`sex_name'_age_`age_name'_educ_`edu_comp' = prop[`i']
	
	
}


***********************************************************
***** Applying wage increments to the Nai Manzil Data *****
***********************************************************



import excel "/Users/bikalpabaniya/Desktop/World Bank/Input/Nai Manzil Data Compiled.xlsx", sheet("Sample Data - wages") firstrow clear


gen female_dummy = GENDER1Male2Female -1
rename EDUCATION_QUALIFICATION_PRISta edu_prior 
rename A_PER_MONTH_INCOME_BEFORE_COBe wage_prior_monthly
rename B_PER_MONTH_INCOME_AFTER_COUR wage_after_monthly
keep SrNo female_dummy edu_prior wage_prior_monthly wage_after_monthly 


gen edu_prior_num = 0
replace edu_prior_num = 4 if edu_prior == "4th Pass"
replace edu_prior_num = 5 if edu_prior == "5th Pass" | edu_prior == "6th Fail" 
replace edu_prior_num = 6 if edu_prior == "6th Pass"
replace edu_prior_num = 7 if edu_prior == "7th Pass"| edu_prior == "8th Fail" 
replace edu_prior_num = 8 if edu_prior == "8th Pass" | edu_prior == "9th Fail" 
replace edu_prior_num = 9 if edu_prior == "9th Pass" | edu_prior == "10th Fail" 
replace edu_prior_num = 10 if edu_prior == "10th Pass"


bysort edu_prior_num female_dummy: generate group_total = _N

gen total_wage_inc = (wage_after_monthly - wage_prior_monthly)*12 


gen sorting_wage_increment = - total_wage_inc
bysort edu_prior_num female_dummy (sorting_wage_increment): generate prop = _n/group_total  // Prop of people with this edu and sex 
drop sorting_wage_increment


//Assigning the ages to the Nai Mazil sample data 
//It is assumed that older people will have higher wage increments

gen age = -9999

loc num_obs = _N
forval i = 1/`num_obs'{
	
	loc sex_name = female_dummy[`i']
	loc edu_comp = edu_prior_num[`i']
	loc prop_NM = prop[`i']   - 0.0001
	
	
	loc control = 0
	loc age_prop = 0 
	
	
	forval age_name = 35(-1)17{
		
		
		loc age_prop = `age_prop' + `sex_`sex_name'_age_`age_name'_educ_`edu_comp''
		
		if `age_prop' >= `prop_NM' & `control' == 0 {
			replace age = `age_name' in `i'
			loc control = 1
			
		}
			
	}
	
	
}



//Creating the two category blocks 
gen category = 0
replace category = 1 if edu_prior_num <8
replace category = 2 if edu_prior_num >7


//Creating the age groups 

gen age_group = 0
replace age_group = 1 if age <=20             //17-20
replace age_group = 2 if age >=21  & age <=25 //21-25
replace age_group = 2 if age >=26  & age <=35 //26-30
replace age_group = 4 if age <=35 & age >=31  //31-35


drop if total_wage_inc <= 0 




collapse total_wage_inc, by(age_group female_dummy category)


//Saving the wage increments 

loc num_obs = _N
forval i = 1/`num_obs'{
	loc cat = category[`i']
	loc is_female = female_dummy[`i']
	loc age_grp = age_group[`i']
	
	loc IsFemale_`is_female'_Cat_`cat'_AgeGrp_`age_grp' = total_wage_inc[`i']
	
}



















