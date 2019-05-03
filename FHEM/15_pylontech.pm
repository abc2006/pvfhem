##############################################
# $Id: 15_pylontech.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;

my %requests = (
	'NOP' => "200146900000FDAA", ## Number of Packs Check FDAA
	'PACKSTATE1' => "20014692E00201FD30", ## Number of Packs
	'PACKSTATE2' => "20014692E00202FD2F", ## Number of Packs
	'PACKSTATE3' => "20014692E00203FD2E", ## Number of Packs
	'CELL1' => "20014642E00201FD35", ## Values of Cells, voltages, temperatures 
	'CELL2' => "20014642E00202FD34", ## Values of Cells, voltages, temperatures 
	'CELL3' => "20014642E00203FD33", ## Values of Cells, voltages, temperatures 
	'WARN1' => "20014644E00201FD33", ## Warnings of the Cells
	'WARN2' => "20014644E00202FD32", ## Warnings of the Cells
	'WARN3' => "20014644E00203FD31" ## Warnings of the Cells
##	'VERSION' => "200146510000FDAD", ## Firmware version
	);

#####################################
sub
pylontech_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "pylontech_Define";
  $hash->{SetFn}     = "pylontech_Set";
  $hash->{GetFn}     = "pylontech_Get";
  $hash->{UndefFn}   = "pylontech_Undef";
  $hash->{NotifyFn}    = "pylontech_Notify";
  $hash->{ReadFn}    = "pylontech_Read";
  $hash->{ReadyFn}    = "pylontech_Ready";
  $hash->{AttrList}  = "interval Anschluss unknown_as_reading:yes,no ".
                        $readingFnAttributes;

  $hash->{helper}{value} = "";
  $hash->{helper}{key} = "";
}

#####################################
sub
pylontech_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> pylontech <device>";
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];
 
  $hash->{NAME} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
  $hash->{NOTIFYDEV} 	= "global";
  $hash->{INTERVAL} = AttrVal($name,"interval",60);
  $hash->{actionQueue} 	= [];	
#close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "pylontech_DoInit" );
  Log3($name, 1, "pylontech DevIO_OpenDev_Define" . __LINE__); 
  return $ret;
}


sub
pylontech_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
 pylontech_TimerGetData($hash);
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub pylontech_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
	$ret = DevIo_OpenDev($hash, 1, "pylontech_DoInit" );
}
###################################
sub pylontech_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};

Log3 $name, 4, "pylontech ($name) - pylontech_Notify  Line: " . __LINE__;	
return if (IsDisabled($name));
my $devname = $dev->{NAME};
my $devtype = $dev->{TYPE};
my $events = deviceEvents($dev,1);
Log3 $name, 4, "pylontech ($name) - pylontech_Notify - not disabled  Line: " . __LINE__;	
return if (!$events);
if( grep /^ATTR.$name.interval/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
	Log3 $name, 4, "pylontech ($name) - pylontech_Notify change Interval to AttrVal($name,interval,60) _Line: " . __LINE__;	
	$hash->{INTERVAL} = AttrVal($name,"interval",60);
}


Log3 $name, 4, "pylontech ($name) - pylontech_Notify got events @{$events} Line: " . __LINE__;	
pylontech_TimerGetData($hash) if( grep /^INITIALIZED$/,@{$events}
				or grep /^CONNECTED$/,@{$events}
				or grep /^DELETEATTR.$name.disable$/,@{$events}
				or grep /^DELETEATTR.$name.interval$/,@{$events}
				or (grep /^DEFINED.$name$/,@{$events} and $init_done) );


