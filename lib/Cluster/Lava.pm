package Cluster::Lava;

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

	print "bsub -P $name $job\n";
	`bsub -P $name $job`;
}

# ============================================================
sub busy {
# ============================================================
	my $self = shift;
	my $name = shift;

	my @nodes = `bhosts | grep -e ok -e closed`;
	my $total = 0;
	foreach my $node (@nodes) {
		chomp $node;
		my ($name, $status, $jlu, $max) = split /\s+/, $node;
		$total += $max;
	}

	my @jobs  = `bjobs -P $name`;
	shift @jobs; # Drop the header

	return (int( @jobs ) >= $total);
}

1;
