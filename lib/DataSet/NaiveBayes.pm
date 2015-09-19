package DataSet::NaiveBayes;
use DataSet;
use warnings;
use strict;

our @ISA = qw( DataSet );

# ============================================================
sub init {
# ============================================================
	my $self = shift;
	$self->SUPER::init( @_ );
	$self->{ output_extension } = "ff";
}

# ============================================================
sub convert {
# ============================================================
=head2 convert()

Do nothing. FEATURE is natively Naive Bayes, so this is the
default format.

=cut
# ------------------------------------------------------------
	my $self = shift;
	return ($self->{ 'pos' }, $self->{ 'neg' });
}

# ============================================================
sub postprocess_kfold_files {
# ============================================================
=head2 convert()

Do nothing. FEATURE is natively Naive Bayes, so no preparation
is necessary.

=cut
# ------------------------------------------------------------
	my $self           = shift;
	my $training_files = shift;
	my $testing_files  = shift;
}

1;
