package ClassifierPerformance::ConfusionMatrices;
use warnings;
use strict;

=head1 NAME

ClassifierPerformance::ConfusionMatrices - Generates classifier performance
metrics based on confusion matricies. This includes an ROC curve, AUC, and
Precision vs.  Recall curve.

=cut
# ============================================================
sub new { 
# ============================================================
=head1 new()

Constructor. 

=cut
# ------------------------------------------------------------
	my ($class) = map { ref || $_ } shift;
	my $self = bless {}, $class;

	my $scores                         = shift;
	$self->{ scores }                  = $scores;
	$self->{ store_path }              = $scores->{ store_path };
	$self->{ model }                   = $scores->{ model };
	$self->{ matrices }                = [];
	$self->{ precision_recall }        = [];
	$self->{ sensitivity_specificity } = [];
	$self->{ roc }                     = [];

	return $self;
}

# ============================================================
sub read_results_file {
# ============================================================
=head1 read_results_file()
Reads a results file and creates a new Confusion Matrices
object.

Example:

	my $cm = ClassifierPerformance::ConfusionMatrices::read_results_file( $file );
	$cm->{ store_path } = $path;
	$cm->{ model } = $model;
	$cm->write_performance_summary();

=cut
# ------------------------------------------------------------
    my $file    = shift;
    my $results = bless {}, 'ClassifierPerformance::ConfusionMatrices';
    open FILE, $file or die "Can't read '$file' $!";
    while( <FILE> ) {
        chomp;
        next if /^#/;
        next if /^$/;
        if     ( /^(?:Pos|Neg)/ ) {
            my $samples = lc $1;
            my ($label, $count) = split /:\s+/, $_, 2;
            $results->{ $samples } = $count;

        } elsif( /^\s*-?\d+/ ) {
            s/^\s+//;
            my ($cutoff, $tp, $tn, $fp, $fn) = split /\s+/;
            my $positives   = $tp + $fn;
            my $negatives   = $tn + $fp;
            my $retrieved   = $tp + $fp;
            my $sensitivity = $positives == 0 ? 0 : $tp / $positives;
            my $specificity = $negatives == 0 ? 0 : $tn / $negatives;
            my $precision   = $retrieved == 0 ? 0 : $tp / $retrieved;
            my $recall      = $sensitivity;
            my $tpr         = $sensitivity;
            my $fpr         = 1 - $specificity;

            $results->{ positive_samples } = $positives;
            $results->{ negative_samples } = $negatives;

            push @{ $results->{ matrices }},          { tp  => $tp,     tn   => $tn,          fp   => $fp,          fn => $fn };
            push @{ $results->{ cutoffs_sens_spec }}, { cut => $cutoff, sens => $sensitivity, spec => $specificity            };
            push @{ $results->{ precision_recall }},  { cut => $cutoff, p    => $precision,   r    => $recall                 };
            push @{ $results->{ roc }},               { tpr => $tpr,    fpr  => $fpr                                          };
		}
    }
    close FILE;
    return $results;
}


# ============================================================
sub add_confusion_matrix {
# ============================================================
	my $self     = shift;
	my $cutoff   = shift;
	my $scores   = $self->{ scores };

	# ===== GET THE POSITIVE AND NEGATIVE SCORES
	my $positive_scores         = $scores->{ 'pos' };
	my $negative_scores         = $scores->{ 'neg' };
	$self->{ positive_samples } = int( @$positive_scores );
	$self->{ negative_samples } = int( @$negative_scores );

	# ===== COUNT THE CORRECT PREDICTIONS, TYPE I, AND TYPE II ERRORS
	my $true_positives          = int( grep { $_ >= $cutoff; } @$positive_scores );
	my $true_negatives          = int( grep { $_ <  $cutoff; } @$negative_scores );
	my $false_positives         = int( grep { $_ >= $cutoff; } @$negative_scores );
	my $false_negatives         = int( grep { $_ <  $cutoff; } @$positive_scores );

	# ===== CALCULATE THE AGGREGATE SET SIZES
	my $positives               = int( @$positive_scores );
	my $negatives               = int( @$negative_scores );
	my $retrieved               = $true_positives + $false_positives;

	# ===== CALCULATE THE DATA OF INTEREST
	my $sensitivity             = $positives == 0 ? 0 : $true_positives / $positives;
	my $specificity             = $negatives == 0 ? 0 : $true_negatives / $negatives;

	my $precision               = $retrieved == 0 ? 0 : $true_positives / $retrieved;
	my $recall                  = $sensitivity;

	my $tpr                     = $sensitivity;
	my $fpr                     = 1 - $specificity;

	push @{ $self->{ matrices }},                { tp   => $true_positives, tn   => $true_negatives, fp   => $false_positives, fn   => $false_negatives };
	push @{ $self->{ cutoffs_sens_spec }},       { cut  => $cutoff,         sens => $sensitivity,    spec => $specificity };
	push @{ $self->{ precision_recall }},        { cut  => $cutoff,         p    => $precision,      r    => $recall      };
	push @{ $self->{ roc }},                     { tpr  => $tpr,            fpr  => $fpr         };
}

