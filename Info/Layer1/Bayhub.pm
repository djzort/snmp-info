# SNMP::Info::Layer1::Bayhub
# Eric Miller <eric@jeneric.org>
#
# Copyright (c) 2004 Max Baker changes from version 0.8 and beyond.
#
# Copyright (c) 2002,2003 Regents of the University of California
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the University of California, Santa Cruz nor the 
#       names of its contributors may be used to endorse or promote products 
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

package SNMP::Info::Layer1::Bayhub;
$VERSION = 0.9;
use strict;

use Exporter;
use SNMP::Info;
use SNMP::Info::Bridge;
use SNMP::Info::NortelStack;
use SNMP::Info::SONMP;

@SNMP::Info::Layer1::Bayhub::ISA = qw/SNMP::Info SNMP::Info::Bridge SNMP::Info::NortelStack SNMP::Info::SONMP Exporter/;
@SNMP::Info::Layer1::Bayhub::EXPORT_OK = qw//;

use vars qw/$VERSION %FUNCS %GLOBALS %MIBS %MUNGE $AUTOLOAD $INIT $DEBUG/;

%MIBS    = (
	    %SNMP::Info::MIBS,
            %SNMP::Info::Bridge::MIBS,
            %SNMP::Info::NortelStack::MIBS,	    
            %SNMP::Info::SONMP::MIBS,
            'S5-ETHERNET-COMMON-MIB'	=> 's5EnPortTable',
            'S5-COMMON-STATS-MIB'	=> 's5CmStat',
            );

%GLOBALS = (
            %SNMP::Info::GLOBALS,
            %SNMP::Info::Bridge::GLOBALS,
            %SNMP::Info::NortelStack::GLOBALS,
            %SNMP::Info::SONMP::GLOBALS,
	    );

%FUNCS   = (
            %SNMP::Info::FUNCS,
            %SNMP::Info::Bridge::FUNCS,
            %SNMP::Info::NortelStack::FUNCS,
            %SNMP::Info::SONMP::FUNCS,
            # S5-ETHERNET-COMMON-MIB::s5EnPortTable
            'bayhub_pb_index'	=> 's5EnPortBrdIndx',
            'bayhub_pp_index'	=> 's5EnPortIndx',
            'bayhub_up_admin'	=> 's5EnPortPartStatus',
            'bayhub_up'		=> 's5EnPortLinkStatus',
	    # S5-COMMON-STATS-MIB::s5CmSNodeTable
            'bayhub_nb_index'	=> 's5CmSNodeBrdIndx',
            'bayhub_np_index'	=> 's5CmSNodePortIndx',
            'fw_mac'		=> 's5CmSNodeMacAddr',
            );

%MUNGE   = (
            %SNMP::Info::MUNGE,
            %SNMP::Info::Bridge::MUNGE,
            %SNMP::Info::NortelStack::MUNGE,
            %SNMP::Info::SONMP::MUNGE,
            );

sub layers {
    return '00000011';
}

sub os {
    return 'bay_hub';
}

sub vendor {
    return 'nortel';
}

sub model {
    my $bayhub = shift;
    my $id = $bayhub->id();
    return undef unless defined $id;
    my $model = &SNMP::translateObj($id);
    return $id unless defined $model;
    $model =~ s/^sreg-//i;

    return 'Baystack Hub' if ($model =~ /BayStackEth/);
    return '5000' if ($model =~ /5000/);
    return '5005' if ($model =~ /5005/);
    return $model;
}

# Hubs do not support ifMIB requirements for get MAC
# and port status 
sub i_index {
    my $bayhub = shift;
    my $b_index = $bayhub->bayhub_pb_index();
    my $p_index = $bayhub->bayhub_pp_index();
    my $model = $bayhub->model();

    my %i_index;
    foreach my $iid (keys %$b_index){
        my $board = $b_index->{$iid};
        next unless defined $board;
        my $port = $p_index->{$iid}||0;

        if ($model eq 'Baystack Hub') {
            my $comidx = $board;
               if (! ($comidx % 5)) {
                  $board = ($board / 5);
               } elsif ($comidx =~ /[16]$/) {
                  $board = int($board/5);
                  $port = 25;          
               } elsif ($comidx =~ /[27]$/) {
                  $board = int($board/5);
                  $port = 26;          
               }
          }

	my $index = ($board*256)+$port;

	$i_index{$iid} = $index;
    }
    return \%i_index;
}

sub interfaces {
    my $bayhub = shift;
    my $i_index = $bayhub->i_index();

    my %if;
    foreach my $iid (keys %$i_index){
        my $index = $i_index->{$iid};
        next unless defined $index;

	# Index numbers are deterministic slot * 256 + port
	my $port = $index % 256;
        my $slot = int($index / 256);

        my $slotport = "$slot.$port";
    
        $if{$index} = $slotport;
    }

    return \%if;
}

