package Cluster;
use Cluster::Lava;
use Cluster::SGE;

# ============================================================
sub new {
# ============================================================
	my ($class) = map { ref || $_ } shift;
	my $self = bless {}, $class;
	return $self->init( @_ );
}

# ============================================================
sub init {
# ============================================================
	my $self = shift;
	
	if   ( `which bsub` ) { return new Cluster::Lava(); } # Platform LAVA Scheduler
	elsif( `which qsub` ) { return new Cluster::SGE();  } # Sun Grid Engine
}

# ============================================================
sub submit {
# ============================================================
	my $self = shift;
	my $name = shift;
	my $job  = shift;

	die "Cluster has unknown scheduler $!";
}

# ============================================================
sub busy {
# ============================================================
	my $self = shift;

	die "Cluster has unknown scheduler $!";
}

1;
