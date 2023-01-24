##############################################
# $Id: 15_jkbms.pm 2022-02-14 09:25:24Z stephanaugustin $
# This Module is reading Values from JK-B2A24S20P BMS  and offers them as readings.
# test
package main;

use strict;
use warnings;
use DevIo;
<<<<<<< HEAD
=======
## default Vars
##{{{
my %req_warn = (
	## get alarm information; 3.7
    'WARN1' => "20014644E00201",    ## Warnings of the Cells
    'WARN2' => "20014644E00202",    ## Warnings of the Cells
    'WARN3' => "20014644E00203",    ## Warnings of the Cells
    'WARN4' => "20014644E00204",    ## Warnings of the Cells
    'WARN5' => "20014644E00205",    ## Warnings of the Cells
    'WARN6' => "20014644E00206",    ## Warnings of the Cells
    'WARN7' => "20014644E00207",    ## Warnings of the Cells
    'WARN8' => "20014644E00208"     ## Warnings of the Cells
);
my %req_warn_sm = (
	'WARN' => "44E002"
);	## Warnings of the Cells
my %req_packstate = (
	## get analog value; 3.5
    'PACKSTATE1' => "20014692E00201",    ## Number of Packs
    'PACKSTATE2' => "20014692E00202",    ## Number of Packs
    'PACKSTATE3' => "20014692E00203",    ## Number of Packs
    'PACKSTATE4' => "20014692E00204",    ## Number of Packs
    'PACKSTATE5' => "20014692E00205",    ## Number of Packs
    'PACKSTATE6' => "20014692E00206",    ## Number of Packs
    'PACKSTATE7' => "20014692E00207",    ## Number of Packs
    'PACKSTATE8' => "20014692E00208"     ## Number of Packs
);
my $req_packstate_sm = "92E002"; ## get analog Values 
my %req_cell = (
    'CELL1' => "20014642E00201",         ## Values of Cells, voltages, temperatures
    'CELL2' => "20014642E00202",         ## Values of Cells, voltages, temperatures
    'CELL3' => "20014642E00203",         ## Values of Cells, voltages, temperatures
    'CELL4' => "20014642E00204",         ## Values of Cells, voltages, temperatures
    'CELL5' => "20014642E00205",         ## Values of Cells, voltages, temperatures
    'CELL6' => "20014642E00206",         ## Values of Cells, voltages, temperatures
    'CELL7' => "20014642E00207",         ## Values of Cells, voltages, temperatures
    'CELL8' => "20014642E00208"          ## Values of Cells, voltages, temperatures
);

my $req_cell_sm = "42E002"; ## Values of Cells, voltages, temperatures

my %req_adm = (
##    'NOP' => "200146900000",              ## Number of Packs Check FDAA ##get Pack Number 3.2 Packs as Attribute
    'VERSION' => "200146510000",          ## Firmware version ## get Manufacturer information; 3.3
    'XXX' => "2001464F0000"	      ## get Protocol version; 3.1	
);

my %requests = (
    'CELL' => "42E002",         ## Values of Cells, voltages, temperatures
    'WARN' => "44E002",    ## Warnings of the Cells
    'PACK' => "92E002"    ## Number of Packs
);
##my $ver_hex = "3230"; version
##my $adr = ""; ## Adr: 01 for 232; 02-09 for 485
##my $cid1_hex = "46";
##my $ord_hex = "42";# specifies what i really want to know
##my $length_hex = "E0";
##my $info = ""; ##Number of pack. Adr: 01-08 for RS232; Adr: 02-09 for RS485. same as $adr.
##my $chksum = ""; ## wird später über den kompletten befehl berechnet

##my $adr_hex = ""; ## $adr in hex umwandeln;
##
##my $compound .= $ver_hex . $adr_hex . $cid_hex . $ord_hex . $length_hex . $info_hex


##}}}

>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
#####################################
sub jkbms_Initialize
{
##{{{
    my ($hash) = @_;

    #require "$attr{global}{modpath}/FHEM/DevIo.pm";

    $hash->{DefFn}    = "jkbms_Define";
    $hash->{SetFn}    = "jkbms_Set";
    $hash->{GetFn}    = "jkbms_Get";
    $hash->{UndefFn}  = "jkbms_Undef";
    $hash->{NotifyFn} = "jkbms_Notify";
    $hash->{ReadFn}   = "jkbms_Read";
    $hash->{ReadyFn}  = "jkbms_Ready";
    $hash->{AttrFn}   = "jkbms_Attr";
    $hash->{AttrList} = "unknown_as_reading:yes,no interval " . $readingFnAttributes;
    
    $hash->{helper}{value}           = q{};
    $hash->{helper}{key}             = q{};
    $hash->{helper}{timer_adm}       = q{};
    $hash->{helper}{timer_warn}      = q{};
    $hash->{helper}{timer_cell}      = q{};
    $hash->{helper}{timer_packstate} = q{};
    return;
##}}}
}

