package Cluster::SGE;

# ============================================================
sub new {
# ============================================================
	my ($class) = map { ref || $_ } shift;
	my $self = bless {}, $class;
	$self->init( @_ );
	return $self;
}

# ============================================================
sub submit {
# ============================================================
	my $self = shift;
	my $name = shift;
	my $job  = shift;

	print "qsub -N $name $job\n";
	`qsub -N $name $job`;
}

# ============================================================
sub busy {
# ============================================================
	my $self = shift;
	my $name = shift;

	my @nodes = `qhost | grep compute`;
	my $total = 0;
	foreach my $node (@nodes) {
		chomp $node;
		my ($name, $arch, $ncpu) = split /\s+/, $node;
		$total += $ncpu;
	}

	my @jobs  = `qstat | grep $name`;

	return (int( @jobs ) >= $total);
}

1;
