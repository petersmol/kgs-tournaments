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

my $tag='Бойцы Вейцы 2013';

Tournaments::Controller::Root->process_tournament($tag);
Tournaments::Controller::Root->update_coefficients;

