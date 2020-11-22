#!/usr/bin/perl

# Copyright 2020 - James Toebes
# Simple script to use a USB key for locking and unlocking a computer.
# james@toebesacademy.com
# https://james.toebesacademy.com
# Let me know what you think.


use strict;
use Term::ReadKey;
use Term::ANSIColor qw(:constants);
use FindBin qw($RealBin);

my @usbentries = `lsusb | cut -d ' ' -f 6,7- | sed 's/ / "/' | sed 's/\$/"/'`;

#Read a single key,  show on screen and return
sub onekey {
    ReadMode 'cbreak';
    my $key = ReadKey(0);
    ReadMode 'normal';
    print $key;
    return $key;
}
    
#Select an entry from an array of entries.
sub selentry {
    my @entries = shift;
    my $cursel = 0;
    my $key;
    ReadMode 'cbreak';
    while (1) {
        #Sho entries
        my $row = -1;
        foreach my $entry (@usbentries) {
            $row++;
            chomp ($entry);
            #Highlight current row
            if ($cursel == $row) {print REVERSE;}
            print "$entry\n";
            print RESET;
        }

        #Look for input        
        $key = ord(ReadKey(0));
        if ($key eq 27 ) {
            #Start of cursor escape sequence.  Check if second part is cursor
            $key = ord(ReadKey(-1));
            if ($key eq 91) {
                #Read final sequence 
                $key = ord(ReadKey(-1));
                if ($key eq 66) {
                    #Cursor down
                    $cursel++;
                    if ($cursel gt $row) {$cursel = $row}
                } elsif ($key eq 65) {
                    #cursor up
                    $cursel--;
                    if ($cursel lt 0) {$cursel = 0}
                #} else {
                #    #Debugging info
                #    print "3: $key  \n";
                #    $row++;
                }
            } elsif ($key eq 0) {
                #Esc key - return not selected
                ReadMode 'normal';
                return '';
            #} else {
            #    #Debugging info
            #    print "2: $key  \n";
            #    $row++;
            }
        } elsif ($key eq 10 ) {
            #Enter Key - return selection
            ReadMode 'normal';
            return @usbentries[$cursel];
        #} else {
        #    #Debugging info
        #    print "1: $key  \n";
        #    $row++;
        }

        #Cursor back to top of list
        $row++;
        print "\033[${row}A";
    }
    #Should never get here,  but just in case...
    ReadMode 'normal';
}

#Find out if root
chomp(my $UID = `echo \$UID`);
if ($UID) { die "Must run as root!" }

#Select device
chomp(my $selected = selentry(@usbentries));
if ($selected eq "") {print "\n"; die "You must select a device to continue"};

#Determine info
my $ID = (split(' ', $selected))[0];
my $Name = $selected;
$Name =~ s/^.*"(.*)".*$/$1/;
print "\n\nSelected:\n";
print "\tName:\t$Name\n";
print "\tID:\t$ID\n";
$ID =~ s/:/_/g; #: causes issues with file name

#Confirm proceeding
print "Proceed (Y/N)? ";
if (onekey() !~  /[Yy]/ )  {print "\n"; die "Not Continuing"}
print "\n";

#Confirm Encryption
my $encrypt = 0;
chomp(my $hostname = `hostname`);
my $keyfile = "/root/.ssh/usb_${hostname}_$ID.key";
my $pubfile = "$RealBin/usb_${hostname}_$ID.key.pub";
my $encrypt = 0;
print "Do you want a key pair (Y/N)? ";
if (onekey() =~  /[Yy]/ )  {
    #Use Encryption - Generate key pair if needed
    $encrypt = 1;
    unless ( -e "$keyfile") {
        print "\nGenerating Key Pair";
        `ssh-keygen -t ed25519 -C \"$hostname\" -f $keyfile -N \"\"`;
        `cp '$keyfile.pub' '$pubfile'`;
    }
}
print "\n";

#Build lock/unlock file
my $addInfo = 1;
my $lockfile = "/usr/local/bin/usb-lock_$ID.sh";
if ( -e "$lockfile") {
    print "$lockfile ALREADY EXIST!\n";
    print "Replace (Y/N): \n";
    if (onekey() !~  /[Yy]/ )  {print "\nNot Replacing\n"; $addInfo = 0};
}
#Add/append info
if ($addInfo) {
    #Get UserName and usb path.
    chomp (my $LOGIN = `logname`);
    
    #Open file, Set file permissions
    open ( my $FILE, ">", $lockfile);
    chmod 0755, $FILE;

    #Write file
    print $FILE "#!/bin/bash\n";
    print $FILE "session=\$(loginctl|grep '$LOGIN'|awk '{print \$1;}')\n";
    print $FILE "if [ \${1} == \"lock\" ]\n";
    print $FILE "then\n";
    print $FILE "    loginctl lock-session \${session}\n";
    print $FILE "elif [ \${1} == \"unlock\" ]\n";
    print $FILE "then\n";
    print $FILE "    loginctl unlock-session \${session}\n";
    print $FILE "elif [ \${1} == \"keytest\" ]\n";
    print $FILE "then\n";
    print $FILE "    diff <(ssh-keygen -y -f $keyfile) $pubfile\n";
    print $FILE "    if [ \$? -ne 0 ]\n";
    print $FILE "    then\n";
    print $FILE "         loginctl lock-session \${session}\n";
    print $FILE "   fi\n";
    print $FILE "fi\n";
    close $FILE;
}

#Build USB rules
my @IDInfo = split("_",$ID);
my $addInfo = 1;
my $rulesfile = "/etc/udev/rules.d/80-usb.rules";
if ( -e "$rulesfile") {
    print "\n----------\n";
    system ("cat $rulesfile");
    print "----------\n";
    print "$rulesfile ALREADY EXIST!\nContents Above\n";
    print "Add Info for idVendor:@IDInfo[0] idProduct @IDInfo[1] (Y/N): ";
    if (onekey() !~  /[Yy]/ )  {print "\nNot Adding"; $addInfo = 0};
    print "\n";
}

#Add/append info
if ($addInfo) {
    #Add data to rules file
    open ( my $FILE, ">>", $rulesfile);
    print $FILE "ACTION==\"add\", SUBSYSTEMS==\"usb\", ATTR{idVendor}==\"@IDInfo[0]\", ATTR{idProduct}==\"@IDInfo[1]\", RUN+=\"$lockfile unlock\"\n";
    print $FILE "ACTION==\"remove\", SUBSYSTEMS==\"usb\", ENV{ID_VENDOR_ID}==\"@IDInfo[0]\", ENV{ID_MODEL_ID}==\"@IDInfo[1]\", RUN+=\"$lockfile lock\"\n";
    if ($encrypt) {
        #Note Device is not mounted at add.  
        #change runs at mount. 
        #unlock does not work at change.
        #so it unlocks at add.  then locks if the key does not verify at change.
        print $FILE "ACTION==\"change\", SUBSYSTEMS==\"usb\", ENV{ID_VENDOR_ID}==\"@IDInfo[0]\", ENV{ID_MODEL_ID}==\"@IDInfo[1]\", RUN+=\"$lockfile keytest\"\n";
    }
    close $FILE;
    
    #reload rules - Note may need a modification for different distros.  This works on fedora
    `udevadm control -R`;
}

