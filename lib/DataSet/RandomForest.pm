package DataSet::RandomForest;
use DataSet;
use warnings;
use strict;
use base qw( DataSet );
no warnings qw( redefine );

# ============================================================
sub init {
# ============================================================
# R's random forest uses the arff dataformat, so our file extension
# is .arff.
# ------------------------------------------------------------
	my $self = shift;
	$self->SUPER::init( @_ );
	$self->{ output_extension } = "arff";
}

# ============================================================
sub convert {
# ============================================================
=head2 convert()

Converts the FEATURE vector format to the ARFF file format.

=cut
# ------------------------------------------------------------
	my $self = shift;

	# ===== COUNT ATTRIBUTES
	my $vec = ${ $self->{ 'pos'  } }[0];
	chomp($vec);
	$vec =~ s/#.*$//;	# Remove everything after first comment
	my @fields = split(/\t/,$vec); # get fields
	my $num_attrs  = $#fields;	# count fields
	
	# ===== CREATE HEADER, STORE FOR LATER
	$self->{ header } = "\@RELATION feature_model\n";
	for (my $i = 0; $i < $num_attrs; $i++){
		$self->{ header } .= "\@ATTRIBUTE a$i NUMERIC\n";
	}
	$self->{ header } .=  "\@ATTRIBUTE class {1,-1}\n\@DATA\n";

	foreach my $posneg (qw( pos neg )) {
		# ===== CREATE HEADER
		my $arff			= [];
		my $label			= $posneg eq 'pos' ? 1 : -1;
		my $vectors			= $self->{ $posneg };
		
		# ==== WRITE DATA
		for $_ (@$vectors) {
			chomp;
			s/#.*$//;
			@fields = split /\t/;
			shift @fields;	# Remove environment label
			my $arff_vec = join(",",@fields);	# Recombine with commas
			push @$arff, "$arff_vec,$label\n";
		}

		# ===== REPLACE FEATURE VECTORS WITH NEWLY CONVERTED ARFF VECTORS
		$self->{ $posneg } = $arff;
	}
	return ( $self->{ 'pos' }, $self->{ 'neg' });
}

# ============================================================
sub postprocess_kfold_files {
# ============================================================
	my $self           = shift;
	my $training_files = shift;
	my $testing_files  = shift;
	my $cache_path     = $self->{ cache_path };
	my $model          = $self->{ model };
	
	my $training_file = "$cache_path/$model/$model.training.arff";
	
	# ===== ADD HEADER DATA
	open FILE, ">$training_file" or die "Can't open file '$training_file' for writing $!";
	print FILE $self->{ header }; 
	close FILE;

	# ===== CONCATENATE TRAINING DATA
	`cat $training_files->{ 'pos' } $training_files->{ 'neg' } >> $training_file`;
	unlink $training_files->{ 'pos' }, $training_files->{ 'neg' };
}

1;
