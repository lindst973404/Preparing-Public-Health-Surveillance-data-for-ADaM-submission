***********************************************************************************************************************
Title: “Simulated ADaM Dataset Using BRFSS 2022"
Subtitle: "Arthritis and Physical Health Burden”
Author: Lindsay Trujillo, PhD, MPH
LinkedIn: https://www.linkedin.com/in/lindsay-trujillo/ 
GitHub: https://www.github.com/lindst973404

ADaM (Analysis Data Model) is a standardized framework used in clinical research to create analysis-ready datasets that are 
traceable, reproducible, and aligned with regulatory expectations. However, throughout my career these practices have
also been conducted for disease and surveillance programs but often under different terms. Regardless, the intent 
is to create a clean, curated analytic file from raw/semi-processed data where every derived variable is documented, every
inclusion criteria is clear, and every table or figure can be traced back to its source with the most minimal difficulty 
as possible. 

To demonstrate how this aligns within public health data, this program will use BRFSS 2022 to build an ADaM-style analysis
dataset, applying derived flags, age stratification, and complex survey weighting. In addition, this example will 
demonstrate how to build tables intended for dashboards as well as a stand-alone table (TLF within the clinical realm).

Finally, this program will also show how to create meta-data analogus to what would be expected from an ADaM dataset, which
is the define.xml file. 
***********************************************************************************************************************;
***********************************************************************************************************************
Objective: 

* To determine differences of between self-reported arthritis status and poor physical health (defined as ≥15 days of 
poor physical health in the past 30 days), using BRFSS 2022 data and complex survey design weights.

Note: Due to computing capacity, BRFSS 2022 was subsetted to specific variables before loading to work enviornment. 

***********************************************************************************************************************;
*Building an ADaM dataset;
data ADaM_brfss;
  set brfss.brfss2022;

  USUBJID = _N_;

*Making Chronic condition flag;
	   if HAVARTH4 =  1 then CHRONIC_FLAG = 1;
  else if HAVARTH4 ne . then CHRONIC_FLAG = 0;


*Flag for physical health not good for 15 days or more;
  	   if 15 <= PHYSHLTH <= 30 then PHYSBAD30 = 1;
  else if       PHYSHLTH ne .  then PHYSBAD30 = 0;

*Age cut-off for 65 years and older;
  	   if 1 <= X_AGE_G <= 5 then AGEGRP = 0;
  else if      X_AGE_G >= 6 then AGEGRP = 1;

*Analysis flag;
  if HAVARTH4 ne . and PHYSHLTH ne . and AGEGRP ne . then ANALYSIS_FLAG = 1;
  

keep USUBJID CHRONIC_FLAG PHYSBAD30 AGEGRP ANALYSIS_FLAG X_LLCPWT2 X_STSTR X_PSU;
run;

*Checking flags;
proc freq data=ADaM_brfss;
  tables AGEGRP*CHRONIC_FLAG*PHYSBAD30 / list nocum missing;
run;

**************************************************************************************************************************
Weighted 2×2 tables were generated using PROC SURVEYFREQ and formatted into classic contingency tables stratified by age group. 
Row percentages and standard errors were extracted via ODS OUTPUT, simulating a safety signal summary consistent with ADaM-style 
regulatory analysis.
************************************************************************************************************************;
*Building dashboard-ready data;
*For 18-64 year old age group;
ods output CrossTabs=FreqOut_18_64;
proc surveyfreq data=ADaM_brfss;
  where AGEGRP = 0;
  strata X_STSTR;
  cluster X_PSU;
  weight X_LLCPWT2;
  tables CHRONIC_FLAG*PHYSBAD30 / row ;
  title "Weighted 2x2 Table for Age Group 18–64";
run;
ods output close; 
data FreqOut_18_64;
  set FreqOut_18_64;
  AGEGRP = "18-64";
