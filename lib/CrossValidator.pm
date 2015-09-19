package CrossValidator;
use ClassifierPerformance;
use CrossValidator::NaiveBayes;
use CrossValidator::SupportVectorMachine;
use CrossValidator::RandomForest;
use warnings;
use strict;

# ============================================================
sub new {
# ============================================================
	my ($class) = map { ref || $_ } shift;
	my $self = bless {}, $class;

	my $dataset    = shift;
	my $buildmodel = shift;
	my $scoreit    = shift;

	$self->{ dataset }    = $dataset;
	$self->{ store_path } = $dataset->{ store_path };
	$self->{ cache_path } = $dataset->{ cache_path };
	$self->{ model }      = $dataset->{ model };
	$self->{ buildmodel } = $buildmodel;
	$self->{ scoreit }    = $scoreit;

	# ===== REMOVE COMMAND-LINE ARGUMENTS AND VERIFY EXISTANCE OF PROGRAMS
	($buildmodel) = split /\s/, $buildmodel;
	($scoreit) = split /\s/, $scoreit;
	die "Executable '$buildmodel' not found $!" unless -e $buildmodel;
	die "Executable '$scoreit' not found $!" unless -e $scoreit;

	return $self;
}

# ============================================================
sub build_model {
# ============================================================
	my $self = shift;
	die "CrossValidator::build_model() is undefined $!";
}

# ============================================================
sub cross_validate {
# ============================================================
=head2 cross_validate

Produces a model file and score files for each k-fold validation. The score
files are uniquely named and do not overwrite; the models do overwrite each
other (they can be big files and testing for the buildmodel systems should be
done elsewhere, not here).

The score files are text files that contain the scores for each test sample per
k-fold validation; one line per score.

=cut
# ------------------------------------------------------------
	my $self     = shift;
	my $k        = shift;
	$self->{ k } = $k;

	my $dataset = $self->{ dataset };

	$dataset->convert();
	$dataset->split_into_subsets( $k );
	my @subset_ids = map { chr( $_ + ord( 'A' )); } ( 0 .. ($k - 1 ));

	foreach my $subset_id (@subset_ids) {
		my $time = scalar localtime();
		print "    Leaving Group $subset_id out. $time\n"; # MW
		$dataset->k_fold( $subset_id );
		$self->build_model();
		$self->score( $subset_id );
	}

	my $classifier_performance = new ClassifierPerformance( $self );
	return $classifier_performance;
}

# ============================================================
sub score {
# ============================================================
	my $self = shift;
	die "CrossValidator::score() is undefined $!";
}

1;
