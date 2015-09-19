# R script for creating a random forest model

require(randomForest)	# For random forest
require(foreign)		# For reading ARFF files

# Parse arugments for ntree, mtry, and appropriate files.
args 		  <- commandArgs(trailingOnly=TRUE)
ntree 		  <- as.integer(args[which(args=="--ntree")+1])
mtry 		  <- as.integer(args[which(args=="--mtry")+1])
training_file <- args[which(args=="--training_file")+1]
model_file 	  <- args[which(args=="--model_file")+1]
topn          <- 0

# check if only top n features should be used
if ( '--topn' %in% args){
    topn <- as.integer(args[which(args=="--topn")+1])
    if(topn<mtry && topn!=0) stop("Error: need to use at least mtry features")
}

# Check for seed and set
if ( '--seed' %in% args) {
	seed <- as.integer(args[which(args=="--seed")+1])
	set.seed(seed)
	sprintf("using seed=%d",seed)
}

# Load training file into data frame.
df <- read.arff(training_file)
sprintf("ntree=%d, mtry=%d",ntree,mtry)

# if specified, only use top N features
if(topn!=0){
    name <- gsub("\\.model", "", basename(model_file))
    load(sprintf("./data/%s/%s.importance",name, name))
    
    features <- sort(top[1:topn])
} else{
    features <- 1:480
}

# Train RF model, large datasets will consume quite a bit of memroy.
model <- randomForest(df[,features], y=df[,"class"], ntree=ntree, mtry=mtry)

# Save R object to file, will read with load() later.
save(model,file=model_file)
