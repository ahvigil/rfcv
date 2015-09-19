package ClassifierPerformance;

use ClassifierPerformance::Scores;
use ClassifierPerformance::ConfusionMatrices;
use warnings;
use strict;

=head1 NAME

ClassifierPerformance - A suite of related performance metrics for ML classifiers

=head1 DESCRIPTION

	my $classifier_performance = $cross_validator->cross_validate( 5 );
	$classifier_performance->write_performance_summary();

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

	my $cross_validator           = shift;
	my $scores                    = new ClassifierPerformance::Scores( $cross_validator );
	$self->{ store_path }         = $cross_validator->{ store_path };
	$self->{ cache_path }         = $cross_validator->{ cache_path };
	$self->{ model }              = $cross_validator->{ model };
	$self->{ scores }             = $scores;
	$self->{ confusion_matrices } = new ClassifierPerformance::ConfusionMatrices( $scores );

	return $self;
}

# ============================================================
sub cleanup {
# ============================================================
	my $self       = shift;
	my $cache_path = $self->{ cache_path };
	my $model      = $self->{ model };

	unlink "$cache_path/$model/$model.scores";
	rmdir "$cache_path/$model";
}

# ============================================================
sub write_performance_summary {
# ============================================================
	my $self     = shift;
    my $label    = shift;
	my %range    = @_;
	my $min      = $range{ min_cutoff } || 0;
	my $max      = $range{ max_cutoff } || 1;
	my $scores   = $self->{ scores };
	my $range    = abs( $max - $min );
	my $steps    = 200;
	my $step     = $range/$steps;
	my $matrices = $self->{ confusion_matrices };

	print "    Writing scores.\n"; # MW
	$scores->write_all_subsets();

	print "    Calculating confusion matrices.\n"; # MW
	for( my $cutoff = $min; $cutoff <= $max; $cutoff += $step ) {
		$matrices->add_confusion_matrix( $cutoff );
	}
	
	print "    Writing results per cutoff steps.\n"; # MW
    $matrices->write_full_results($label);

	print "    Generating AUC and sensitivity at fixed specificities.\n"; # MW
	$matrices->write_performance_summary($label);
}

1;
