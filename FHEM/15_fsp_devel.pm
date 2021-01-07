##############################################
# $Id: 15_fsp_devel.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use Digest::CRC qw(crc);

my %requests_02 = (
	'P003PS' => "5e5030303350530d", # Query Power Status ## 2 sek
	'P007EMINFO' => "5e50303037454d494e464f0d"
);

my %requests_30 = (
	'P003WS' => "5e5030303357530d", # Query Warning Status ##30 sek
	'P003GS' => "5e5030303347530d", # Query General Status ##2 sek
	'P004MOD' => "5e503030344d4f440d" # Query Working Mode ## 30 sek
);

###############################
sub
fsp_devel_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "fsp_devel_Define";
  $hash->{SetFn}     = "fsp_devel_Set";
  $hash->{GetFn}     = "fsp_devel_Get";
  $hash->{UndefFn}   = "fsp_devel_Undef";
  $hash->{NotifyFn}    = "fsp_devel_Notify";
  $hash->{ReadFn}    = "fsp_devel_Read";
  $hash->{ReadyFn}    = "fsp_devel_Ready";
$hash->{AttrList}	= $readingFnAttributes . " mode:manual,automatic interval:2,5,10";
}

#####################################
sub
fsp_devel_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> fsp_devel <device>";
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];
 
  $hash->{NAME} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
  $hash->{NOTIFYDEV} 	= "global";
  $hash->{actionQueue} 	= [];
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "fsp_devel_DoInit" );
  Log3($name, 1, "fsp_devel DevIO_OpenDev_Define" . __LINE__); 
  $hash->{MODE} = AttrVal($name,"mode","automatic");
  $hash->{INTERVAL} = AttrVal($name,"interval",2);
  fsp_devel_prepareRequests("prepare:$name");
  
  return $ret;
}


sub
fsp_devel_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub fsp_devel_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
	$ret = DevIo_OpenDev($hash, 1, "fsp_devel_DoInit" );
}
###################################
sub fsp_devel_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};
Log3 $name, 4, "fsp_devel ($name) - fsp_devel_Notify  Line: " . __LINE__;    
return if (IsDisabled($name));
my $devname = $dev->{NAME};
my $devtype = $dev->{TYPE};
my $events = deviceEvents($dev,1);
Log3 $name, 4, "fsp_devel ($name) - fsp_devel_Notify - not disabled  Line: " . __LINE__;    
return if (!$events);
if( grep /^ATTR.$name.mode/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
        Log3 $name, 4, "fsp_devel ($name) - fsp_devel_Notify change mode to AttrVal($name,mode) _Line: " . __LINE__; 
        $hash->{MODE} = AttrVal($name,"mode","automatic");
}
if( grep /^ATTR.$name.interval/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
        Log3 $name, 4, "fsp_devel ($name) - fsp_devel_Notify change mode to AttrVal($name,mode) _Line: " . __LINE__; 
        $hash->{INTERVAL} = AttrVal($name,"interval",2);
	RemoveInternalTimer($hash); # Stoppe Timer
	InternalTimer(gettimeofday()+$hash->{INTERVAL},'fsp_devel_prepareRequests',"prepare:$name");
}


Log3 $name, 4, "fsp_devel ($name) - fsp_devel_Notify got events @{$events} Line: " . __LINE__;  
fsp_devel_prepareRequests("prepare:$name") if( grep /^INITIALIZED$/,@{$events}
                                or grep /^CONNECTED$/,@{$events}
                                or grep /^DELETEATTR.$name.disable$/,@{$events}
                                or grep /^DELETEATTR.$name.interval$/,@{$events}
                                or (grep /^DEFINED.$name$/,@{$events} and $init_done) );








