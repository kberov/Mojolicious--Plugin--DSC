package Mojolicious::Plugin::DSC;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Simple::Class;


our $VERSION = '0.03';

#some known good defaults
my %COMMON_ATTRIBUTES = (
  RaiseError  => 1,
  HandleError => sub { Carp::croak(shift) },
  AutoCommit  => 1,
);

my $DRIVER_ATTRIBUTES = {
  'mysql'  => {mysql_enable_utf8 => 1, mysql_bind_type_guessing => 1},
  'SQLite' => {sqlite_unicode    => 1},
  'Pg'     => {pg_enable_utf8    => 1}
};

my $MEx = 'Mojo::Exception';

sub register {
  my ($self, $app, $config) = @_;

  # This stuff is executed, when the plugin is loaded
  # Config
  $config                 ||= {};
  $config->{load_classes} ||= [];
  $config->{namespace}    ||= '';
  $config->{DEBUG} ||= ($app->mode =~ /^dev/ ? 1 : 0);
  $config->{dbh_attributes} ||= {};

  #prepared Data Source Name?
  if (!$config->{dsn}) {
    $config->{driver}
      || $MEx->throw(
      'Please choose and set a database driver like "mysql","SQLite","Pg"!..');
    $config->{database} || $MEx->throw('Please set "database"!');
    $config->{host} ||= 'localhost';
    $config->{dsn} = 'dbi:'
      . $config->{driver}
      . ':database='
      . $config->{database}
      . ';host='
      . $config->{host};
  }

  #check if it is ok
  DBI->parse_dsn($config->{dsn})
    || $MEx->throw("Can't parse DBI DSN! dsn=>'$config->{dsn}'");


  $MEx->throw('"load_classes" configuration directive '
      . 'must be an ARRAY reference containing a list of classes to load.')
    unless (ref($config->{load_classes}) eq 'ARRAY');
  if (@{$config->{load_classes}} && !$config->{namespace}) {
    $MEx->throw('Please define namespace for your model classes!');
  }
  DBIx::Simple::Class->DEBUG($config->{DEBUG});

  #ready... Go!
  my $dbix = DBIx::Simple->connect(
    $config->{dsn},
    $config->{user},
    $config->{password},
    { %COMMON_ATTRIBUTES, %{$DRIVER_ATTRIBUTES->{$config->{driver}} || {}},
      %{$config->{dbh_attributes}}
    }
  );
  $config->{onconnect_do} ||= [];
  if (!ref($config->{onconnect_do})) {
    $config->{onconnect_do} = [$config->{onconnect_do}];
  }
  for my $sql (@{$config->{onconnect_do}}) {
    $dbix->dbh->do($sql) if $sql;
  }
  DBIx::Simple::Class->dbix($dbix);    #do not forget
  $config->{dbix_helper} ||= 'dbix';
  $app->helper($config->{dbix_helper}, $dbix);    #add helper dbix


  if ($config->{namespace} && @{$config->{load_classes}}) {
    my @classes   = @{$config->{load_classes}};
    my $namespace = $config->{namespace};
    $namespace .= '::' unless $namespace =~ /\:\:$/;
    foreach my $class (@classes) {
      if ($class =~ /$namespace/) {
        my $e = Mojo::Loader->load($class);
        $MEx->throw($e) if $e;
        next;
      }
      my $e = Mojo::Loader->load($namespace . $class);
      $MEx->throw($e) if $e;
    }
  }
  elsif ($config->{namespace} && !@{$config->{load_classes}}) {
    my @classes = Mojo::Loader->search($config->{namespace});
    foreach my $class (@classes) {
      my $e = Mojo::Loader->load($class);
      $MEx->throw($e) if $e;
    }
  }
  return;
}    #end register


1;

__END__

=head1 NAME

Mojolicious::Plugin::DSC - use DBIx::Simple::Class in your application.

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('DSC', $config);

  # Mojolicious::Lite
  plugin 'DSC', $config;

=head1 DESCRIPTION

L<Mojolicious::Plugin::DSC> is a L<Mojolicious> plugin that helps you
use DBIx::Simple::Class in your application.


=head1 METHODS

L<Mojolicious::Plugin::DSC> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=cut
