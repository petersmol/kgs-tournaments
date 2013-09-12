#
# Основной функционал 
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013.
package Tournaments::Controller::Root;
use strict;
use warnings;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tournaments::Model::KGS;
use Tournaments::Model::DB;


# Получает список игроков турнира и скачивает все их партии
sub download_all {
    my ($self, $days_shift)=@_; # Set timeshift in days to download prevous month games

    my $players = Tournaments::Model::DB->getTournamentPlayers;

    foreach my $name (keys %$players){
        my $res = Tournaments::Model::KGS->downloadArchive($name, $days_shift);

        print "$name ".$res->{code}." ".$res->{url}."\n";
        die Dumper ($res) if ($res->{code} eq 'error');
        sleep 10; # KGS server-friendly delay
    }
}

# Парсит скаченные SGF и сохраняет результат в базе
sub parse_all {

    # Получаем список имеющихся SGF-файлов
    my $files = Tournaments::Model::KGS->filelist;

    # Получаем список партий из базы
    my $games = Tournaments::Model::DB->enumerateGames;


    # Добавляем недостающие файлы в базу данных
    foreach my $file (@$files){
        next if ($games->{$file}); # Пропускаем игры, уже добавленные в базу
        
        # Парсим файл 
        my $info=Tournaments::Model::KGS->parse($file);
        print "$file\n".Dumper($info);

        Tournaments::Model::DB->createGame($info);
    }
}


# Обсчитывает турнирную таблицу по необработанным партиям
sub process_tournament {
    my ($self, $tag)=@_;

    # Получаем информацию об игроках
    my $players = Tournaments::Model::DB->getTournamentPlayers;

    # Получаем список новых партий
    my $res = Tournaments::Model::DB->enumerateNewGames($tag);

    foreach my $game (@$res){
        my $winner=$players->{$game->{winner}};
        my $loser=$players->{$game->{loser}};

        # Пропускаем игроков из разных групп
        next if ($winner->{groupid}!=$loser->{groupid});

        # Пропускаем повторно сыгранные партии
        next if (@{Tournaments::Model::DB->enumerateRepeatedGames($winner->{id}, $loser->{id})}>0);

        # Пересчитываем очки победителя
        $winner->{points}+=2 + 0.1*($winner->{init_place}-$loser->{init_place});
        $winner->{games_cnt}++;
        $winner->{lastupdate}=\'NOW()';

        # Пересчитываем очки проигравшего
        $loser->{points}+=1;
        $loser->{games_cnt}++;
        $loser->{lastupdate}=\'NOW()';

        # Записываем информацию о турнирной партии
        Tournaments::Model::DB->insertTournamentGame($winner, $loser, $game);

        # Помечаем sgf как обработанную
        Tournaments::Model::DB->updateGameStatus($game, 'tournament_game');

        print Dumper $game;
    }

    # Сохраняем новые очки игроков
    Tournaments::Model::DB->updatePlayers($players);
}
1;
