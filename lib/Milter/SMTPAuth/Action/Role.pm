package Milter::SMTPAuth::Action::Role;

use Moose::Role;
requires 'execute', 'pre_actions', 'post_actions';

1;
