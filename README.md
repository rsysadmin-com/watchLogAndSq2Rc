# watchLogAndSq2Rc.pl
Squirrelmail address book to Roundcube migration tool.

## history
I was looking for an automatic and easy way to migrate all address books from Squirrelmail (SM) into Roundcube (RC). I found some little scripts which would convert the SM’s .abook files to .vcf which then could be imported from SM easily. I even drafted a document with step-by-step instructions, screenshots included, describing how to do that but one of the things you learn quickly as SysAdmin is: never trust the users ;-)   Therefore I thought: “there must be a way to directly import those .abook files, which are basically in ASCII format, into RC’s database”. Luckily for me, someone else had the same idea and coded a script to do that.<p>

The original script is very good but I found out that those .abook files could not be imported into RC unless the username already existed in the database.  As an initial approach I coded a little script to bulk-insert all usernames into the RC database and then imported their address books automatically. During the process, each username was assigned an ID (this is how contacts are matched against a username)… so far, so good. But when a user did the first real login it got assigned another (and final) ID by the system which was used from that moment on. This means that all the previously imported contacts for a particular user would not be seen by them…<p>

So, I moved a step forward and came out with another solution which consists on parsing RC’s log in real-time, obtaining the usernames and triggering the migration process. Then I fired up vi (yes, the editor) and added some modifications to the original Perl script coded by Alessandro de Zorzi (hi dude!) which, after some tweaking (my Perl is rusty), did the trick.<p>

## functionality
In a nutshell, watchLogAndSq2Rc.pl (I’m not very good at making up names) does the following:

1. parses /var/log/roundcubemail/userlogins in real-time (your full path may vary).
2. obtains the username and checks whether they have been migrated already – watchLogAndSq2Rc.pl creates its own audit log
3. if the user was already migrated it does nothing (quite convenient :-) )
4. if the user hasn’t been migrated yet, it triggers the import process and adds the username to the audit log.<p>

With all this, the following is achieved:<p>

* the migration process is fully automated and transparent to the users as they only have to login to Roundcube for the process to kick in
* imported contacts are assigned the correct user_id on the RC’s database
* only usernames with an address book will be migrated (makes sense, or? ;-) )

## requirements
The following Perl modules are needed: Text::CSV, DBI and File::Tail.

## mandatory disclaimer
this script is distributed on an “AS IS” basis, with no warranty of any kind. The Author is not to be held responsible for any use or misuse of this product or the result thereof.
