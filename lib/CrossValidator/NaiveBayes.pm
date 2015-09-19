package CrossValidator::NaiveBayes;
use CrossValidator;
use warnings;
use strict;

our @ISA = qw( CrossValidator );

# ============================================================
sub build_model {
# ============================================================
	my $self       = shift;
	my $buildmodel = $self->{ buildmodel }; 
	my $cache_path = $self->{ cache_path };
	my $model      = $self->{ model };

	die "Can't find program to build a model '$buildmodel' $!" unless -e (split /\s+/, $buildmodel)[ 0 ];

	my $positive_training_set = "$cache_path/$model/$model.pos.training.ff";
	my $negative_training_set = "$cache_path/$model/$model.neg.training.ff";
	my $model_file            = "$cache_path/$model/$model.model";
	my $command               = "$buildmodel $positive_training_set $negative_training_set > $model_file 2>/dev/null";

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
		my $test_set_file = "$cache_path/$model/$model.$posneg.testing.ff";
		my $test_results  = "$cache_path/$model/$model.$posneg.$subset_id.scores";
		my $command       = "$scoreit -a $model_file $test_set_file 2>/dev/null";

		print "      Scoring $posneg test set.\n"; # MW

		my @results = split /\n/, `$command`;
		open FILE, ">$test_results" or die "Can't open file '$test_results' for writing $!";
		while( @results ) {
			local $_ = shift @results;
			next if /^#/; # ignore comments and metadata
			my ($env, $score) = split /\t/;
			print FILE "$score\n";
		}
		close FILE;
	}
}

# ============================================================
sub read_score_file {
# ============================================================
	my $set    = shift;
	my $file   = shift;
	my $scores = [];
	my $label  = $set eq 'pos' ? 1 : -1;
	open FILE, $file or die "Can't open file '$file' for reading $!";
	while( <FILE> ) {
		next if /^#/;
		my ($env, $score) = split /\t/;
		push @$scores, { label => $label, score => $score };
	}
	close FILE;
	return $scores;
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

	calculate_mu_sigma( $score );

	print "  NORMALIZING SCORES\n";

	# ===== FOR EACH SUBSET
	my $scores = $score->{ score_subsets };
	for my $i ( 0 .. $k ) {

		# ===== STORE THE CONVERTED Z-SCORES, SEPARATED BY KNOWN CLASSIFICATION (POS/NEG)
		for my $posneg (qw( pos neg )) {
			my $mu        = $scores->[ $i ]{ mu };
			my $sigma     = $scores->[ $i ]{ sigma };
			my $converted = [];
			foreach my $score (@{ $scores->[ $i ]{ $posneg }}) {
				my $z_score = ($score - $mu)/$sigma; 
				push @$converted, { score => $score, normalized => $z_score };
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
