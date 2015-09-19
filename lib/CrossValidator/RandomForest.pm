package CrossValidator::RandomForest;
use CrossValidator;
use warnings;
use strict;

our @ISA = qw( CrossValidator );

# ============================================================
sub build_model {
# ============================================================
=head2 build_model()

Builds an SVM model, with probability score output support, 
using the linear kernel.

=cut
# ------------------------------------------------------------
	my $self       = shift;
	my $buildmodel = $self->{ buildmodel };
	my $cache_path = $self->{ cache_path };
	my $model      = $self->{ model };

	my $training_file          = "$cache_path/$model/$model.training.arff";
	my $model_file             = "$cache_path/$model/$model.model";
	my $model_log              = "$cache_path/$model/$model.build.log";
	my $command                = "$buildmodel --training_file $training_file --model_file $model_file > $model_log 2>&1";

	print "      Building model.\n"; # MW

	system( $command );
}

# ============================================================
sub score {
# ============================================================
	my $self       = shift;
	my $subset_id   = shift;
	my $scoreit    = $self->{ scoreit };
	my $cache_path = $self->{ cache_path };
	my $model      = $self->{ model };
	my $model_file = "$cache_path/$model/$model.model";

	foreach my $posneg (qw( pos neg )) {
		my $test_set_file = "$cache_path/$model/$model.$posneg.testing.arff"; 
		my $test_results  = "$cache_path/$model/$model.$posneg.$subset_id.scores";
		my $test_log      = "$cache_path/$model/$model.$posneg.$subset_id.log";
		my $command       = "$scoreit --test_set_file $test_set_file --model_file $model_file --test_results $test_results > $test_log 2>&1";

		print "      Scoring $posneg test set.\n"; # MW

		system( $command );

		# ===== OPEN THE OUTPUT FILE AND CONVERT IT TO JUST SCORES
		my @scores = ();
		open FILE, "$test_results" or die "Can't open file '$test_results' for reading $!";
		while( <FILE> ) {
			if (m/^\d+/) {
				chomp;
				#my ($label, $positive_score, $negative_score) = split /\s+/;
				my ($label, $positive_vote, $negative_vote) = split /\s+/;
				my $positive_score = $positive_vote / ( $negative_vote + $positive_vote );
				my $score = $positive_score;
				push @scores, "$score\n";
			}
		}
		close FILE;

		open FILE, ">$test_results" or die "Can't open file '$test_results' for writing $!";
		print FILE @scores;
		close FILE;
	}
}

# ============================================================
sub normalize {
# ============================================================
	my $self  = shift;
	my $score = shift;

	# ===== AVOID ACCIDENTALLY REAPPLYING THE CONVERSION
	return if $score->{ converted };
	$score->{ converted } = 1;
	my $k = ($score->{ k } -1); # upper-bound array limit for k-fold (start at 0)

	# ===== FOR EACH SUBSET
	my $scores = $score->{ score_subsets };
	for my $i ( 0 .. $k ) {

		# ===== COPY THE SCORES AS THEY ARE (SVM SCORES ARE ALREADY NORMALIZED)
		for my $posneg (qw( pos neg )) {
			my $converted = [];
			foreach my $score (@{ $scores->[ $i ]{ $posneg }}){
				push @$converted, { score => $score, normalized => $score };
			}
			$scores->[ $i ]{ $posneg } = $converted;
		}
	}
}

# ============================================================
sub calculate_mu_sigma {
# ============================================================
	my $score = shift;
	my $k     = ($score->{ k } -1); # upper-bound array limit for k-fold (start at 0)

	# ===== FOR EACH SUBSET
	my $scores = $score->{ score_subsets };
	for my $i ( 0 .. $k ) {

		# ===== ACCUMULATE THE STATISTICS FOR ALL SUBSETS EXCEPT THE CURRENT
		my $stats = new Statistics::Descriptive::Full;
		for my $j ( 0 .. $k ) {
			next if $i == $j;
			for my $posneg (qw( pos neg )) {
				$stats->add_data( @{ $scores->[ $i ]{ $posneg } } );
			}
		}

		# ===== CALCULATE AND STORE MU AND SIGMA
		my $mean   = $stats->mean();
		my $stddev = $stats->standard_deviation();
		$scores->[ $i ]{ mu }    = $mean;
		$scores->[ $i ]{ sigma } = $stddev;
	}
}


1;
