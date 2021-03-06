package FusionInventory::Agent::Task::Deploy::P2P;

use strict;
use warnings;

use English qw(-no_match_vars);
use Net::IP;
use Net::Ping;
use Parallel::ForkManager;

use UNIVERSAL::require;

use FusionInventory::Agent::Logger;

sub new {
    my ($class, %params) = @_;

    my $self = {
        logger        => $params{logger} ||
                         FusionInventory::Agent::Logger->new(),
        max_workers   => $params{max_workers}   || 10,
        cache_timeout => $params{cache_timeout} || 600,
        scan_timeout  => $params{scan_timeout}  || 5,
        max_peers     => $params{max_peers}     || 5,
        max_size      => $params{max_size}      || 5000,
        cache_time    => 0,
        cache         => []
    };

    bless $self, $class;

    return $self;
}

sub findPeers {
    my ($self, $port) = @_;

#    $logger->debug("cachedate: ".$cache{date});
    $self->{logger}->info("looking for a peer in the network");
    return @{$self->{cache}}
        if time - $self->{cache_time} < $self->{cache_timeout};

    my @interfaces;

    if ($OSNAME eq 'linux') {
        FusionInventory::Agent::Tools::Linux->require();
        @interfaces = FusionInventory::Agent::Tools::Linux::getInterfacesFromIfconfig();

    } elsif ($OSNAME eq 'MSWin32') {
        FusionInventory::Agent::Tools::Win32->require();
        @interfaces = FusionInventory::Agent::Tools::Win32::getInterfaces();
    }

    if (!@interfaces) {
        $self->{logger}->info("No network interfaces found");
        return;
    }

    my @addresses;

    foreach my $interface (@interfaces) {
#if interface has both ip and netmask setup then push the address
        next unless $interface->{IPADDRESS};
        next unless $interface->{IPMASK};
        next unless lc($interface->{STATUS}) eq 'up';

        push @addresses, {
            ip   => $interface->{IPADDRESS},
            mask => $interface->{IPMASK}
        };
    }

    if (!@addresses) {
        $self->{logger}->info("No local address found");
        return;
    }

    my @potential_peers;
    
    foreach my $address (@addresses) {
        push @potential_peers, $self->_getPotentialPeers($address);
    }

    if (!@potential_peers) {
        $self->{logger}->info("No neighbour address found");
        return;
    }

    $self->{cache_time} = time;
    $self->{cache}      = [ $self->_scanPeers($port, @potential_peers) ];

    return @{$self->{cache}};
}

sub _getPotentialPeers {
    my ($self, $address, $limit) = @_;

    $limit = $self->{max_peers} unless defined $limit;

    my @ipToTest;

    my @ip_bytes   = split(/\./, $address->{ip});
    my @mask_bytes = split(/\./, $address->{mask});
    return if $ip_bytes[0] == 127; # Ignore 127.x.x.x addresses
    return if $ip_bytes[0] == 169; # Ignore 169.x.x.x range too

    # compute range
    my @start;
    my @end;

    foreach my $idx (0..3) {
        ## no critic (ProhibitBitwise)
        push @start, $ip_bytes[$idx] & (255 & $mask_bytes[$idx]);
        push @end,   $ip_bytes[$idx] | (255 - $mask_bytes[$idx]);
    }

    my $ipStart = join('.', @start);
    my $ipEnd   = join('.', @end);
    return if $ipStart eq $ipEnd;

    my $ipInterval = Net::IP->new($ipStart.' - '.$ipEnd) || die Net::IP::Error();

    my $size = $ipInterval->size();
    if ($size > $self->{max_size}) {
        $self->{logger}->debug(
            "Range too large: $size (max $self->{max_size})"
        );
        return;
    }

    my $after = 0;
    my @peers;
    do {
        push @peers, $ipInterval->ip();
        if ($after || $address->{ip} eq $ipInterval->ip()) {
            $after++;
        } elsif (@peers > ($limit / 2)) {
            shift @peers;
        }
    } while (++$ipInterval && ($after < ($limit / 2)));

    return @peers;
}

sub _scanPeers {
    my ($self, $port, @addresses) = @_;

    $self->{logger}->debug(
        "Scanning from $addresses[0] to $addresses[-1]"
    );

    _fisher_yates_shuffle(\@addresses);

    my $ping = Net::Ping->new('tcp');
    $ping->{port_num} = $port;
    $ping->service_check(1);

    my @found;

    my $manager = Parallel::ForkManager->new($self->{max_workers});
    $manager->run_on_finish(sub {
        my ($pid, $exit_code, $address) = @_;
        push @found, $address if $exit_code;
     });

    foreach my $address (@addresses) {
        $manager->start($address) and next;
        $manager->finish($ping->ping($address, $self->{scan_timeout}) ? 1 : 0);
    }

    return @found;
}

sub _fisher_yates_shuffle {
    my $deck = shift;  # $deck is a reference to an array

    return unless @$deck; # must not be empty!

    my $i = @$deck;
    while (--$i) {
        my $j = int rand ($i+1);
        @$deck[$i,$j] = @$deck[$j,$i];
    }
}

1;
