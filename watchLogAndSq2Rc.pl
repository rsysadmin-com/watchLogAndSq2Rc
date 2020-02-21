#!/usr/bin/perl
#
# watchLogAndSq2Rc.pl v0.01 alpha by Martin Mielke <martin@mielke.com> - 20131003
#
# inspired by the work of Alessandro De Zorzi - www.rhx.it
# original idea and initial code:
# http://lota.nonlontano.it/2010/06/squirrelmail-to-roundcube-address-book-contacts-migration/
#
# new features:
#       added real-time RoundCube userlogin file parsing (needs File::Tail)
#       check whether a username has already been migrated based on $checkfile
#       automatic/transparent migration process
#       removed the need for an external shell script to iterate the .abook files
#       contacts are assigned to the correct user_id (created by RoundCube on the 1st login)
#       only usernames with an address book will be migrated (makes sense, or? ;-) )


# Require config file
#
require "variable.pl";

use Text::CSV;
use DBI;
use File::Tail;
#use autodie;

#
# some usefull definitions
#
#
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);

$mon    = sprintf("%02d", $mon );
$mday   = sprintf("%02d", $mday );
$hour   = sprintf("%02d", $hour );
$min    = sprintf("%02d", $min );
$sec    = sprintf("%02d", $sec );
$changed = ($year+1900).'-'.$mon.'-'.$mday.' '.$hour.':'.$min.':'.$sec;

# Audit file for migrated users
#       create one if it does not exist
#
my $checkfile = "./checkfile.log"; 	# set proper path in production
unless (-e $checkfile) {
        open (CREATEFILE, ">", $checkfile);
        print CREATEFILE "$changed - $checkfile initialized.\n";
        close CREATEFILE;
        };

# keep an eye on the userlogins file (adjust path accordingly), extract the username
# and build the .abook filename (username.abook) to be imported later
#
# Read perldoc File::Tail if you need more info on how to use this module
#
my $file = File::Tail->new(name=>"/var/log/roundcubemail/userlogins", maxinterval=>1, adjustafter=>1);
while ((my $line = $file->read)) {
        my @array = split(/ /, $line);
        my $username = $array[6];
        my $abook = "$username".".abook";	# you might want to add the full path to those .abook files
        print "$changed - LOGIN : $username - ";
        print "ABOOK: $abook - ";

        open (CHECKFILE, "<", $checkfile) or die "Cannot read $checkfile: $!\n";
        if (grep {/$username/} <CHECKFILE> ) {
                print "STATUS: migrated OK\n";
                close CHECKFILE;
        } else {
                open (CHECKFILE, ">>", $checkfile) or die "Cannot write to $checkfile: $!\n";
                print "STATUS: migration started - ";


#
# main()
#


        my $csv = Text::CSV_XS->new({ sep_char => "|" });

        if (-e $abook) {
                open(CSV, $abook);

                # Create MySQL connection
                $dbh = DBI->connect('DBI:mysql:'.$db_name.';host='.$db_host, $db_user, $db_pass,
                                { RaiseError => 1 }
                               );

                # Try to find user code in roundcube
                $sth = $dbh->prepare("SELECT user_id FROM users WHERE username='".$username."'");
                $sth->execute();
                $result = $sth->fetchrow_hashref();
                $user_id = $result->{user_id};
                print "USER_ID: $user_id\n";

                if (!$user_id)
                {
                    print "User ".$username." not found... (never logged in RC?)"."\n";
                    print "-------------------------------------"."\n";
                }
                else
                {
                    $lines=0;

                    while (defined ($_ = <CSV>))
                    {
                        s/"//g;
                        s/è/e/g;
                        s/è/e/g;
                        s/é/e/g;
                        s/ì/i/g;
                        s/ò/o/g;
                        s/ù/u/g;
                        s/\'/\_/g;
                        s/\| /\|/g;

                        $csv->parse($_) or warn("invalid CSV line: ", $csv->error_input(), "\n"), next;
                        my @fields = $csv->fields();

                        $firstname  = $fields[1];
                        $surname    = $fields[2];
                        $email      = $fields[3];

                        if ($fields[0])
                        {
                            $name           = $fields[0];
                        }
                        elsif ($fields[4])
                        {
                            $name           = $fields[4];
                        }
                        else
                        {
                            $name = $firstname.' '.$surname;
                        }

                        $query = "INSERT INTO contacts (`contact_id`,`changed`,`del`,`name`,`email`,`firstname`,`surname`,`vcard`,`user_id`) VALUES (NULL,'$changed',0,'$name','$email','$firstname','$surname',NULL,$user_id) ";


                        # Check if countact already exists
                        $sth = $dbh->prepare("SELECT contacts.* FROM contacts WHERE user_id='".$user_id."' AND email='".$email."'");
                        $sth->execute();
                        $result = $sth->fetchrow_hashref();

                        if (!$result->{email})
                        {
                            # Insert the contact
                            $dbh->do($query, undef, 'Hello');
                        }

                        $lines = ($lines + 1);
                    }

                    $sth = $dbh->prepare("SELECT COUNT(contact_id) AS nr FROM contacts WHERE user_id='".$user_id."'");
                    $sth->execute();
                    $result = $sth->fetchrow_hashref();

                    print "SM contacts: ".$lines."\n";
                    print "Import contacts: ".$result->{nr}."\n";
                    print "-------------------------------------"."\n";
                }

                print CHECKFILE "$changed - $username successfully migrated.\n";	# add $username to audit file so we do not
                close CHECKFILE;                                        		# process them again

                close(CSV) or die "close: $abook: $!\n";
                # Close DB MySQL
                #$dbh->disconnect();
        } else {
                print "ERROR - cannot find $abook - STATUS: not migrated\n";
                }
        }
}

# The End
