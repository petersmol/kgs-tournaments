#
# Модуль, отвечающий за получение данных с сервера KGS
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013.
package Tournaments::Model::KGS;
use strict;

use LWP::UserAgent;
use File::Compare;
use POSIX qw(strftime);
use FindBin;
use lib "$FindBin::Bin/../lib";


sub formatUrl
{
    my ($self, $name, $days_shift) = (@_);
    $days_shift=0 unless ($days_shift);
    my $time=strftime("%Y-%m", localtime(time - $days_shift*3600*24));
    my $url="http://www.gokgs.com/servlet/archives/en_EN/$name-$time.tar.gz";
#    my $url="http://go.petersmol.ru/tmp/$name-$time.tar.gz";
    return $url;
}

# Downloading game archive from KGS
sub downloadArchive
{
    my ($self, $name, $days_shift) = (@_);
    my $url = $self->formatUrl($name, $days_shift);
    my $filename=(split (/\//, $url))[-1];
    my $cache_dir  = "$FindBin::Bin/../cache";

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

            system ("tar xzf $old -C $FindBin::Bin/../sgf");
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

1;
