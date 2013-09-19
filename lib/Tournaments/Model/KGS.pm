#
# Модуль, отвечающий за получение данных с сервера KGS
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013.
package Tournaments::Model::KGS;
use strict;

use LWP::UserAgent;
use File::Compare;
use File::Spec::Functions qw(catdir splitdir abs2rel);
use Games::Go::SGF;
use POSIX qw(strftime);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tournaments::Config qw(CNF);

my $cache_dir  = "$FindBin::Bin/../cache";
my $sgf_dir  = "$FindBin::Bin/../sgf";

sub formatUrl
{
    my ($self, $name, $days_shift) = (@_);
    $days_shift=0 unless ($days_shift);
    my $time=strftime("%Y-%m", localtime(time - $days_shift*3600*24));
    my $url="http://www.gokgs.com/servlet/archives/en_EN/$name-$time.tar.gz";
    return $url;
}

# Downloading game archive from KGS
sub downloadArchive
{
    my ($self, $name, $days_shift) = (@_);
    my $url = $self->formatUrl($name, $days_shift);
    my $filename=(split (/\//, $url))[-1];

    my $result = {
        player => $name,
        url    => $url,
    };

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);

    my $response = $ua->get($url);

    if ($response->is_success){     # Download succeed!
        my $old="$cache_dir/$filename";
        my $new="$cache_dir/tmp";

        open FILE, '>', $new;
        print FILE $response->decoded_content;
        close FILE;

        if (compare($new,$old)){ # if player have new games in archive
            rename $new, $old;
            $result->{code}='updated';

            system ("tar xzf $old -C $sgf_dir");
        }else {
            unlink $new;
            $result->{code}='checked';
        }

    }elsif ($response->code == 404){ # Player has no games
        $result->{code}='no_games';
    }else {                          # Something is wrong
        $result->{code}='error';
        $result->{status}=$response->status_line;
    }
    
    return $result;
}


# Возвращает список файлов в директории sgf
sub filelist
{
    my @files=`find $sgf_dir -name "*.sgf"`;

    foreach (@files){
        chomp;
        $_=abs2rel($_, $sgf_dir);
    }

    return \@files;
}

# Парсит SGF-файл и возвращает необходимую нам информацию
sub parse
{
    my ($self, $file)=@_;

    my $sgf = new Games::Go::SGF(catdir($sgf_dir,$file));

   
    # Заполняем информацию о партии
    my $info= {
        sgf     => $file,
        date    => $sgf->date,
        komi    => 0+$sgf->komi,
        tag     => '',
    };

    # Определяем победителя
    if ($sgf->RE =~ /^(B|W)\+(.*)$/){
        if ($1 eq 'B'){
            $info->{winner} = $sgf->black;
            $info->{loser}  = $sgf->white;
        }elsif($1 eq 'W'){
            $info->{winner} = $sgf->white;
            $info->{loser}  = $sgf->black;
        }
        $info->{win_by}=0+$2;

        $info->{win_by}=$2 unless ($info->{win_by});
        
    }

    # Проверяем, удовлетворяет ли партия всем условиям добавления в базу
    my $status='ok';
    if ($sgf->HA){
        $status='Handicap game: '.$sgf->HA;
    }elsif($sgf->komi != CNF('game.komi')){
        $status='Bad komi: '.$sgf->komi;
    }elsif($sgf->size != CNF('game.board')){
        $status='Bad board size: '.$sgf->size;
    }elsif(CNF('game.main_time') and $sgf->TM != 60*CNF('game.main_time')){
        $status='Bad main time: '.($sgf->TM/60);
    }elsif(CNF('game.additional_time') and $sgf->OT ne CNF('game.additional_time')){
        $status='Bad additional time: '.$sgf->OT;
    }

    if ($file =~ /([a-z0-9]+)-([a-z0-9]+)(-[0-9]+)?\.sgf$/i){
        if (($1 ne $info->{winner} and $2 ne $info->{winner}) or ($1 ne $info->{loser} and $2 ne $info->{loser})){
            $status='wrong opponents: '.$sgf->white."-".$sgf->black;
        }
    }else{
        $status='demo game';
    }

    # Ищем теги
    foreach (@{CNF('game.tags')}){
        $info->{tag}=$_ if ($sgf->getsgf =~ /$_/i);
    }

    $info->{status}=$status;
    return $info;
}

1;
