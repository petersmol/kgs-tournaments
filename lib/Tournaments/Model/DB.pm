#
# Модуль, отвечающий за получение данных из локальной базы данных
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013.
package Tournaments::Model::DB;
use strict;
use warnings;

use DBI;
use constant AS_HASH => { Slice => {} }; # DBI option
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
sub getTournamentPlayersByNick {
    my ($self)=@_; 
    
    my $rows=$dbh->selectall_hashref("SELECT * FROM tournamentPlayers WHERE active=1 ORDER BY kgs", 'kgs');
    return $rows;
}

sub getTournamentPlayers {
    my ($self)=@_; 
    
    my $rows=$dbh->selectall_arrayref("SELECT * FROM tournamentPlayers WHERE active=1", AS_HASH);
    return $rows;
}

# Delete all players from current tournament (For test purposes)
sub clearPlayers {
    my ($self, $tournament)=@_; 
    $dbh->do("DELETE FROM tournamentPlayers WHERE tournament='$tournament'");
    $dbh->do("DELETE FROM tournamentChat");
    $dbh->do("DELETE FROM tournamentAnnounce");
    $dbh->do("UPDATE tournamentPlayers SET active=0");
}

# Import players from register table 
sub importPlayers {
    my ($self, $tournament)=@_; 
    my $rows=$dbh->selectall_arrayref("SELECT * FROM tournamentReg WHERE tournament='$tournament'", AS_HASH );
    my $groups=4; # Group counts
#    my $players_in_group=int(@$rows/$groups +0.99);
    my $players_in_group=10;

    # Sort players by rating
    $rows = [ reverse sort {$a->{rating} <=> $b->{rating}} @$rows ];
    

    my $sth=$dbh->prepare("INSERT INTO tournamentPlayers (tournament, kgs, fio, rating, groupid, init_place, points, games_cnt, lastupdate, active) 
                                          VALUES ('$tournament', ?  , ?  , ?     , ?      , ?         , 0     , 0        , NOW()     , 1     )");


    my ($cur_group,$cur_place)=(1,1);
    foreach my $p (@$rows){
        $sth->execute( lc($p->{kgs}), $p->{fio}, $p->{rating}, $cur_group, $cur_place);
        
        # Incrementing counters
        $cur_place++;
        if ($cur_place>$players_in_group){
            $cur_place=1;
            $cur_group++;
        }
    }
}

sub updatePlayers {
    my ($self, $players)=@_; 

    my $sth=$dbh->prepare("UPDATE tournamentPlayers SET place=?, points=?, k1=?, games_cnt=?, lastupdate=? WHERE kgs=? AND active=1");

    if (ref $players eq 'HASH'){
        foreach my $name (keys %$players){
            $sth->execute($players->{$name}{place}, $players->{$name}{points}, $players->{$name}{k1}, $players->{$name}{games_cnt}, $players->{$name}{lastupdate}, $name);
        }
    }else{
        foreach my $p (@$players){
            $sth->execute($p->{place}, $p->{points}, $p->{k1}, $p->{games_cnt}, $p->{lastupdate}, $p->{kgs});
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

sub enumerateNewGames {
    my ($self, $tags)=@_; 
    my $taglist=join "', '", @$tags;
    print "SELECT * FROM KGS_games WHERE status='ok' AND tag IN('$taglist') ORDER BY id\n";
    my $rows=$dbh->selectall_arrayref("SELECT * FROM KGS_games WHERE status='ok' AND tag IN('$taglist') ORDER BY id", AS_HASH);
    return $rows;
}

sub createGame {
    my ($self, $i)=@_; 
    my $sth=$dbh->prepare("INSERT INTO KGS_games (sgf, winner, loser, win_by, date, tag, status) VALUES (?, ?, ?, ?, ?, ?, ?)");
    $sth->execute($i->{sgf}, lc($i->{winner}), lc($i->{loser}), $i->{win_by}, $i->{date}, $i->{tag}, $i->{status});
}


sub updateGameStatus {
    my ($self, $game, $status)=@_; 
    $dbh->do("UPDATE KGS_games SET status='$status' WHERE id='$game->{id}'");
}

# To recount tournament points
sub refreshGames {
    my ($self, $tags)=@_; 
    my $taglist=join "', '", @$tags;
    $dbh->do("UPDATE KGS_games SET status='ok' WHERE status='tournament_game' AND tag IN('$taglist')");
}

# To parse it again
sub clearGames {
    my ($self)=@_; 
    $dbh->do("DELETE FROM KGS_games;");
}

################################
###    Tournament  Games    ####
################################

sub insertTournamentGame {
    my ($self, $winner, $loser, $game)=@_;

    my $sth=$dbh->prepare("INSERT INTO tournamentGames (winner, loser, game_id, added) VALUES (?, ?, ?, NOW())");
    $sth->execute($winner->{id}, $loser->{id}, $game->{id});
}

sub enumeratePlayerGames {
    my ($self, $id)=@_;
    $dbh->selectall_arrayref("SELECT * FROM tournamentGames WHERE winner='$id' OR loser='$id'", AS_HASH);
}


sub enumerateRepeatedGames {
    my ($self, $winner_id, $loser_id)=@_;

    $dbh->selectall_arrayref("SELECT * FROM tournamentGames WHERE (winner='$winner_id' AND loser='$loser_id' ) OR
                                                                           (winner='$loser_id'  AND loser='$winner_id')", AS_HASH);
}



################################
###     Tournament  Log     ####
################################

# Delete all log entries (For test purposes)
sub clearLog {
    my ($self, $tournament)=@_; 
    $dbh->do("DELETE FROM tournamentLog");
}

sub writeLog {
    my ($self, $name, $descr, $game_id)=@_; 
    $dbh->do("INSERT INTO tournamentLog (name, descr, game_id) VALUES ('$name', '$descr', '$game_id')");
}

1;
