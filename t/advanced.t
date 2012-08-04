use Mojo::Base -strict;

# Disable IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}

use Test::More tests => 5;

package main;
use Mojolicious::Lite;
use Test::Mojo;
use Data::Dumper;
use lib qw(t/lib);

isa_ok(plugin('DSC', { 
    database       => ':memory:',
    DEBUG        => 0,
    namespace      => 'My',
    load_classes   => ['Groups'],
    dbh_attributes => {},
    driver         => 'SQLite',
    onconnect_do =>[],
    dbix_helper =>'dbix',
    host =>'localhost',
    dsn => 'dbi:SQLite:database=:memory:;host=localhost'
  }),'Mojolicious::Plugin::DSC');

my $my_groups_table = <<"T";
CREATE TABLE "my groups"(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  "group" VARCHAR(12),
  "is' enabled" INT DEFAULT 0
  )
T

app->dbix->query($my_groups_table);
#my $group = My::Groups->new(group=>'Mojo',is_enabled=>1);
#isa_ok($group,'My::Groups');

get '/' => sub {
  my $self = shift;
  $self->render_text('Hello Mojo!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');

