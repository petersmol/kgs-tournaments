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
    $dbh->do('SET NAMES utf8'); 
}

################################
#######     Players     ########
################################
sub getTournamentPlayers {
    my ($self)=@_; 
    my $rows=$dbh->selectall_hashref("SELECT * FROM tournamentPlayers", 'kgs');
    return $rows;
}

# Delete all players from current tournament (For test purposes)
sub clearPlayers {
    my ($self, $tournament)=@_; 
    $dbh->do("DELETE FROM tournamentPlayers WHERE tournament='$tournament'");
    $dbh->do("UPDATE tournamentPlayers SET active=0");
}

# Import players from register table 
sub importPlayers {
    my ($self, $tournament)=@_; 
    my $rows=$dbh->selectall_arrayref("SELECT * FROM tournamentReg WHERE tournament='$tournament'", { Slice => {} });
    my $groups=4; # Group counts
    my $players_in_group=int(@$rows/$groups +0.99);

    # Sort players by rating
    $rows = [ reverse sort {$a->{rating} <=> $b->{rating}} @$rows ];
    

    my $sth=$dbh->prepare("INSERT INTO tournamentPlayers (tournament, kgs, fio, rating, groupid, init_place, points, games_cnt, lastupdate, active) 
                                          VALUES ('$tournament', ?  , ?  , ?     , ?      , ?         , 0     , 0        , NOW()     , 1     )");


    my ($cur_group,$cur_place)=(1,1);
    foreach my $p (@$rows){
        $sth->execute($p->{kgs}, $p->{fio}, $p->{rating}, $cur_group, $cur_place);
        
        # Incrementing counters
        $cur_place++;
        if ($cur_place>$players_in_group){
            $cur_place=1;
            $cur_group++;
        }
    }
}


################################
#######      Games      ########
################################
sub enumerateGames {
    my ($self)=@_; 
    my $rows=$dbh->selectall_hashref("SELECT * FROM KGS_games", 'sgf');
    return $rows;
}

sub createGame {
    my ($self, $i)=@_; 
    my $sth=$dbh->prepare("INSERT INTO KGS_games (sgf, winner, loser, win_by, date, tag, status) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $sth->execute($i->{sgf}, $i->{winner}, $i->{loser}, $i->{win_by}, $i->{date}, $i->{tag}, $i->{status});
}

1;
