#
# Модуль, отвечающий за получение данных из локальной базы данных
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013.
package Tournaments::Model::DB;
use strict;
use warnings;

use DBI;
use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tournaments::Config qw(CNF);

our $dbh;

BEGIN {
    $dbh = DBI->connect(CNF('mysql.conn'), CNF('mysql.user'), CNF('mysql.password')) or die $DBI::errstr;;
}

sub getTournamentPlayers {
    my ($self)=@_; 

    my $rows=$dbh->selectall_hashref("SELECT * FROM tournamentPlayers", 'kgs');
    return $rows;
}

1;
