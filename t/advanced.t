use Mojo::Base -strict;
use lib qw(t/lib);

use Test::More;

use Mojolicious::Lite;
use Test::Mojo;
use Data::Dumper;
use File::Temp qw(tmpnam);

my $ddbix = tmpnam();
my $ydbix = tmpnam();

#Suppress some warnings from DBIx::Simple::Class during tests.
local $SIG{__WARN__} = sub {
  if (
    $_[0] =~ /(ddbix\sredefined
         |SQL\sfrom)/x
    )
  {
    my ($package, $filename, $line, $subroutine) = caller(1);
    ok($_[0], $subroutine . " warns '$1' OK");
  }
  else {
    warn $_[0];
  }
};
plugin('Charset', {charset => 'UTF-8'});
my $config = {
  database       => ':memory:',
  DEBUG          => 0,
  namespace      => 'My',
  load_classes   => ['Groups'],
  dbh_attributes => {sqlite_unicode => 1},
  driver         => 'SQLite',
  onconnect_do   => [],
  dbix_helper    => 'ddbix',
  dsn            => 'dbi:SQLite:database=' . $ddbix
};


my $my_groups_table = <<"TAB";
CREATE TABLE my_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  "group" VARCHAR(12),
  "is' enabled" INT DEFAULT 0
  )
TAB

my $users_table = <<"TAB";
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INT default 1,
  login_name VARCHAR(12),
  login_password VARCHAR(100)
  )
TAB

$config->{load_classes} = ['My::User', 'Groups'];

isa_ok(plugin('DSC', $config), 'Mojolicious::Plugin::DSC');

ok(app->ddbix->dbh->do($users_table),     'app->ddbix->dbh->do works');
ok(app->ddbix->dbh->do($my_groups_table), 'app->ddbix->dbh->do works2');

ok(app->ddbix->query('INSERT INTO my_groups ("group") VALUES(?)', 'pojo'),
  'app->ddbix->query works');

my $group = My::Groups->find(1);
is($group->id, 1, 'Group 1 found');
my $user = My::User->new(
  group_id       => $group->id,
  login_name     => 'петър',
  login_password => 'secretpass12'
);
$user->save;
is($user->id, 1, 'User 1 saved');


#additional dbix
my $your_config = {
  namespace    => 'Your',
  load_classes => ['User'],
  user         => 'me',
  dbix_helper  => 'your_dbix',
  dsn          => 'dbi:SQLite:database=' . $ddbix
};

my $your_dbix = plugin('DSC', $your_config);

can_ok(app, 'your_dbix');
isnt(app->your_dbix, app->ddbix, 'two schemas loaded');

get '/' => sub {
  my $self = shift;
  my $group_row =
    $self->ddbix->query('SELECT * FROM my_groups WHERE "group"=?', $group->group);
  $self->render(
    text => 'Hello ' . $user->login_name . ' from group ' . $group->group . '!');
};

post '/edit/user' => sub {
  my $c    = shift;
  my $user = My::User->find($c->param('id'));
  $user->login_password($c->param('login_password'));
  $user->save;
  $c->render(text => 'New password for user '
      . $user->login_name . ' is '
      . $user->login_password);
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200);
$t->content_is('Hello ' . $user->login_name . ' from group ' . $group->group . '!');

$t->post_ok('/edit/user', form => {id => 1, login_password => 'alabala123'})
  ->status_is(200)->content_is('New password for user петър is alabala123');

done_testing;