return;

}
#####################################
sub fsp_devel_Undef($$)
{
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
  return undef;
}
#####################################
sub fsp_devel_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of cmd timer:noArg S005LON:0,1 S012FPADJ S005ED:feed_power_enable,feed_power_disable S013FPRADJ S013FPSADJ S013FPTADJ"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "fsp_devel argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	readingsSingleUpdate($hash,"1_1VERSION","1.06",1);
	$hash->{VERSION} = 1.13;
	Log3($name,5, "fsp_devel argument set fragezeichen _Line:" . __LINE__);
	return $usage;
	}
  	if ($a[1] eq "cmd"){
	Log3($name,5, "fsp_devel argument cmd _Line: " . __LINE__);
		if($hash->{MODE} eq "automatic"){
			Log3($name,5, "fsp_devel cmd in automatic mode" . __LINE__);
			RemoveInternalTimer($hash); # Stoppe Timer
			push(@{$hash->{helper}{addCMD}}, $a[2] );
			InternalTimer(gettimeofday()+$hash->{INTERVAL},'fsp_devel_prepareRequests',"prepare:$name");
		} else{
			Log3($name,5, "fsp_devel cmd in manual mode" . __LINE__);
			push(@{$hash->{helper}{addCMD}}, $a[2] );
			fsp_devel_sendRequests("send:$name");
		}
		readingsSingleUpdate($hash,"1_lastcmd",$a[2],1);
	return;	
	}
  	if ($a[1] eq "timer"){
	Log3($name,5, "fsp_devel argument timer" . __LINE__);
	InternalTimer(gettimeofday()+$hash->{INTERVAL},'fsp_devel_prepareRequests',"prepare:$name");
	}
	my $setcmd = $a[1];
	my $setvalue_hex;

	if(defined($a[2]) && $a[2] ne ""){
		$setvalue_hex = unpack "H*", $a[2];
	Log3($name,5, "fsp_devel setvalue $a[2] _Line: " . __LINE__);
	Log3($name,5, "fsp_devel setvalue $setvalue_hex _Line: " . __LINE__);
	}



	if ($setcmd eq "S005LON"){ #en/dis-able power supply to load
		my $push = "5e533030354c4f4e". $setvalue_hex ."0d";
		push(@{$hash->{helper}{addCMD}}, $push );
		Log3($name,5, "fsp_devel_set push: $push _Line: " . __LINE__);
	}elsif ($setcmd eq "S012FPADJ"){ # Feeding Grid power Calibrationi
		#S012FPADJm,nnnn
		#m = direktion => +=1; -=0
		#calibration power, range 0-1000
		my $sendstring = "5e53303132465041444a";
		if(defined($a[2]) && $a[2] ne "" && $a[2] != 0 && abs($a[2]) < 1000){
			if($a[2] > 0){
				$sendstring .= "312c"; ## hex für 1
			} else {
				$sendstring .= "302c"; ## hex für 0
			}
			Log3($name,5, "fsp_devel setFn S012FPADJ a2 $a[2] _Line: " . __LINE__);
			my @digits = split ("", $a[2]);
			my $value;
			foreach(@digits) {
				if($_ =~ /[0-9]/){
					$value .= unpack "H*", $_;
				}
			}
			while(length($value) < 8){
				$value = "30" . $value;
			}
			
			
			my $lenval = length($value);
			Log3($name,5, "fsp_devel setFn S012FPADJ laenge $lenval _Line: " . __LINE__);
			$sendstring .= $value;			
			$sendstring .= "0d";
			Log3($name,5, "fsp_devel setFn S012FPADJ $sendstring _Line: " . __LINE__);
		}
		## den Befehl wegsenden
		push(@{$hash->{helper}{addCMD}}, $sendstring);
		Log3($name,5, "fsp_devel_set push: $sendstring _Line: " . __LINE__);
		## und danach direkt abfragen, wie die aktuellen Werte sind
		push(@{$hash->{helper}{addCMD}}, "5e50303036465041444a0d");
	}elsif ($setcmd eq "S005ED"){ #
		my $value = $a[2] eq "feed_power_enable" ? "31" : "30";
		my $push = "5e53303035454443" . $value . "0d";
		push(@{$hash->{helper}{addCMD}}, $push );
		Log3($name,5, "fsp_devel_set push: $push _Line: " . __LINE__);
		readingsSingleUpdate($hash,"1_lastcmd",$push,1);
	}elsif ($setcmd eq "S013FPRADJ"){ #
		#S012FPRADJm,nnnn
		#m = direktion => +=1; -=0
		#calibration power, range 0-1000
		my $sendstring = "5e5330313346505241444a";
		if(defined($a[2]) && $a[2] ne "" && $a[2] != 0 && abs($a[2]) < 1000){
			if($a[2] > 0){
				$sendstring .= "312c"; ## hex für 1
			} else {
				$sendstring .= "302c"; ## hex für 0
			}
			Log3($name,5, "fsp_devel setFn S013FPRADJ a2 $a[2] _Line: " . __LINE__);
			my @digits = split ("", $a[2]);
			my $value;
			foreach(@digits) {
				if($_ =~ /[0-9]/){
					$value .= unpack "H*", $_;
				}
			}
			while(length($value) < 8){
				$value = "30" . $value;
			}
			
			
			my $lenval = length($value);
			Log3($name,5, "fsp_devel setFn S013FPADJ laenge $lenval _Line: " . __LINE__);
			$sendstring .= $value;			
			$sendstring .= "0d";
			Log3($name,5, "fsp_devel setFn S013FPADJ $sendstring _Line: " . __LINE__);
		}
		## den Befehl wegsenden
		push(@{$hash->{helper}{addCMD}}, $sendstring);
		Log3($name,5, "fsp_devel_set push: $sendstring _Line: " . __LINE__);
		## und danach direkt abfragen, wie die aktuellen Werte sind
		push(@{$hash->{helper}{addCMD}}, "5e50303036465041444a0d");
	}
	if ($setcmd eq "S013FPSADJ"){ #
		#S012FPSADJm,nnnn
		#m = direktion => +=1; -=0
		#calibration power, range 0-1000
		my $sendstring = "5e5330313346505341444a";
		if(defined($a[2]) && $a[2] ne "" && $a[2] != 0 && abs($a[2]) < 1000){
			if($a[2] > 0){
				$sendstring .= "312c"; ## hex für 1
			} else {
				$sendstring .= "302c"; ## hex für 0
			}
			Log3($name,5, "fsp_devel setFn S013FPSADJ a2 $a[2] _Line: " . __LINE__);
			my @digits = split ("", $a[2]);
			my $value;
			foreach(@digits) {
				if($_ =~ /[0-9]/){
					$value .= unpack "H*", $_;
				}
			}
			while(length($value) < 8){
				$value = "30" . $value;
			}
			
			
			my $lenval = length($value);
			Log3($name,5, "fsp_devel setFn S013FPADJ laenge $lenval _Line: " . __LINE__);
			$sendstring .= $value;			
			$sendstring .= "0d";
			Log3($name,5, "fsp_devel setFn S013FPADJ $sendstring _Line: " . __LINE__);
		}
		## den Befehl wegsenden
		push(@{$hash->{helper}{addCMD}}, $sendstring);
		Log3($name,5, "fsp_devel_set push: $sendstring _Line: " . __LINE__);
		## und danach direkt abfragen, wie die aktuellen Werte sind
		push(@{$hash->{helper}{addCMD}}, "5e50303036465041444a0d");
	}elsif ($setcmd eq "S013FPTADJ"){ #
		#S012FPTADJm,nnnn
		#m = direktion => +=1; -=0
		#calibration power, range 0-1000
		my $sendstring = "5e5330313346505441444a";
		if(defined($a[2]) && $a[2] ne "" && $a[2] != 0 && abs($a[2]) < 1000){
			if($a[2] > 0){
				$sendstring .= "312c"; ## hex für 1
			} else {
				$sendstring .= "302c"; ## hex für 0
			}
			Log3($name,5, "fsp_devel setFn S013FPTADJ a2 $a[2] _Line: " . __LINE__);
			my @digits = split ("", $a[2]);
			my $value;
			foreach(@digits) {
				if($_ =~ /[0-9]/){
					Log3($name,5, "fsp_devel setFn S013FPTADJ digits $_ _Line: " . __LINE__);
					$value .= unpack "H*", $_;
				}
			}
			while(length($value) < 8){
				$value = "30" . $value;
			}
			
			
			my $lenval = length($value);
			Log3($name,5, "fsp_devel setFn S013FPTADJ laenge $lenval _Line: " . __LINE__);
			$sendstring .= $value;			
			$sendstring .= "0d";
			Log3($name,5, "fsp_devel setFn S013FPTADJ $sendstring _Line: " . __LINE__);
		}
		## den Befehl wegsenden
		push(@{$hash->{helper}{addCMD}}, $sendstring);
		Log3($name,5, "fsp_devel_set push: $sendstring _Line: " . __LINE__);
		## und danach direkt abfragen, wie die aktuellen Werte sind
		push(@{$hash->{helper}{addCMD}}, "5e50303036465041444a0d");
	}elsif ($setcmd eq ""){ #
		push(@{$hash->{helper}{addCMD}}, "");
	}
	if($hash->{MODE} eq "automatic"){
		Log3($name,5, "fsp_devel setcmd in automatic mode" . __LINE__);
		RemoveInternalTimer($hash); # Stoppe Timer
		fsp_devel_sendRequests("send:$name");
	} else{
		Log3($name,5, "fsp_devel setcmd in manual mode" . __LINE__);
		fsp_devel_sendRequests("send:$name");
	}
}
#####################################
sub fsp_devel_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of P003PI:noArg P003ID:noArg P004VFW:noArg P005VFW2:noArg P003MD:noArg P005PIRI:noArg P005FLAG:noArg P002T:noArg P003ET:noArg P004GOV:noArg P004GOF:noArg P005OPMP:noArg P005GPMP:noArg P006MPPTV:noArg P004LST:noArg P003SV:noArg P003DI:noArg P005BATS:noArg P003DM:noArg P004MAR:noArg P004CFS:noArg P005HECS:noArg P006GLTHV:noArg P004FET:noArg P003FT:noArg P005ACCT:noArg P005ACLT:noArg P006FPADJ:noArg P006FPPF:noArg P005AAPF:noArg P007EMINFO:noArg";
	Log3($name,5, "fsp_devel argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fsp_devel argument get fragezeichen _Line: " . __LINE__);
	return $usage;
	}

	my $getcmd = $a[1];
	if ($getcmd eq "P003PI"){ # Query Protocol ID
		push(@{$hash->{helper}{addCMD}}, "5e5030303350490d");
	}

	if ($getcmd eq "P003ID"){ #Query Series Number
		push(@{$hash->{helper}{addCMD}}, "5e5030303349440d");
	}
	
	if ($getcmd eq "P004VFW"){ #Query CPU Version
		push(@{$hash->{helper}{addCMD}}, "5e503030345646570d");
	}

	if ($getcmd eq "P005VFW2"){ #Query secondary CPU Version
		push(@{$hash->{helper}{addCMD}}, "5e50303035564657320d");
	}
	
	if ($getcmd eq "P003MD"){ #Query Device Model
		push(@{$hash->{helper}{addCMD}}, "5e503030334d440d");
	}

	if ($getcmd eq "P005PIRI"){ # Query rated information
		push(@{$hash->{helper}{addCMD}}, "5e50303035504952490d");
	}
	if ($getcmd eq "P005FLAG"){ # Query Flag Status
		push(@{$hash->{helper}{addCMD}}, "5e50303035464c41470d");
	}
	if ($getcmd eq "P002T"){ # Query current Time
		push(@{$hash->{helper}{addCMD}}, "5e50303032540d");
	}
	if ($getcmd eq "P003ET"){ # Query total generated Energy
		push(@{$hash->{helper}{addCMD}}, "5e5030303345540d");
	}
	if ($getcmd eq "P010EYyyyynnn"){ # Query generated Energy of year
		push(@{$hash->{helper}{addCMD}}, "");
		## Implementierung ist mir grade unwichtig
	}
	if ($getcmd eq "P012EMyyyymmnnn"){ #  Query generated Energy of month 
		push(@{$hash->{helper}{addCMD}}, "");
		## Implementierung ist mir grade unwichtig
	}
	if ($getcmd eq "P014EDyyyymmddnnn"){ #  Query generated Energy of day 
		push(@{$hash->{helper}{addCMD}}, "");
		## Implementierung ist mir grade unwichtig
		#das hier scheint aber interessant
	}
	if ($getcmd eq ""){ #  Query generated Energy of hour 
		push(@{$hash->{helper}{addCMD}}, "");
		## Implementierung ist mir grade unwichtig
	}
	if ($getcmd eq "P004GOV"){ # Query AC input Voltage acceptable range for feed Power
		push(@{$hash->{helper}{addCMD}}, "5e50303034474f560d");
	}
	if ($getcmd eq "P004GOF"){ # Query AC input frequency acceptable range for feed Power
		push(@{$hash->{helper}{addCMD}}, "5e50303034474f460d");
	}
	if ($getcmd eq "P005OPMP"){ #Query the maximum output power - durchgestrichen.. 
		push(@{$hash->{helper}{addCMD}}, "5e503030354f504d500d");
	}
	if ($getcmd eq "P005GPMP"){ # Query the maximum output Power for feeding Grid
		push(@{$hash->{helper}{addCMD}}, "5e5030303547504d500d");
	}
	if ($getcmd eq "P006MPPTV"){ #Query Solar input MPP acceptable Range
		push(@{$hash->{helper}{addCMD}}, "5e3030364d505054560d");
	}
	if ($getcmd eq "P004LST"){ #Query LCD Sleeping Time
		push(@{$hash->{helper}{addCMD}}, "5e503030344c53540d");
	}
	
	if ($getcmd eq "P003SV"){ # Query Solar input Voltage acceptable Range
		push(@{$hash->{helper}{addCMD}}, "5e5030303353560d");
	}
	if ($getcmd eq "P003DI"){ # Query default Value for changeable Parameter
		push(@{$hash->{helper}{addCMD}}, "5e5030303344490d");
	}
	if ($getcmd eq "P005BATS"){ # Query Battery Setting
		push(@{$hash->{helper}{addCMD}}, "5e50303035424154530d");

	}
	if ($getcmd eq "P003DM"){ # Query Machine Model
		push(@{$hash->{helper}{addCMD}}, "5e50303033444d0d");
	}
	if ($getcmd eq "P004MAR"){ # Query Maschine Adjustable range
		push(@{$hash->{helper}{addCMD}}, "5e503030344d41520d");
	}
	if ($getcmd eq "P004CFS"){ # Query current Fault Status
		push(@{$hash->{helper}{addCMD}}, "5e503030344346530d");
	}
	if ($getcmd eq "P006HFSnn"){ # Query history fault parameter
		push(@{$hash->{helper}{addCMD}}, "");
		# unwichtig ?!?
	}
	if ($getcmd eq "P005HECS"){ # Query Energy control Status
		push(@{$hash->{helper}{addCMD}}, "5e50303035484543530d");
	}
	if ($getcmd eq "P006GLTHV"){ # Query AC input long-lime highest average Power
		push(@{$hash->{helper}{addCMD}}, "5e50303036474c5448560d");
	}
	if ($getcmd eq "P004FET"){ #Query first generated energy save time
		push(@{$hash->{helper}{addCMD}}, "5e503030344645540d");
	}
	if ($getcmd eq "P003FT"){ # Query wait time for Feed Power
		push(@{$hash->{helper}{addCMD}}, "5e5030303346540d");
	}
	if ($getcmd eq "P005ACCT"){ #Query AC charge time bucket
		push(@{$hash->{helper}{addCMD}}, "5e50303035414343540d");
	}
	if ($getcmd eq "P005ACLT"){ #Query AC supply load time bucket
		push(@{$hash->{helper}{addCMD}}, "5e5030303541434c540d");
	}
	if ($getcmd eq "P006FPADJ"){ #Query feeding grid power calibration
		push(@{$hash->{helper}{addCMD}}, "5e50303036465041444a0d");
		## kandidat für automatik? 
	}
	if ($getcmd eq "QDVPR"){ #Query feeding grid power calibration
		push(@{$hash->{helper}{addCMD}}, "5e51445650520d");
	}
	if ($getcmd eq "P006FPPF"){ #Query feed in Power factor
		push(@{$hash->{helper}{addCMD}}, "5e50303036465050460d");
	}
	if ($getcmd eq "P007EMINFO"){ #Query feed in Power factor
		push(@{$hash->{helper}{addCMD}}, "5e50303037454d494e464f0d");
		Log3($name,3, "fsp_devel($name) adding $getcmd to cmdqueue _Line:" . __LINE__);
		Log3($name,4, "fsp_devel($name) cmdqueue scalar(@{$hash->{helper}{addCMD}}  _Line:" . __LINE__);
	}
	if ($getcmd eq "P005AAPF"){ #query auto-adjust PF with power Information (rot gefärbt)
		push(@{$hash->{helper}{addCMD}}, "5e50303035414150460d");
		## kandidat für automatik? 
	}
	if($hash->{MODE} eq "automatic"){
		Log3($name,3, "fsp_devel($name) getcmd in automatic mode" . __LINE__);
		RemoveInternalTimer("send:$name"); # Stoppe Timer
		fsp_devel_sendRequests("send:$name");
	} else{
		Log3($name,3, "fsp_devel($name) getcmd in manual mode" . __LINE__);
		fsp_devel_sendRequests("send:$name");
	}
}
#######################################
sub fsp_devel_prepareRequests{
	
#	my ($hash) = @_;
#	my $name = $hash->{NAME};
	my ($calltype,$name) = split(':', $_[0]);
	my $hash = $defs{$name};
	Log3($name,4, "fsp_devel prepareRequests _Line:" . __LINE__);

	if ($calltype eq 'prepare'){
	#leere das array
	#$hash->{actionQueue} 	= [];
	#fülle das array mit den abzufragenden werten
	foreach my $key (keys %requests_02){ 
		push(@{$hash->{actionQueue}}, $requests_02{$key} );
		Log3($name,4, "fsp_devel($name) prepareRequests_02 key $key value $requests_02{$key}_Line:" . __LINE__);
	}
	my $now = gettimeofday();
	$hash->{helper}{timer1} = $hash->{helper}{timer1} // 0; ## if helper_timer is not defined, use 0 
	if($now - $hash->{helper}{timer1} > 30){
		foreach my $key (keys %requests_30){ 
			push(@{$hash->{actionQueue}}, $requests_30{$key} );
			Log3($name,4, "fsp_devel($name) prepareRequests_30 key $key value $requests_30{$key}_Line:" . __LINE__);
		}
	$hash->{helper}{timer1} = gettimeofday();
	}
	#rufe sendRequests auf
	fsp_devel_sendRequests("send:$name");
	}elsif($calltype eq 'watchdog'){
		
	}	

}


