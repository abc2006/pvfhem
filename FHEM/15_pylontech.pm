##############################################
# $Id: 15_pylontech.pm 2016-01-14 09:25:24Z stephanaugustin $
# This Module is reading Values from pylontech US2000B and offers them as readings.
# test
package main;

use strict;
use warnings;
use DevIo;

my %req_warn = (
    'WARN1' => "20014644E00201FD33",    ## Warnings of the Cells
    'WARN2' => "20014644E00202FD32",    ## Warnings of the Cells
    'WARN3' => "20014644E00203FD31",    ## Warnings of the Cells
    'WARN4' => "20014644E00204FD30",    ## Warnings of the Cells
    'WARN5' => "20014644E00205FD2F",    ## Warnings of the Cells
    'WARN6' => "20014644E00206FD2E",    ## Warnings of the Cells
    'WARN7' => "20014644E00207FD2D",    ## Warnings of the Cells
    'WARN8' => "20014644E00208FD2C"     ## Warnings of the Cells
);
my %req_packstate = (
    'PACKSTATE1' => "20014692E00201FD30",    ## Number of Packs
    'PACKSTATE2' => "20014692E00202FD2F",    ## Number of Packs
    'PACKSTATE3' => "20014692E00203FD2E",    ## Number of Packs
    'PACKSTATE4' => "20014692E00204FD2D",    ## Number of Packs
    'PACKSTATE5' => "20014692E00205FD2C",    ## Number of Packs
    'PACKSTATE6' => "20014692E00206FD2B",    ## Number of Packs
    'PACKSTATE7' => "20014692E00207FD2A",    ## Number of Packs
    'PACKSTATE8' => "20014692E00208FD29"     ## Number of Packs
);
my %req_cell = (
    'CELL1' => "20014642E00201FD35",         ## Values of Cells, voltages, temperatures
    'CELL2' => "20014642E00202FD34",         ## Values of Cells, voltages, temperatures
    'CELL3' => "20014642E00203FD33",         ## Values of Cells, voltages, temperatures
    'CELL4' => "20014642E00204FD32",         ## Values of Cells, voltages, temperatures
    'CELL5' => "20014642E00205FD31",         ## Values of Cells, voltages, temperatures
    'CELL6' => "20014642E00206FD30",         ## Values of Cells, voltages, temperatures
    'CELL7' => "20014642E00207FD2F",         ## Values of Cells, voltages, temperatures
    'CELL8' => "20014642E00208FD2E"          ## Values of Cells, voltages, temperatures
);
my %req_adm = (
    'NOP' => "200146900000FDAA"              ## Number of Packs Check FDAA

      #    'VERSION' => "200146510000FDAD"          ## Firmware version
);

#####################################
sub pylontech_Initialize
{
    my ($hash) = @_;

    #require "$attr{global}{modpath}/FHEM/DevIo.pm";

    $hash->{DefFn}    = "pylontech_Define";
    $hash->{SetFn}    = "pylontech_Set";
    $hash->{GetFn}    = "pylontech_Get";
    $hash->{UndefFn}  = "pylontech_Undef";
    $hash->{NotifyFn} = "pylontech_Notify";
    $hash->{ReadFn}   = "pylontech_Read";
    $hash->{ReadyFn}  = "pylontech_Ready";
    $hash->{AttrList} = "interval Anschluss unknown_as_reading:yes,no " . $readingFnAttributes;

    $hash->{helper}{value}           = q{};
    $hash->{helper}{key}             = q{};
    $hash->{helper}{timer_adm}       = q{};
    $hash->{helper}{timer_warn}      = q{};
    $hash->{helper}{timer_cell}      = q{};
    $hash->{helper}{timer_packstate} = q{};
    return;
}

