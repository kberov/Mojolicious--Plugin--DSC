use Test::More;
use Mojolicious::Lite;
use File::Basename qw(dirname);
use lib dirname(__FILE__) . '/lib';

#Suppress some warnings from DBIx::Simple::Class during tests.
local $SIG{__WARN__} = sub {
  if (
    $_[0] =~ /(ddbix\sredefined
         |SQL\sfrom|locate\sMemory\.pm\sin)/x
    )
  {
    my ($package, $filename, $line, $subroutine) = caller(1);
    ok($_[0], $subroutine . " warns '$1' OK");
  }
  else {
    warn @_;
  }
};
my $help_count = 1;
my $config     = {};
like(
  (eval { plugin 'DSC' }, $@),
  qr/Please choose and set a database driver/,
  ' no driver'
);
$config->{driver} = 'SQLite';
like((eval { plugin 'DSC', $config }, $@), qr'Please set "database"!', 'no database');
$config->{database} = ':memory:';
my $generated_config = plugin('DSC', $config)->config;
is_deeply(
  $generated_config,
  { database       => ':memory:',
    DEBUG          => 1,
    load_classes   => [],
    namespace      => 'Memory',
    dbh_attributes => {},
    driver         => 'SQLite',
    onconnect_do   => [],
    dbix_helper    => 'dbix',
    host           => 'localhost',
    dsn            => 'dbi:SQLite:database=:memory:;host=localhost'
  },
  'default generated from minimal config'
);

#warn app->dumper($generated_config);
$config->{dbix_helper} = $config->{dbix_helper} . $help_count++;
isa_ok(eval { plugin('DSC', $config) } || $@, 'Mojolicious::Plugin::DSC');

$config = {dsn => 'garbage'};
like((eval { plugin 'DSC', $config }, $@), qr/Can't parse DBI DSN/, 'garbage dsn');
$config = {
  dsn          => 'dbi:SQLite:dbname=:memory:',
  load_classes => 'someclass',
  dbix_helper  => 'dbix_' . $help_count++
};

like(
  (eval { plugin 'DSC', $config }, $@),
  qr/must be an ARRAY reference /,
  'load_classes'
);
delete $config->{namespace};
$config->{load_classes} = ['My::User'];

#get namespace from dbname/$schema
is(plugin('DSC', $config)->config->{namespace}, 'Memory', 'namespace');
$config = {dsn => 'dbi:SQLite:dbname=:memory:', dbix_helper => 'dbix_' . $help_count++};

isa_ok(plugin('DSC', $config), 'Mojolicious::Plugin::DSC', 'proper dsn');

done_testing();

