package CrossValidator::SupportVectorMachine;
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

	my $training_file          = "$cache_path/$model/$model.training.sparse";
	my $model_file             = "$cache_path/$model/$model.model";
	my $model_log              = "$cache_path/$model/$model.build.log";
	my $command                = "$buildmodel -s 0 -t 0 -b 1 $training_file $model_file > $model_log 2>&1";

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
		my $test_set_file = "$cache_path/$model/$model.$posneg.testing.sparse"; 
		my $test_results  = "$cache_path/$model/$model.$posneg.$subset_id.scores";
		my $test_log      = "$cache_path/$model/$model.$posneg.$subset_id.log";
		my $command       = "$scoreit -b 1 $test_set_file $model_file $test_results > $test_log 2>&1";

		print "      Scoring $posneg test set.\n"; # MW

		system( $command );

		# ===== OPEN THE OUTPUT FILE AND CONVERT IT TO JUST SCORES
		my @scores = ();
		open FILE, "$test_results" or die "Can't open file '$test_results' for reading $!";
		while( <FILE> ) {
			next if /^labels/; # ignore header
			chomp;
			my ($label, $positive_score, $negative_score) = split /\s+/;
			my $score = $positive_score;
			push @scores, "$score\n";
		}
		close FILE;

		open FILE, ">$test_results" or die "Can't open file '$test_results' for writing $!";
		print FILE @scores;
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

	# ===== FOR EACH SUBSET
	my $scores = $score->{ score_subsets };
	for my $i ( 0 .. $k ) {

		# ===== COPY THE SCORES AS THEY ARE (SVM SCORES ARE ALREADY NORMALIZED)
		for my $posneg (qw( pos neg )) {
			my $converted = [];
			foreach my $score (@{ $scores->[ $i ]{ $posneg }}) {
				push @$converted, { score => $score, normalized => $score };
			}
			$scores->[ $i ]{ $posneg } = $converted;
		}
	}
}

1;