#####################################
sub pylontech_Define
{
    my ( $hash, $def ) = @_;
    my @a = split( "[ \t][ \t]*", $def );

    if ( @a < 3 || @a > 5 )
    {
        my $msg = "wrong syntax: define <name> pylontech <device>";
        return $msg;
    }
    my $name   = $a[0];
    my $device = $a[2];

    $hash->{NAME} = $name;
    ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
    $hash->{DeviceName}  = $device;
    $hash->{NOTIFYDEV}   = "global";
    $hash->{INTERVAL}    = AttrVal( $name, "interval", 60 );
    $hash->{actionQueue} = [];

    #close connection if maybe open (on definition modify)
    if ( DevIo_IsOpen($hash) )
    {
	    DevIo_CloseDev($hash);
    }
    Log3( $name, 4, "pylontech DevIO_OpenDev_Define" . __LINE__ );
    InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
    return DevIo_OpenDev( $hash, 0, "pylontech_DoInit" );
}
########
sub pylontech_DoInit
{
    my ($hash) = @_;
    my $name = $hash->{NAME};
    Log3( $name, 2, "DoInitfkt" );
    return;
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub pylontech_Ready
{
    my ($hash) = @_;
    my $name = $hash->{NAME};
    $hash->{helper}{newconn} = 'true';    ## remind the new connection and ask for number of packs
    return DevIo_OpenDev( $hash, 1, "pylontech_DoInit" );
}
###################################
sub pylontech_Notify
{
    #    my ( $hash, $dev ) = @_;
    #    my $name = $hash->{NAME};
    #
    #    Log3 $name, 4, "pylontech ($name) - pylontech_Notify  Line: " . __LINE__;
    #    return if ( IsDisabled($name) );
    #    my $devname = $dev->{NAME};
    #    my $devtype = $dev->{TYPE};
    #    my $events  = deviceEvents( $dev, 1 );
    #    Log3 $name, 4, "pylontech ($name) - pylontech_Notify - not disabled  Line: " . __LINE__;
    #    return if ( !$events );
    #    if ( grep { /^ATTR.$name.interval/ } @{$events} or grep { /^INITIALIZED$/ } @{$events} )
    #    {
    #        Log3 $name, 4, "pylontech ($name) - pylontech_Notify change Interval to AttrVal($name,interval,60) _Line: " . __LINE__;
    #        $hash->{INTERVAL} = AttrVal( $name, "interval", 60 );
    #    }
    #
    #    Log3 $name, 4, "pylontech ($name) - pylontech_Notify got events @{$events} Line: " . __LINE__;
    #    	InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
    #      if ( grep { /^INITIALIZED$/ } @{$events}
    #        or grep { /^CONNECTED$/ } @{$events}
    #        or grep { /^DELETEATTR.$name.disable$/ } @{$events}
    #        or grep { /^DELETEATTR.$name.interval$/ } @{$events}
    #        or ( grep { /^DEFINED.$name$/ } @{$events} and $init_done ) );
    #
    return;

}
#####################################
sub pylontech_Undef
{
    my ( $hash, $name ) = @_;
    DevIo_CloseDev($hash);
    RemoveInternalTimer($hash);
    return;
}
#####################################
sub pylontech_Set
{
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};
    my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg";
    my $ret;
    my $minInterval = 30;
    Log3( $name, 4, "pylontech argument $a[1] _Line: " . __LINE__ );
    if ( $a[1] eq '?' )
    {
        Log3( $name, 4, "pylontech argument question _Line: " . __LINE__ );
        return $usage;
    }
    if ( $a[1] eq 'reopen' )
    {
        if ( DevIo_IsOpen($hash) )
        {
            Log3( $name, 1, "Device is open, closing ... Line: " . __LINE__ );
            DevIo_CloseDev($hash);
            Log3( $name, 1, "pylontech Device closed Line: " . __LINE__ );
        }
        Log3( $name, 1, "pylontech_Set  Device is closed, trying to open Line: " . __LINE__ );
        $ret = DevIo_OpenDev( $hash, 1, "pylontech_DoInit" );
        while ( !DevIo_IsOpen($hash) )
        {
            Log3( $name, 1, "pylontech_Set  Device is closed, opening failed, retrying" . __LINE__ );
            $ret = DevIo_OpenDev( $hash, 1, "pylontech_DoInit" );
            sleep 1;
        }
        return "device opened";
    } elsif ( $a[1] eq "reset" )
    {
        $hash->{helper}{value} = q{}; # empty string
        $hash->{helper}{key}   = q{}; # empty string
        @{ $hash->{actionQueue} } = (); # empty array
        Log3( $name, 1, "pylontech_Set actionQueue is empty: @{$hash->{actionQueue}} Line:" . __LINE__ );
        InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
    }

    return;
}
#####################################
sub pylontech_Get
{
    my ( $hash, @a ) = @_;
    my $name  = $hash->{NAME};
    my $usage = "Unknown argument $a[1], choose one of calcHex";
    Log3( $name, 5, "pylontech argument $a[1]_Line: " . __LINE__ );
    if ( $a[1] eq '?' )
    {
        Log3( $name, 5, "pylontech argument question_Line: " . __LINE__ );
        return $usage;
    }
    return;
}
############################################
sub pylontech_fillhelper
{
    my ( $hash, %orders ) = @_;
    my $name = $hash->{NAME};
    my $nop  = $hash->{helper}{NOP} // '1'; ## Number of Packs
    Log3 $name, 5, "pylontech ($name) - pylontech_fillhelper nop: $nop Line: " . __LINE__;

    foreach my $key ( sort( keys %orders ) )
    {
        if ( substr( $key, -1, 1 ) <= $nop || $key eq 'NOP')
        {
            push( @{ $hash->{actionQueue} }, $key );
            Log3 $name, 5, "pylontech ($name) _fillhelper fill key: $key  Line: " . __LINE__;
            push( @{ $hash->{actionQueue} }, $orders{$key} );
            Log3 $name, 5, "pylontech ($name) _fillhelper fill value: $orders{$key}  Line: " . __LINE__;
        }
    }

    return;
}

