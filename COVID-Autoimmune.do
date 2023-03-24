import delimited "/rds/projects/s/subramaa-covid/COVID_Autoimmune_AllPracs20220311110715.csv", delimiter(comma) varnames(1) clear

drop o_mediinflammatory_bowel_as9 od_mediinflammatory_bowel_as9 ominflammatory_bowel_as9 ompyinflammatory_bowel_as9

gen IndexDate = date(index_date, "YMD")

format IndexDate %tdDD/NN/CCYY

count

merge m:1 practice_patient_id IndexDate using "/rds/projects/s/subramaa-covid/ConsultationData_ToMerge.dta" , force

drop _merge

merge m:1 practice_patient_id IndexDate using "/rds/projects/s/subramaa-covid/ibd.dta" , force

drop _merge
************************Data Cleaning*******************************************

generate standarddate1 = date(standard_date1, "YMD") 
format standarddate1 %tdDD/NN/CCYY

generate CollectionDate = date(collection_date, "YMD")
format CollectionDate %tdDD/NN/CCYY

generate StartDate = date(start_date, "YMD") 
format StartDate %tdDD/NN/CCYY

generate EndDate = date(end_date, "YMD") 
format EndDate %tdDD/NN/CCYY

generate DeathDate = date(death_date, "YMD")									 
format DeathDate %tdDD/NN/CCYY			

generate RegistrationDate = date(registration_date, "YMD")
format RegistrationDate %tdDD/NN/CCYY

generate TransferDate = date(transfer_date, "YMD")
format TransferDate %tdDD/NN/CCYY

generate ExpConfCovidDate = date(exposedconfirmedcovid_aurum_date, "YMD")
format ExpConfCovidDate %tdDD/NN/CCYY

generate YearofBirth = date(year_of_birth, "YMD")
format YearofBirth %tdDD/NN/CCYY

label define ethnicityorder 1 WHITE 2 SOUTH_ASIAN 3 BLACK 4 MIXED_RACE 5 OTHERS 6 MISSING
encode ethnicity, gen(Ethnicity) label(ethnicityorder)



**Death status
gen death =0
replace death =1 if DeathDate!=.

**Temporality
count if CollectionDate-IndexDate < 0
count if DeathDate-IndexDate < 0 
count if IndexDate-RegistrationDate < 0 
count if ExpConfCovidDate-IndexDate <0

**labelling sex
gen gender = 1 if sex == "M"
replace gender = 2 if sex == "F"
label define Sexlab 2 "Female" 1 "Male"
label value gender Sexlabel 
drop sex 
recode gender (1=1 "Men") (2=2 "Women"), gen(COV_sex)
drop gender
tab COV_sex

**labelling age
gen long age = (IndexDate - YearofBirth)/ 365.25
sum age, detail
recode age (min/17.9=1 "<18 years")(16/29.9=2 "18 - 30 years") (30/39.9=3 "30 - 40 years") (40/49.9=4 "40 - 50 years") (50/59.9=5 "50 - 60 years") (60/69.9=6 "60 - 70 years") (70/max=7 ">70 years"), gen (agecat)
label var agecat "age categories (grouped)"
tab agecat

**labelling BMI
misstable summarize valuemass
replace valuemass = . if valuemass < 14 | valuemass > 75 
misstable summarize valuemass
recode valuemass (min/18.4999 = 1 "Normal Weight(18.5-25)") (18.5/24.999 = 2 "Underweight (<18.5)") (25/29.999 = 3 "Overweight(25-30)")(30/max = 4 "Obese(>30)") (. = 5 "missing weight value"), gen(BMIcat)
label var BMIcat "BMI categories at baseline (grouped)"
tab BMIcat

**labellingsmoking
gen D_CurSmoker = date(bd_medicurrent_smoker0, "YMD")
gen D_ExSmoker = date(bd_mediex_smoker2, "YMD")
gen D_NeverSmoker = date(bd_medinever_smoked1, "YMD")
gen D_NonSmoker = date(bd_medismokingstatus_nonsmoker3, "YMD")
format D_CurSmoker D_ExSmoker D_NeverSmoker D_NonSmoker %tdDD/NN/CCYY

gen D_Smoking = max(D_CurSmoker, D_ExSmoker, D_NeverSmoker)
gen Smoker = .
replace Smoker = 1 if D_NeverSmoker == D_Smoking & D_Smoking != .
replace Smoker = 2 if D_ExSmoker == D_Smoking & D_Smoking != .
replace Smoker = 3 if D_CurSmoker == D_Smoking & D_Smoking != .