return;

}
#####################################
sub pylontech_Undef($$)
{
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
  RemoveInternalTimer($hash);
  RemoveInternalTimer("resend:$name");
  RemoveInternalTimer("next:$name");
  RemoveInternalTimer("first:$name");
  return undef;
}
#####################################
sub pylontech_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "pylontech argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "pylontech argument fragezeichen" . __LINE__);
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "Device is open, closing ... Line: " . __LINE__);
			DevIo_CloseDev($hash);
			Log3($name,1, "pylontech Device closed Line: " . __LINE__);
		} 
		Log3($name,1, "pylontech_Set  Device is closed, trying to open Line: " . __LINE__);
		$ret = DevIo_OpenDev($hash, 1, "pylontech_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "pylontech_Set  Device is closed, opening failed, retrying" . __LINE__);
			$ret = DevIo_OpenDev($hash, 1, "pylontech_DoInit" );
			sleep 1;
		}
		return "device opened";
	} elsif ($a[1] eq "reset"){
	$hash->{helper}{value} = "";
	$hash->{helper}{key} = "";
	@{$hash->{actionQueue}} = ();
	Log3($name,1, "pylontech_Set actionQueue is empty: @{$hash->{actionQueue}} Line:" . __LINE__);
	pylontech_TimerGetData($hash);
	}
	
}
#####################################
sub pylontech_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of calcHex"; 
	Log3($name,5, "pylontech argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "pylontech argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}
}