sub fsp_devel_sendRequests{

	#my ($hash) = @_;
	#my $name = $hash->{NAME};
	my ($calltype,$name) = split(':', $_[0]);
	my $hash = $defs{$name};
	Log3($name,4, "fsp_devel sendRequests calltype $calltype _Line:" . __LINE__);
	
	# anzahl der Items bestimmen
	my $len = @{$hash->{actionQueue}};
	Log3($name,4, "fsp_devel addCMD length $len before adding _Line:" . __LINE__);
	foreach(@{$hash->{helper}{addCMD}}){
		Log3($name,4, "fsp_devel addCMD adding item $_ _Line:" . __LINE__);
		push(@{$hash->{actionQueue}}, shift(@{$hash->{helper}{addCMD}}));
	}
	$len = @{$hash->{actionQueue}};
	Log3($name,4, "fsp_devel addCMD length $len after adding _Line:" . __LINE__);

	my $length = @{$hash->{actionQueue}};
	Log3($name,4, "fsp_devel actionQueue length $length _Line:" . __LINE__);
	if($length > 0){
		#nehme den ersten Wert aus dem array und sende ihn
		my $req = shift( @{$hash->{actionQueue}});
		Log3($name,4, "fsp_devel sendRequests sende $req _Line:" . __LINE__);
		DevIo_SimpleWrite($hash,$req,1);
		#tue gar nichts weiter, denn du wirst vom read aufgerufen
		# doch, starte einen Watchdog-Timer, falls das Read nicht antwortet
		InternalTimer(gettimeofday()+1,'fsp_devel_sendRequests',"watchdog:$name");

	} else {
		#rufe prepareRequests auf
		Log3($name,4, "fsp_devel sendRequests _Line: " . __LINE__);
		if($hash->{MODE} eq "automatic"){
			InternalTimer(gettimeofday()+$hash->{INTERVAL},'fsp_devel_prepareRequests',"prepare:$name");
		}
	}
}
####################################
sub fsp_devel_Read($$)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{CONNECTION} = "established";
	Log3($name,5, "fsp_devel jetzt wird gelesen _Line:" . __LINE__);
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,5, "fsp_devel buffer: $buf _Line: " . __LINE__);
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "fsp_devel Fehler beim lesen _Line:" . __LINE__);
		$hash->{CONNECTION} = "failed";
		return "error" ;
	}
	$hash->{helper}{recv} .= $buf; 
	Log3($name,5, "fsp_devel($name) helper_recv: $hash->{helper}{recv}  _Line: " . __LINE__ );

