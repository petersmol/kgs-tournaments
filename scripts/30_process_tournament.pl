#!/usr/bin/perl
#
# Скрипт обсчитывает турнирную таблицу с учетом появившихся партий 
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013
use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tournaments::Controller::Root;
use Tournaments::Config;

my $tags=CNF('game.tags');

Tournaments::Controller::Root->process_tournament($tags);
Tournaments::Controller::Root->update_coefficients;

