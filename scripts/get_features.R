# ================================================================================================
# Description: perform feature extraction
#
# Input: 
# train = model build dataset
# valid = roc validation hold out dataset
#
# Output: 
# train$high_leverage = column identifying points with high leverage
# train$high_influence = column identifying influential points
# train$high_outlier = column identifying standardised jack knife residuals
# boruta_cols = list of columns that were flagged as important via the boruta algorithm
# 
#
# Author: E Walsh
#
# Dependencies: 
# run via main script to load all the packages and data
#
# Notes:
#
# Issues:
#
# History (reverse order): 
# 01 Feb 2018 EW v1
# ================================================================================================

print("Extracting features...")

# ===================================== features ================================================

# ###############################  Flag interesting obs ################################################

# uses a multivariate model approach to identify outliers

#TODO: probably dont want to fit the saturated model
#TODO: need to ensure that we have the dataset that has dealt with the missing values
logistic_model <- glm (is_female ~ ., data = train, family = binomial)
npar <- length(logistic_model$coefficients)-1
summary(logistic_model)

# check the jack knife residuals to identy the extreme obs
res_jk <- rstudent(logistic_model)
std_jk <- sqrt((sum(res_jk^2))/nrow(train))
train$high_outlier <- ifelse(res_jk > 3*std_jk, 1, 0)

# have a look at the hat matrix to identify high leverage pooints
h_ii <- hat (model.matrix(logistic_model))
train$high_leverage <- ifelse(h_ii > 2*(npar+1)/nrow(train), 1, 0)

# also check cooks distance to identify influence points
cd_i <- cooks.distance(logistic_model)
train$high_influence <- ifelse(unname(cd_i) > 1, 1, 0)

# ###############################  Boruta ################################################

# see if producing shadow features or shuffled copies of features highlight useful features

# first cut of features with detailed trace
boruta_features <- Boruta(is_female ~ ., data = train, maxRuns = 15, doTrace = 2)
print(boruta_features)

# decide whether the tentative attributes are in or out
boruta_features_final <- TentativeRoughFix(boruta_features)
print(boruta_features_final)

# retain summary stats
boruta_features_df <- attStats(boruta_features_final)

# find the useful features
boruta_cols <- row.names(boruta_features_df[which(boruta_features_df$decision=="Confirmed"),])
save(boruta_cols, file = "boruta_features.RData")

# extract useful columns and convert target into factors that start with a charcter to avoid errors
# around variable names
train_boruta <- train %>% select(is_female, boruta_cols)
valid_boruta <- valid %>% select(is_female, boruta_cols)
levels(train_boruta$is_female) <- make.names(levels(factor(train_boruta$is_female)))

# quickly check on the fly see if the columns extracted prove to be useful
glmnet_control_object <- trainControl(method='cv', number = 5, returnResamp = 'none', classProbs = TRUE)
model_object <- caret::train(as.data.frame(train_boruta[,boruta_cols]), train_boruta$is_female,
                      method = 'glmnet',
                      trControl = glmnet_control_object,
                      metric = "Accuracy")

# confirm what the roc score is on the validation data
# this metric is not available for glmnet so the pROC package is required
# this will require changing the prediction levels back again...
predict_boruta <- predict(object = model_object, valid_boruta[,boruta_cols])
roc_boruta <- roc(valid_boruta[,"is_female"], ifelse(predict_boruta=="X0",0,1))
# boruta columns look promising but will require more tuning
print(roc_boruta$auc)


                      
