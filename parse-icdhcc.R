# Generate ICD to HCC Crosswalks from CMS
# The ICD/HCC mappings were obtained from CMS (https://www.cms.gov/Medicare/Health-Plans/MedicareAdvtgSpecRateStats/Risk-Adjustors.html).
# Due to the complex file structure of the original data (many nested zip files), they have
# been organized in the folder data/icd_hcc_rawdata/
# This script creates an .RData file containing crosswalks, hierarchy rules, and labels for CC and HCCs

# Import the ICD9 and ICD10 HCC crosswalks, one per year, into a list of dataframes
icd9cc <- apply(data.frame(paste("data/icdhcc_rawdata/icd9/",list.files("data/icdhcc_rawdata/icd9/"),sep="")), 1, FUN=read.fwf, width=c(7,4), header=F, stringsAsFactors=F)
icd10cc <- apply(data.frame(paste("data/icdhcc_rawdata/icd10/",list.files("data/icdhcc_rawdata/icd10/"),sep="")), 1, FUN=read.fwf, width=c(7,4), header=F, stringsAsFactors=F)

# Create a vector of year names based on the file names in the icd folders
years <- list()
years$icd9 <- as.numeric(substr(list.files("data/icdhcc_rawdata/icd9/"), 0,4))
years$icd10 <- as.numeric(substr(list.files("data/icdhcc_rawdata/icd10/"), 0,4))

# assign year to each dataframe within the list of dataframes
icd9cc <- mapply(cbind, icd9cc, "year" = years$icd9, SIMPLIFY=F)
icd10cc <- mapply(cbind, icd10cc, "year" = years$icd10, SIMPLIFY=F)

# Row bind icd9 and icd10 from different years into despective dataframes
icd9cc <- do.call(rbind, icd9cc)
icd10cc <- do.call(rbind, icd10cc)

# Assign ICD version (9 or 10) and combine into single dataframe
icd9cc$icdversion <- 9
icd10cc$icdversion <- 10
icdcc <- rbind(icd9cc, icd10cc)

rm(icd9cc, icd10cc, years)

# add variable names
colnames(icdcc) <- c("icd_code", "cc", "year", "icdversion")

# Remove whitespace from codes
icdcc$icd_code <- trimws(icdcc$icd_code)
icdcc$cc <- trimws(icdcc$cc)

#############################################
######### Edit ICD9/10s
#############################################

# Per CMS instructions, certain ICD9s have to be manually assigned additional CCs

# icd9 40403, 40413, and 40493 are assigned to CC 80 in 2007-2012
extracodes <- list()
extracodes$e1 <- c("40403", "40413", "40493")
extracodes$e1 <- expand.grid(extracodes$e1, "80", 2007:2012, 9, stringsAsFactors = F)

# icd9 40401, 40403, 40411, 40413, 40491, 40493 are assigned to CC85 in 2013
extracodes$e2 <- c("40401","40403","40411","40413","40491","40493")
extracodes$e2 <- expand.grid(extracodes$e2, "85", 2013, 9, stringsAsFactors = F)

# icd9 40403, 40413, 40493 are assigned to CC85 in 2014-2015
extracodes$e3 <- c("40403","40413","40493")
extracodes$e3 <- expand.grid(extracodes$e3, "85", 2014:2015, 9, stringsAsFactors = F)

# icd9 3572 and 36202 are assigned to CC18 in 2013
extracodes$e4 <- c("3572", "36202")
extracodes$e4 <- expand.grid(extracodes$e4, "18", 2013, 9, stringsAsFactors = F)

# icd9 36202 is assigned to CC18 in 2014-2015
extracodes$e5 <- "36202"
extracodes$e5 <- expand.grid(extracodes$e5, "18", 2014:2015, 9, stringsAsFactors = F)

# combine into one DF
extracodes <- do.call(rbind, extracodes)

# add variable names
colnames(extracodes) <- c("icd_code", "cc", "year", "icdversion")

# combine with full icdcc listing
icdcc <- rbind(icdcc, extracodes)
rm(extracodes)

#############################################
######### Import Labels
#############################################
# Import HCC labels from all years
labels <- apply(data.frame(paste("data/icdhcc_rawdata/labels/",list.files("data/icdhcc_rawdata/labels/"),sep="")), 1, FUN=readLines)

# Convert a single dataframe
labels <- lapply(labels, as.data.frame, stringsAsFactors=F)
labels <- do.call(rbind, labels)

# Extract HCC numbers
hccnum <- str_match(labels[,1], "HCC([:digit:]*)")[,2]

# Extract HCC names
hccname <- substr(labels[,1], regexpr("=", labels[,1])+2, nchar(labels[,1])-1)

# Combine numbers and names into dataframe of labels
labels <- data.frame(hccnum, hccname, stringsAsFactors = F, row.names = NULL)
rm(hccnum, hccname)

# Drop lines with NA/out of range HCC numbers
labels$hccnum <- as.numeric(labels$hccnum)
labels <- labels[!is.na(labels$hccnum),]

# Drop duplicated HCC numbers
labels <- labels[!duplicated(labels$hccnum),]

# Remove whitespace from hccnames
labels$hccname <- trimws(labels$hccname)

# Order in ascending order of HCC number
labels <- labels[order(labels$hccnum),]

#############################################
######### Define Hierarchy
#############################################

# import raw hierarchy files from CMS
hierarchy <- apply(data.frame(paste("data/icdhcc_rawdata/hierarchy/",list.files("data/icdhcc_rawdata/hierarchy/"),sep="")), 1, FUN=readLines)

# Create a vector of year names based on the file names in the icd folders
years <- substr(list.files("data/icdhcc_rawdata/hierarchy/"), 0,4)

# Add year variable to each dataframe
hierarchy <- mapply(cbind, hierarchy, "year" = years, SIMPLIFY=F)
rm(years)

# convert each item in the list of hierarchy objects into a data.frame and combine into a single DF
hierarchy <- lapply(hierarchy, as.data.frame, stringsAsFactors=F)
hierarchy <- do.call(rbind, hierarchy)

# convert years to numeric
hierarchy$year <- as.numeric(hierarchy$year)

# only keep the lines that are logical hierarchy statements (removes comments, empty lines, additional code) and rename variable
hierarchy <- hierarchy[grepl("if hcc|%SET0", hierarchy$V1),]
colnames(hierarchy)[1] <- "condition"

# Extract the HCC that is used in the if condition statement
hierarchy$ifcc <- as.numeric(str_extract(hierarchy$condition, "(?<=hcc)([0-9]*)|(?<=CC\\=)([0-9]*)"))

# Extract the HCCs that should be set to zero if the above condition is met
todrop <- str_extract(hierarchy$condition, 
                      "(?<=i\\=)([:print:]*)(?=;hcc)|(?<=STR\\()([:print:]*)(?= \\)\\);)")

# convert it to a dataframe and bind it with the original hierarchy data
todrop <- as.data.frame(str_split_fixed(todrop, ",", n=10), stringsAsFactors = F)
# convert to numeric
todrop <- as.data.frame(lapply(todrop, as.numeric))

# combine CC requirements with CCs to zero
hierarchy <- cbind(hierarchy[,c("year", "ifcc")], todrop)
rm(todrop)

# remove columns that are completely NA
# intially, set up hierchy to allow for up to 10 possible conditions, now will remove extra columns
# In current data, maximum is 6 conditions to zero, however leaving room in case these are expanded in the future
hierarchy <- hierarchy[,colSums(is.na(hierarchy))<nrow(hierarchy)]

#############################################
######### save data files
#############################################
save(labels, hierarchy, icdcc, file="data/icd_hcc.RData")