# Required Variables and Sample Construction Guide

To support the implementation of Section 2.2 of the stats_instructions_v3 document, the following variable extract from the CCHS 2010 and 2014 data dictionaries is provided in a plain-text format.

---

## 1. Primary Outcome Variable: Total Days Absent (All Health Reasons)

This variable must be constructed by summing the workdays missed across the following categories in the Loss of Production (LOP) module. Variable names are identical for both the 2010-2011 and 2013-2014 cycles.

| Health Reason | Variable Name | Description |
|---------------|---------------|-------------|
| Chronic Condition | `LOPG040` | Number of work days lost due to chronic condition |
| Injuries | `LOPG070` | Number of work days missed due to injury |
| Cold | `LOPG082` | Number of work days missed due to a cold |
| Flu / Influenza | `LOPG083` | Number of work days missed due to flu or influenza |
| Stomach Flu | `LOPG084` | Number of work days missed due to stomach flu |
| Respiratory Infection | `LOPG085` | Number of work days missed due to respiratory infection |
| Other Infectious Disease | `LOPG086` | Number of work days missed due to other infectious disease |
| Other Phys./Mental Health | `LOPG100` | Work days missed related to physical or mental health |

**Implementation Note**: The total count for each respondent is the mathematical sum of these values. Respondents reporting 0 absences across all reasons should be assigned a value of 0.

---

## 2. Sensitivity Outcome Variable: Days Absent (Chronic Conditions Only)

This restricted outcome is required for sensitivity analysis as specified in the instructions.

- **Variable Name (2011 & 2014)**: `LOPG040`
- **Description**: Number of work days lost due to chronic condition (Grouped)

---

## 3. Variables for Sample Construction (Inclusion/Exclusion)

These variables are necessary to filter the dataset to the analytical sample defined in Section 3.1.

| Variable Purpose | Variable Name | Description |
|------------------|---------------|-------------|
| Age Identifier | `DHHGAGE` | Used to include only respondents aged 15 to 75 |
| Employment Status | `LOP_015` | Used to include only those employed in the past three months |
| Proxy Indicator | `ADM_PRX` | Used to exclude respondents where a proxy completed the component; exclude if code = 1 |

---

## 4. Survey Design Variables

These variables are required to account for the complex sampling design during statistical modeling.

| Variable Purpose | Variable Name | Description |
|------------------|---------------|-------------|
| Master Survey Weight | `WTS_M` | Referred to in instructions as `WGHT_FINAL` |
| Health Region / Strata | `GEODPMF` | Used for identifying strata and cluster components |
| Bootstrap Weights | Available in CCHS sampling files | 500 replicates required per cycle |