replace Smoker = 2 if Smoker == 1 & (D_ExSmoker != . | D_CurSmoker != .)
replace Smoker = 2 if Smoker == 3 & D_NonSmoker > D_Smoking & D_Smoking != . & D_NonSmoker != .
recode Smoker (1 = 1 "Never Smoked") (2 = 2 "Ex-Smoker")(1 = 3 "Current Smoker")(. = 4 "Smoking data missing"), gen(COV_SmokingStatus)
tab COV_SmokingStatus
//If a smoking record present, then non-smoker gets replaced by ex-smoker 
//If a non-smoking record was the latest, then replace current smoker by ex-smoker

**Renaming Data
rename *_code* *
rename *_us* *
rename bdhydralazine15 bdhydralazine_drug

**Outcome cleaning
rename *_mumpred* *
rename *_aurum2* *
rename *_mm* *
rename *_birm* *
rename *_bham* *
rename od_meditype1dm_11_3_2 od_mediType1DM
foreach var in od_mediType1DM  od_medisle od_medimyasthenia_gravis od_mediautoimmunethyroid od_medisjogrenssyndrome od_medivitiligo od_medirheumatoidarthritis od_medipsoriasis od_mediperniciousanaemia od_mediinflammatory_bowel_as11 od_medicoeliac_disease{
local newname = substr("`var'",8, .)
gen O_`newname' = 0
replace O_`newname' = 1 if `var' != ""
}

foreach var in  od_mediType1DM  od_medisle od_medimyasthenia_gravis od_mediautoimmunethyroid od_medisjogrenssyndrome od_medivitiligo od_medirheumatoidarthritis od_medipsoriasis od_mediperniciousanaemia od_mediinflammatory_bowel_as11 od_medicoeliac_disease {
local newname = substr("`var'", 8, . )
gen OD_`newname' = date(`var' ,"YMD")
format OD_`newname' %tdDD/NN/CCYY	
gen ED_`newname' = min(CollectionDate , TransferDate , DeathDate , OD_`newname', td(22/03/2022)) 
format ED_`newname' %tdDD/NN/CCYY 
gen PY_`newname' = (ED_`newname' - IndexDate)/365.25 
replace PY_`newname' = 0.0001 if PY_`newname' == 0
}

** forming composite outcome
gen O_AID = 0
replace O_AID = 1 if O_Type1DM == 1 | O_sle == 1 | O_myasthenia_gravis == 1 | O_autoimmunethyroid == 1 |  O_sjogrenssyndrome == 1 | O_vitiligo == 1 | O_rheumatoidarthritis == 1 | O_psoriasis == 1 | O_perniciousanaemia == 1 | O_inflammatory_bowel_as11 ==1 | O_coeliac_disease == 1
gen OD_AID = min(OD_Type1DM, OD_sle, OD_myasthenia_gravis, OD_autoimmunethyroid, OD_sjogrenssyndrome, OD_vitiligo, OD_rheumatoidarthritis, OD_psoriasis, OD_perniciousanaemia, OD_inflammatory_bowel_as11, OD_coeliac_disease)
format OD_AID %tdDD/NN/CCYY	
gen ED_AID = min(CollectionDate , TransferDate , DeathDate , OD_AID, td(22/03/2022)) 
format ED_AID %tdDD/NN/CCYY 
gen PY_AID = (ED_AID - IndexDate)/365.25 
replace PY_AID = 0.0001 if PY_AID == 0


//B --> Baseline record of the condition 
//BD __> Data of recording of the baseline condition of interest before study entry 
//O --> Outcome record of the condition  
//OD ---> Data of recording of the outcome condition of interest after study entry 
//ED ---> Patient Exit Date for the condition of interest 
//PY ---> person Years calculated for the patient for the outcome of interest

** forming composite baseline infection 
gen B_Infection = 0
replace B_Infection = 1 if bmhepatitis_c ==1 | bminfluenzaa ==1| bmrubella ==1 | bmcmv ==1 | bmmeasles ==1 | bmhtlv ==1 | bmparvovirus ==1 | bmebv ==1 | bmhhv6==1 

** forming composite baseline medication
gen B_Medication = 0
replace B_Medication =1 if bdprocainamide_drug ==1 | bdquinidine_drug ==1 | bdisoniazid_drug ==1 |  bdhydralazine_drug ==1

