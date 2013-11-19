# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::Outputter;

use Moose::Role;
requires 'output';
requires 'close';

1;