sub pylontech_prepareRequests
{
    my $hash = shift;
    my $name = $hash->{NAME};
    my $now  = gettimeofday();
    my $delta;
    Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests now: $now  Line: " . __LINE__;

    $delta = $now - $hash->{helper}{timer_adm};
    Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests delta_adm: $delta Line: " . __LINE__;
    if ( $delta > 150 )    # fragt nur administrative Werte ab, die sich fast nie ändern
    {
        Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests now: $now minus timer_adm $hash->{helper}{timer_adm} = $delta Line: " . __LINE__;
	pylontech_fillhelper( $hash, %req_adm );
	$hash->{helper}{timer_adm} = $now;
    }

    $delta = $now - $hash->{helper}{timer_warn};
    Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests delta_warn: $delta Line: " . __LINE__;
    if ( $delta > 120 )    # warnings, more important than adm, but yet not that far. slow-changing
    {
        Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests now: $now minus timer_warn $hash->{helper}{timer_warn} = $delta Line: " . __LINE__;
        pylontech_fillhelper( $hash, %req_warn );
        $hash->{helper}{timer_warn} = $now;
    }

    $delta = $now - $hash->{helper}{timer_packstate};
    Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests delta_packstate: $delta Line: " . __LINE__;
    if ( $delta > 60 )     # state of pack, more important than adm, but yet not that far. slow-changing
    {
        Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests now: $now minus timer_ packstate $hash->{helper}{timer_packstate} = $delta Line: " . __LINE__;
        pylontech_fillhelper( $hash, %req_packstate );
        $hash->{helper}{timer_packstate} = $now;
    }
    ## cell information such as power and current. short updates needed, every attr{interval}
    Log3 $name, 4, "pylontech ($name) - pylontech_prepareRequests now: $now Line: " . __LINE__;
    pylontech_fillhelper( $hash, %req_cell );

    return;
}