run;
*For 65+ year old age group;
ods output CrossTabs=FreqOut_65plus;
proc surveyfreq data=ADaM_brfss;
  where AGEGRP = 1;
  strata X_STSTR;
  cluster X_PSU;
  weight X_LLCPWT2;
  tables CHRONIC_FLAG*PHYSBAD30 / row ;
  title "Weighted 2x2 Table for Age Group 65+";
run;
ods output close;
data FreqOut_65plus;
  set FreqOut_65plus;
  AGEGRP = "65+";
run;
*Combining the two datasets;
data CombinedFreq;
  set FreqOut_18_64 FreqOut_65plus;
  where CHRONIC_FLAG in (0,1) and PHYSBAD30 in (0,1);
run;

proc print data=CombinedFreq noobs label;
  var AGEGRP CHRONIC_FLAG PHYSBAD30 RowPercent RowStdErr;
  label
    AGEGRP = "Age Group"
    CHRONIC_FLAG = "Chronic Condition"
    PHYSBAD30 = "Poor Physical Health (≥15 Days)"
    RowPercent = "Row %"
    RowStdErr = "SE of Row %";
run;

*********************************************************************************************************
Mock Table was generated using PROC REPORT to summarize weighted row percentages and standard errors 
for arthritis and physical health status, stratified by age group, simulating a safety signal summary consistent 
with ADaM-style regulatory analysis
***************************************************************************************************************;
*Making a mock TLF;
proc format; 
	value age65_fmt
	1 = "65 and over"
	0 = "18 to 64"
	;
	value chr_fmt
	1 = " Arthritis"
	0 = "No arthritis"
	; 
	value phys_fmt
	1 = " Not good physical health"
	0 = "Good physical health"
	;
proc report data=CombinedFreq nowd headline headskip split='*';
  columns AGEGRP CHRONIC_FLAG PHYSBAD30 RowPercent RowStdErr;

  define AGEGRP / group "Age Group";
  define CHRONIC_FLAG / group "Chronic Condition";
  define PHYSBAD30 / group "Poor Physical Health (≥15 Days)";
  define RowPercent / analysis mean format=8.2 "Row %";
  define RowStdErr / analysis mean format=8.2 "SE of Row %";

  title "Table 1: 2×2 Summary of Arthritis and Poor Physical Health by Age Group";
  footnote "Weighted Row percentages and standard errors.";
  format CHRONIC_FLAG chr_fmt. PHYSBAD30 phys_fmt.;
run;

*****************************************************************************************************
“Variable-level metadata was documented in a SAS dataset simulating define.xml structure. Each variable includes labels, 
types, derivation sources, and analytic notes to support traceability and reviewer alignment. Metadata was exported to 
Excel for inclusion in submission-style documentation.”
********************************************************************************************************;
*Building XML-style metadata analogous to define.xml;
data adam_metadata;
  length Variable $32 Label $100 Type $10 Source $100 Notes $100;
  infile datalines dsd dlm='|';
  input Variable $ Label $ Type $ Source $ Notes $;
datalines;
USUBJID|Unique Subject Identifier|Numeric|Simulated via _N_|Used for traceability
CHRONIC_FLAG|Chronic Condition Indicator|Binary|HAVARTH4 = 1|1 = Yes, 0 = No
PHYSBAD30|Poor Physical Health ≥15 Days|Binary|PHYSHLTH >= 15|1 = Yes, 0 = No
AGEGRP|Age Group Bucket|Categorical|X_AGE_G|18–64 vs 65+
ANALYSIS_FLAG|Analysis Population Inclusion|Binary|Non-missing HAVARTH4, PHYSHLTH, AGE|1 = Included
X_LLCPWT2|Final Survey Weight|Numeric|BRFSS 2022|Used for weighting
X_STSTR|Stratification Variable|Categorical|BRFSS 2022|Required for survey design
X_PSU|Primary Sampling Unit|Numeric|BRFSS 2022|Required for survey design
;
run;

proc print data=adam_metadata noobs label;
  title "Variable-Level Metadata for ADaM-BRFSS Dataset";
run;
