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
use Tournaments::Config qw(CNF);


# Получает список игроков турнира и скачивает все их партии
sub download_all {
    my ($self, $days_shift)=@_; # Set timeshift in days to download prevous month games

    my $players = Tournaments::Model::DB->getTournamentPlayersByNick;

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
        print "$file\n";
        my $info=Tournaments::Model::KGS->parse($file);
        print Dumper($info);

        next if ($info->{status} eq 'unfinished');
        Tournaments::Model::DB->createGame($info);
    }
}


# Обсчитывает турнирную таблицу по необработанным партиям
sub process_tournament {
    my ($self, $tags)=@_;
    my $game_type=CNF('game.type'); # В зависимости от системы проведения, коэффициенты считаются по-разному
    my $tournament=CNF('game.tournament'); 

    # Получаем информацию об игроках
    my $players = Tournaments::Model::DB->getTournamentPlayersByNick;

    # Получаем список новых партий
    my $res = Tournaments::Model::DB->enumerateNewGames($tags);

    foreach my $game (@$res){
        my $winner=$players->{$game->{winner}};
        my $loser=$players->{$game->{loser}};

        # Пропускаем партии неизвестных игроков 
        next if (!$winner or !$loser);
        
        if ($game_type eq 'round-robin'){
            # Пропускаем игроков из разных групп
            next if ($winner->{groupid}!=$loser->{groupid});
        }else{
            # Пропускаем партии, которых нет в жеребьевке
            next if (!Tournaments::Model::DB->checkPairing($tournament, $winner->{id}, $loser->{id}));
        }

        # Пропускаем повторно сыгранные партии
        next if (@{Tournaments::Model::DB->enumerateRepeatedGames($winner->{id}, $loser->{id})}>0);

        # Пересчитываем очки

        # Победитель получает 1 очкo 
        $winner->{points}+=1;

        $winner->{games_cnt}++;
        $winner->{lastupdate}=\'NOW()';

        # Проигравший получает 0.5 фиктивных очка в случае тех.поражения (фиктивные очки учитываются только в коэффициентах соперников)
        $loser->{fictive_points}+=0.5 if ($game->{win_by} =~/Tech/);
        $loser->{games_cnt}++;
        $loser->{lastupdate}=\'NOW()';

        # Записываем информацию о турнирной партии
        Tournaments::Model::DB->insertTournamentGame($winner, $loser, $game);
        Tournaments::Model::DB->writeLog($winner->{kgs}, "выиграл у $loser->{kgs} ($game->{win_by})", $game->{id});

        # Помечаем sgf как обработанную
        Tournaments::Model::DB->updateGameStatus($game, 'tournament_game');

        print Dumper $game;
    }

    # Сохраняем новые очки игроков
    Tournaments::Model::DB->updatePlayers($players);
}


sub update_coefficients {
    my ($self)=@_;
    my $players = Tournaments::Model::DB->getTournamentPlayers;

    # Делаем из массива хэш для удобства поиска по id
    my $PLAYERS;
    foreach my $p (@$players){
        $PLAYERS->{$p->{id}}=$p;
    }
    my $game_type=CNF('game.type'); # В зависимости от системы проведения, коэффициенты считаются по-разному

    # Пересчитываем коэффициенты
    foreach my $p (@$players){
        my $games=Tournaments::Model::DB->enumeratePlayerGames($p->{id});

        my ($berger, $buchholtz)=(0, 0);
        foreach my $g (@$games){
            if ($g->{winner}==$p->{id}){
                if ($g->{win_by} eq 'Tech'){
                    $buchholtz+=$PLAYERS->{$g->{winner}}{points}-1; # очки фиктивного соперника считаем равными очкам игрока (без учета этой технической победы)
                    $berger+=$PLAYERS->{$g->{winner}}{points}-1;  
                }else{
                    $buchholtz+=$PLAYERS->{$g->{loser}}{points}+$PLAYERS->{$g->{loser}}{fictive_points};
                    $berger+=$PLAYERS->{$g->{loser}}{points}+$PLAYERS->{$g->{loser}}{fictive_points};
                    $p->{opp}{$g->{loser}}=1; # Учет личной встречи для расстановки мест
                }
            }else{
                if ($g->{win_by} eq 'Tech'){
                    # Если партия проиграна у фиктивного соперника, получаем прибавку к бухгольцу, как будто у соперника столько же очков, сколько у нас
                    $buchholtz+=$PLAYERS->{$g->{loser}}{points};
                }else{
                    # Иначе - прибавляем к Бухгольцу фактические очки соперника
                    $buchholtz+=$PLAYERS->{$g->{winner}}{points}+$PLAYERS->{$g->{winner}}{fictive_points};
                    $p->{opp}{$g->{winner}}=-1;  # Учет личной встречи для расстановки мест
                }
            }
        }

        $p->{k1}=$buchholtz;
        $p->{k2}=$berger;
    }

    # Пересчитываем места в группах
    if ($game_type eq 'round-robin'){
        $players= [ sort { 
            $a->{groupid}<=>$b->{groupid} or 
            $b->{points} <=> $a->{points} or 
            $b->{k2} <=> $a->{k2} or 
            $b->{opp}{$a->{id}} <=> $a->{opp}{$b->{id}} or 
            $b->{rating} <=> $a->{rating} 
        } @$players ];
    } else {
        $players= [ sort { 
            $b->{points} <=> $a->{points} or 
            $b->{k1} <=> $a->{k1} or 
            $b->{k2} <=> $a->{k2} or 
            $b->{rating} <=> $a->{rating} 
        } @$players ];
    }

    
    my ($groupid, $place)=(0,1);
    foreach my $p (@$players){
        # В круговике места в каждой группе свои
        if ($game_type eq 'round-robin' and $p->{groupid}!=$groupid){ 
            $groupid=$p->{groupid};
            $place=1; 
        }
        $p->{place}=$place;
        $place++;
    }

    Tournaments::Model::DB->updatePlayers($players);
}
1;
