use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::DSC',
  VERSION_FROM => 'lib/Mojolicious/Plugin/DSC.pm',
  ABSTRACT_FROM => 'lib/Mojolicious/Plugin/DSC.pm',
  AUTHOR       => q{Красимир Беров <berov@cpan.org>},
  PREREQ_PM    => {'Mojolicious' => '2.0','DBIx::Simple::Class' =>'0.62'},
  test         => {TESTS => 't/*.t'},
  dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
  clean               => { FILES => 'Mojolicious-Plugin-DSC-*' },

);