####################################
sub pylontech_sendRequests
{
    my $hash        = shift // return 'Not enough Arguments';
    my $name        = $hash->{NAME};
    my $aq_length   = @{ $hash->{actionQueue} };
    my $modo_length = $aq_length % 2;
    Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests length: $aq_length  Line: " . __LINE__;
    Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests modolength: $modo_length  Line: " . __LINE__;
    Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests ActionQueue: @{ $hash->{actionQueue}}  Line: " . __LINE__;
    if ( $aq_length > 0 && $modo_length == 0 )
    {

        # get new value/key pair
        $hash->{helper}{value} = pop( @{ $hash->{actionQueue} } );
        $hash->{helper}{key}   = pop( @{ $hash->{actionQueue} } );
        Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests value: $hash->{helper}{value}  Line: " . __LINE__;
        Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests key: $hash->{helper}{key}  Line: " . __LINE__;

        #do some weird checks, if value is right
        my $length = length( $hash->{helper}{value} );
        Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests length: $length  Line: " . __LINE__;
        if ( $length != 18 && $length != 16)
        {
            #go crazy.. dont know... whatever
            #maybe anywhen calculate value from key... xD
            @{ $hash->{actionQueue} } = ();
            InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
            return;
        }

        $hash->{helper}{recv} = q{}; ## empty string

        Log3 $name, 5, "pylontech ($name) - pylontech_sendRequests unpack: $hash->{helper}{value}  Line: " . __LINE__;
        my $send = "7E" . unpack( "H*", $hash->{helper}{value} ) . "0D";
        Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests sendString: $send  Line: " . __LINE__;

        DevIo_SimpleWrite( $hash, $send, 1 );

        # start an internal Timer as Watchdog if no answer is received
        InternalTimer( gettimeofday() + 10, 'pylontech_sendRequests', $hash );
    } else
    {
        #leere die ActionQueue
        @{ $hash->{actionQueue} } = ();

        Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests aqlength: $aq_length  Line: " . __LINE__;
        #rufe prepareRequests auf
        pylontech_prepareRequests($hash);
        InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
    }
    return;
}
#####################################
sub pylontech_Read
{

    my ($hash) = @_;
    my $name = $hash->{NAME};
    readingsSingleUpdate( $hash, "_status", "communication in progress", 1 );
    Log3( $name, 5, "pylontech currently reading _Line:" . __LINE__ );

    # read from serial device

    my $buf = DevIo_SimpleRead($hash);
    Log3( $name, 5, "pylontech buffer: $buf" );
    if ( !defined($buf) || $buf eq q{} ) ## check if buffer is not defined or empty
    {

        Log3( $name, 1, "pylontech Error while reading _Line:" . __LINE__ );
        $hash->{CONNECTION} = "failed";
        return "error";
    }

    # each Message is starting by 0x7e and finishes with 0x0d.
    $hash->{helper}{recv} .= $buf;

    Log3( $name, 5, "pylontech helper: $hash->{helper}{recv}" );
    ##my $hex_before = unpack "H*", $hash->{helper}{recv};
    ##Log3($name,5, "pylontech hex_before: $hex_before");
    ## now we can modify the hex string ...
    if ( $hash->{helper}{recv} =~ m/~(.*)\r/xms )
    {
        Log3( $name, 5, "pylontech hex: $1" );

        ## decode data
        my %receive;
        $receive{'Ver'}  = substr( $1, 0, 2 );
        $receive{'ADR'}  = substr( $1, 2, 2 );
        $receive{'CID1'} = substr( $1, 4, 2 );    ## reverse-engineered. is always 46H. Not yet important.
        $receive{'CID2'} = substr( $1, 6, 2 );
        Log3( $name, 4, "pylontech ver: $receive{'Ver'} Line:" . __LINE__ );
        Log3( $name, 4, "pylontech ADR: $receive{'ADR'} Line:" . __LINE__ );
        Log3( $name, 4, "pylontech CID1: $receive{'CID1'} Line:" . __LINE__ );
        Log3( $name, 4, "pylontech CID2: $receive{'CID2'} Line:" . __LINE__ );
        if ( $receive{'CID2'} != 0 )
        {

            Log3( $name, 5, "pylontech Error: $receive{'CID2'} Line:" . __LINE__ );
            my $error;

            my %cid2_errorcodes = (

                # blah
                '01' => 'Version Error',
                '02' => 'CHKSUM Error',
                '03' => 'LCHKSUM Error',
                '04' => 'CID2 Invalidation Error',
                '05' => 'Command Format Error',
                '06' => 'Invalid Data Error',
                '90' => 'Address Error',
                '91' => 'Communication Error',
            );
            if ( defined( $receive{'CID2'} ) )
            {
                $error = $cid2_errorcodes{ $receive{'CID2'} };
            }

            readingsSingleUpdate( $hash, "_error", "$error", 1 );
            Log3( $name, 5, "pylontech Error: $error Line:" . __LINE__ );
            readingsSingleUpdate( $hash, "_status", "communication failed. Proceeding", 1 );
        } else
        {

            $receive{'LENHEX'} = substr( $1, 8, 4 );
            Log3( $name, 4, "pylontech LENHEX: $receive{'LENHEX'} Line:" . __LINE__ );
            $receive{'LEN'} = hex( substr( $1, 9, 3 ) );
            Log3( $name, 4, "pylontech LEN: $receive{'LEN'} Line:" . __LINE__ );
            if ( $receive{'LEN'} > 0 )
            {
                $receive{'INFO'} = substr( $1, 12, $receive{'LEN'} );
                Log3( $name, 4, "pylontech INFO: $receive{'INFO'} Line:" . __LINE__ );
                pylontech_analyze_answer( $hash, $receive{'INFO'} );
            }
        }

    }

    return;
}
##########################################################################################
sub pylontech_analyze_answer
{

    my ( $hash, $value ) = @_;
    my $name = $hash->{NAME};
    my $cmd  = $hash->{helper}{key};

    # remove Watchdog-Timer
    RemoveInternalTimer($hash);
    my $success = "failed";
    Log3( $name, 3, "pylontech cmd: $cmd _Line:" . __LINE__ );
    Log3( $name, 4, "pylontech analyzing anyway _Line:" . __LINE__ );

    if ( $value =~ m/NAK.*/xms )
    {
        Log3( $name, 4, "pylontech invalid Query, valid Answer. Aborting. _Line:" . __LINE__ );
        InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
        return;
    }
    if ( $cmd =~ m/PACKSTATE(\d)/xms )
    {

        Log3( $name, 4, "pylontech cmd: analyzing PACKSTATE _Line:" . __LINE__ );
        ## get Pack-Number
        Log3( $name, 4, "pylontech PackNumber = $1 _Line:" . __LINE__ );

        my $recommChargVoltageLimit = hex( substr( $value, 2, 4 ) ) / 1000;
        Log3( $name, 4, "pylontech recommChargVoltageLimit  = $recommChargVoltageLimit _Line:" . __LINE__ );
        my $recommDischargeVoltageLimit = hex( substr( $value, 6, 4 ) ) / 1000;
        Log3( $name, 4, "pylontech recommDischargeVoltageLimit = $recommDischargeVoltageLimit _Line:" . __LINE__ );
        my $maxChargeCurrent = hex( substr( $value, 10, 4 ) );
        Log3( $name, 4, "pylontech maxChargeCurrent  = $maxChargeCurrent _Line:" . __LINE__ );
        my $maxDisChargeCurrent = hex( substr( $value, 14, 4 ) );
        Log3( $name, 4, "pylontech maxDisChargeCurrent  = $maxDisChargeCurrent _Line:" . __LINE__ );
        my $status = substr( $value, 18, 2 );
        Log3( $name, 4, "pylontech Status = $status _Line:" . __LINE__ );
        my $message;
        my $bits = unpack( "B*", pack( "H*", $status ) );

        if ( substr( $bits, 2, 1 ) == 1 )
        {
            $message .= "Charge immediately";
            ##32 = charge immediately
        }

        if ( substr( $bits, 1, 1 ) == 1 )
        {
            $message .= "discharge enabled";
            ## 64 = discharge enable
        }

        if ( substr( $bits, 0, 1 ) == 1 )
        {
            $message .= "Charge enabled";
            ##128 = charge enable
        }

        Log3( $name, 4, "pylontech A = $message _Line:" . __LINE__ );
        Log3( $name, 4, "pylontech B = $bits _Line:" . __LINE__ );
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "Pack_$1_recommChargeVoltageLimit",    $recommChargVoltageLimit,     1 );
        readingsBulkUpdate( $hash, "Pack_$1_recommDischargeVoltageLimit", $recommDischargeVoltageLimit, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_maxChargeCurrent ",           $maxChargeCurrent,            1 );
        readingsBulkUpdate( $hash, "Pack_$1_maxDisChargeCurrent ",        $maxDisChargeCurrent,         1 );
        readingsBulkUpdate( $hash, "Pack_$1_general_status ",             $message,                     1 );
        readingsEndUpdate( $hash, 1 );
        Log3( $name, 4, "pylontech $cmd successful _Line:" . __LINE__ );
        $success = "success";
    } elsif ( $cmd =~ m/CELL(\d)/xms )
    {
        Log3( $name, 4, "pylontech cmd: analyzing $cmd _Line:" . __LINE__ );

        # get Pack-Number
        Log3( $name, 4, "pylontech PackNumber = $1 _Line:" . __LINE__ );

        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "Pack_$1_Anzahl_Zellen", hex( substr( $value, 4,  2 ) ),        1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle1",        hex( substr( $value, 6,  4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle2",        hex( substr( $value, 10, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle3",        hex( substr( $value, 14, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle4",        hex( substr( $value, 18, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle5",        hex( substr( $value, 22, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle6",        hex( substr( $value, 26, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle7",        hex( substr( $value, 30, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle8",        hex( substr( $value, 34, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle9",        hex( substr( $value, 38, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle10",       hex( substr( $value, 42, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle11",       hex( substr( $value, 46, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle12",       hex( substr( $value, 50, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle13",       hex( substr( $value, 54, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle14",       hex( substr( $value, 58, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Zelle15",       hex( substr( $value, 62, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Temperaturfühler", substr( $value, 66, 2 ), 1 );
        my $sensor = 0;

        # loop through the temperatursensors. The Values are available at position 68,72,76,80,84 in the Data-String
        foreach ( ( 68, 72, 76, 80, 84 ) )
        {
            Log3( $name, 4, "pylontech temploop foreach $_ _Line:" . __LINE__ );
            $sensor++;
            my $temp = ( hex( substr( $value, $_, 4 ) ) - 2731 ) / 10;
            Log3( $name, 5, "pylontech temploop temp $temp _Line:" . __LINE__ );
            if ( $temp > 0 && $temp < 100 )
            {
                readingsBulkUpdate( $hash, "Pack_$1_Temp$sensor", $temp, 1 );

                Log3( $name, 5, "pylontech temploop update Pack_$1_Temp$sensor : $temp Part: $_ _Line:" . __LINE__ );
            }
        }

        my $current =
          unpack( 's', pack( 'S', hex( substr( $value, 88, 4 ) ) ) ) / 10;

        readingsBulkUpdate( $hash, "Pack_$1_Strom", $current, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Spannung", hex( substr( $value, 92, 4 ) ) / 1000,     1 );
        readingsBulkUpdate( $hash, "Pack_$1_Ah_left",  hex( substr( $value, 96, 4 ) ) / 1000,     1 );
        readingsBulkUpdate( $hash, "Pack_$1_SoC",      hex( substr( $value, 96, 4 ) ) / 1000 * 2, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_unbekannt_hex", substr( $value, 100, 2 ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Ah_total", hex( substr( $value, 102, 4 ) ) / 1000, 1 );
        readingsBulkUpdate( $hash, "Pack_$1_cycle",    hex( substr( $value, 106, 4 ) ),        1 );

        readingsEndUpdate( $hash, 1 );
        Log3( $name, 4, "pylontech ($name) - pylontech_analyze_answer aktualisiere totals. Line: " . __LINE__ );
        pylontech_calcTotal($hash);

        Log3( $name, 4, "pylontech $cmd successful _Line:" . __LINE__ );
        $success = "success";
    } elsif ( $cmd =~ m/WARN(\d)/xms )
    {
        Log3( $name, 4, "pylontech cmd: analysiere WARN _Line:" . __LINE__ );

        # get Pack-Number
        Log3( $name, 4, "pylontech PackNummer = $1 _Line:" . __LINE__ );

        readingsBeginUpdate($hash);

        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle1",       hex( substr( $value, 6,  2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle2",       hex( substr( $value, 8,  2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle3",       hex( substr( $value, 10, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle4",       hex( substr( $value, 12, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle5",       hex( substr( $value, 14, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle6",       hex( substr( $value, 16, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle7",       hex( substr( $value, 18, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle8",       hex( substr( $value, 20, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle9",       hex( substr( $value, 22, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle10",      hex( substr( $value, 24, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle11",      hex( substr( $value, 26, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle12",      hex( substr( $value, 28, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle13",      hex( substr( $value, 30, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle14",      hex( substr( $value, 32, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Zelle15",      hex( substr( $value, 34, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Anzahl_Temp",  hex( substr( $value, 36, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Temp1",        hex( substr( $value, 38, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Temp2",        hex( substr( $value, 40, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Temp3",        hex( substr( $value, 42, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Temp4",        hex( substr( $value, 44, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Temp5",        hex( substr( $value, 46, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_LadeStrom",    hex( substr( $value, 48, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Spannung",     hex( substr( $value, 50, 2 ) ), 1 );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_EntladeStrom", hex( substr( $value, 52, 2 ) ), 1 );
        my $message = q{}; # create empty variable
        my $bits    = q{}; # create empty variable
        $bits = unpack( "B*", pack( "H*", substr( $value, 54, 2 ) ) );

        if ( substr( $bits, 7, 1 ) == 1 )
        {
            $message .= "OverVoltage";
            ##32 = charge immediately
        }
        if ( substr( $bits, 6, 1 ) == 1 )
        {
            $message .= "iCell lower-limit-voltage";
            ##32 = charge immediately
        }
        if ( substr( $bits, 5, 1 ) == 1 )
        {
            $message .= "Charge overcurrent";
            ##32 = charge immediately
        }
        if ( substr( $bits, 4, 1 ) == 1 )
        {
            $message .= "intentionally blank";
            ##32 = charge immediately
        }
        if ( substr( $bits, 3, 1 ) == 1 )
        {
            $message .= "Discharge overcurrent";
            ##32 = charge immediately
        }
        if ( substr( $bits, 2, 1 ) == 1 )
        {
            $message .= "Discharge Temperature Protection";
            ##32 = charge immediately
        }
        if ( substr( $bits, 1, 1 ) == 1 )
        {
            $message .= "Charge Temperature protection";
            ## 64 = discharge enable
        }
        if ( substr( $bits, 0, 1 ) == 1 )
        {
            $message .= "Pack Undervoltage";
            ##128 = charge enable
        }
        Log3( $name, 4, "pylontech W1A = $message _Line:" . __LINE__ );
        Log3( $name, 4, "pylontech W1B = $bits _Line:" . __LINE__ );

        readingsBulkUpdate( $hash, "Pack_$1_Warn_Status1", $bits . ':' . $message, 1 );
        $message = q{}; # empty $message for the next part
	# fill in bit pattern of the next part
	$bits =
          substr( unpack( "B*", pack( "H*", substr( $value, 56, 2 ) ) ), 4 );
        if ( substr( $bits, 3, 1 ) == 1 )
        {
            $message .= "Use the Pack Power ";
            ##32 = charge immediately
        }
        if ( substr( $bits, 2, 1 ) == 1 )
        {
            $message .= "DFET ";
            ##32 = charge immediately
        }

        if ( substr( $bits, 1, 1 ) == 1 )
        {
            $message .= "CFET ";
            ## 64 = discharge enable
        }

        if ( substr( $bits, 0, 1 ) == 1 )
        {
            $message .= "PreFET ";
            ##128 = charge enable
        }

        Log3( $name, 4, "pylontech A = $message _Line:" . __LINE__ );
        Log3( $name, 4, "pylontech B = $bits _Line:" . __LINE__ );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Status2", $bits . ":" . $message, 1 );
        $message = q{}; # empty $message for the next part
	# fill in bit pattern of the next part
        $bits = unpack( "B*", pack( "H*", substr( $value, 58, 2 ) ) );
        if ( substr( $bits, 7, 1 ) == 1 )
        {
            $message .= "Buzzer";
            ##32 =
        }
        if ( substr( $bits, 6, 1 ) == 1 )
        {
            $message .= "int blank";
            ##32 =
        }
        if ( substr( $bits, 5, 1 ) == 1 )
        {
            $message .= "int blank";
            ##32 =
        }
        if ( substr( $bits, 4, 1 ) == 1 )
        {
            $message .= "Fully Charged";
            ##32 =
        }
        if ( substr( $bits, 3, 1 ) == 1 )
        {
            $message .= "int blank";
            ##32 =
        }
        if ( substr( $bits, 2, 1 ) == 1 )
        {
            $message .= "Startup-Heater";
            ##32 =
        }
        if ( substr( $bits, 1, 1 ) == 1 )
        {
            $message .= "Effective Discharge Current";
            ## 64 = discharge enable
        }
        if ( substr( $bits, 0, 1 ) == 1 )
        {
            $message .= "Effective Charge Current";
            ##128 = charge enable
        }

        Log3( $name, 4, "pylontech A = $message _Line:" . __LINE__ );
        Log3( $name, 4, "pylontech B = $bits _Line:" . __LINE__ );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Status3", $bits . ":" . $message, 1 );
        $message = q{}; # empty $message for the next part
	# fill in bit pattern of the next part
        $bits = unpack( "B*", pack( "H*", substr( $value, 60, 2 ) ) );
        if ( substr( $bits, 7, 1 ) == 1 )
        {
            $message .= "Check Cell 1";
            ##32 =
        }
        if ( substr( $bits, 6, 1 ) == 1 )
        {
            $message .= "Check Cell 2";
            ##32 =
        }
        if ( substr( $bits, 5, 1 ) == 1 )
        {
            $message .= "Check Cell 3";
            ##32 = 3
        }
        if ( substr( $bits, 4, 1 ) == 1 )
        {
            $message .= "Check Cell 4";
            ##32 =
        }
        if ( substr( $bits, 3, 1 ) == 1 )
        {
            $message .= "Check Cell 5";
            ##32 =
        }
        if ( substr( $bits, 2, 1 ) == 1 )
        {
            $message .= "Check Cell 6";
            ##32 =
        }
        if ( substr( $bits, 1, 1 ) == 1 )
        {
            $message .= "Check Cell 7";
            ## 64 = discharge enable
        }
        if ( substr( $bits, 0, 1 ) == 1 )
        {
            $message .= "Check Cell 8";
            ##128 =
        }

        Log3( $name, 4, "pylontech A = $message _Line:" . __LINE__ );
        Log3( $name, 4, "pylontech B = $bits _Line:" . __LINE__ );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Status4", $bits . ":" . $message, 1 );
        $message = q{}; # empty $message for the next part
	# fill in bit pattern of the next part
        $bits = unpack( "B*", pack( "H*", substr( $value, 62, 2 ) ) );
        if ( substr( $bits, 7, 1 ) == 1 )
        {
            $message .= "Check Cell 9";
            ##32 =
        }
        if ( substr( $bits, 6, 1 ) == 1 )
        {
            $message .= "Check Cell 10";
            ##32 =
        }
        if ( substr( $bits, 5, 1 ) == 1 )
        {
            $message .= "Check Cell 11";
            ##32 = 3
        }
        if ( substr( $bits, 4, 1 ) == 1 )
        {
            $message .= "Check Cell 12";
            ##32 =
        }
        if ( substr( $bits, 3, 1 ) == 1 )
        {
            $message .= "Check Cell 13";
            ##32 =
        }
        if ( substr( $bits, 2, 1 ) == 1 )
        {
            $message .= "Check Cell 14";
            ##32 =
        }
        if ( substr( $bits, 1, 1 ) == 1 )
        {
            $message .= "Check Cell 15";
            ## 64 = discharge enable
        }
        if ( substr( $bits, 0, 1 ) == 1 )
        {
            $message .= "Check Cell 16";
            ##128 =
        }

        Log3( $name, 4, "pylontech A = $message _Line:" . __LINE__ );
        Log3( $name, 4, "pylontech B = $bits _Line:" . __LINE__ );
        readingsBulkUpdate( $hash, "Pack_$1_Warn_Status5", $bits . ":" . $message, 1 );
        $message = q{};

        readingsEndUpdate( $hash, 1 );

        Log3( $name, 4, "pylontech $cmd successful _Line:" . __LINE__ );
        $success = "success";
    } elsif ( $cmd eq "NOP" )
    {
        Log3( $name, 4, "pylontech cmd: analysiere $cmd _Line:" . __LINE__ );
        my $a = $value * 1;
        Log3( $name, 4, "pylontech uebergeben: $a _Line:" . __LINE__ );
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "1_Number_of_Packs", $a, 1 );
        readingsEndUpdate( $hash, 1 );
        $hash->{helper}{NOP} = $a;
        Log3( $name, 4, "pylontech $cmd successful _Line:" . __LINE__ );
        $success = "success";
    } else
    {
        Log3( $name, 1, "pylontech cmd " . $cmd . " not implemented yet, putting value in _devel<nr>, Line: " . __LINE__ );
        readingsBeginUpdate($hash);
        Log3( $name, 1, "pylontech cmd  $cmd unknown" );
        if ( AttrVal( $name, "unknown_as_reading", 0 ) eq "yes" )
        {
            Log3( $name, 1, "putting $value in _devel" );
            readingsBulkUpdate( $hash, "_devel", $value, 1 );
        }

        readingsEndUpdate( $hash, 1 );
        Log3( $name, 4, "pylontech $cmd successful _Line:" . __LINE__ );
        $success = "success";
    }

    Log3( $name, 4, "pylontech analyze ready. success: $success _Line:" . __LINE__ );
    if ( $success eq "success" )
    {
        $hash->{CONNECTION}    = "established";
        $hash->{helper}{key}   = "";
        $hash->{helper}{value} = "";
        Log3( $name, 3, "pylontech ($name) - Transmission finished " . __LINE__ );
    }
    InternalTimer( gettimeofday() + 1, 'pylontech_sendRequests', $hash );
    return;
}
##########################################
sub pylontech_calcTotal
{

    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $numberOfPacks  = ReadingsNum( $name, "1_Number_of_Packs", 8 );
    my $Ah_left        = 0;
    my $Ah_total       = 0;
    my $U_total        = 0;
    my $I_total        = 0;
    my $P_total        = 0;
    my $T_total        = 0;
    my $soc_total      = 0;
    my $kWh_left_total = 0;
    readingsBeginUpdate($hash);

    for ( my $i = 1; $i < $numberOfPacks + 1; $i++ )
    {
        $U_total = $U_total + ReadingsNum( $name, "Pack_" . $i . "_Spannung", 0 );
        $I_total = $I_total + ReadingsNum( $name, "Pack_" . $i . "_Strom",    0 );
        $Ah_total = $Ah_total + ReadingsNum( $name, "Pack_" . $i . "_Ah_total", 0 );
        $Ah_left = $Ah_left + ReadingsNum( $name, "Pack_" . $i . "_Ah_left", 0 );
        for ( my $k = 1; $k < 6; $k++ )
        {
            $T_total += ReadingsNum( $name, "Pack_" . $i . "_Temp" . $k, 0 );
        }
    }
    $T_total        = int( 10 *   ( $T_total / $numberOfPacks / 5 ) ) / 10;
    $U_total        = int( 1000 * ( $U_total / $numberOfPacks ) ) / 1000;
    $kWh_left_total = int( 10 *   ( $Ah_left * $U_total / 1000 ) ) / 10;
    $P_total        = int( $U_total * $I_total );
    Log3( $name, 5, "pylontech ($name) - Ah_left: $Ah_left " . __LINE__ );
    Log3( $name, 5, "pylontech ($name) - Ah_total: $Ah_total " . __LINE__ );
    if (   defined($Ah_left)
        && $Ah_left > 0
        && defined($Ah_total)
        && $Ah_total > 0 )
    {
        my $var1 = ( 100 * $Ah_left ) / $Ah_total;
        Log3( $name, 5, "pylontech ($name) - soc total calculation: $var1 " . __LINE__ );
        $soc_total = int( 10 * $var1 ) / 10;
        Log3( $name, 5, "pylontech ($name) - soc total rounded: $soc_total " . __LINE__ );
    }
    readingsBulkUpdate( $hash, "1_kWh_BMS_left_total", $kWh_left_total );
    readingsBulkUpdate( $hash, "1_Ah_BMS_total",       $Ah_total );
    readingsBulkUpdate( $hash, "1_Ah_BMS_left",        $Ah_left );
    readingsBulkUpdate( $hash, "1_SOC_BMS_total",      $soc_total );
    readingsBulkUpdate( $hash, "1_Temperature_total",  $T_total );
    readingsBulkUpdate( $hash, "1_Spannung_total",     $U_total );
    readingsBulkUpdate( $hash, "1_Strom_total",        $I_total );
    readingsBulkUpdate( $hash, "1_Power_total",        $P_total );
    readingsEndUpdate( $hash, 1 );
    return;
}

1;

=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