# ============================================================
sub calculate_auc {
# ============================================================
	my $self = shift;
	my @points = @{ $self->{ roc }};
	
	# ===== TRAPEZOIDAL APPROXIMATION
	my $auc = 0;
	my $i   = shift @points;
	foreach my $j (@points) {
		my $width   = abs($j->{ fpr } - $i->{ fpr });
		my $height  = ($i->{ tpr } + $j->{ tpr })/2;
		$auc       += $width * $height;
		$i = $j;
	}
	$auc = sprintf "%7.5f", $auc;
	return $auc;
}

# ============================================================
sub linear_interpolation {
# ============================================================
	my $target = shift;
	my $points = shift;
	my $x      = shift;
	my $y      = shift;

	# ===== ROUND THE VALUES
	my @points = map { { 
			$x   => sprintf( "%5.3f", $_->{ $x } ), 
			$y   => sprintf( "%5.3f", $_->{ $y } ),
			cut  => sprintf( "%5.3f", $_->{ cut } ) 
		}; } @$points;

	# ===== OPTION 1: ONE OR MORE MATCHES TO THE TARGET
	# Return the largest sensitivity value
	my @found = sort { $b->{ $y } <=> $a->{ $y } } grep { $_->{ $x } == $target } @points;

	# ===== OPTION 2: NO EXACT MATCHES
	# Find the pairs of points that surround the target; there
	# may be more than one pair if the curve is concave
	my @pairs = ();
	for my $i ( 0 .. ($#points-1) ) {
		my $b = $points[ $i ];
		my $a = $points[ ($i+1) ];

		if      ( $a->{ $x } < $target && $b->{ $x } > $target ) {
			push @pairs, { before => $a, after => $b };
		} elsif ( $b->{ $x } < $target && $a->{ $x } > $target ) {
			push @pairs, { before => $b, after => $a };
		}
	}

	# ===== OPTION 3: REQUESTED TARGET WOULD REQUIRE EXTRAPOLATION
	# Extrapolation is beyond what we're trying to achieve here.
	return ('0.000', '0.000') unless( @pairs || @found );

	# ===== OPTION 2 CONT'D: INTERPOLATE FOR ALL BOUNDING PAIRS 
	# Return the one with the highest sensitivity or recall for the lowest cutoff.
	foreach my $pair (@pairs) {
		my $before        = $pair->{ before };
		my $after         = $pair->{ after };
		my $distance      = $target - $before->{ $x };
		my $range         = $after->{ $x } - $before->{ $x };
		my $cut_range     = $after->{ cut }  - $before->{ cut };
		my $ratio         = $distance/$range;
		my $height        = $after->{ $y } - $before->{ $y };
		my $interpolation = $before->{ $y } + ($ratio * $height);
		my $cutoff        = $before->{ cut } + ($ratio * $cut_range);

		push @found, { $y => $interpolation, cut => $cutoff };
	}

	# ===== OPTION 1 & 2 CONT'D: FIND THE HIGHEST VALUE FOR THE LOWEST CUTOFF
	my $interpolated_point = (sort { $b->{ $y } <=> $a->{ $y } || $a->{ cut } <=> $b->{ cut } } @found)[ 0 ];
	my $interpolation      = $interpolated_point->{ $y };
	my $cutoff             = $interpolated_point->{ cut };
	return (sprintf( "%5.3f", $interpolation ), sprintf( "%5.3f", $cutoff ));
}

# ============================================================
sub write_performance_summary {
# ============================================================
	my $self       = shift;
    my $label      = shift || "";
	my $store_path = $self->{ store_path };
	my $model      = $self->{ model };

	my $points      = undef;
	my $sensitivity = {};
	my $cutoff_sens = {};
	my $recall      = {};
	my $cutoff_rec  = {};

	$points = $self->{ cutoffs_sens_spec };
	($sensitivity->{ 1.000 }, $cutoff_sens->{ 1.000 }) = linear_interpolation( 1.000, $points, 'spec', 'sens' );
	($sensitivity->{ 0.990 }, $cutoff_sens->{ 0.990 }) = linear_interpolation( 0.990, $points, 'spec', 'sens' );
	($sensitivity->{ 0.950 }, $cutoff_sens->{ 0.950 }) = linear_interpolation( 0.950, $points, 'spec', 'sens' );
	($sensitivity->{ 0.900 }, $cutoff_sens->{ 0.900 }) = linear_interpolation( 0.900, $points, 'spec', 'sens' );

	$points = $self->{ precision_recall };
	($recall->{ 1.000 },      $cutoff_rec->{ 1.000 })  = linear_interpolation( 1.000, $points, 'p',    'r' );
	($recall->{ 0.990 },      $cutoff_rec->{ 0.990 })  = linear_interpolation( 0.990, $points, 'p',    'r' );
	($recall->{ 0.950 },      $cutoff_rec->{ 0.950 })  = linear_interpolation( 0.950, $points, 'p',    'r' );
	($recall->{ 0.900 },      $cutoff_rec->{ 0.900 })  = linear_interpolation( 0.900, $points, 'p',    'r' );

	my $auc = $self->calculate_auc();

	# ===== PRINT FILE
	my $file = "$store_path/$model/$model.$label.summary";
	open FILE, ">$file" or die "Can't open file '$file' for writing $!";
	print FILE <<EOF;
# ============================================================
# $model Performance Summary
# ============================================================
Positive sample size:                      $self->{ positive_samples }
Negative sample size:                      $self->{ negative_samples }
AUC:                                       $auc
Sensitivity & Cutoff at 1.000 Specificity: $sensitivity->{ 1.000 }, $cutoff_sens->{ 1.000 }
Sensitivity & Cutoff at 0.990 Specificity: $sensitivity->{ 0.990 }, $cutoff_sens->{ 0.990 }
Sensitivity & Cutoff at 0.950 Specificity: $sensitivity->{ 0.950 }, $cutoff_sens->{ 0.950 }
Sensitivity & Cutoff at 0.900 Specificity: $sensitivity->{ 0.900 }, $cutoff_sens->{ 0.900 }
Recall      & Cutoff at 1.000 Precision:   $recall->{ 1.000 }, $cutoff_rec->{ 1.000 }
Recall      & Cutoff at 0.990 Precision:   $recall->{ 0.990 }, $cutoff_rec->{ 0.990 }
Recall      & Cutoff at 0.950 Precision:   $recall->{ 0.950 }, $cutoff_rec->{ 0.950 }
Recall      & Cutoff at 0.900 Precision:   $recall->{ 0.900 }, $cutoff_rec->{ 0.900 }

EOF
	close FILE;
}

# ============================================================
sub write_full_results {
# ============================================================
	my $self       = shift;
    my $label      = shift || "";
	my $store_path = $self->{ store_path };
	my $model      = $self->{ model };
	my $file       = "$store_path/$model/$model.$label.results";

	open FILE, ">$file" or die "Can't open file '$file' for writing $!";
	print FILE <<EOF;
# ============================================================
# $model Performance Raw Results
# ============================================================
Positive sample size:            $self->{ positive_samples }
Negative sample size:            $self->{ negative_samples }

# ------------------------------------------------------------
# Cutoff    TP    TN    FP    FN Sens  Spec
# ------------------------------------------------------------
EOF
	for my $i ( 0 .. $#{ $self->{ matrices }} ) {
		my $matrix  = $self->{ matrices }[ $i ];
		my $value   = $self->{ cutoffs_sens_spec }[ $i ];
		printf FILE "% 8.3f %5d %5d %5d %5d %5.3f %5.3f\n", $value->{ cut }, $matrix->{ tp }, $matrix->{ tn }, $matrix->{ fp }, $matrix->{ fn }, $value->{ sens }, $value->{ spec };
		
		
	}
	close FILE;

}

1;
