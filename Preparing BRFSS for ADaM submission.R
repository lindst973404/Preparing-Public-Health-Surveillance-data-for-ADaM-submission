library(tidyverse)
library(haven)
library(dplyr)
library(janitor)
library(survey)
library(gt)
library(tibble)
options(survey.lonely.psu = "adjust")

#Bringing in dataset
#Modifying it for session
brfss <- read_xpt("LLCP2022.XPT")
names(brfss) <- make.names(names(brfss), unique = TRUE)

#Subsetting it for capacity purposes
brfss2022 <- brfss %>%
  select(X_STATE, X_SEX, X_AGE_G, X_RACE1, X_EDUCAG, HAVARTH4, PHYSHLTH, X_LLCPWT2, X_STSTR, X_PSU) 

#Creating .RData version for storage
save(brfss2022, file = "brfss2022.RData")
load("brfss2022.RData")

##########################################################################

#Creating ADaM Dataset 

###########################################################################
ADaM_brfss <- brfss2022 %>%
  mutate(
    USUBJID = row_number(),
      # Chronic condition flag
    CHRONIC_FLAG = case_when(
      HAVARTH4 == 1    ~ 1,
      !is.na(HAVARTH4) ~ 0
    ),
      # Physical health not good for 15+ days
    PHYSBAD30 = case_when(
      PHYSHLTH >= 15 & PHYSHLTH <= 30 ~ 1,
      !is.na(PHYSHLTH)                ~ 0
    ),
      # Age group flag (65+)
    AGEGRP = case_when(
      X_AGE_G >= 1 & X_AGE_G <= 5 ~ 0,
      X_AGE_G >= 6                ~ 1
    ),
      # Analysis flag
    ANALYSIS_FLAG = if_else(
      !is.na(HAVARTH4) & !is.na(PHYSHLTH) & !is.na(AGEGRP),
      1, NA_integer_
    )
  ) %>%
  select(USUBJID, CHRONIC_FLAG, PHYSBAD30, AGEGRP, ANALYSIS_FLAG,
         X_LLCPWT2, X_STSTR, X_PSU)

#Checking flags
ADaM_check <- ADaM_brfss %>%
  count(AGEGRP, CHRONIC_FLAG, PHYSBAD30) %>%
  complete(AGEGRP, CHRONIC_FLAG, PHYSBAD30, fill = list(n = 0)) %>%
  mutate(
    Frequency = n,
    Percent = round(100 * Frequency / sum(Frequency), 2),
    across(c(AGEGRP, CHRONIC_FLAG, PHYSBAD30), 
           ~ifelse(is.na(.), ".", as.character(.))
          )
    ) %>%
  select(AGEGRP, CHRONIC_FLAG, PHYSBAD30, Frequency, Percent)

print(ADaM_check)

##########################################################################

#Dashboard ready weighted 2x2 table 

###########################################################################
#Survey weights 
#Modifying to factor 
ADaM_brfss <- ADaM_brfss %>%
  filter(!is.na(CHRONIC_FLAG), !is.na(PHYSBAD30)) %>%
  mutate(
    CHRONIC_FLAG = factor(CHRONIC_FLAG),
    PHYSBAD30 = factor(PHYSBAD30)
  )

#Weight function for overall
svy_design <- svydesign(
  id = ~X_PSU,
  strata = ~X_STSTR,
  weights = ~X_LLCPWT2,
  data = ADaM_brfss,
  nest = TRUE
)

#Subset to 18-64 years old
svy_subset <- subset(svy_design, AGEGRP == 0)
svy_table <- svytable(~CHRONIC_FLAG + PHYSBAD30, design = svy_subset)

#Generating Row percentages for 18-64 years old group
svy_prop <- prop.table(svy_table, margin = 1)  
svy_rowpercent <- round(100 * svy_prop, 4)

#Generating SE of row percentages for 18-64 years old group
svySE_design <- svyby(
  ~PHYSBAD30,
  ~CHRONIC_FLAG,
  svy_subset,
  svymean,
  vartype = "se"
)

# Extract SEs into a new table
svy_propSE <- svySE_design %>%
  select(CHRONIC_FLAG, se.PHYSBAD300, se.PHYSBAD301) %>%
  rename(
    SE_PHYSBAD30_0 = se.PHYSBAD300,
    SE_PHYSBAD30_1 = se.PHYSBAD301
  ) %>%
  mutate(
    SE_PHYSBAD30_0 = 100 * SE_PHYSBAD30_0,
    SE_PHYSBAD30_1 = 100 * SE_PHYSBAD30_1
  )

#Checking printout of weighted information for 18-64 group
#print(svy_table)
#print(svy_rowpercent)
#print(svy_propSE)

