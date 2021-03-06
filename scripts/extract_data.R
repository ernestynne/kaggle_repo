# ================================================================================================ #
# Description: Extract the train and test datasets and apply basic transformations
# 
# Author: V Benny
#
# ================================================================================================ #


############################### Data Extraction ################################################

# Read files into memory
train <- fread('data/train.csv', stringsAsFactors = FALSE) %>% as.data.frame()
test <- fread('data/test.csv', stringsAsFactors = FALSE)  %>% as.data.frame()
dict <- read.xlsx("data/data_dictionary.xlsx", sheetName = "Codebook")

############################### Data Pre-cleaning ################################################

# Rename id columns in train and test
train <- rename(train, id = train_id)
test <- rename(test, id = test_id)

# Check missingness in training dataset
missing_values <- train %>% 
  summarize_all(funs(sum(is.na(.))/n())) %>% 
  gather(key="feature", value="missing_pct") %>%
  left_join(dict, by = c("feature" = "Column.Name")) %>%
  select(-Values) %>%
  arrange(missing_pct)

# Drop all columns which are completely empty or have no variance at all in train, and retain only these in test.
train <- removeConstantFeatures(train)
test <- test %>% select(one_of(names(train)))

# Assign labels to dataset wherever available for ease of interpreting columns. Use label(train) to get descriptions
train <- assignLabels(train, dict)


# Classify column variables based on types
# Assuming all columns in the codebook are categorical, since these have levels defined. Of course, we lose 
# ordinality when we do this. these can be revisited later on a case-by-case basis. 
# We add all columns of char type to this, and some other columns that look like those are factors.
idcol <- "id"
targetcol <- "is_female"
catcols <- union(union(names(train[, !grepl("Unknown", label(train), fixed = TRUE) & !names(train) %in% c(targetcol)]), 
                 names(train[, sapply(train, is.character)])),
                 c("AA4", "AA7", "AA14", "AA15", "DG8a", "DG8b", "DG8c", "DL4_96", "DL4_99", "DL11", "MT1", "IFI18", "FB13",
                   "DG9a", "DG9b", "DG9c", "G2P2_96", "G2P3_6", "G2P3_8", "G2P3_9","G2P3_11", "G2P3_13", "G2P3_96", "MT6C",
                   "MM23", "FB14", "FB15", "MM41"))
intcols <- names(train[, sapply(train, is.integer) & !( names(train) %in% c(idcol, catcols, targetcol))])
numcols <- names(train[, !names(train) %in% c(catcols, intcols, idcol, targetcol) ])

# identified as potentially useful in research 
# note some of them arent useful AA19 RI8_1
sme_catcols <- c("DL0", "FL12", "FL13", "FL14", "FL15", "FL16", "GN1", "GN2", "GN3", "GN4", "GN5", "MM28, MM29",
                 "FF1", "G2P1_5", "G2P1_4","G2P1_6", "MT1A", "MT2", "MT6", "MM38_14", "MMP1_1", "MMP1_2", "MMP1_3",
                 "MMP1_4", "MMP1_5", "MMP1_6", "MMP1_7", "MMP1_8", "MMP1_9", "MMP1_10", "MMP1_11", "IFI10_1", "IFI10_20"
                 , "FB27_1", "FB27_2", "FB27_3", "FB27_4", "FB27_5", "FB27_6", "FB27_7", "FB27_8", "FF14_14", "FF14_15"
                 ,"FF14_15", "FF14_16", "FF13", "FF14_17", "FF14_19", "MM2_4", "MM3_4", "MM4_4", "MM38_14")


# A crude treatment of all NAs in the dataset as a special category. This has repercussions on numeric columns
#train[is.na(train)] <- -99

# Cast all categorical columns as factors in train & test
train[catcols] <- lapply(train[catcols], as.factor)
test[catcols] <- lapply(test[catcols], as.factor)

# Train-Validation split
validation_size <- 0.7
train_indices <- createDataPartition(train$is_female, times = 1, p = validation_size, list = TRUE)
valid <- train[-train_indices$Resample1,]
train <- train[train_indices$Resample1,]

# Convert target into a factor variable
train$is_female <- factor(train$is_female)
valid$is_female <- factor(valid$is_female)


############################### Data Exploration ################################################

# Plot histograms of all variables after filtering NA
 train %>%
   select_if(is.numeric) %>%
   select(-one_of(idcol)) %>%
   melt() %>%
  filter(!is.na(value)) %>%
  ggplot(aes(x = value)) + facet_wrap(~variable,scales = "free") + geom_histogram()
  ggsave(file = "output/plots/histograms_before_imputation.pdf", device = "pdf", width = 16, height = 8, units = "in")



