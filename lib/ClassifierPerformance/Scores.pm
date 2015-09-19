package ClassifierPerformance::Scores;
use Statistics::Descriptive;
use warnings;
use strict;

# ============================================================
sub new {
# ============================================================
=head1 new()

Constructor. 

	my $dataset                = new DataSet( $store_path, $model, $cache_path );
	my $cross_validator        = new CrossValidator::NB( $dataset );
	my $classifier_performance = $cross_validator->cross_validate( 5 );
	my $scores                 = $classifier_performance->{ scores };

=cut
# ------------------------------------------------------------
	my ($class) = map { ref || $_ } shift;
	my $self = bless {}, $class;

	my $cross_validator   = shift;
	$self->{ store_path } = $cross_validator->{ store_path };
	$self->{ cache_path } = $cross_validator->{ cache_path };
	$self->{ model }      = $cross_validator->{ model };
	$self->{ k }          = $cross_validator->{ k };

	$self->read_scores();
	$cross_validator->normalize( $self );
	$self->collect_scores();

	return $self;
}

# ============================================================
sub collect_scores {
# ============================================================
	my $self = shift;
	my $k    = $self->{ k } - 1;

	foreach my $posneg ( qw( pos neg ) ) {
		$self->{ $posneg } = [];
		foreach my $i ( 0 .. $k ) {
			push @{$self->{ $posneg }}, map { $_->{ normalized }; } @{$self->{ score_subsets }[ $i ]{ $posneg }};
		}
	}
}

# ============================================================
sub read_scores {
# ============================================================
	my $self                 = shift;
	my $cache_path           = $self->{ cache_path };
	my $model                = $self->{ model };
	my $k                    = $self->{ k } - 1;
	$self->{ score_subsets } = [];

	# ===== READ ALL THE SCORE FILES
	foreach my $i ( 0 .. $k ) {
		my $subset_id = chr( $i + ord( 'A' )); 
		foreach my $posneg (qw( pos neg )) {
			$self->{ score_subsets }[ $i ]{ $posneg } = [];
			my $file = "$cache_path/$model/$model.$posneg.$subset_id.scores";
			open FILE, $file or die "Can't open file '$file' for reading $!";
			while( <FILE> ) {
				chomp;
				push @{$self->{ score_subsets }[ $i ]{ $posneg }}, $_;
			}
			close FILE;
		}
	}
}

# ============================================================
sub write_all_subsets {
# ============================================================
	my $self       = shift;
	my $store_path = $self->{ store_path };
	my $model      = $self->{ model };
	my $k          = $self->{ k } - 1;

	# ===== READ ALL THE SCORE FILES
	foreach my $i ( 0 .. $k ) {
		my $subset_id = chr( $i + ord( 'A' )); 
		my $trained   = join( ", ", map { chr( $_ + ord( 'A' )); } grep { $_ != $i } ( 0 .. $k ));
		foreach my $posneg (qw( pos neg )) {
			my $score = $self->{ score_subsets }[ $i ];
			my $file  = "$store_path/$model/$model.$posneg.$subset_id.scores_per_subset";
			my $mu    = $score->{ mu }    || undef;
			my $sigma = $score->{ sigma } || undef;
			open FILE, ">$file" or die "Can't open file '$file' for writing $!";
			print FILE "# =============================================================================\n";
			print FILE "# $model testing on subset $subset_id (trained on $trained)\n";
			print FILE "# =============================================================================\n";
			print FILE "# mu: $mu, sigma: $sigma\n" if defined $mu;
			print FILE "# Columns are: normalized_score, score\n";
			print FILE "# ------------------------------------------------------------\n";
			print FILE map { sprintf( "%s\t%s\n", $_->{ normalized }, $_->{ score } ); } @{ $score->{ $posneg }};
			close FILE;
		}
	}
}

# ============================================================
sub discretize {
# ============================================================
	my $score = shift;
	my $decimal = abs( $score - int( $score ));
	if     ( $decimal >= 0   && $decimal < 0.5 ) {
		$score = int( $score )
	} elsif( $decimal >= 0.5 && $decimal < 1.0 ) {
		$score = int( $score ) + 0.5;
	} else {
		die "Score '$score' has an unusual fractional component '$decimal' $!";
	}
	return $score;
}

1;