############################################
sub pylontech_TimerGetData($){
my $hash = shift;
my $name = $hash->{NAME};
Log3 $name, 4, "pylontech ($name) _TimerGetData - action Queue 1: $hash->{actionQueue} Line: " . __LINE__;	
Log3 $name, 4, "pylontech ($name) _TimerGetData - actionQueue_array  @{$hash->{actionQueue}}  Line: " . __LINE__;	
if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ){
	Log3 $name, 4, "pylontech ($name) _TimerGetData - is defined and empty Line: " . __LINE__;	
	if( not IsDisabled($name) ) {
		Log3 $name, 4, "pylontech ($name) _TimerGetData - is not disabled Line: " . __LINE__;	
		while( my ($key,$value) = each %requests ){
		Log3 $name, 4, "pylontech ($name) _TimerGetData - actionQueue fill: $key  Line: " . __LINE__;	
		Log3 $name, 4, "pylontech ($name) _TimerGetData - actionQueue fill: $value  Line: " . __LINE__;	
			unshift( @{$hash->{actionQueue}}, $value );
			unshift( @{$hash->{actionQueue}}, $key );
			#My $hash = (
			#	foo => [1,2,3,4,5],
			#	bar => [a,b,c,d,e]
			#);
			#@{$hash{foo}} would be (1,2,3,4,5)
		}
		Log3 $name, 4, "pylontech ($name) _TimerGetData - actionQueue filled: @{$hash->{actionQueue}}  Line: " . __LINE__;	
		Log3 $name, 4, "pylontech ($name) _TimerGetData - call pylontech_sendRequests Line: " . __LINE__;	
		pylontech_sendRequests("first:$name");
	}else{
		readingsSingleUpdate($hash,'state','disabled',1);
	}
	InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'pylontech_TimerGetData', $hash);
	Log3 $name, 4, "pylontech ($name) _TimerGetData - call InternalTimer pylontech_TimerGetData Line: " . __LINE__;	
}else {
	Log3 $name, 4, "pylontech ($name) _TimerGetData - call pylontech_sendRequests Line: " . __LINE__;	
	pylontech_sendRequests("next:$name");
}
}
####################################
sub pylontech_sendRequests($){
my ($calltype,$name) = split(':', $_[0]);
my $hash = $defs{$name};
Log3 $name, 5, "pylontech ($name) - pylontech_sendRequests calltype $calltype  Line: " . __LINE__;	
if($calltype eq "resend" && $hash->{helper}{recv} eq ""){

	$hash->{CONNECTION} = "timeout";
	readingsSingleUpdate($hash, "_status","communication failed",1);
}


if($hash->{helper}{key} eq "" || $hash->{helper}{retrycount} > 10)
{
	$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
	$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
	 $hash->{helper}{retrycount} = 0;
	Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests key == '', next one  Line: " . __LINE__;	
}else{
	$hash->{helper}{retrycount}++;
	Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests key ($hash->{helper}{key}) != '', retry. retryCount is  $hash->{helper}{retrycount} Line: " . __LINE__;	
}


Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests value: $hash->{helper}{value}  Line: " . __LINE__;	
Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests key: $hash->{helper}{key}  Line: " . __LINE__;	
$hash->{helper}{recv} = "";

#?#my $raw = $hash->{helper}{value};
#?#
#?#Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests raw: $hash->{helper}{value}  Line: " . __LINE__;	
#?#my $hexstring = unpack("H*", $raw);
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests hexstring: $hexstring  Line: " . __LINE__;	
#?#
#?#my @splithexstring = ($hexstring =~ /(..)/g);
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests splithexstring: " . $splithexstring[0] . "  Line: " . __LINE__;	
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests scalar " . scalar(@splithexstring) . "  Line: " . __LINE__;	
#?#my $sum;
#?#foreach my $n (@splithexstring){
#?#$sum += "0x" . $n;
#?#
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests sum: " . $sum . "  Line: " . __LINE__;	
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests n: " . $n . "  Line: " . __LINE__;	
#?#}
#?#
#?#my $hex = sprintf("0x%X", $sum);
#?#
#?#
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests iback to hex: " . $hex . "  Line: " . __LINE__;	
#?#
#?#
#?#my $result = $hex % 65536;
#?#
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests result : " . $result . "  Line: " . __LINE__;	
#?#
#?### complement bitwise invert
#?#my $bits = unpack ("B*", pack("H*", $result));
#?#my @singlebits = ($bits =~ /./g);
#?#my $turned;
#?#my $tocheck;
#?#foreach my $b (@singlebits){
#?#	if($b == "1"){
#?#		$turned .= "0";
#?#	} else {
#?#		$turned .= "1";
#?#	}
#?#	$tocheck .= $b;
#?#}
#?#
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests tocheck : " . $tocheck . "  Line: " . __LINE__;	
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests turned : " . $turned . "  Line: " . __LINE__;	
#?#
#?#my $converted = unpack ("H*", pack("B*", $turned));
#?#Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests converted : " . $converted . "  Line: " . __LINE__;	
#?#
#?#
#?### convert decimal to hex
#?#
#?#
#?### just take the last (first?) four


my $send = "7E" . unpack("H*", $hash->{helper}{value}) . "0D";
Log3 $name, 3, "pylontech ($name) - pylontech_sendRequests sendString: $send  Line: " . __LINE__;	

DevIo_SimpleWrite($hash,$send,1);
InternalTimer(gettimeofday()+2,'pylontech_sendRequests',"resend:$name");
	Log3 $name, 4, "pylontech ($name) - pylontech_sendRequests starte resend-timer.Line: " . __LINE__;	
}
#####################################
sub pylontech_Read($$)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{CONNECTION} = "established";
	readingsSingleUpdate($hash, "_status","communication in progress",1);
	Log3($name,4, "pylontech jetzt wird gelesen _Line:" . __LINE__);
	# read from serial device
	#
	
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,5, "pylontech buffer: $buf");
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "pylontech Fehler beim lesen _Line:" . __LINE__);
		$hash->{CONNECTION} = "failed";
		return "error" ;
	}
 	# es geht los mit 0x7e und hört auf mit 0x0d - eigentlich.	
	$hash->{helper}{recv} .= $buf; 
	
	Log3($name,5, "pylontech helper: $hash->{helper}{recv}"); 
	##my $hex_before = unpack "H*", $hash->{helper}{recv};
	##Log3($name,5, "pylontech hex_before: $hex_before");
	## now we can modify the hex string ... 
	if($hash->{helper}{recv} =~ /~(.*)\r/){
	Log3($name,5, "pylontech hex: $1");
	
##		my @h1 = ($1 =~ /(..)/g);
##		my @ascii_ary = map { pack ("H2", $_) } @h1;
##		my $asciistring;
##	foreach my $part (@ascii_ary){
##		$asciistring .= $part;
##	}
##		Log3($name,5, "pylontech iasciistring: $asciistring");
##		my @splits = split(" ",$asciistring);
##		Log3($name,5, "pylontech splits: @splits");
####		pylontech_analyze_answer($hash, @splits);

	## Daten entschluesseln
	my %empfang;
	$empfang{'Ver'} = substr($1,0,2);
	$empfang{'ADR'} = substr($1,2,2);
	$empfang{'CID1'} = substr($1,4,2); ## muss *immer* 46H sein
	$empfang{'CID2'} = substr($1,6,2);
	if ($empfang{'CID2'} != 0){
	
		Log3($name,5, "pylontech Fehler: $empfang{'CID2'}");
	
		my $error;
		if ($empfang{'CID2'} eq "01"){
			$error = "Version Error";
		} elsif ($empfang{'CID2'} eq "02"){
			$error = "CHKSUM Error";
		} elsif ($empfang{'CID2'} eq "03"){
			$error = "LCHKSUM Error";
		} elsif ($empfang{'CID2'} eq "04"){
			$error = "CID2 invalidation";
		} elsif ($empfang{'CID2'} eq "05"){
			$error = "Commnd Format Error";
		} elsif ($empfang{'CID2'} eq "06"){
			$error = "Invalid Data";
		} elsif ($empfang{'CID2'} eq "90"){
			$error = "ADR Error";
		} elsif ($empfang{'CID2'} eq "91"){
			$error = "Communication Error";
		}
	readingsSingleUpdate($hash, "_error","$error",1);
	Log3($name,5, "pylontech Fehler: $error");
	}
	


	$empfang{'LENHEX'} = substr($1,8,4);
	$empfang{'LEN'} = hex(substr($1,9,3));
	if($empfang{'LEN'} > 0){
		$empfang{'INFO'} = substr($1,12,$empfang{'LEN'});
	}
	
	my @splits = split(" ",$empfang{'INFO'});
	Log3($name,5, "pylontech ver: $empfang{'Ver'}");
	Log3($name,5, "pylontech ADR: $empfang{'ADR'}");
	Log3($name,5, "pylontech CID1: $empfang{'CID1'}");
	Log3($name,5, "pylontech CID2: $empfang{'CID2'}");
	Log3($name,5, "pylontech LENHEX: $empfang{'LENHEX'}");
	Log3($name,5, "pylontech LEN: $empfang{'LEN'}");
	Log3($name,5, "pylontech INFO: $empfang{'INFO'}");
	pylontech_analyze_answer($hash, $empfang{'INFO'});



	if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) != 0 ){
		Log3 $name, 4, "pylontech ($name) - pylontech_ReadFn Noch nicht alle Abfragen gesendet, rufe sendRequests wieder auf  Line: " . __LINE__;	
		Log3 $name, 4, "pylontech ($name) - pylontech_ReadFn Noch anstehende Abfragen:  @{$hash->{actionQueue}} Line: " . __LINE__;	
		pylontech_sendRequests("next:$name");
	}else{
	
	readingsSingleUpdate($hash, "_status","communication finished, standby",1);
	}
	}
 
	return;
}
##########################################################################################
sub pylontech_analyze_answer($$){

	my ($hash,$value) = @_;
        my @values;
	my $name = $hash->{NAME};
	my $cmd = $hash->{helper}{key};
	my $success = "failed";
	Log3($name,4, "pylontech cmd: $cmd _Line:" . __LINE__);

	Log3($name,5, "pylontech analysiere ueberhaupt mal irgendwas _Line:" . __LINE__);

	if($values[0] =~ /NAK/){
		Log3($name,5, "pylontech analysiere $values[0] _Line:" . __LINE__);
		Log3($name,5, "pylontech Keine Gültige Abfrage, Antwort fehlerfrei. Abbruch. _Line:" . __LINE__);
		##pylontech_blck_doInternalUpdate($hash); 
			$hash->{helper}{key} = "";
		$hash->{helper}{value} = "";
		$hash->{helper}{retrycount} = "";
		Log3($name, 5, "pylontech ($name) - pylontech_analyze_answer stoppe resend-timer. Line: " . __LINE__);	
		RemoveInternalTimer("resend:$name");
return;
	}

if($cmd =~ /PACKSTATE(\d)/) {

		Log3($name,4, "pylontech cmd: analysiere PACKSTATE _Line:" . __LINE__);
		## get Pack-Number
		Log3($name,5, "pylontech PackNummer = $1 _Line:" . __LINE__);

		my $recommChargVoltageLimit = hex(substr($value,2,4))/1000;
		Log3($name,5, "pylontech recommChargVoltageLimit  = $recommChargVoltageLimit _Line:" . __LINE__);
		my $recommDischargeVoltageLimit = hex(substr($value,6,4))/1000;
		Log3($name,5, "pylontech recommDischargeVoltageLimit = $recommDischargeVoltageLimit _Line:" . __LINE__);
		my $maxChargeCurrent = hex(substr($value,10,4));
		Log3($name,5, "pylontech DmaxChargeCurrent  = $maxChargeCurrent _Line:" . __LINE__);
		my $maxDisChargeCurrent = hex(substr($value,14,4));
		Log3($name,5, "pylontech DmaxDisChargeCurrent  = $maxDisChargeCurrent _Line:" . __LINE__);
		my $status = substr($value,18,2);
		Log3($name,5, "pylontech Status = $status _Line:" . __LINE__);
		my $message;
		my $bits = unpack ("B*", pack("H*", $status));
		if(substr($bits,2,1) == 1) {
			$message .= "Charge immediately";
 			##32 = charge immediately
		}

		if(substr($bits,1,1) == 1) {
			$message .= "discharge enabled";
			## 64 = discharge enable
		}

		if(substr($bits,0,1) == 1) {
			$message .= "Charge enabled";
 			##128 = charge enable
		}

		Log3($name,5, "pylontech A = $message _Line:" . __LINE__);
		Log3($name,5, "pylontech B = $bits _Line:" . __LINE__);
				readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"Pack_$1_recommChargeVoltageLimit",$recommChargVoltageLimit ,1);
						readingsBulkUpdate($hash,"Pack_$1_recommDischargeVoltageLimit",$recommDischargeVoltageLimit ,1);
						readingsBulkUpdate($hash,"Pack_$1_maxChargeCurrent ",$maxChargeCurrent ,1);
						readingsBulkUpdate($hash,"Pack_$1_maxDisChargeCurrent ",$maxDisChargeCurrent ,1);
						readingsBulkUpdate($hash,"Pack_$1_general_status ",$message ,1);
					readingsEndUpdate($hash,1);
		Log3($name,5, "pylontech $cmd successful _Line:" . __LINE__);
		$success="success";
}elsif($cmd =~ /CELL(\d)/) {
	Log3($name,4, "pylontech cmd: analysiere $cmd _Line:" . __LINE__);

	# get Pack-Number
	Log3($name,5, "pylontech PackNummer = $1 _Line:" . __LINE__);



				readingsBeginUpdate($hash);
	readingsBulkUpdate($hash,"Pack_$1_Anzahl_Zellen",hex(substr($value,4,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle1",hex(substr($value,6,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle2",hex(substr($value,10,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle3",hex(substr($value,14,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle4",hex(substr($value,18,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle5",hex(substr($value,22,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle6",hex(substr($value,26,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle7",hex(substr($value,30,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle8",hex(substr($value,34,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle9",hex(substr($value,38,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle10",hex(substr($value,42,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle11",hex(substr($value,46,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle12",hex(substr($value,50,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle13",hex(substr($value,54,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle14",hex(substr($value,58,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Zelle15",hex(substr($value,62,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Temperaturfühler",substr($value,66,2),1);
	readingsBulkUpdate($hash,"Pack_$1_Temp1",(hex(substr($value,68,4))-2731)/10,1);
	readingsBulkUpdate($hash,"Pack_$1_Temp2",(hex(substr($value,72,4))-2731)/10,1);
	readingsBulkUpdate($hash,"Pack_$1_Temp3",(hex(substr($value,76,4))-2731)/10,1);
	readingsBulkUpdate($hash,"Pack_$1_Temp4",(hex(substr($value,80,4))-2731)/10,1);
	readingsBulkUpdate($hash,"Pack_$1_Temp5",(hex(substr($value,84,4))-2731)/10,1);
	
##	my $current = hex(substr($value,88,4))/10;
	my $current = unpack('s', pack('S', hex(substr($value,88,4))))/10;
##	$current -= 0x100000000 if $current >= 0x800000;

	readingsBulkUpdate($hash,"Pack_$1_Strom",$current,1);
	Log3($name,5, "pylontech Strom = " . substr($value,88,4) . ":" . $current . " _Line:" .  __LINE__);
	readingsBulkUpdate($hash,"Pack_$1_Spannung",hex(substr($value,92,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_Ah_left",hex(substr($value,96,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_unbekannt_hex",substr($value,100,2),1);
	readingsBulkUpdate($hash,"Pack_$1_Ah_total",hex(substr($value,102,4))/1000,1);
	readingsBulkUpdate($hash,"Pack_$1_cycle",hex(substr($value,106,4)),1);

	readingsEndUpdate($hash,1);
			
	Log3($name,5, "pylontech $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd =~ /WARN(\d)/) {
	Log3($name,4, "pylontech cmd: analysiere WARN _Line:" . __LINE__);
			
	# get Pack-Number
	Log3($name,5, "pylontech PackNummer = $1 _Line:" . __LINE__);
	
	
	readingsBeginUpdate($hash);
	
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle1",hex(substr($value,6,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle2",hex(substr($value,8,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle3",hex(substr($value,10,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle4",hex(substr($value,12,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle5",hex(substr($value,14,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle6",hex(substr($value,16,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle7",hex(substr($value,18,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle8",hex(substr($value,20,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle9",hex(substr($value,22,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle10",hex(substr($value,24,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle11",hex(substr($value,26,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle12",hex(substr($value,28,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle13",hex(substr($value,30,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle14",hex(substr($value,32,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Zelle15",hex(substr($value,34,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Anzahl_Temp",hex(substr($value,36,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Temp1",hex(substr($value,38,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Temp2",hex(substr($value,40,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Temp3",hex(substr($value,42,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Temp4",hex(substr($value,44,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Temp5",hex(substr($value,46,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_LadeStrom",hex(substr($value,48,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Spannung",hex(substr($value,50,2)),1);
	readingsBulkUpdate($hash,"Pack_$1_Warn_EntladeStrom",hex(substr($value,52,2)),1);
	my $message; 
	my $bits = unpack ("B*", pack("H*", substr($value,54,2)));
		if(substr($bits,7,1) == 1) {
			$message .= "OverVoltage";
 			##32 = charge immediately
		}
		if(substr($bits,6,1) == 1) {
			$message .= "iCell lower-limit-voltage";
 			##32 = charge immediately
		}
		if(substr($bits,5,1) == 1) {
			$message .= "Charge overcurrent";
 			##32 = charge immediately
		}
		if(substr($bits,4,1) == 1) {
			$message .= "intentionally blank";
 			##32 = charge immediately
		}
		if(substr($bits,3,1) == 1) {
			$message .= "Discharge overcurrent";
 			##32 = charge immediately
		}
		if(substr($bits,2,1) == 1) {
			$message .= "Discharge Temperature Protection";
 			##32 = charge immediately
		}
		if(substr($bits,1,1) == 1) {
			$message .= "Charge Temperature protection";
			## 64 = discharge enable
		}
		if(substr($bits,0,1) == 1) {
			$message .= "Pack Undervoltage";
 			##128 = charge enable
		}
	Log3($name,5, "pylontech W1A = $message _Line:" . __LINE__);
	Log3($name,5, "pylontech W1B = $bits _Line:" . __LINE__);

	readingsBulkUpdate($hash,"Pack_$1_Warn_Status1",$bits . ":" . $message,1);
	$message = "";
	my $bits = substr(unpack ("B*", pack("H*", substr($value,56,2))),4);
		if(substr($bits,3,1) == 1) {
			$message .= "Use the Pack Power ";
 			##32 = charge immediately
		}
		if(substr($bits,2,1) == 1) {
			$message .= "DFET ";
 			##32 = charge immediately
		}

		if(substr($bits,1,1) == 1) {
			$message .= "CFET ";
			## 64 = discharge enable
		}

		if(substr($bits,0,1) == 1) {
			$message .= "PreFET ";
 			##128 = charge enable
		}

	Log3($name,5, "pylontech A = $message _Line:" . __LINE__);
	Log3($name,5, "pylontech B = $bits _Line:" . __LINE__);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Status2",$bits . ":" . $message,1);
	$message = "";
	my $bits = unpack ("B*", pack("H*", substr($value,58,2)));
		if(substr($bits,7,1) == 1) {
			$message .= "Buzzer";
 			##32 = 
		}
		if(substr($bits,6,1) == 1) {
			$message .= "int blank";
 			##32 = 
		}
		if(substr($bits,5,1) == 1) {
			$message .= "int blank";
 			##32 = 
		}
		if(substr($bits,4,1) == 1) {
			$message .= "Fully Charged";
 			##32 = 
		}
		if(substr($bits,3,1) == 1) {
			$message .= "int blank";
 			##32 = 
		}
		if(substr($bits,2,1) == 1) {
			$message .= "Startup-Heater";
 			##32 = 
		}
		if(substr($bits,1,1) == 1) {
			$message .= "Effective Discharge Current";
			## 64 = discharge enable
		}
		if(substr($bits,0,1) == 1) {
			$message .= "Effective Charge Current";
 			##128 = charge enable
		}

	Log3($name,5, "pylontech A = $message _Line:" . __LINE__);
	Log3($name,5, "pylontech B = $bits _Line:" . __LINE__);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Status3",$bits . ":" .$message,1);
	$message = "";
	my $bits = unpack ("B*", pack("H*", substr($value,60,2)));
		if(substr($bits,7,1) == 1) {
			$message .= "Check Cell 1";
 			##32 = 
		}
		if(substr($bits,6,1) == 1) {
			$message .= "Check Cell 2";
 			##32 = 
		}
		if(substr($bits,5,1) == 1) {
			$message .= "Check Cell 3";
 			##32 = 3
		}
		if(substr($bits,4,1) == 1) {
			$message .= "Check Cell 4";
 			##32 = 
		}
		if(substr($bits,3,1) == 1) {
			$message .= "Check Cell 5";
 			##32 = 
		}
		if(substr($bits,2,1) == 1) {
			$message .= "Check Cell 6";
 			##32 = 
		}
		if(substr($bits,1,1) == 1) {
			$message .= "Check Cell 7";
			## 64 = discharge enable
		}
		if(substr($bits,0,1) == 1) {
			$message .= "Check Cell 8";
 			##128 = 
		}

	Log3($name,5, "pylontech A = $message _Line:" . __LINE__);
	Log3($name,5, "pylontech B = $bits _Line:" . __LINE__);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Status4",$bits . ":" .$message,1);
	$message = "";
	my $bits = unpack ("B*", pack("H*", substr($value,62,2)));
		if(substr($bits,7,1) == 1) {
			$message .= "Check Cell 9";
 			##32 = 
		}
		if(substr($bits,6,1) == 1) {
			$message .= "Check Cell 10";
 			##32 = 
		}
		if(substr($bits,5,1) == 1) {
			$message .= "Check Cell 11";
 			##32 = 3
		}
		if(substr($bits,4,1) == 1) {
			$message .= "Check Cell 12";
 			##32 = 
		}
		if(substr($bits,3,1) == 1) {
			$message .= "Check Cell 13";
 			##32 = 
		}
		if(substr($bits,2,1) == 1) {
			$message .= "Check Cell 14";
 			##32 = 
		}
		if(substr($bits,1,1) == 1) {
			$message .= "Check Cell 15";
			## 64 = discharge enable
		}
		if(substr($bits,0,1) == 1) {
			$message .= "Check Cell 16";
 			##128 = 
		}

	Log3($name,5, "pylontech A = $message _Line:" . __LINE__);
	Log3($name,5, "pylontech B = $bits _Line:" . __LINE__);
	readingsBulkUpdate($hash,"Pack_$1_Warn_Status5",$bits . ":" .$message,1);
	$message = "";

	readingsEndUpdate($hash,1);
	
	
	
	Log3($name,5, "pylontech $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "NOP") {
	Log3($name,4, "pylontech cmd: analysiere $cmd _Line:" . __LINE__);
	##my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "pylontech uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Number_of_Packs",$values[0],1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "pylontech $cmd successful _Line:" . __LINE__);
	$success="success";
} else {
	Log3($name,1,"pylontech cmd " . $cmd . " not implemented yet, putting value in _devel<nr>, Line: " . __LINE__);	
	readingsBeginUpdate($hash);
	Log3($name,1,"pylontech cmd  $cmd unknown");	
	if( AttrVal($name,"unknown_as_reading",0) eq "yes" ){
 		Log3($name,1,"putting $value in _devel");	
		readingsBulkUpdate($hash, "_devel",$value,1);
	}


	readingsEndUpdate($hash,1);
	Log3($name,5, "pylontech $cmd successful _Line:" . __LINE__);
	$success="success";
}

Log3($name,5, "pylontech analyze ready. success: $success _Line:" . __LINE__);
if($success eq "success"){
	$hash->{CONNECTION} = "established";
	$hash->{helper}{key} = "";
	$hash->{helper}{value} = "";
	$hash->{helper}{retrycount} = "";
	Log3($name, 5, "pylontech ($name) - pylontech_analyze_answer stoppe resend-timer. Line: " . __LINE__);	
	RemoveInternalTimer("resend:$name");
}


}

1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
