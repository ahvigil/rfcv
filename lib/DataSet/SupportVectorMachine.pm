package DataSet::SupportVectorMachine;
use DataSet;
use warnings;
use strict;

our @ISA = qw( DataSet );

# ============================================================
sub init {
# ============================================================
# LibSVM uses "sparse" format, so we use .sparse as the file extension
#
# See http://www.csie.ntu.edu.tw/~cjlin/libsvm/faq.html#/Q3:_Data_preparation
# ------------------------------------------------------------
	my $self = shift;
	$self->SUPER::init( @_ );
	$self->{ output_extension } = "sparse"; 
}

# ============================================================
sub convert {
# ============================================================
=head2 convert()

Converts the FEATURE vector format to the LibSVM sparse vector format.

=cut
# ------------------------------------------------------------
	my $self = shift;

	foreach my $posneg (qw( pos neg )) {
		my $sparse_vector     = [];
		my $label             = $posneg eq 'pos' ? 1 : -1;
		my $vectors           = $self->{ $posneg };

		local $_;
		foreach $_ (@$vectors) {
			my $feature_vector = $_;
			chomp;
			s/#.*$//;      # Remove everything after first comment
			my $vector = $label;
			my @fields = split /\t/;
			shift @fields; # Remove environment label
			for my $i ( 0 .. $#fields ) {
				next if $fields[ $i ] == 0;
				my $j = $i + 1;
				$vector .= " $j:$fields[ $i ]";
			}
			push @$sparse_vector, "$vector\n";
		}

		# ===== REPLACE FEATURE VECTORS WITH NEWLY CONVERTED SPARSE VECTOR FORMAT
		$self->{ $posneg } = $sparse_vector;
	}
	return ($self->{ 'pos' }, $self->{ 'neg' });
}

# ============================================================
sub postprocess_kfold_files {
# ============================================================
	my $self           = shift;
	my $training_files = shift;
	my $testing_files  = shift;
	my $cache_path     = $self->{ cache_path };
	my $model          = $self->{ model };

	my $training_file = "$cache_path/$model/$model.training.sparse";
	`cat $training_files->{ 'pos' } $training_files->{ 'neg' } > $training_file`;
	unlink $training_files->{ 'pos' }, $training_files->{ 'neg' };
}

1;