#For ages 65 and over
svy_subset2 <- subset(svy_design, AGEGRP == 1)

#Generating Row percentages for 65 and over group
svy_table2 <- svytable(~CHRONIC_FLAG + PHYSBAD30, design = svy_subset2)

#Generating Row percentages for 65 and over group
svy_prop2 <- prop.table(svy_table2, margin = 1)  
svy_rowpercent2 <- round(100 * svy_prop2, 4)

#Generating SE of row percentages for 65 and over group
svySE2_design <- svyby(
  ~PHYSBAD30,
  ~CHRONIC_FLAG,
  svy_subset2,
  svymean,
  vartype = "se"
)

# Extract SEs into a new table
svy_propSE2 <- svySE2_design %>%
  select(CHRONIC_FLAG, se.PHYSBAD300, se.PHYSBAD301) %>%
  rename(
    SE_PHYSBAD30_0 = se.PHYSBAD300,
    SE_PHYSBAD30_1 = se.PHYSBAD301
  ) %>%
  mutate(
    SE_PHYSBAD30_0 = 100 * SE_PHYSBAD30_0,
    SE_PHYSBAD30_1 = 100 * SE_PHYSBAD30_1
  )

#Checking printout of weighted information for 65 and over group
#print(svy_table2)
#print(svy_rowpercent2)
#print(svy_propSE2)

#Combining to make one table
#Convert weighted frequency tables to data frames
freq1 <- as.data.frame.table(svy_table)
freq2 <- as.data.frame.table(svy_table2)

#Add AGEGRP labels
freq1$AGEGRP <- "18-64"
freq2$AGEGRP <- "65+"

#Column labels
names(freq1) <- c("CHRONIC_FLAG", "PHYSBAD30", "WgtFreq", "AGEGRP")
names(freq2) <- c("CHRONIC_FLAG", "PHYSBAD30", "WgtFreq", "AGEGRP")

#Keeps row order consistent across programs
freq1 <- freq1[c(1, 3, 2, 4), ]
freq2 <- freq2[c(1, 3, 2, 4), ]

#Weighted Row percentages
rowpct1 <- as.data.frame(svy_rowpercent)
rowpct2 <- as.data.frame(svy_rowpercent2)

#Add AGEGRP labels
rowpct1$AGEGRP <- "18-64"
rowpct2$AGEGRP <- "65+"

#Keeps row order consistent across programs
rowpct1 <- rowpct1[c(1, 3, 2, 4), ]
rowpct2 <- rowpct2[c(1, 3, 2, 4), ]

#Column labels
names(rowpct1) <- c("CHRONIC_FLAG", "PHYSBAD30", "WgtRowPerc", "AGEGRP")
names(rowpct2) <- c("CHRONIC_FLAG", "PHYSBAD30", "WgtRowPerc", "AGEGRP")

#Weighted Row SE percentages
#Since row # will be the same from PHYSBAD30 = 1 and PHYSBAD30 = 0
svy_propSE1d <- rbind(svy_propSE, svy_propSE)
svy_propSE1d <- svy_propSE1d %>% 
  select(-SE_PHYSBAD30_1)
rownames(svy_propSE1d) <- NULL
svy_propSE2d <- rbind(svy_propSE2, svy_propSE2)
svy_propSE2d <- svy_propSE2d %>% 
  select(-SE_PHYSBAD30_1)
rownames(svy_propSE2d) <- NULL

#Includes Arthritis groups as factors
svy_propSE1d$PHYSBAD30 <- factor(c(0, 0, 1, 1))
svy_propSE2d$PHYSBAD30 <- factor(c(0, 0, 1, 1))

#Add AGEGRP labels
svy_propSE1d$AGEGRP <- "18-64"
svy_propSE2d$AGEGRP <- "65+"

#Keeps row order consistent across programs
svy_propSE1d <- svy_propSE1d[c(1, 3, 2, 4), ]
svy_propSE2d <- svy_propSE2d[c(1, 3, 2, 4), ]

#Keeps col order consistent across programs
se1 <- svy_propSE1d %>%
  select(CHRONIC_FLAG, PHYSBAD30, SE_PHYSBAD30_0, AGEGRP)
se2 <- svy_propSE2d %>%
  select(CHRONIC_FLAG, PHYSBAD30, SE_PHYSBAD30_0, AGEGRP)

#Column labels
names(se1) <- c("CHRONIC_FLAG", "PHYSBAD30", "WgtRowPercSE", "AGEGRP")
names(se2) <- c("CHRONIC_FLAG", "PHYSBAD30", "WgtRowPercSE", "AGEGRP")

#Combine tables
#Age 18-64
agr0_full <- freq1 %>%
  left_join(rowpct1, by = c("CHRONIC_FLAG", "PHYSBAD30", "AGEGRP")) %>%
  left_join(se1, by = c("CHRONIC_FLAG", "PHYSBAD30", "AGEGRP"))