sub i_duplex {
    my $bayhub = shift;
    my $port_index  = $bayhub->i_index();

    my %i_duplex;
    foreach my $iid (keys %$port_index){
        my $index = $port_index->{$iid};
        next unless defined $index;
    
        my $duplex = 'half';
        $i_duplex{$index}=$duplex; 
    }
    return \%i_duplex;
}

sub i_duplex_admin {
    my $bayhub = shift;
    my $port_index  = $bayhub->i_index();

    my %i_duplex_admin;
    foreach my $iid (keys %$port_index){
        my $index = $port_index->{$iid};
        next unless defined $index;
    
        my $duplex = 'half';
        $i_duplex_admin{$index}=$duplex; 
    }
    return \%i_duplex_admin;
}

sub i_speed {
    my $bayhub = shift;
    my $port_index  = $bayhub->i_index();

    my %i_speed;
    foreach my $iid (keys %$port_index){
        my $index = $port_index->{$iid};
        next unless defined $index;
    
        my $speed = '10 Mbps';
        $i_speed{$index}=$speed; 
    }
    return \%i_speed;
}

sub i_up {
    my $bayhub = shift;
    my $port_index = $bayhub->i_index();
    my $link_stat = $bayhub->bayhub_up();
   
    my %i_up;
    foreach my $iid (keys %$port_index){
        my $index = $port_index->{$iid};
        next unless defined $index;
        my $link_stat = $link_stat->{$iid};
	next unless defined $link_stat;
	
        $link_stat = 'up' if $link_stat =~ /on/i;
        $link_stat = 'down' if $link_stat =~ /off/i;
             
        $i_up{$index}=$link_stat; 
    }
    return \%i_up;
}

sub i_up_admin {
    my $bayhub = shift;
    my $i_index = $bayhub->i_index();
    my $link_stat = $bayhub->bayhub_up_admin();
 
    my %i_up_admin;
    foreach my $iid (keys %$i_index){
    	my $index = $i_index->{$iid};
    	next unless defined $index;
        my $link_stat = $link_stat->{$iid};
	next unless defined $link_stat;
 
        $i_up_admin{$index}=$link_stat; 
    }
    return \%i_up_admin;
}
# Hubs do not support the standard Bridge MIB
sub bp_index {
   my $bayhub = shift;
    my $b_index = $bayhub->bayhub_nb_index();
    my $p_index = $bayhub->bayhub_np_index();
    my $model = $bayhub->model();

    my %bp_index;
    foreach my $iid (keys %$b_index){
        my $board = $b_index->{$iid};
        next unless defined $board;
        my $port = $p_index->{$iid}||0;
		
        if ($model eq 'Baystack Hub') {
            my $comidx = $board;
               if (! ($comidx % 5)) {
                  $board = ($board / 5);
               } elsif ($comidx =~ /[16]$/) {
                  $board = int($board/5);
                  $port = 25;          
               } elsif ($comidx =~ /[27]$/) {
                  $board = int($board/5);
                  $port = 26;          
               }
          }

	my $index = ($board*256)+$port;

	$bp_index{$index} = $index;
    }
    return \%bp_index;
}

sub fw_port {
    my $bayhub = shift;
    my $b_index = $bayhub->bayhub_nb_index();
    my $p_index = $bayhub->bayhub_np_index();
    my $model = $bayhub->model();

    my %fw_port;
    foreach my $iid (keys %$b_index){
        my $board = $b_index->{$iid};
        next unless defined $board;
        my $port = $p_index->{$iid}||0;

      if ($model eq 'Baystack Hub') {
          my $comidx = $board;
             if (! ($comidx % 5)) {
                $board = ($board / 5);
             } elsif ($comidx =~ /[16]$/) {
                $board = int($board/5);
                $port = 25;          
             } elsif ($comidx =~ /[27]$/) {
                $board = int($board/5);
                $port = 26;          
             }
       }
	
	my $index = ($board*256)+$port;

      $fw_port{$iid} = $index;
    }
    return \%fw_port;
}

sub index_factor {
    return 256;
}

sub slot_offset {
    return 0;
}

1;
__END__

=head1 NAME

SNMP::Info::Layer1::Bayhub - SNMP Interface to Bay / Nortel Hubs

=head1 AUTHOR

Eric Miller (C<eric@jeneric.org>)

