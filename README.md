# ICD to HCC

### Generate Medicare Hierchical Condition Categories (HCC) based on ICD codes

### Introduction
- many to many relationship
- ICD9/10 are mapped to Condition Categories (CC), and a hierarchy based on disease severity is applied to the CCs to generate HCCs. For example, if a patient has ICDs (and subsequently CC) for diabetes without complications and diabetes with complications, they are only assigned to the most severe HCC, which in this case would be diabetes with complications.

### Data
The ICD/HCC mappings were obtained from [CMS](https://www.cms.gov/Medicare/Health-Plans/MedicareAdvtgSpecRateStats/Risk-Adjustors.html). CMS provides SAS macros for assigning HCCs and HCC scores based on ICDs, adjusted annually. We have implemented assigning HCCs (but not scores) in R. The original data is available from CMS, or in the github repository at /crosswalks/originalCMS_xw.

Between 2007-2012, there were 70 HCCs (Version 12). In 2013, this was expanded to 87 (Version 20). We use the labels for the more inclusive mappings (post-2013) for all years for consistency. This means that in pre-2013 data 17 HCCs will be structurally zero. 

### Source
[See here](http://htmlpreview.github.io/?https://github.com/anobel/icdtohcc/blob/master/icdtohcc.html)