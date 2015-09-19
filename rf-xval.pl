#! /usr/bin/perl
use lib qw( lib perl5/lib ../lib );
use Cwd qw( getcwd );
use DataSet;
use CrossValidator;
use warnings;
use strict;

$ENV{ PATH } = "./bin:$ENV{ PATH }";
my $model      = shift;
my $ntree	   = shift;
my $mtry	   = shift;
my $topn       = shift || 0;
my $home       = ".";
my $rf_dir     = "$home/r";
my $input_path = "$home/data";
my $store_path = sprintf( "$home/performance/ntree%04d_mtry%02d%s", $ntree, $mtry, ($topn!=0 ? sprintf("_top%03d", $topn) : ""));
my $runid      = sprintf("%d%05d", time, int(rand(100000)));
my $cache_path = "$home/cache/".$runid;

my $buildmodel = "/home/share/bin/Rscript $rf_dir/rf-train.R --ntree $ntree --mtry $mtry --topn $topn";
my $scoreit    = "/home/share/bin/Rscript $rf_dir/rf-predict.R";

unless (-d $store_path){
	mkdir $store_path or die "Could not make directory $store_path $!";
}

unless (-d $cache_path){
    mkdir $cache_path or die "Could not make directory $$cache_path $!";
}

my $start = scalar localtime();
print "$start Evaluating $model performance at ntree = $ntree and mtry = $mtry".($topn!=0 ? " using $topn features" : "")."\n";
print "  Loading data...\n";
my $dataset                = new DataSet::RandomForest( $model, $input_path, $store_path, $cache_path);

print "  Cross validating...\n";
my $cross_validator        = new CrossValidator::RandomForest( $dataset, $buildmodel, $scoreit );

print "  Calculating performance metrics...\n";
my $classifier_performance = $cross_validator->cross_validate( 5 );

$classifier_performance->write_performance_summary($runid);
`rm -rf $cache_path`;

my $stop = scalar localtime();
print "$stop $model evaluation complete.\n";
