#!/usr/bin/perl

use strict;
use warnings;

use Test::Deep;
use Test::More;

use FusionInventory::Agent::SNMP::Client::Virtual;
use FusionInventory::Agent::Tools::Hardware;

my @mac_tests = (
    [ 'd2:05:a8:6c:26:d5' , 'd2:05:a8:6c:26:d5' ],
    [ '0xD205A86C26D5'    , 'd2:05:a8:6c:26:d5' ],
    [ '0x6001D205A86C26D5', 'd2:05:a8:6c:26:d5' ],
);

# each item is an arrayref of 3 elements:
# - raw SNMP values
# - expected output
# - test description
my @cdp_info_extraction_tests = (
    [
        {
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.4.24.7' => [ 'STRING', '0xc0a8148b' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.5.24.7' => [ 'STRING', '7.4.9c' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.6.24.7' => [ 'STRING', 'SIPE05FB981A7A7' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.7.24.7' => [ 'STRING', 'Port 1' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.8.24.7' => [ 'STRING', 'Cisco IP Phone SPA508G' ],
        },
        {
            24 => {
                MAC      => 'e0:5f:b9:81:a7:a7',
                SYSDESCR => '7.4.9c',
                IFDESCR  => 'Port 1',
                MODEL    => 'Cisco IP Phone SPA508G',
                IP       => '192.168.20.139',
                SYSNAME  => 'SIPE05FB981A7A7'
             }
        },
        'CDP info extraction'
    ],
    [
        {
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.4.24.7' => [ 'STRING', '0xc0a8148b' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.6.24.7' => [ 'STRING', 'SIPE05FB981A7A7' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.7.24.7' => [ 'STRING', 'Port 1' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.8.24.7' => [ 'STRING', 'Cisco IP Phone SPA508G' ],
        },
        undef,
        'CDP info extraction, missing CDP cache version'
    ],
    [
        {
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.4.24.7' => [ 'STRING', '0xc0a8148b' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.5.24.7' => [ 'STRING', '7.4.9c' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.6.24.7' => [ 'STRING', 'SIPE05FB981A7A7' ],
            '.1.3.6.1.4.1.9.9.23.1.2.1.1.7.24.7' => [ 'STRING', 'Port 1' ],
        },
        undef,
        'CDP info extraction, missing CDP cache platform'
    ],
);

# each item is an arrayref of 3 elements:
# - raw SNMP values
# - expected output
# - test explication
my @mac_addresses_extraction_tests = (
    [
        {
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.106' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.1.4.1.2.52'                => [ 'INTEGER', 52 ],
        },
        {
            52 => [ '00:00:74:d2:09:6a' ]
        },
        'mac addresses extraction, single address'
    ],
    [
        {
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.106' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.107' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.1.4.1.2.52'                => [ 'INTEGER', 52 ],
        },
        {
            52 => [ '00:00:74:d2:09:6a', '00:00:74:d2:09:6b' ]
        },
        'mac addresses extraction, two addresses'
    ],
);

# each item is an arrayref of 4 elements:
# - raw SNMP values
# - initial port list
# - expected final port list
# - test explication
my @mac_addresses_addition_tests = (
    [
        {
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.106' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.1.4.1.2.52'                => [ 'INTEGER', 52 ],
        },
        {
            52 => {
            }
        },
        {
            52 => {
                CONNECTIONS => {
                    CONNECTION => {
                        MAC => [ '00:00:74:d2:09:6a' ]
                    }
                },
            }
        },
        'mac addresses addition, single address'
    ],
    [
        {
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.106' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.107' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.1.4.1.2.52'                => [ 'INTEGER', 52 ],
        },
        {
            52 => {
            }
        },
        {
            52 => {
                CONNECTIONS => {
                    CONNECTION => {
                        MAC => [ '00:00:74:d2:09:6a', '00:00:74:d2:09:6b' ]
                    }
                },
            }
        },
        'mac addresses addition, two addresses'
    ],
    [
        {
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.106' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.107' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.1.4.1.2.52'                => [ 'INTEGER', 52 ],
        },
        {
            52 => {
                CONNECTIONS => {
                    CDP => 1,
                },
            }
        },
        {
            52 => {
                CONNECTIONS => {
                    CDP => 1,
                },
            }
        },
        'mac addresses addition, CDP/LLDP info already present'
    ],
    [
        {
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.106' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.4.3.1.2.0.0.116.210.9.107' => [ 'INTEGER', 52 ],
            '.1.3.6.1.2.1.17.1.4.1.2.52'                => [ 'INTEGER', 52 ],
        },
        {
            52 => {
                MAC => '00:00:74:d2:09:6a',
            }
        },
        {
            52 => {
                MAC         => '00:00:74:d2:09:6a',
                CONNECTIONS => {
                    CONNECTION => {
                        MAC => [ '00:00:74:d2:09:6b' ]
                    }
                },
            }
        },
        'mac addresses addition, exclusion of port own address'
    ],
);

# each item is an arrayref of 3 elements:
# - raw SNMP values
# - expected output
# - test description
my @trunk_ports_extraction_tests = (
    [
        {
            '.1.3.6.1.4.1.9.9.46.1.6.1.1.14.0' => [ 'INTEGER', 1  ],
            '.1.3.6.1.4.1.9.9.46.1.6.1.1.14.1' => [ 'INTEGER', 0  ],
            '.1.3.6.1.4.1.9.9.46.1.6.1.1.14.2' => [ 'INTEGER', 1  ]
        },
        {
            0 => 1,
            1 => 0,
            2 => 1,
        },
        'trunk ports extraction'
    ]
);

plan tests =>
    scalar @mac_tests                      +
    scalar @cdp_info_extraction_tests      +
    scalar @mac_addresses_extraction_tests +
    scalar @mac_addresses_addition_tests   +
    scalar @trunk_ports_extraction_tests   +
    8;

foreach my $test (@mac_tests) {
    is(
        FusionInventory::Agent::Tools::Hardware::_getCanonicalMacAddress($test->[0]),
        $test->[1],
        "$test->[0] normalisation"
    );
}

my $snmp1 = FusionInventory::Agent::SNMP::Client::Virtual->new(
    hash => {
        '.1.3.6.1.2.1.1.1.0'        => [ 'STRING', 'foo' ],
    }
);

my $device1 = getDeviceInfo(snmp => $snmp1);
cmp_deeply(
    $device1,
    { DESCRIPTION => 'foo' },
    'getDeviceInfo() with no sysobjectid'
);

my $snmp2 = FusionInventory::Agent::SNMP::Client::Virtual->new(
    hash => {
        '.1.3.6.1.2.1.1.1.0'        => [ 'STRING', 'foo' ],
        '.1.3.6.1.2.1.1.2.0'        => [ 'STRING', '.1.3.6.1.4.1.45' ],
    }
);

my $device2 = getDeviceInfo(snmp => $snmp2);
cmp_deeply(
    $device2,
    {
        DESCRIPTION  => 'foo',
    },
    'getDeviceInfo() with sysobjectid'
);

my $device3 = getDeviceInfo(snmp => $snmp2, datadir => './share');
cmp_deeply(
    $device3,
    {
        DESCRIPTION  => 'foo',
        TYPE         => 'NETWORKING',
        MANUFACTURER => 'Nortel',
        VENDOR       => 'Nortel'
    },
    'getDeviceInfo() with sysobjectid'
);

foreach my $test (@cdp_info_extraction_tests) {
    my $snmp  = FusionInventory::Agent::SNMP::Client::Virtual->new(hash => $test->[0]);

    my $cdp_info = FusionInventory::Agent::Tools::Hardware::_getCDPInfo(
        snmp  => $snmp,
    );

    cmp_deeply(
        $cdp_info,
        $test->[1],
        $test->[2]
    );
}

foreach my $test (@mac_addresses_extraction_tests) {
    my $snmp = FusionInventory::Agent::SNMP::Client::Virtual->new(hash => $test->[0]);

    my $mac_addresses = FusionInventory::Agent::Tools::Hardware::_getKnownMacAddresses(
        snmp           => $snmp,
        address2port   => '.1.3.6.1.2.1.17.4.3.1.2',
        port2interface => '.1.3.6.1.2.1.17.1.4.1.2',
    );

    cmp_deeply(
        $mac_addresses,
        $test->[1],
        $test->[2]
    );
}

foreach my $test (@mac_addresses_addition_tests) {
    my $snmp  = FusionInventory::Agent::SNMP::Client::Virtual->new(hash => $test->[0]);

    FusionInventory::Agent::Tools::Hardware::_setKnownMacAddresses(
        snmp  => $snmp,
        ports => $test->[1],
    );

    cmp_deeply(
        $test->[1],
        $test->[2],
        $test->[3]
    );
}

foreach my $test (@trunk_ports_extraction_tests) {
    my $snmp = FusionInventory::Agent::SNMP::Client::Virtual->new(hash => $test->[0]);

    my $trunk_ports = FusionInventory::Agent::Tools::Hardware::_getTrunkPorts(
        snmp  => $snmp,
    );

    cmp_deeply(
        $trunk_ports,
        $test->[1],
        $test->[2]
    );
}

my $oid = '0.1.2.3.4.5.6.7.8.9';
is(
    FusionInventory::Agent::Tools::Hardware::_getElement($oid, 0),
    0,
    'index 0'
);
is(
    FusionInventory::Agent::Tools::Hardware::_getElement($oid, -1),
    9,
    'index -1'
);
is(
    FusionInventory::Agent::Tools::Hardware::_getElement($oid, -2),
    8,
    'index -2'
);
cmp_deeply(
    [ FusionInventory::Agent::Tools::Hardware::_getElements($oid, 0, 3) ],
    [ qw/0 1 2 3/ ],
    'getElements with index 0 to 3'
);
cmp_deeply(
    [ FusionInventory::Agent::Tools::Hardware::_getElements($oid, -4, -1) ],
    [ qw/6 7 8 9/ ],
    'getElements with index -4 to -1'
);