**********************************Results***************************************

**baseline tables 
 
bysort exposed : tab B_Infection
bysort exposed : tab bmhepatitis_c
bysort exposed : tab bminfluenzaa
bysort exposed : tab bmrubella
bysort exposed : tab bmcmv
bysort exposed : tab bmmeasles
bysort exposed : tab bmhtlv
bysort exposed : tab bmparvovirus
bysort exposed : tab bmebv
bysort exposed : tab bmhhv6
bysort exposed : tab bmgastricreflux_tlc6

bysort exposed : tab B_Medication
bysort exposed : tab bdhydralazine_drug 
bysort exposed : tab bdprocainamide_drug
bysort exposed : tab bdquinidine_drug
bysort exposed : tab bdisoniazid_drug

bysort exposed : tab COV_sex
bysort exposed : sum age, detail
bysort exposed : tab agecat
bysort exposed : sum valuemass
bysort exposed : tab BMIcat
bysort exposed : tab COV_SmokingStatus
bysort exposed : tab ethnicity

bysort exposed : sum PY_AID, detail
bysort exposed: tab O_AID
ir O_AID exposed PY_AID

// Cox Analysis
stset PY_AID, failure(O_AID==1)
stcox exposed

stset PY_AID, failure(O_AID==1)
stcox exposed i.agecat i.BMIcat i.COV_SmokingStatus i.COV_sex B_Infection B_Medication i.Ethnicity 

stset PY_AID, failure(O_AID==1)
stcox exposed, hr strata(exposed_control_group)

//Subgroup Analysis
stset PY_AID, failure(O_AID==1)
stcox i.agecat i.BMIcat i.COV_SmokingStatus i.COV_sex B_Infection B_Medication i.Ethnicity if exposed == 1

//Individual outcomes analysis
stset PY_Type1DM, failure(O_Type1DM==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_Type1DM
ir O_Type1DM exposed PY_Type1DM

stset PY_sle, failure(O_sle==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_sle
ir O_sle exposed PY_sle

stset PY_myasthenia_gravis, failure(O_myasthenia_gravis==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_myasthenia_gravis
ir O_myasthenia_gravis exposed PY_myasthenia_gravis


stset PY_autoimmunethyroid, failure(O_autoimmunethyroid==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_autoimmunethyroid
ir O_autoimmunethyroid exposed PY_autoimmunethyroid

stset PY_sjogrenssyndrome, failure(O_sjogrenssyndrome==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_sjogrenssyndrome
ir O_sjogrenssyndrome exposed PY_sjogrenssyndrome

stset PY_vitiligo, failure(O_vitiligo==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_vitiligo
ir O_vitiligo exposed PY_vitiligo

stset PY_rheumatoidarthritis, failure(O_rheumatoidarthritis==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_rheumatoidarthritis
ir O_rheumatoidarthritis exposed PY_rheumatoidarthritis

stset PY_psoriasis, failure(O_psoriasis==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_psoriasis
ir O_psoriasis exposed PY_psoriasis

stset PY_perniciousanaemia, failure(O_perniciousanaemia==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_perniciousanaemia
ir O_perniciousanaemia exposed PY_perniciousanaemia

stset PY_inflammatory_bowel_as11, failure(O_inflammatory_bowel==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_inflammatory_bowel
ir O_inflammatory_bowel_as11 exposed PY_inflammatory_bowel_as11

stset PY_coeliac_disease, failure(O_coeliac_disease==1)
stcox exposed
stcox exposed agecat BMIcat COV_SmokingStatus COV_sex B_Infection B_Medication Ethnicity
bysort exposed: tab O_coeliac_disease
ir O_coeliac_disease exposed PY_coeliac_disease



import excel "Z:\Forest Plot.xlsx", sheet("Sheet1") firstrow
ssc install metan
gen logadjustedHR = ln(adjustedHR)
gen logupperCI = ln(upperCI)
gen loglowerCI = ln(lowerCI)
metan logadjustedHR loglowerCI logupperCI, lcols (Outcomes)eform xscale(range(0 3)) xlabel(0.01, 0.1, 0.5, 1,2,3) null(1) nobox nooverall nowt effect(aHR) textsize(100) astext(50) pointopt(mcolor (red) msize(1)) graphregion(color(white)) bgcolor(white) ysize(1) xsize(2)
