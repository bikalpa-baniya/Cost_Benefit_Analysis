
/*
Economics Analysis for Nai Manzil Project
By: Bikalpa Baniya
June 8th, 2021

The following code calculates the Net Present Value and the Internal Rate of Return for the Nai Mazil Project. 
These indicators are calculated using the following steps 

1) Prepare the Data (Get inflation rates, MoMA disbursement and Age share)
2) Create the required functions for indicator calculation
3) Merge the data from step 1) with the Status and Results Report 
4) Create Future Years and account for aging 
5) Calculate Wage Increment due to the project 
7) Calculate the indicators


Input required: An excel data with the following sheets 
1) Inflation Rate: Inflation Rate in India from 2010 to 2021
2) MoMA expenditure information from the ministries' expenditure reports 
3) Age Analysis Excel Sheet which has the age of participants
4) Data from the Implementation And Status Report 
		Specifically, Year, 
		IDA Total Disbursement, 
		Grade8 certificate Completion Rate, 
		Secondary certificate Completion Rate, 	
		Skills certificate Completion rate, 	
		Minority Blocks Share,
		Employment Rate	
		Direct beneficiaries 	
		Exchange Rate
5) Sample data from the Final Impact Report that contains education level and wages prior to Nai Manzil 

		
External information used 
- Figure 26, page 37 from the International Labor Organization India Wage Report 2018 
https://www.ilo.org/wcmsp5/groups/public/---asia/---ro-bangkok/---sro-new_delhi/documents/publication/wcms_638305.pdf
*/





//Controls for sensitivity analysis

global include_all_PAD_assumption = 0   //This could also be interpreted as using 68th NSS wage increment (1) or the Mott MacDonald Survey wage increment (0)
global include_opp_cost = 1
global include_future_cost = 1

loc employ_rate_increment = 0.08 //Employment Rate increment every year 





**********************
**********************
**Preparing the data**
**********************
**********************

//Setting the location of the input data 
global data "/Users/bikalpabaniya/Desktop/World Bank/Input"



//Retrieving wages across gender and project blocks. Also retrieving gender ratios from the blocks
//The sample data from the final impact report is used
import excel "$data\\Nai Manzil Data Compiled.xlsx", sheet("Sample Data - wages") firstrow clear
gen female_dummy = GENDER1Male2Female -1
rename EDUCATION_QUALIFICATION_PRISta edu_prior 
rename A_PER_MONTH_INCOME_BEFORE_COBe wage_prior_monthly
rename B_PER_MONTH_INCOME_AFTER_COUR wage_after_monthly
keep SrNo female_dummy edu_prior wage_prior_monthly wage_after_monthly 


***Total wage increment gender prop ***

egen female_sum = total(female_dummy)
gen total_female_prop_temp = female_sum[1]/_N
loc total_female_prop = total_female_prop_temp[1]

gen total_wage_inc_f = (wage_after_monthly - wage_prior_monthly)*12 if female_dummy==1
quietly: summarize total_wage_inc_f
gen total_wage_inc_f_mean = r(mean)
loc total_wage_inc_f_mean = total_wage_inc_f_mean[1]

gen total_wage_inc_m = (wage_after_monthly - wage_prior_monthly)*12 if female_dummy==0
quietly: summarize total_wage_inc_m
gen total_wage_inc_m_mean = r(mean)
loc total_wage_inc_m_mean = total_wage_inc_m_mean[1]



*** Wage increment gender prop for the minority block***

gen MinBlock_dummy = (edu_prior == "7th Pass"|edu_prior == "6th Pass"|edu_prior == "6th Fail"|edu_prior == "5th Pass"|edu_prior == "4th Pass"|edu_prior == "8th Fail" |edu_prior == "7th Fail")
egen MinBlock_sum = total(MinBlock_dummy)
gen MinBlock_prop = MinBlock_sum[1]/_N 

egen MinBlock_female_sum = total(female_dummy) if MinBlock_dummy==1
gen MinBlock_female_prep_temp = MinBlock_female_sum/MinBlock_sum
sort MinBlock_female_prep_temp, stable
loc MinBlock_female_prop = MinBlock_female_prep_temp[1]

