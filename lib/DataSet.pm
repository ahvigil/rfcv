package DataSet;
use DataSet::NaiveBayes;
use DataSet::SupportVectorMachine;
use DataSet::RandomForest;
use List::Util qw( shuffle );
use warnings;
use strict;

=head1 NAME

DataSet - Manages subset recombination for cross-validation

=head1 SYNOPSIS

	my $dataset = new DataSet( $input_path, $model, $output_path );

	$dataset->split_into_subsets( 5 );

=head1 DESCRIPTION


=cut

# ============================================================
sub new {
# ============================================================
	my ($class) = map { ref || $_ } shift;
	my $self = bless {}, $class;
	$self->init( @_ );
	return $self;
}

# ============================================================
sub init {
# ============================================================
	my $self       = shift;
	my $model      = shift;
	my $input_path = shift;
	my $store_path = shift;
	my $cache_path = shift;

	$self->{ model }            = $model;
	$self->{ input_path }       = $input_path;
	$self->{ store_path }       = $store_path;
	$self->{ cache_path }       = $cache_path;
	$self->{ output_extension } = "billcosby"; # If we see this in our output, something is wrong... fiddly faddly pudding pops

	foreach my $posneg (qw( pos neg fp )) {
		$self->{ $posneg } = _read_environment_file( "$input_path/$model/$model.$posneg.ff" );
	}

	# ===== FALSE POSITIVES ARE NEGATIVE SAMPLES
	if( @{ $self->{ fp }} ) {
		push @{ $self->{ neg }}, @{ $self->{ fp }};
		delete $self->{ fp };
	}
}

# ============================================================
sub convert {
# ============================================================
	my $self = shift;
	die "DataSet::convert(): No ML specified; try using DataSet::NaiveBayes $!";
}

# ============================================================
sub k_fold {
# ============================================================
=head2 k_fold()

Writes out training and testing files for positive and
negative samples. Takes numerical or letter arguments.

	$dataset->k_fold( 1 );   # Leaves out the first subset
	$dataset->k_fold( 'C' ); # Leaves out subset 'C'

=cut
# ------------------------------------------------------------
	my $self             = shift;
	my $n                = shift;
	my $k                = $#{ $self->{ pos_subset }};
	my $cache_path       = $self->{ cache_path };
	my $model            = $self->{ model };
	my $output_extension = $self->{ output_extension };

	# ===== SET N TO START AT 0 INSTEAD OF 1
	$n = $n =~ /^\d+$/ ? $n - 1 : ord( $n ) - ord ( 'A' );

	my $path = "$cache_path/$model";
	mkdir $path unless -e $path;

	my $file;
	my $training_files = {};
	my $testing_files  = {};
	foreach my $posneg ( qw( pos neg )) {
		my @set = ();
		my $subset = $posneg . "_subset";

		foreach my $i ( 0 .. $k ) {
			next if $i == $n;
			push @set, @{ $self->{ $subset }[ $i ]};

		}

		$file = "$path/$model.$posneg.training.$output_extension";
		open FILE, ">$file" or die "Can't open file '$file' for writing $!";
		print FILE @set;
		close FILE;
		$training_files->{ $posneg } = $file;

		$file = "$path/$model.$posneg.testing.$output_extension";
		open FILE, ">$file" or die "Can't open file '$file' for writing $!";
		if ( $self->{ output_extension } eq "arff" ) {
			print FILE $self->{ header };
		}
		print FILE @{ $self->{ $subset }[ $n ]};
		close FILE;
		$testing_files->{ $posneg } = $file;
	}
	$self->postprocess_kfold_files( $training_files, $testing_files );
}

# ============================================================
sub split_into_subsets {
# ============================================================
=head2 split_into_subsets()

	$dataset->split_into_subsets( 5 );

Splits a given feature vector set into subsets. This method has
two use cases:

=over 4

=item * Split the feature vectors into C<n> number of subsets 
and generate a I<subset assignment file>. C<n> is provided as
a numeric argument; up to 26 subsets can be created.

=item * Read an existing I<subset assignment file> and recreate 
the subsets from the prior use case. The number of subsets must
match the SUBSETS entry in the file.

=back 

=cut
# ------------------------------------------------------------
	my $self         = shift;
	my $n            = shift;
	my $store_path   = $self->{ store_path };
	my $model        = $self->{ model };
	my $subsets_file = "$store_path/$model/$model.subsets";
	
	# ===== INITIALIZE SUBSETS
	foreach my $posneg (qw( pos neg )) {
		my $subset         = $posneg . "_subset";
		$self->{ $subset } = [ map { [] } (0 .. ($n-1)) ];
	}

	# ===== OPTION 1: SPLIT INTO SUBSETS DEFINED BY A GROUP ASSIGNMENT FILE
	if( -e $subsets_file ) {
		$self->_read_subsets_file( $n );

	# ===== OPTION 2: CREATE A SUBSETS FILE
	} elsif( $n =~ /^\d+$/ ) {
		$self->_create_subsets_file( $n );

	} else {
		die "Subsets file '$subsets_file' doesn't exist $!";
	}
}

