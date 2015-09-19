# R script for predicting class values using random forest models

require(randomForest)	# For random forest
require(foreign)		# For reading ARFF files

# Parse arguments for appropriate files.
args		<- commandArgs(trailingOnly=TRUE)
test_set_file <- args[which(args=="--test_set_file")+1]
model_file <- args[which(args=="--model_file")+1]
test_results <- args[which(args=="--test_results")+1]

# Load test set into a data frame
df <- read.arff(test_set_file)

# Load random forest model, the load function
# adds the stored variable (model) into R.
load(model_file)

# Predict class probabilities over data frame.
# LF: Changed to votes instead of probabilities, division done in perl.
preds <- predict(model,df,type="vote",norm.votes=FALSE)  

# Save predictions to a file.
sink(test_results,split=FALSE)
print(preds)
sink()
