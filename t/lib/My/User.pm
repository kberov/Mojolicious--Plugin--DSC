package My::User;
use Mojo::Base 'My';

sub TABLE   {'users'}
sub COLUMNS { [qw(id group_id login_name login_password)] }
sub WHERE   { {disabled => 1} }

#See Params::Check
my $_CHECKS = {
  id         => {allow => qr/^\d+$/x},
  group_id   => {allow => qr/^\d+$/x, default => 1},
  login_name => {allow => qr/^\p{IsAlnum}{4,12}$/x},
  login_password => {
    required => 1,
    allow    => sub { $_[0] =~ /^[\w\W]{8,20}$/x; }
  }
};
sub CHECKS {$_CHECKS}

sub id {
  my ($self, $value) = @_;
  if (defined $value) {    #setting value
    $self->{data}{id} = $self->_check(id => $value);

    #make it chainable
    return $self;
  }
  $self->{data}{id} //= $self->CHECKS->{id}{default};    #getting value
}

my $users_table = <<"T";
CREATE TABLE users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INT default 1,
  login_name VARCHAR(12),
  login_password VARCHAR(100)
  )
T

my $dbh = __PACKAGE__->dbix->dbh;
$dbh->do($users_table)
  unless $dbh->table_info(undef, undef, 'users', 'TABLE')->fetchrow_hashref;

1;