#####################################
sub jkbms_Define
{
##{{{
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );

    if ( @a < 3 || @a > 5 )
    {
        my $msg = "wrong syntax: define <name> jkbms <device> @115200";
        return $msg;
    }
    my $name   = $a[0];
    my $device = $a[2];

    $hash->{NAME} = $name;
    ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
    $hash->{DeviceName}  = $device;
    $hash->{NOTIFYDEV}   = "global";
    $hash->{actionQueue} = [];

    #close connection if maybe open (on definition modify)
    if ( DevIo_IsOpen($hash) )
    {
	    DevIo_CloseDev($hash);
    }
<<<<<<< HEAD
    Log3( $name, 4, "jkbms ($name) DevIO_OpenDev_Define" . __LINE__ );
    
    if(!IsDisabled($name) && AttrVal($name, "interval", "none") ne "none"){
    	readingsSingleUpdate($hash, "1_status", "starting sendRequest in 10 Seconds",1); 
=======
    Log3( $name, 4, "jkbms DevIO_OpenDev_Define" . __LINE__ );
    
    if(!IsDisabled($name) && AttrVal($name, "interval", "none") ne "none"){
    	readingsSingleUpdate($hash, "1_status", "starting sendRequests in 10 Seconds",1); 
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
    	readingsSingleUpdate($hash, "1_version", "1",1); 
    	InternalTimer( gettimeofday() + 10, 'jkbms_sendRequest', $hash );
	}
    return DevIo_OpenDev( $hash, 0, "jkbms_DoInit" );
##}}}
}
########
sub jkbms_DoInit
{
##{{{
    my ($hash) = @_;
    my $name = $hash->{NAME};
<<<<<<< HEAD
    Log3( $name, 2, "jkbms ($name) DoInitfkt _Line:" . __LINE__ );
   InternalTimer( gettimeofday() + 10, 'jkbms_sendRequest', $hash );
=======
    Log3( $name, 2, "DoInitfkt" );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
    return;
##}}}
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub jkbms_Ready
{
##{{{
    my ($hash) = @_;
    my $name = $hash->{NAME};
    $hash->{helper}{newconn} = 'true';    ## remind the new connection and ask for number of packs
    return DevIo_OpenDev( $hash, 1, "jkbms_DoInit" );
##}}}
}
###################################
sub jkbms_Notify
{
##{{{
    #    my ( $hash, $dev ) = @_;
    #    my $name = $hash->{NAME};
    #
    #    Log3 $name, 4, "jkbms ($name) - jkbms_Notify  Line: " . __LINE__;
    #    return if ( IsDisabled($name) );
    #    my $devname = $dev->{NAME};
    #    my $devtype = $dev->{TYPE};
    #    my $events  = deviceEvents( $dev, 1 );
    #    Log3 $name, 4, "jkbms ($name) - jkbms_Notify - not disabled  Line: " . __LINE__;
    #    return if ( !$events );
    #    Log3 $name, 4, "jkbms ($name) - jkbms_Notify got events @{$events} Line: " . __LINE__;
    #    	InternalTimer( gettimeofday() + 1, 'jkbms_sendRequests', $hash );
    #      if ( grep { /^INITIALIZED$/ } @{$events}
    #        or grep { /^CONNECTED$/ } @{$events}
    #        or grep { /^DELETEATTR.$name.disable$/ } @{$events}
    #        or ( grep { /^DEFINED.$name$/ } @{$events} and $init_done ) );
    #
    return;

##}}}
}
#####################################
sub jkbms_Undef
{
##{{{
    my ( $hash, $name ) = @_;
    DevIo_CloseDev($hash);
    RemoveInternalTimer($hash);
    return;
##}}}
}
#####################################
sub jkbms_Attr
{
##{{{
    my ( $cmd, $name, $attrName, $attrValue  ) = @_;
    my $hash = $defs{$name};
    $hash->{helper}{$attrName} = $attrValue;
    
    Log3( $name, 1, "jkbms ($name) attr $attrName $attrValue _Line: " . __LINE__ );
 return;
##}}}
}
#######################################
sub jkbms_Set
{
##{{{
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};
<<<<<<< HEAD
    my $usage = "Unknown argument $a[1], choose one of reopen:noArg cmd _requestall activate";
=======
    my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg cmd _requestall activate";
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
    my $ret;
    my $platzhalter;
    Log3( $name, 4, "jkbms  ($name) argument $a[1] _Line: " . __LINE__ );
    if ( $a[1] eq '?' )
    {
        Log3( $name, 4, "jkbms  ($name) argument question _Line: " . __LINE__ );
        return $usage;
    }elsif ( $a[1] eq 'reopen' )
    {
    	RemoveInternalTimer($hash);
        if ( DevIo_IsOpen($hash) )
        {
            Log3( $name, 1, "D ($name) evice is open, closing ... Line: " . __LINE__ );
            DevIo_CloseDev($hash);
            Log3( $name, 1, " ($name) jkbms Device closed Line: " . __LINE__ );
        }
        Log3( $name, 1, "jkbms_Set   ($name) Device is closed, trying to open Line: " . __LINE__ );
        $ret = DevIo_OpenDev( $hash, 1, "jkbms_DoInit" );
        while ( !DevIo_IsOpen($hash) )
        {
            Log3( $name, 1, "jkbms_Set ($name) Device is closed, opening failed, retrying" . __LINE__ );
            $ret = DevIo_OpenDev( $hash, 1, "jkbms_DoInit" );
            sleep 1;
        }
<<<<<<< HEAD
	##InternalTimer( gettimeofday() + 1, 'jkbms_sendRequest', $hash );
        return "device opened";
    } elsif ( $a[1] eq "restart" )
    {
    	RemoveInternalTimer($hash);
	InternalTimer( gettimeofday() + 1, 'jkbms_sendRequest', $hash );
=======
	##InternalTimer( gettimeofday() + 1, 'jkbms_sendRequests', $hash );
        return "device opened";
    } elsif ( $a[1] eq "reset" )
    {
    	RemoveInternalTimer($hash);
        $hash->{helper}{value} = q{}; # empty string
        $hash->{helper}{key}   = q{}; # empty string
        @{ $hash->{actionQueue} } = (); # empty array
        Log3( $name, 1, "jkbms_Set ($name) actionQueue is empty: @{$hash->{actionQueue}} Line:" . __LINE__ );
	##	readingsSingleUpdate($hash, "1_status", "starting sendRequests",1); 
	##InternalTimer( gettimeofday() + 1, 'jkbms_sendRequests', $hash );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
    }elsif($a[1] eq "cmd"){
            Log3( $name, 1, "jkbms_Set ($name) cmd=$a[2] _Line: " . __LINE__ );
	    	##my $val = jkbms_addChecksum($hash, $a[2]);
        	DevIo_SimpleWrite( $hash, $a[2], 1 );
		##Log3( $name, 1, "jkbms_Set   cmd=$a[2], return= $val _Line: " . __LINE__ );
    }elsif($a[1] eq "activate"){
	my $cmd = "4E5700130000000001030000000000006800000124";
	##4E57
	##0013
	##0000
	##0000
	##06
	##0000
	##0000
	##0000
	##0068
	##0000
	##0124";
    	readingsSingleUpdate($hash, "activate", "$cmd",1); 
       	DevIo_SimpleWrite( $hash, $cmd, 1 );
    }elsif($a[1] eq "_requestall"){
<<<<<<< HEAD
	my $cmd = "4E5700130000000006030000000000006800000129";
    	my $var = pack("(H2)*", $cmd);
        Log3( $name, 0, "jkbms ($name)  cmd $cmd Line: " . __LINE__ );
        Log3( $name, 0, "jkbms ($name)  packed $var Line: " . __LINE__ );
	readingsSingleUpdate($hash, "requestall", "$cmd",1); 
	my $size = length($hash->{helper}{NEW});
	$size //= '0';
        Log3( $name, 3, "jkbms ($name) size $size _Line: " . __LINE__ );
       	if($size > 1000){
		$hash->{helper}{NEW} = q{};
	        Log3( $name, 3, "jkbms ($name) size $size _Line: " . __LINE__ );
	}	
	
	DevIo_SimpleWrite( $hash, $cmd, 1 );
=======
	    my $cmd = "4E5700130000000006030000000000006800000129";
    	my $var = pack("(H2)*", $cmd);
    Log3( $name, 0, "jkbms ($name)  cmd $cmd Line: " . __LINE__ );
    Log3( $name, 0, "jkbms ($name)  packed $var Line: " . __LINE__ );
	    
	    
	    
	   readingsSingleUpdate($hash, "requestall", "$cmd",1); 
       	DevIo_SimpleWrite( $hash, $cmd, 1 );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
    }

    return;
##}}}
}
#####################################
sub jkbms_Get
{
##{{{
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};
    my $usage = "Unknown argument $a[1], choose one of calcHex";