#	readingsSingleUpdate($hash,"1_recv",$hash->{helper}{recv},1);
	## check if received Data is complete
	#
	my $value = unpack "H*", $hash->{helper}{recv};
	Log3($name,5, "fsp_devel devpack_hex: $value _Line: " . __LINE__ );
	$hash->{helper}{received_hex} = $value;
##	if ($value =~ /.*?5e(.*?)(....)0d/){
	if ($value =~ /.*?(5e.*?0d)/){
##	readingsSingleUpdate($hash,"1_checksum",$2,1);
		##
##	Log3($name,5, "fsp_devel checksum: $1 _Line: " . __LINE__ );
	my $dev = pack ('H*',$1);
	Log3($name,5, "fsp_devel($name) rcvMessage: $1 _Line: " . __LINE__ );
	
	my @h1 = ($1 =~ /(..)/g);
	my @val2 = map { pack ("H2", $_) } @h1;	
	my $out="";
	foreach my $part (@val2){
		$out .= $part;
	}
	$hash->{helper}{received_ascii} = $out;
	Log3($name,4, "fsp_devel received_ascii: $out _Line: " . __LINE__ );

#	readingsSingleUpdate($hash,"1_recv_ascii",$out,1);
	fsp_devel_analyzeAnswer($hash);
	$hash->{helper}{recv} = "";
	## Watchdog-Timer entfernen, da Antwort empfangen und verarbeitet.
	RemoveInternalTimer("watchdog:$name");
	$value="";
	fsp_devel_sendRequests("send:$name");
	}
	return;
}
##########################################
sub fsp_devel_check_sum{
## fsp_devel_check_sum($response);
  my $hash = shift @_;
  my $name = $hash->{NAME};
my $debu3 = length($hash->{helper}{received_ascii});
	Log3($name,5, "fsp_devel check_sum length(received_ascii): $debu3 _Line:" . __LINE__);
  if(length($hash->{helper}{received_ascii})== 0){
	Log3($name,5, "fsp_devel fehler:received ist empty or undefined: $hash->{helper}{received_ascii} _Line:" . __LINE__);
	return (0);	  
	}
  my $resp1 = substr ($hash->{helper}{received_ascii} , 0,-3  );
  my $crc = substr ($hash->{helper}{received_ascii} , -3,2  );
	Log3($name,5, "fsp_devel check_sum response: $hash->{helper}{received_ascii} _Line:" . __LINE__);
	Log3($name,5, "fsp_devel check_sum resp1: $resp1 _Line:" . __LINE__);
	Log3($name,5, "fsp_devel check_sum crc: $crc _Line:" . __LINE__);
  # ^D0251496161801100008000000
  # \^(D)(\d{3})(.*)(\d{2})$
  ( my ($label, $len, $payload) = 
	  ($resp1 =~ /\^(\w)(\d{3})(.*)$/) )  
	  or return (0) ;
	Log3($name,5, "fsp_devel check_sum label: $label _Line:" . __LINE__);
	Log3($name,5, "fsp_devel check_sum len: $len _Line:" . __LINE__);
	Log3($name,5, "fsp_devel check_sum payload: $payload _Line:" . __LINE__);

  # compare real length with announced lengthi
  my $debu = length($hash->{helper}{received_ascii})-5-$len;
  return (0) if ( length($hash->{helper}{received_ascii})-5-$len ) ;
	Log3($name,5, "fsp_devel check_sum length(response)-5-len (sollte 0 sein): $debu _Line:" . __LINE__);
 
  my $digest = crc($resp1, 16, 0x0000, 0x0000, 0 , 0x1021, 0, 1);
 my $debu2 = unpack ('n', $crc ) ; 
 	my $crc1 = $digest >> 8; 
	my $crc2 = $digest & "0b11111111";
 if ($crc1 eq 0x28 || $crc1 eq 0x0d || $crc1 eq 0x0a){
	Log3($name,0, "fsp_devel check_sum CRC mismatch before $crc1 _Line:" . __LINE__);
	$crc1=$crc1+0x01;
	$crc1 = $crc1 << 8;
	Log3($name,0, "fsp_devel check_sum CRC mismatch after $crc1 _Line:" . __LINE__);
	$digest =  $crc1 + $crc2; 
	}
 if ($crc2 eq 0x28 || $crc2 eq 0x0d || $crc2 eq 0x0a){
	Log3($name,0, "fsp_devel check_sum CRC mismatch before $crc2 _Line:" . __LINE__);
	$crc2=$crc2+0x01;
	Log3($name,0, "fsp_devel check_sum CRC mismatch after $crc2 _Line:" . __LINE__);
	$digest =  $crc1 + $crc2; 
 }
 return (0) unless $digest == unpack ('n', $crc  )  ;
	Log3($name,5, "fsp_devel check_sum check: $digest == $debu2 _Line:" . __LINE__);
	my $order = $label . $len;
  return ($order, $payload); 
	  #  sprintf("%04x", unpack ('n', $crc,  )), 
	  #  sprintf("%04x", $digest) 
}
#######################################
sub fsp_devel_analyzeAnswer
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name,3, "fsp_devel analyzeAnswer jetzt wird ausgewertet _Line:" . __LINE__);
	my ($order,$data) = fsp_devel_check_sum($hash);
	Log3($name,5, "fsp_devel analyzeAnswer order: $order _Line:" . __LINE__);
	Log3($name,5, "fsp_devel analyzeAnswer data: $data _Line:" . __LINE__);
	if (!length($order) || !length($data)){
		Log3($name,5, "fsp_devel analyzeAnswer Error _Line:" . __LINE__);
		return (0);	
	}
	my @splits = split(",",$data);

	if($order eq "D025"){ ##  Query Series Number, P003ID 
		readingsSingleUpdate($hash,"SerialNumber",$splits[0],1);
	}elsif($order eq "D101"){ ## Query Power Status, P003PS, 5e5030303350530d
	
       		readingsBeginUpdate($hash);
	 	readingsBulkUpdate($hash,"Solar_input_power_1",int($splits[0]),1);
	 	readingsBulkUpdate($hash,"Solar_input_power_2",int($splits[1]),1);
	 	readingsBulkUpdate($hash,"Solar_input_power_total",int($splits[0]+$splits[1]),1);
##	 	readingsBulkUpdate($hash,"Battery_Power",$splits[2],1); Field is empty in original answer
	 	readingsBulkUpdate($hash,"AC_input_active_Power_R",int($splits[3]),1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_S",int($splits[4]),1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_T",int($splits[5]),1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_total",int($splits[6]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_R",int($splits[7]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_S",int($splits[8]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_T",int($splits[9]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_total",int($splits[10]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_R",int($splits[11]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_S",int($splits[12]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_T",int($splits[13]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_total",int($splits[14]),1);
	 	readingsBulkUpdate($hash,"AC_output_power_percentage",int($splits[15]),1);
		$splits[16] = $splits[16] == 0 ? "disconnected" : "connected";
	 	readingsBulkUpdate($hash,"AC_output_connect_status",$splits[16],1);
		$splits[17] = $splits[17] == 0 ? "idle" : "working";
	 	readingsBulkUpdate($hash,"Solar_input_work_status_1",$splits[17],1);
		$splits[18] = $splits[18] == 0 ? "idle" : "working";
	 	readingsBulkUpdate($hash,"Solar_input_work_status_2",$splits[18],1);
		$splits[19] = $splits[19] == 0 ? "standby" : $splits[19] == 1 ? "charge" : "discharge";
	 	readingsBulkUpdate($hash,"Battery_Power_direction",$splits[19],1);
		$splits[20] = $splits[20] == 0 ? "standby" : $splits[20] == 1 ? "AC->DC" : "DC->AC";
	 	readingsBulkUpdate($hash,"DC-AC_Power_direction",$splits[20],1);
		$splits[21] = $splits[21] == 0 ? "standby" : $splits[21] == 1 ? "input" : "output";
	 	readingsBulkUpdate($hash,"Line_Power_direction",$splits[21],1);
	 readingsEndUpdate($hash,1);
	
	
	}elsif($order eq "D047"){ ## Query Warning Status, P003WS, 5e5030303357530d
	 readingsBeginUpdate($hash);
	 	readingsBulkUpdate($hash,"Solar_input_loss_1",int($splits[0]),1);
	 	readingsBulkUpdate($hash,"Solar_input_loss_2",int($splits[1]),1);
	 	readingsBulkUpdate($hash,"Solar_input_too_high_1",$splits[2],1);
	 	readingsBulkUpdate($hash,"Solar_input_too_high_1",int($splits[3]),1);
	 	readingsBulkUpdate($hash,"Battery_under_voltage",int($splits[4]),1);
	 	readingsBulkUpdate($hash,"Battery_low_voltage",int($splits[5]),1);
	 	readingsBulkUpdate($hash,"Battery_disconnected",int($splits[6]),1);
	 	readingsBulkUpdate($hash,"Battery_over_voltage",int($splits[7]),1);
	 	readingsBulkUpdate($hash,"Battery_low_in_hybrid_mode",int($splits[8]),1);
	 	readingsBulkUpdate($hash,"Grid_voltage_too_high",int($splits[9]),1);
	 	readingsBulkUpdate($hash,"Grid_voltage_too_low",int($splits[10]),1);
	 	readingsBulkUpdate($hash,"Grid_frequency_too_high",int($splits[11]),1);
	 	readingsBulkUpdate($hash,"Grid_frequency_too_low",int($splits[12]),1);
	 	readingsBulkUpdate($hash,"Grid_long_time_average_too_high",int($splits[13]),1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_out_of_range",int($splits[14]),1);
	 	readingsBulkUpdate($hash,"AC_input_frequency_out_of_range",int($splits[15]),1);
	 	readingsBulkUpdate($hash,"AC_input_island",int($splits[16]),1);
	 	readingsBulkUpdate($hash,"AC_input_phase_dislocation",$splits[17],1);
	 	readingsBulkUpdate($hash,"Overtemperature",$splits[18],1);
	 	readingsBulkUpdate($hash,"Overload",$splits[19],1);
	 	readingsBulkUpdate($hash,"Emergency_power_off_active",$splits[20],1);
	 	readingsBulkUpdate($hash,"AC_input_wave_terrible",$splits[21],1);
	 readingsEndUpdate($hash,1);
	
	}elsif($order eq "D030"){ ## Query feed in grid calibration, P006FPADJ, 5e50303036465041444a0d
		if(scalar(@splits) == 8)
		{	
		 readingsBeginUpdate($hash);
		my $factor= undef;
			$factor = $splits[0] == 0 ? -1 : 1;
			readingsBulkUpdate($hash,"grid_power_calibration_total",int($splits[1])*$factor,1);
			$factor = $splits[2] == 0 ? -1 : 1;
			readingsBulkUpdate($hash,"grid_power_calibration_R",int($splits[3])*$factor,1);
			$factor = $splits[4] == 0 ? -1 : 1;
			readingsBulkUpdate($hash,"grid_power_calibration_S",int($splits[5])*$factor,1);
			$factor = $splits[6] == 0 ? -1 : 1;
			readingsBulkUpdate($hash,"grid_power_calibration_T",int($splits[7])*$factor,1);
	
			 readingsEndUpdate($hash,1);
 		} elsif(scalar(@splits) == 6)
 		{
		 readingsBeginUpdate($hash);
			readingsBulkUpdate($hash,"EMINFO_A",int($splits[0]),1);
			readingsBulkUpdate($hash,"EMINFO_default_feedin_power",int($splits[1]),1);
			readingsBulkUpdate($hash,"EMINFO_actual_PV_power",int($splits[2]),1);
			readingsBulkUpdate($hash,"EMINFO_actual_feedin_power",int($splits[3]),1);
			readingsBulkUpdate($hash,"EMINFO_actual_reserved_power",int($splits[4]),1);
			readingsBulkUpdate($hash,"EMINFO_F",int($splits[5]),1);
		 readingsEndUpdate($hash,1);
		}
 	}elsif($order eq "D005"){ ## Query Working Mode, P004MOD, 5e503030344d4f440d
	my $state;
		if($splits[0] ==0){
		$state = "Power on Mode";
		} elsif($splits[0] ==1){
		$state = "Standby Mode";
		} elsif($splits[0] ==2){
		$state = "Bypass Mode";
		} elsif($splits[0] ==3){
		$state = "Battery Mode";
		} elsif($splits[0] ==4){
		$state = "Fault Mode";
		} elsif($splits[0] ==5){
		$state = "Hybrid mode";
		} elsif($splits[0] ==6){
		$state = "Charge Mode";
		}

	readingsSingleUpdate($hash,"working_mode",$state,1);
	
	}elsif($order eq "D008"){ ## Query the maximum output Power for feeding Grid P005GPMP, 5e5030303547504d500d
	readingsSingleUpdate($hash,"max_feeding_power_pw",int($splits[0]),1);
	
	Log3($name,4, "fsp_devel analyzeAnswer splits0: $splits[0] _Line:" . __LINE__);
	
	
	}elsif($order eq "D110"){ ## Query Power Status, P003GS, 5e5030303347530d
	my $leng = @splits;
	Log3($name,4, "fsp_devel analyzeAnswer length $leng _Line:" . __LINE__);
	Log3($name,4, "fsp_devel analyzeAnswer 0 $splits[0] _Line:" . __LINE__);

	 readingsBeginUpdate($hash);
	 	readingsBulkUpdate($hash,"Solar_input_voltage_1",int($splits[0])/10,1);
	 	readingsBulkUpdate($hash,"Solar_input_voltage_2",int($splits[1])/10,1);
	 	readingsBulkUpdate($hash,"Solar_input_current_1",int($splits[2])/100,1);
	 	readingsBulkUpdate($hash,"Solar_input_current_2",int($splits[3])/100,1);
	 	readingsBulkUpdate($hash,"Battery_voltage",int($splits[4])/10,1);
	 	readingsBulkUpdate($hash,"Battery_capacity",int($splits[5]),1);
		my $powerdirection = ReadingsVal($name,"Battery_Power_direction","");
		my $battpower;
	        my $powerdir = 1;	
		if(length($powerdirection) && $powerdirection eq "charge"){
			$powerdir = -1;
		}
		$battpower = ($splits[4]/10) * ($splits[6]/10) * $powerdir;
	 	readingsBulkUpdate($hash,"Battery_current",($splits[6]/10)*$powerdir,1);
	 	readingsBulkUpdate($hash,"Battery_Power",$battpower,1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_R",int($splits[7]),1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_S",int($splits[8]),1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_T",int($splits[9]),1);
	 	readingsBulkUpdate($hash,"AC_input_frequency",$splits[10]/100,1);
	 	readingsBulkUpdate($hash,"AC_input_current_R",int($splits[11]),1);
	 	readingsBulkUpdate($hash,"AC_input_current_S",int($splits[12]),1);
	 	readingsBulkUpdate($hash,"AC_input_current_T",int($splits[13]),1);
	 	readingsBulkUpdate($hash,"AC_output_voltage_R",int($splits[14])/10,1);
	 	readingsBulkUpdate($hash,"AC_output_voltage_S",int($splits[15])/10,1);
	 	readingsBulkUpdate($hash,"AC_output_voltage_T",int($splits[16])/10,1);
	 	readingsBulkUpdate($hash,"AC_output_frequency",$splits[17]/100,1);
		#Output-Current not available
		#readingsBulkUpdate($hash,"AC_output_current_R",int($splits[18])/10,1);
		#readingsBulkUpdate($hash,"AC_output_current_S",int($splits[19])/10,1);
		#readingsBulkUpdate($hash,"AC_output_current_T",int($splits[20])/10,1);
	 	
		readingsBulkUpdate($hash,"inner_temperature",int($splits[21]),1);
	 	readingsBulkUpdate($hash,"component_max_temperature",int($splits[22]),1);
	 	readingsBulkUpdate($hash,"external_batt_temperature",$splits[23],1);
	 	readingsBulkUpdate($hash,"settings_changed",$splits[24],1);
	 readingsEndUpdate($hash,1);
	}else {
		
		readingsSingleUpdate($hash,"1_communication",$hash->{helper}{received_hex},1);
	}

	
	
	
	
	return;
}


1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