# ============================================================
sub write_subsets {
# ============================================================
=head2 write_subsets()

Writes out the subsets

=cut
# ------------------------------------------------------------
	my $self             = shift;
	my $k                = int( @{ $self->{ pos_subset }} );
	my $cache_path       = $self->{ cache_path };
	my $model            = $self->{ model };
	my $output_extension = $self->{ output_extension };

	my $out = "$cache_path/$model";
	mkdir $out unless -e $out;

	foreach my $posneg ( qw( pos neg )) {
		my $subset = $posneg . "_subset";

		foreach my $i ( 1 .. $k ) {
			my $j         = $i - 1;
			my $subset_id = chr( ord( 'A' ) + $j );

			my $file  = "$cache_path/$model/$model.$posneg.$subset_id.$output_extension";
			open FILE, ">$file" or die "Can't open file '$file' for writing $!";
			if ( $self->{ output_extension } eq "arff" ) {
				print FILE $self->{ header };
			}
			print FILE @{$self->{ $subset }[ $j ]};
			close FILE;
		}
	}
}

# ============================================================
sub _apply_subset_file_assignments_to_samples {
# ============================================================
# Partitions the samples into subsets and returns a text
# representation of the subset assignments for each sample.
#
# Users should not call this method.
# ------------------------------------------------------------
	my $self              = shift;
	my $posneg            = shift;
	my $n                 = shift;
	my $subset            = $posneg . "_subset";
	my $assignments       = $subset . "_assignments";
	my $tag               = $posneg eq 'pos' ? "POSITIVE" : "NEGATIVE";
	my $subset_assignments;

	# ===== OPTION 1: CREATE N SUBSETS AND RANDOMLY ASSIGN
	# Here $n is a number
	#
	# Uses a card-dealing algorithm, shuffling the positive 
	# and negative samples like cards and dealing them out 
	# to players (subsets).
	if( $n =~ /^\d+$/ ) {
		$subset_assignments = _shuffle_and_deal( $#{ $self->{ $posneg }}, $n );

	# ===== OPTION 2: USE PREVIOUSLY CREATED SUBSET ASSIGNMENTS
	# Here $n is a text representation of the subset assignments
	} else {
		$subset_assignments = $n;
	}

	# ===== APPLY SUBSET ASSIGNMENTS
	my $group = $self->{ $subset };
	for my $i (0 .. $#{ $self->{ $posneg }}) {
		my $j = (ord( $subset_assignments->[ $i ] ) - ord( 'A' ));
		push @{ $group->[ $j ]}, $self->{ $posneg }[ $i ];
	}
	$self->{ $assignments } = "[$tag]\n" . _text_wrap( $subset_assignments ) . "[END-$tag]\n";
}

# ============================================================
sub _create_subsets_file {
# ============================================================
	my $self         = shift;
	my $n            = shift;
	my $store_path   = $self->{ store_path };
	my $model        = $self->{ model };
	my $subsets_file = "$store_path/$model/$model.subsets";

	die "DataSet::split_into_subsets(): Can't have more than 26 subsets!\n" if( $n > 26 );
	mkdir "$store_path/$model" unless -e "$store_path/$model";

	open FILE, ">$subsets_file" or die "Can't open '$subsets_file' for writing $!";
	print FILE <<EOF;
# ============================================================================
# SUBSET ASSIGNMENTS FOR TRAINING SAMPLES
# ============================================================================
# This file shows the subset assignments for all positive and negative 
# samples. Each letter represents one sample; for example, if the letter 
# sequence started as "ABC" Then the first sample belongs to subset "A", the 
# second sample belongs to subset "B" and the third sample belongs to 
# subset "C".
# ----------------------------------------------------------------------------
EOF
	print FILE "\[SUBSETS\]$n\[END-SUBSETS\]\n";
	foreach my $posneg (qw( pos neg )) {
		$self->_apply_subset_file_assignments_to_samples( $posneg, $n );
		my $assignments = $posneg . "_subset_assignments";
		print FILE $self->{ $assignments };
	}
	close FILE;
}

# ============================================================
sub _read_environment_file {
# ============================================================
#
# ------------------------------------------------------------
	my $file     = shift;
	my $contents = [];

	if( -e "$file.gz" ) {
		@$contents = grep { !/^#/ } `gunzip -c $file.gz`;

	} elsif( -e $file ) {
		open FILE, $file or die "Can't open environment file '$file' or '$file.gz' for reading $!";
		while( <FILE> ) {
			next if /^#/; # skip metadata
			push @$contents, $_;
		}
		close FILE;

	} elsif( $file =~ /\.fn\.ff/ ) {
		warn "Can't find optional false negative environment file; ignoring.\n";

	} elsif( $file =~ /\.fp\.ff/ ) {
		warn "Can't find optional false positive environment file; ignoring.\n";

	} elsif( $file =~ /\.(?:pos|neg)\.ff/ ) {
		die "Can't find required positive/negative environment file '$file' or '$file.gz' for reading $!";

	} else {
		die "Can't find file '$file' or '$file.gz' for reading $!";
	}
	return $contents;
}

# ============================================================
sub _read_subsets_file {
# ============================================================
	my $self               = shift;
	my $n                  = shift;
	my $store_path         = $self->{ store_path };
	my $model              = $self->{ model };
	my $subsets_file       = "$store_path/$model/$model.subsets";
	my $subset_assignments = '';
	my $posneg;
	my $n_from_file;

	# ===== PARSE THE GROUP ASSIGNMENT FILE
	open FILE, $subsets_file or die "Can't open subset assignments file '$subsets_file' for reading $!";
	while( <FILE> ) {
		next if /^#/;
		chomp;
		if     ( /^\[SUBSETS\](\d+)\[END-SUBSETS\]/ ) {
			$n_from_file        = $1;
			die "Subset assignments file '$subsets_file' reports $n_from_file subsets, but $n subsets requested $!" if( $n_from_file != $n );
		} elsif( /^\[POSITIVE\]/ ) {
			$posneg             = "pos";
			$subset_assignments = '';

		} elsif( /^\[NEGATIVE\]/ ) {
			$posneg             = "neg";
			$subset_assignments = '';

		} elsif( /^\[END-(?:POSITIVE|NEGATIVE)\]/ ) {
			$subset_assignments = [ split( //, $subset_assignments ) ];
			$self->_apply_subset_file_assignments_to_samples( $posneg, $subset_assignments );

		} else {
			$subset_assignments .= $_;
		}
	}
	close FILE;
	return $n_from_file;
}

# ============================================================
sub _shuffle_and_deal {
# ============================================================
# Randomly shuffles an ordering and assigns them into subsets.
# Imagine having k cards and n players; if you shuffle the 
# cards and deal to the players, each player has a random
# ordering of cards and a uniform distribution of red and
# black suits, no matter how many red cards or black cards
# are in the deck. 
#
# For example, if we had 5 positive samples and 45 negative 
# samples to be distributed to 5 groups, each subset would 
# randomly get one positive and 9 negative samples.
#
# By using subset assignments, one can easily reconstruct the
# subsets from the subset assignment file and the original
# feature vectors.
# ------------------------------------------------------------
	my $cards   = shift;
	my $players = shift;
	
	my $j     = 0;
	my @order = shuffle (0 .. $cards);
	my $hands = [];
	for my $i (0 .. $cards) {
		$hands->[ $order[ $i ] ] = chr( ord( 'A' ) + $j );
		$j++;
		$j %= $players;
	}
	return $hands;
}

# ============================================================
sub _text_wrap {
# ============================================================
	my $string = shift;
	my @string = @$string;
	my @text = ();
	while( @string ) {
		if( @string > 79 ) {
			push @text, (join( "", splice @string, 0, 78 ) . "\n");
		} else {
			push @text, (join( "", splice @string, 0 ). "\n");
		}
	}
	return join( "", @text );
}

=head1 COPYRIGHT

Copyright 2012 Mike Wong
Permission is granted to copy, distribute and/or modify this document under the
terms of the GNU Free Documentation License, Version 1.2 or any later version
published by the Free Software Foundation; with no Invariant Sections, with no
Front-Cover Texts, and with no Back-Cover Texts.

=cut

1;