<<<<<<< HEAD
    Log3( $name, 5, "jkbms ($name) argument $a[1] _Line: " . __LINE__ );
=======
    Log3( $name, 5, "jkbms ($name) argument $a[1]_Line: " . __LINE__ );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
    if ( $a[1] eq '?' )
    {
        Log3( $name, 5, "jkbms ($name) argument question_Line: " . __LINE__ );
        return $usage;
    }
    return;
##}}}
}
############################################
sub jkbms_sendRequest
{
my ($hash, $value) = @_;
my $name = $hash->{NAME};

my $cmd = "4E5700130000000006030000000000006800000129";
<<<<<<< HEAD
        Log3( $name, 3, "jkbms ($name) sendRequest sending cmd $cmd _Line: " . __LINE__ );
=======

        Log3( $name, 5, "jkbms ($name) sendRequest sending cmd $cmd _Line: " . __LINE__ );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
	DevIo_SimpleWrite( $hash, $cmd, 1 );

return; 
}
################################################################################
sub jkbms_Read
{

##{{{
    my ($hash) = @_;
    my $name = $hash->{NAME};
<<<<<<< HEAD
##    readingsSingleUpdate( $hash, "1_status", "communication in progress", 1 );
    Log3( $name, 3, "jkbms ($name) currently reading _Line:" . __LINE__ );
=======
    readingsSingleUpdate( $hash, "1_status", "communication in progress", 1 );
    Log3( $name, 5, "jkbms ($name) currently reading _Line:" . __LINE__ );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d

    # read from serial device
    my $buf = DevIo_SimpleRead($hash);
    
    $hash->{helper}{NEW} .= unpack("H*",$buf);	    
<<<<<<< HEAD
    Log3( $name, 4, "jkbms ($name) NEW: $hash->{helper}{NEW} _Line: " . __LINE__ );
=======
    Log3( $name, 0, "jkbms ($name) NEW: $hash->{helper}{NEW}" );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d

    ####################################################
    if ( !defined($buf) || $buf eq q{} ) ## check if buffer is not defined or empty
    {

<<<<<<< HEAD
        Log3( $name, 5, "jkbms ($name) Error while reading _Line: " . __LINE__ );
=======
        Log3( $name, 1, "jkbms ($name) Error while reading _Line:" . __LINE__ );
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
        $hash->{CONNECTION} = "failed";
        return "error";
    }
    if($hash->{helper}{NEW} =~ m/4e57(.*?)680000/xms){
<<<<<<< HEAD
	Log3( $name, 5, "jkbms ($name) regex: $1 __Line: " . __LINE__);
	jkbms_analyze_answer($hash, $1);
	$hash->{helper}{NEW}= q{};
	}

	return;
=======
	    Log3( $name, 0, "jkbms ($name) regex: $1" );
	jkbms_analyze_answer($hash, $1);
	$hash->{helper}{NEW}= q{};
	  }

	   Log3( $name, 0, "jkbms ($name) regex: done" );
    return;
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
##}}}
}