agr0_full <- agr0_full %>%
  select(AGEGRP, CHRONIC_FLAG, PHYSBAD30, WgtFreq, WgtRowPerc, WgtRowPercSE)

#Age 65+
agr1_full <- freq2 %>%
  left_join(rowpct2, by = c("CHRONIC_FLAG", "PHYSBAD30", "AGEGRP")) %>%
  left_join(se2, by = c("CHRONIC_FLAG", "PHYSBAD30", "AGEGRP"))

agr1_full <- agr1_full %>%
  select(AGEGRP, CHRONIC_FLAG, PHYSBAD30, WgtFreq, WgtRowPerc, WgtRowPercSE)

#Combining cleaned tables
final_dashboard <- bind_rows(agr0_full, agr1_full)

#Making a mock TLF
tlf_data <- final_dashboard %>%
  mutate (
    `Age Group` = factor(AGEGRP, levels = c("18-64", "65+"), 
                         labels = c("18 to 64", "65 and over")),
    `Chronic Condition` = factor(CHRONIC_FLAG, levels = c(0, 1), 
                                 labels = c("No arthritis", "Arthritis")),
    `Poor Physical Health (≥15 Days)` = factor(PHYSBAD30, levels = c(0, 1), 
                                  labels = c("Good physical health", "Not good physical health")),
    `Row %` = round(WgtRowPerc, 4),
    `SE of Row %` = round(WgtRowPercSE, 4)
  ) %>%
  select(`Age Group`, `Chronic Condition`, `Poor Physical Health (≥15 Days)`, `Row %`, `SE of Row %`) %>%
  arrange(`Age Group`, desc(`Chronic Condition`), desc(`Poor Physical Health (≥15 Days)`) ) %>%
  group_by(`Age Group`, `Chronic Condition`) %>%
  mutate(`Chronic Condition` = as.character(`Chronic Condition`)) %>%
  mutate(`Chronic Condition` = ifelse(row_number() == 1, `Chronic Condition`, "")) %>%
  ungroup()

tlf_table <- tlf_data %>%
  gt(groupname_col = "Age Group") %>%
  tab_header(
    title = "Table 1: 2×2 Summary of Arthritis and Poor Physical Health by Age Group",
    subtitle = "Weighted Row percentages and standard errors"
  ) %>%
  cols_label(
    `Chronic Condition` = "Chronic Condition",
    `Poor Physical Health (≥15 Days)` = "Poor Physical Health (≥15 Days)",
    `Row %` = "Row %",
    `SE of Row %` = "SE of Row %"
  ) %>%
  fmt_number(
    columns = c(`Row %`, `SE of Row %`),
    decimals = 2
  ) %>%
  tab_options(
    table.font.size = "small",
    heading.align = "left",
    column_labels.font.weight = "bold"
  )

#Building metadata alike define.xml

define_meta <- tribble(
  ~Variable,       ~Label,                                      ~Type,     ~Controlled_Terms,                    ~Source,                   ~Notes,
  "USUBJID",       "Unique Subject Identifier",                 "Integer", NA,                                   "Simulated by _N_",       "row_number()",
  "CHRONIC_FLAG",  "Chronic Condition Indicator",               "Integer", "0=No arthritis; 1=Arthritis",         "BRFSS 2022: HAVARTH",   "HAVARTH4 == 1 → 1; else 0",
  "PHYSBAD30",     "Poor Physical Health (≥15 Days)",           "Integer", "0=Good; 1=Not good",                  "BRFSS 2022: PHYSHLTH",   "PHYSHLTH ≥15 & ≤30 → 1; else 0",
  "AGEGRP",        "Age Group (65+ Flag)",                      "Integer", "0=18–64; 1=65+",                      "BRFSS 2022: X_AGE_G",    "X_AGE_G 1–5 → 0; ≥6 → 1",
  "ANALYSIS_FLAG", "Analysis Inclusion Flag",                   "Integer", "1=Included",                          "Derived",                "Non-missing HAVARTH4, PHYSHLTH, AGEGRP",
  "X_LLCPWT2",     "Final Weight",                              "Double",  NA,                                   "Collected",               "Used for weighting",
  "X_STSTR",       "Stratum Identifier",                        "Integer", NA,                                   "Collected",               "Required for survey design",
  "X_PSU",         "Primary Sampling Unit",                     "Integer", NA,                                   "Collected",               "Required for survey design"
  )

define_meta %>%
  gt() %>%
  tab_header(
    title = "Mock Define.xml: Variable-Level Metadata",
    subtitle = "ADaM-style metadata for BRFSS2022-derived dataset"
  )