gen MinBlock_wage_inc_f = (wage_after_monthly - wage_prior_monthly)*12 if (female_dummy==1 & MinBlock_dummy==1)
quietly: summarize MinBlock_wage_inc_f
gen MinBlock_wage_inc_f_mean = r(mean)
loc MinBlock_wage_inc_f_mean = MinBlock_wage_inc_f_mean[1] 

gen MinBlock_wage_inc_m = (wage_after_monthly - wage_prior_monthly)*12 if (female_dummy==0 & MinBlock_dummy==1)
quietly: summarize MinBlock_wage_inc_m
gen MinBlock_wage_inc_m_mean = r(mean)
loc MinBlock_wage_inc_m_mean = MinBlock_wage_inc_m_mean[1] 



*** Wage increment gender prop for the Category B block ***

egen CatB_female_sum = total(female_dummy) if MinBlock_dummy==0
gen CatB_female_prep_temp = CatB_female_sum/(_N - MinBlock_sum)
sort CatB_female_prep_temp, stable
loc CatB_female_prop = CatB_female_prep_temp[1] 

gen CatB_wage_inc_f = (wage_after_monthly - wage_prior_monthly)*12 if (female_dummy==1 & MinBlock_dummy==0)
quietly: summarize CatB_wage_inc_f
gen CatB_wage_inc_f_mean = r(mean)
loc CatB_wage_inc_f_mean = CatB_wage_inc_f_mean[1] 

gen CatB_wage_inc_m = (wage_after_monthly - wage_prior_monthly)*12 if (female_dummy==0 & MinBlock_dummy==0)
quietly: summarize CatB_wage_inc_m
gen CatB_wage_inc_m_mean = r(mean)
loc CatB_wage_inc_m_mean = CatB_wage_inc_m_mean[1] 







//Preparing the inflation rate to calcuate 2010 currency in 2021 Rs.
//This is done because the code uses the 2010 wage increment given in the apprasial document (Table 4, Page 36)
clear
import excel "$data\\Nai Manzil Data Compiled.xlsx", sheet("Inflation Rate") firstrow clear
loc rows = _N
gen inflation_temp = 1
forval obs_loop= 1/`rows'{
	replace inflation_temp = inflation_temp * (1+InflationRate[`obs_loop'])	
}
loc inflation = inflation_temp[1]



//Retriving the MoMA disbursement data for each year 
clear
import excel "$data\\Nai Manzil Data Compiled.xlsx", sheet("MoMA Annual Reports") firstrow clear

*caluating future potential MoMA disbursement
egen actual_total = total(ActualExpenditureinCrores)
egen budgeted_total = total(BudgetedExpenditureinCrores)
loc future_MoMA_dis_est = (budgeted_total[1]-actual_total[1])/2 * 0.0136809 * 10000000 //where 0.013 is the exchange rate in 2021

keep Year ActualExpenditureinCrores Benificaries 
rename ActualExpenditureinCrores MoMA_disbursement
rename Benificaries MoMA_Benificaries