#########################################################################################
sub jkbms_analyze_answer
{
my ($hash, $value) = @_;
my $name = $hash->{NAME};
<<<<<<< HEAD
	Log3( $name, 3, "jkbms ($name): analyze_answer _Line: " . __LINE__ );
=======
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d

	RemoveInternalTimer($hash);
	my $SingleVoltages = substr($value, 18, 100);
	# how many cells are transmitted, in hex
	my $numberofcells = substr($value,20,2);
	# change to dec in order to use for loop
	$numberofcells = hex($numberofcells);
	#divide by 3 (bytes) to get real number
	$numberofcells = $numberofcells/3;
	Log3( $name, 5, "jkbms ($name): numberofcells $numberofcells _Line: " . __LINE__ );
	my @c = (1..$numberofcells);
	my @singlevoltages;
	for(@c){
		Log3( $name, 5, "jkbms ($name): loop $_ _Line: " . __LINE__ );
		my $start = $_*6;
		my $volt = substr($SingleVoltages,$start,4);
		Log3( $name, 5, "jkbms ($name): loop $_ start $start value $volt _Line: " . __LINE__ );
		my $volt_dec = hex($volt)/1000;
		Log3( $name, 5, "jkbms ($name): volt_dec $volt_dec _Line: " . __LINE__ );
		readingsSingleUpdate($hash, "Cell_$_", $volt_dec,1);
	}	
	readingsBeginUpdate($hash);
	Log3( $name, 5, "jkbms: SingleVoltages $SingleVoltages _Line: " . __LINE__ );
	my $tempMOS = hex(substr($value, 120,4));
	readingsBulkUpdate($hash, "tempMOS", $tempMOS,1);
	my $temperature2 = hex(substr($value, 126,4));
	readingsBulkUpdate($hash, "temp2", $temperature2,1);
	my $temperature3 = hex(substr($value, 132,4));
	readingsBulkUpdate($hash, "temp3", $temperature3,1);

	my $total_battery_voltage = hex(substr($value, 138,4))/100;
	readingsBulkUpdate($hash, "1_Spannung_total", $total_battery_voltage,1);
	
	## current is difficult: 
	#highest Bit 0 means discharging, 1 means charging.
	my $total_battery_current = hex(substr($value, 144,4));
	if ($total_battery_current < 32768){
		## discharging
		$total_battery_current *= -0.01;
		readingsBulkUpdate($hash, "1_Strom_total", $total_battery_current,1);
	}elsif($total_battery_current >= 32768){
		##charging
		$total_battery_current -= 32768;
		$total_battery_current *= 0.01;

		readingsBulkUpdate($hash, "1_Strom_total", $total_battery_current,1);
	}
<<<<<<< HEAD
	##readingsBulkUpdate($hash, "1_Strom_total_raw", substr($value, 136,20));
	my $total_battery_power = int($total_battery_current * $total_battery_voltage);
	readingsBulkUpdate($hash, "1_Power_total", $total_battery_power,1);
	my $total_battery_soc = int(hex(substr($value, 150,2)));
	my $tot_soc = substr($value, 150,2);
	Log3( $name, 5, "jkbms: total_soc $tot_soc  _Line: " . __LINE__ );
=======
	readingsBulkUpdate($hash, "1_Strom_total_raw", substr($value, 136,20));
	my $total_battery_power = $total_battery_current * $total_battery_voltage;
	readingsBulkUpdate($hash, "1_Power_total", $total_battery_power,1);
	my $total_battery_soc = int(hex(substr($value, 150,2)));
>>>>>>> 78154a09c4bb7101a965ecb603df422562078e6d
	readingsBulkUpdate($hash, "1_SOC_total", $total_battery_soc,1);

	my $temp_sensor_amount = hex(substr($value, 154,2));
	#readingsBulkUpdate($hash, "1_SOC_total", $total_battery_soc,1);

	my $cycles = hex(substr($value, 158,4));
	readingsBulkUpdate($hash, "1_cycles", $cycles,1);

	my $total_cycle_capacity = hex(substr($value, 164,8));
	readingsBulkUpdate($hash, "1_cycle_capa_total", $total_cycle_capacity,1);
	my $energy_left = 280*3.2*16/1000*$total_battery_soc/100;
	readingsBulkUpdate($hash, "1_kWh_available", $energy_left,1);
	readingsEndUpdate($hash,1);	
	my $intvl = AttrVal($name, "interval", "none"); 
	if ($intvl eq "none"){
    		readingsSingleUpdate( $hash, "1_status", "Interval-Attribute not set, working in single mode", 1 );
	}elsif(IsDisabled($name)){
    		readingsSingleUpdate( $hash, "1_status", "Module disabled", 1 );
		return; 
	}else{
        	Log3( $name, 4, "jkbms ($name) - Interval set to $intvl, scheduling next run  _Line: " . __LINE__ );
    		readingsSingleUpdate( $hash, "1_status", "waiting for next run", 1 );
		InternalTimer( gettimeofday() + $intvl , 'jkbms_sendRequest', $hash );
	}
	return;	


}
##########################################################################################
sub jkbms_addChecksum
{
##{{{
##	my $v = "20014692E00208";
	my $hash = shift;
	my $order = shift;
    	my $name = $hash->{NAME};
        Log3( $name, 4, "jkbms ($name) - checksum order: $order  _Line: " . __LINE__ );
	my @r = split(//,$order);
	my $var;
	foreach (@r) {
		    $var += hex(unpack("H*",$_));
	    }
	my $output = $var ^ eval "0b1111111111111111";
        Log3( $name, 5, "jkbms ($name) - checksum output: $output  _Line: " . __LINE__ );
	my $checksum = sprintf("%X", $output+1);
        Log3( $name, 5, "jkbms ($name) - checksum checksum: $checksum  _Line: " . __LINE__ );
	return $order . $checksum;
##}}}
}

1;

=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
