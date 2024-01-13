#!/usr/bin/perl

#
# LaPolicia.pl
#
# Checks all processes for excess CPU usage over time and deprioritizes them. Default configuration
# looks for processes using > 95% CPU for more than 120 seconds where the UID owning the process is
# >= 1000. Processes matching the above criteria are reprioritized from a normal value of 20 to 35.
#
# Add to root crontab:
# * * * * * perl /root/lapolicia.pl > /dev/null 2>&1
#
# Test with a CPU intensive process:
# yes > /dev/null
#

use POSIX qw(strftime);
use strict;
use warnings;

####################

my $intMinUID = 1000;

my $intCPUPercentThreshold = 95;
my $intCPUSecondsThreshold = 120;
my $intNicePenalty         = 15;
my $intIONicePenalty       = 7;

my $strTopCommand    = "ps -axo uid,user,pid,pcpu,pmem,pri,ni,cputimes,cmd --sort -pcpu,-cputimes";
my $strReniceCommand = "renice -n $intNicePenalty -p";
my $strIONiceCommand = "ionice -c 2 -n $intIONicePenalty -p";

my $strLogFile = "/root/lapolicia.log";

####################

sub AddToLog
{
	my ($strLogFile, $strLogText) = @_;

	my $hLogFile;

	unless (-e $strLogFile)
	{
		if (open($hLogFile, "> $strLogFile"))
		{
			print $hLogFile "La Policia Log File\n";
			print $hLogFile "\n";

			close($hLogFile);
		}
	}

	if (open($hLogFile, ">> $strLogFile"))
	{
		print $hLogFile $strLogText;

		close($hLogFile);
	}
}

my $hTop;
my $i;
my $j;
my $strUID;
my $strUser;
my $strPID;
my $strCPU;
my $strMEM;
my $strPri;
my $strNice;
my $strTime;
my $strCmd;
my $strDate;

print "La Policia is checking for bad bois...\n";
print "\n";

if (open($hTop, "$strTopCommand |"))
{
	$i = 0;
	$j = 0;

	while (<$hTop>)
	{
		if (/^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/)
		{
			$strUID  = $1;
			$strUser = $2;
			$strPID  = $3;
			$strCPU  = $4;
			$strMEM  = $5;
			$strPri  = $6;
			$strNice = $7;
			$strTime = $8;
			$strCmd  = $9;

			if (int($strUID) >= $intMinUID && int($strCPU) >= $intCPUPercentThreshold && int($strTime) >= $intCPUSecondsThreshold && int($strNice) < $intNicePenalty)
			{
				$strDate = strftime("%Y/%m/%d %H:%M:%S", localtime());

				print "$strDate\n";
				print "Renicing the following offending processes:\n";
				print " -> PID $strPID owned by $strUID/$strUser using %CPU/%MEM $strCPU/$strMEM for $strTime seconds\n";
				print " -> Command: $strCmd\n";
				print "\n";

				AddToLog($strLogFile, "$strDate\n");
				AddToLog($strLogFile, "Renicing the following offending processes:\n");
				AddToLog($strLogFile, " -> PID $strPID owned by $strUID/$strUser using %CPU/%MEM $strCPU%/$strMEM% for $strTime seconds\n");
				AddToLog($strLogFile, " -> Command: $strCmd\n");
				AddToLog($strLogFile, "\n");

				system($strReniceCommand . " " . $strPID);
				system($strIONiceCommand . " " . $strPID);

				$j = $j + 1;
			}

			$i = $i + 1;
		}
	}

	print " -> $i processes reviewed\n";
	print " -> $j bad bois deprioritized\n";
}
else
{
	print "Oops! Couldn't run top command: $strTopCommand\n";
}