=head1 SYNOPSIS

    #Let SNMP::Info determine the correct subclass for you.

    my $bayhub = new SNMP::Info(
                          AutoSpecify => 1,
                          Debug       => 1,
                          # These arguments are passed directly on to SNMP::Session
                          DestHost    => 'myswitch',
                          Community   => 'public',
                          Version     => 2
                        ) 

    or die "Can't connect to DestHost.\n";

    my $class = $bayhub->class();
    print "SNMP::Info determined this device to fall under subclass : $class\n";

=head1 DESCRIPTION

Provides abstraction to the configuration information obtainable from a 
Bayhub device through SNMP.  Also provides device MAC to port mapping through the propietary MIB. 

For speed or debugging purposes you can call the subclass directly, but not after determining
a more specific class using the method above. 

my $bayhub = new SNMP::Info::Layer1::Bayhub(...);

=head2 Inherited Classes

=over

=item SNMP::Info

=item SNMP::Info::Bridge

=item SNMP::Info::NortelStack

=item SNMP::Info::SONMP

=back

=head2 Required MIBs

=over

=item S5-ETHERNET-COMMON-MIB

=item S5-COMMON-STATS-MIB

=item Inherited Classes' MIBs

See SNMP::Info for its own MIB requirements.

See SNMP::Info::Bridge for its own MIB requirements.

See SNMP::Info::NortelStack for its own MIB requirements.

See SNMP::Info::SONMP for its own MIB requirements.

=back

MIBs can be found on the CD that came with your product.

Or, they can be downloaded directly from Nortel Networks regardless of support
contract status.  Go to http://www.nortelnetworks.com Technical Support, Browse Technical Support,
Select by Product Families, BayStack, BayStack: Hubs - 150 Series, 10BASE-T,
Software.  Filter on mibs and download the latest version's archive.

=head1 GLOBALS

These are methods that return scalar value from SNMP

=over

=item $bayhub->vendor()

Returns 'Nortel'

=item $bayhub->os()

Returns 'Bay Hub'

=item $bayhub->model()

Cross references $bayhub->id() to the SYNOPTICS-MIB and returns
the results.

Removes sreg- from the model name

=back

=head2 Overrides

=over

=item $bayhub->layers()

Returns 00000011.  Class emulates Layer 2 functionality through proprietary MIBs.

=item  $bayhub->index_factor()

Required by SNMP::Info::SONMP.  Number representing the number of ports
reserved per slot within the device MIB.  Returns 256.

=item $bayhub->slot_offset()

Required by SNMP::Info::SONMP.  Offset if slot numbering does not
start at 0.  Returns 0.

=back

=head2 Globals imported from SNMP::Info

See documentation in SNMP::Info for details.

=head2 Globals imported from SNMP::Info::Bridge

See documentation in SNMP::Info::Bridge for details.

=head2 Global Methods imported from SNMP::Info::NortelStack

See documentation in SNMP::Info::NortelStack for details.

=head2 Global Methods imported from SNMP::Info::SONMP

See documentation in SNMP::Info::SONMP for details.

=head1 TABLE ENTRIES

These are methods that return tables of information in the form of a reference
to a hash.

=head2 Overrides

=over

=item $bayhub->i_index()

Returns reference to map of IIDs to Interface index. 

Since hubs do not support ifIndex, the interface index is created using the
formula (board * 256 + port).

=item $bayhub->interfaces()

Returns reference to map of IIDs to physical ports. 

=item $bayhub->i_duplex()

Returns half, hubs do not support full duplex. 

=item $bayhub->i_duplex_admin()

Returns half, hubs do not support full duplex.

=item $bayhub->i_speed()

Currently returns 10 Mbps.  The class does not currently support 100 Mbps hubs.

=item $bayhub->i_up()

Returns (B<s5EnPortLinkStatus>) for each port.  Translates on/off to up/down.

=item $bayhub->i_up_admin()

Returns (B<s5EnPortPartStatus>) for each port.

=item $bayhub->bp_index()

Simulates bridge MIB by returning reference to a hash containing the index for
both the keys and values.

=item $bayhub->fw_port()

Returns reference to map of IIDs of the S5-COMMON-STATS-MIB::s5CmSNodeTable
to the Interface index.

=item $bayhub->fw_mac()

(B<s5CmSNodeMacAddr>)

=back

=head2 Table Methods imported from SNMP::Info

See documentation in SNMP::Info for details.

=head2 Table Methods imported from SNMP::Info::Bridge

See documentation in SNMP::Info::Bridge for details.

=head2 Table Methods imported from SNMP::Info::NortelStack

See documentation in SNMP::Info::NortelStack for details.

=head2 Table Methods imported from SNMP::Info::SONMP

See documentation in SNMP::Info::SONMP for details.

=cut