tempfile MoMA
save `MoMA'



//Calculating the share of participants at each age. 
clear 	  
import excel "$data\\Nai Manzil Data Compiled.xlsx", sheet("Age Analysis") cellrange(A1:B97450) firstrow clear
forval Age= 13/60{
	generate age_`Age' = (age == `Age')
	egen sum_`Age' = total(age_`Age')
	local age_`Age' = cond(`Age' <36 & `Age' > 16 , sum_`Age'[1]/_N  , 0)	
}

//Getting the data from the Implementation And Status Report 
clear
import excel "$data\\Nai Manzil Data Compiled.xlsx", sheet("Status & Results Report") firstrow
drop if  IA !=1 //There are multiple reports per year so only one per year is used. Drop if the report is not used 
drop IA









*****************************************
*****************************************
***Creating functions to be used later***
*****************************************
*****************************************
//This is done to avoid repeated blocks of codes 




capture program drop Indicator_calculator   //Ensuring the function has not already been defined. Would be an error otherwise
 
program define Indicator_calculator   //Benefit  MoMA_disbursement_USD  Group 
                                      //These three will be the required arguments while executing the code 
									  //Here Group =1 if calcuating for the whole program, Group =2 if only for Cat B and 
													//Group = 3 is calcuating only for the minority block

													
		**************************************
		***Calculate the cost for each year***
		**************************************

		//Cost for each year 
		gen Disbursement = `2'  //Here `2' is the second argument, i.e. the MoMA_disbursement_USD or cost

		//Opporunity Cost which is considered to be the lost wages 
		loc primary_IC = 159.5 * 365
		loc secondary_IC = 247 * 365
		loc unemployment_rate = (0.3* (0.44 + 0.02) + 0.7 * (0.59+0.03)) //From figure 26 page 37 ILO report described above. Also considering the 30% Minority Block share assumption from the apprasial document

		////Once people have been placed they no longer bear opportunity cost
		//Here `3' is the third argument 
		if `3'==3 {
			gen in_program = (1- Employment_Rate) * MoMA_Benificaries *  Minority_Blocks
			replace Disbursement  = Disbursement  * 0.3 //Because only minority block	
		}
		else if `3' == 2{
			gen in_program = (1- Employment_Rate) * MoMA_Benificaries * (1-Minority_Blocks)
			replace Disbursement  = Disbursement  * 0.7 //Because only Category B	
		}
		else if `3' == 1{
			gen in_program = (1- Employment_Rate) * MoMA_Benificaries 	
		}
	
		replace in_program =0 if Year > 2021
		gen opp_cost = (0.3 * in_program *`primary_IC' + 0.3 * in_program * `secondary_IC')*Exchange_rate*(1-`unemployment_rate') 
		gen opp_cost_w_stipend = opp_cost - ( in_program * 14500 * Exchange_rate )
		replace opp_cost =0 if Year > 2021

		//Total Cost per year 
		if $include_opp_cost == 1 {
			egen cost = rowtotal(opp_cost_w_stipend Disbursement  )
		}
		if $include_opp_cost == 0 {
			egen cost = rowtotal(Disbursement  )
		}
		bysort Year: keep if _n==5
		drop Disbursement 

		
		
		********************************
		***Calculating the indicators***
		********************************

		//Calculating the Net Present Value
		local obs_loop = _N
		gen discount = 0.12
		gen Cash_flow = `1' - cost  //Here `1' is the first argument for the function
		gen Net_Present_Value = Cash_flow / ((1+discount)^(Year-2021))
		egen NPV_sum = total(Net_Present_Value)
		global NPV_value_function = NPV_sum[1]

		//Calculating the Internal Rate of Return
		loc loop_start = -100
		loc loop_end = 100
		loc NPV_prev = `loop_start'
		loc sensitivity = 100

		forvalues IRR = `loop_start'/`loop_end' {
				if `IRR'!= -1 * abs(`sensitivity '){
					
					gen NPV_value_temp = Cash_flow / ((1 +  `IRR'/`sensitivity')^(Year-2021))
					egen NPV_value_sum = total(NPV_value_temp)
					loc NPV_current = NPV_value_sum[1]
					//display `NPV_current'
					//display `IRR'
					if (`NPV_prev' >= 0 & `NPV_current' <= 0 ) | (`NPV_prev' >= 0 & `NPV_current' <=0 ){
						global IRR_value_function = `IRR'
					}
					loc NPV_prev = NPV_value_sum[1]
					drop NPV_value_temp NPV_value_sum
				}
			}
			
			
		//Calcuating the External Rate of Return 
		gen inflow_ERR = `1' *  ((1 + 0.12)^(2064-Year))
		gen outflow_ERR = cost / (( 1+0.12)^(Year-2017))
		egen inflow_ERR_total = total(inflow_ERR)
		egen outflow_ERR_total = total(outflow_ERR)
		global ERR_value_function =  100 * (  (inflow_ERR_total[1]/outflow_ERR_total[1]) ^ (1 / (2064-2017) ) - 1)
		//drop inflow_ERR outflow_ERR inflow_ERR_total outflow_ERR_total
		
		
end






**********************
**********************
*******Merging********
**********************
**********************

merge 1:1 Year using `MoMA'

//Convert the currency if Rs. was recorded and change the scale 
generate MoMA_disbursement_USD = MoMA_disbursement * Exchange_rate * 10000000
generate IDA_disbursement_USD = IDATotalDisbursedinMillions * 1000000


//Calculating certificate given out at each age using the age share calcuated above 
foreach var of varlist  Grade8_certificate-Skills_certificate {
	forval Age_loop= 13/60{
		loc age_share = `age_`Age_loop''               //Share of population at current age with age being value Age_loop
		generate `var'_`Age_loop' = -9999     
		replace `var'_`Age_loop' = `age_`Age_loop''*`var'* MoMA_Benificaries if `Age_loop' < 36 & `Age_loop' > 16 
		replace `var'_`Age_loop' = 0 if  `Age_loop' >35
		replace `var'_`Age_loop' = . if  `Age_loop' <17
		replace `var'_`Age_loop' = 0 if  Year == 2018 | Year == 2017
	}
}






**************************************************
**************************************************
**Creating Future Years and Accounting for Aging**
**************************************************
**************************************************



//Accounting for aging in the future after the reference year 2021
forval year_loop= 2022/2064{
		insobs 1
		
		//These values aisconsidered constant after 2021
		replace MoMA_Benificaries= MoMA_Benificaries[_N-1] if  MoMA_Benificaries==. & Year != 2018 & Year != 2017
		replace Minority_Blocks= Minority_Blocks[_N-1] if  Minority_Blocks==. & Year != 2018 & Year != 2017
		replace Exchange_rate= Exchange_rate[_N-1] if  Exchange_rate==. & Year != 2018 & Year != 2017
		
	
		//Employment Rate increases by the the value of employ_rate_increment until 100% employment is reached 
		replace Employment_Rate= Employment_Rate[_N-1]+`employ_rate_increment' if  Employment_Rate==. & Year != 2018 & Year != 2017 & Employment_Rate[_N-1]+`employ_rate_increment' < 1
		replace Employment_Rate = 1 if  Employment_Rate==. & Year != 2018 & Year != 2017 & Employment_Rate[_N-1]+`employ_rate_increment' > 1
					
					
		//Aging of the population 
		forval age_loop = 18/60{
			loc age_loop_prev = `age_loop'-1
			replace Year = `year_loop' if Year == . 
			replace Grade8_certificate_`age_loop' = Grade8_certificate_`age_loop_prev'[_N-1] if Grade8_certificate_`age_loop' == . 
			replace Sec_educ_certificate_`age_loop' = Sec_educ_certificate_`age_loop_prev'[_N-1] if Sec_educ_certificate_`age_loop' == .
			replace Skills_certificate_`age_loop' = Skills_certificate_`age_loop_prev'[_N-1] if Skills_certificate_`age_loop' == .	
			
			
		}
	}
	
//Accounting for aging in the past before the reference year 2021
forval year_loop = 2019/2020{
	forval age_loop = 15/16{
		loc age_loop_before = `age_loop'+1
		replace Year = `year_loop' if Year == . 
		replace Grade8_certificate_`age_loop' = Grade8_certificate_`age_loop_before'[_n+1] if Grade8_certificate_`age_loop' == . 
		replace Sec_educ_certificate_`age_loop' = Sec_educ_certificate_`age_loop_before'[_n+1] if Sec_educ_certificate_`age_loop' == .
		replace Skills_certificate_`age_loop' = Skills_certificate_`age_loop_before'[_n+1] if Skills_certificate_`age_loop' == .	
	}
}

//Use the number of beneficiaries in 2018 and 2017 is that from 2019 because the number was not recorded for the two years
replace Direct_beneficiaries = Direct_beneficiaries[3] if Year ==2017 | Year ==2018
replace Direct_beneficiaries = Direct_beneficiaries[3] if Year ==2017 | Year ==2018

//Use the number of beneficiaries in 2017 is that from 2018 because the number was not recorded for 2017
replace MoMA_Benificaries = MoMA_Benificaries[2] if Year ==2017


//Use the Minority Block ratio in 2018 and 2017 is that from 2019 because the number was not recorded for the two years
replace Minority_Blocks = Minority_Blocks[3] if Year ==2017 | Year ==2018
replace Minority_Blocks = Minority_Blocks[3] if Year ==2017 | Year ==2018

if $include_future_cost == 1{
	replace MoMA_disbursement_USD = `future_MoMA_dis_est' if Year ==2022 | Year ==2023
}



//Share of population still active at given Year 
gen share_pop_active = 1 if Year < 2046
forval year_loop = 2046/2064{
	loc share_pop_active = 0 
	forval age_loop = 17/35{
		if (`year_loop'-2021 + `age_loop') < 61 {   //Is cohort `age_loop' less than 60 years old in year `year_loop'
			loc share_pop_active = `share_pop_active'+ `age_`age_loop''
			}
		
	}
	
	replace share_pop_active = `share_pop_active' if Year == `year_loop'
}


reshape long Grade8_certificate_ Sec_educ_certificate_ Skills_certificate_ , i(Year) j(Age)

tempfile Main_df
save `Main_df'





if $include_all_PAD_assumption == 1{
	
	    ***********************************************************
		****** Calcuating Indicators for the total project*********
	    ***********************************************************
	
		//Local variables for wages as per apprasial document (Table 4, Page 36)
		local Grade8_increment_15_19 = 8300 
		local Grade8_increment_20_29 = 8100
		local Grade8_increment_30_39 = 20200
		local Grade8_increment_40_49 = 12160
		local Grade8_increment_50_59 = 27900

		local Grade10_increment_15_19 = 14750
		local Grade10_increment_20_29 = 3000
		local Grade10_increment_30_39 = 11372
		local Grade10_increment_40_49 = 48167
		local Grade10_increment_50_59 = 96075

		//Creating the shells for wage increment by grade because of the program
		gen G8_increment = 0
		gen G10_increment = 0
		gen Skill_Cert_increment = 0


		//Multiply wage and people to calculate benefit for each age group and each year_loop
		forval year_loop = 1/5{
			if `year_loop' == 1 loc age_loop_lower = 10+5*`year_loop' 
			if `year_loop' != 1 loc age_loop_lower = 10*`year_loop' 
			loc age_loop_upper =9+`year_loop'*10
			
			gen G8_increment_temp = (Exchange_rate * `Grade8_increment_`age_loop_lower'_`age_loop_upper'')* Employment_Rate * Grade8_certificate_  * `inflation'
			gen G10_increment_temp = (Exchange_rate * `Grade10_increment_`age_loop_lower'_`age_loop_upper'')* Employment_Rate * Sec_educ_certificate_ * `inflation'
			gen Skill_Cert_increment_temp = (Exchange_rate * 300*12)* Employment_Rate * Skills_certificate_ //300 per month premimum  
			
			replace G8_increment = G8_increment_temp if Age >= `age_loop_lower' & Age<= `age_loop_upper'
			replace G10_increment = G10_increment_temp if Age >= `age_loop_lower' & Age<= `age_loop_upper'
			replace Skill_Cert_increment = Skill_Cert_increment_temp  if Age >= `age_loop_lower' & Age<= `age_loop_upper'
			 
			drop G8_increment_temp G10_increment_temp Skill_Cert_increment_temp
		}

		
		***Calculate the benefit for each year***


		//The benefit for each year
		by Year: egen benefit_G8 = total(G8_increment)
		by Year: egen benefit_G10 = total(G10_increment)
		by Year: egen benefit_Skill_cert = total(Skill_Cert_increment )

		gen benefit = benefit_G8 + benefit_G10 + benefit_Skill_cert
		drop benefit_G8 benefit_G10 benefit_Skill_cert 
		

		***Calculate the indicator***
		Indicator_calculator benefit  MoMA_disbursement_USD  1
		loc NPV_value = $NPV_value_function
		loc IRR_value = $IRR_value_function
		loc ERR_value = $ERR_value_function
			
		
		
		display `NPV_value'	

		display `IRR_value'
		
		display `ERR_value'
}


if $include_all_PAD_assumption == 0{
	
	    ***********************************************************
		****** Calcuating Indicators for the total project*********
	    ***********************************************************	
		
		replace MoMA_Benificaries = MoMA_Benificaries *share_pop_active
	
		//Multiply wage and people to calculate benefit 
		gen wage_increment_Dtotal_avg = (`total_female_prop' * `total_wage_inc_f_mean' + (1-`total_female_prop') *  `total_wage_inc_m_mean' )
		gen wage_increment_Dtotal = Exchange_rate * Employment_Rate * MoMA_Benificaries * wage_increment_Dtotal_avg

		***Calculate the indicator***
		Indicator_calculator wage_increment_Dtotal  MoMA_disbursement_USD  1
		loc NPV_value = $NPV_value_function
		loc IRR_value = $IRR_value_function
		loc ERR_value = $ERR_value_function
		
		


		
			
	    ***********************************************************
		****** Calcuating Indicators for the Minority Block *******
	    ***********************************************************
		    
		***Calculating Wage Increment due to the project***
		use `Main_df', clear
		replace MoMA_Benificaries = MoMA_Benificaries *share_pop_active
		
		//Multiply wage and people to calculate benefit 
		gen wage_increment_MinBlock_avg = `MinBlock_female_prop' * `MinBlock_wage_inc_f_mean' + (1-`MinBlock_female_prop') *  `MinBlock_wage_inc_m_mean' 
		gen wage_increment_MinBlock = Exchange_rate * Employment_Rate * (MoMA_Benificaries *  Minority_Blocks ) * wage_increment_MinBlock_avg


		***Calculate the indicators***
		Indicator_calculator wage_increment_MinBlock  MoMA_disbursement_USD  3
		loc NPV_value_MinBlock = $NPV_value_function
		loc IRR_value_MinBlock = $IRR_value_function
		loc ERR_value_MinBlock = $ERR_value_function
		

			
			
			
	    ***********************************************************
		****** Calcuating Indicators for the Catagory B Block *****
	    ***********************************************************

		***Calculating Wage Increment due to the project***
		
		use `Main_df', clear
		replace MoMA_Benificaries = MoMA_Benificaries *share_pop_active
		
		//Multiply wage and people to calculate benefit 
		gen wage_increment_CatB_avg = `CatB_female_prop' * `CatB_wage_inc_f_mean' + (1-`CatB_female_prop') *  `CatB_wage_inc_m_mean' 
		gen wage_increment_CatB = Exchange_rate * Employment_Rate * (MoMA_Benificaries *  (1-Minority_Blocks) ) * wage_increment_CatB_avg

		
		***Calculate the indicators***
		Indicator_calculator wage_increment_CatB  MoMA_disbursement_USD  2
		loc IRR_value_CatB = $IRR_value_function
		loc NPV_value_CatB = $NPV_value_function
		loc ERR_value_CatB = $ERR_value_function
		
		

			
		display `NPV_value'
			
		display `IRR_value'
		
		display `ERR_value'

		display `NPV_value_MinBlock'	

		display `IRR_value_MinBlock'
		
		display `ERR_value_MinBlock'

		display `NPV_value_CatB'	

		display `IRR_value_CatB'
		
		display `ERR_value_CatB'

	
}


//Value for the total project 
		display `NPV_value'	
		display `IRR_value'
		display `ERR_value'

		
//Other relevant indicators
		
display `total_female_prop'
display `total_wage_inc_f_mean'
display `total_wage_inc_m_mean'

display `MinBlock_female_prop'
display `MinBlock_wage_inc_f_mean'
display `MinBlock_wage_inc_m_mean'

display `CatB_female_prop'
display `CatB_wage_inc_f_mean'
display `CatB_wage_inc_m_mean'



use `Main_df', clear




