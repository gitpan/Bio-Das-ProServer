use strict;
use warnings;
use Test::More;

eval {
  require LWP::UserAgent;
  require Cache::FileCache;
};
if ($@) {
  plan skip_all => 'HTTP authentication requires LWP::UserAgent and Cache::FileCache';
} else {
  plan tests => 12;
}

# Initial basic tests
use_ok('Bio::Das::ProServer::Authenticator::http');
my $auth = Bio::Das::ProServer::Authenticator::http->new();
isa_ok($auth, 'Bio::Das::ProServer::Authenticator::http');
can_ok($auth, qw(parse_token authenticate));

my $server_err = 0;
$SIG{INT} = sub { $server_err = 1; };

if (my $child_pid = fork) {
  # Parent process does the testing
  use HTTP::Request;
  
  for my $type (qw(cookie param header default)) {
  
    $auth = Bio::Das::ProServer::Authenticator::http->new({
      'config' => {
                   'authurl'   => 'http://127.0.0.1:9123?token=%token',
                   "auth$type" => 'key',
                  },
    });
    
    for my $token (qw(allow deny)) {
      my $req = HTTP::Request->new('get', "http://my.example.com?key=$token", ['Cookie', "key=$token", 'key', $token, 'Authorization', $token]);
      my ($uri) = $req->uri() =~ m/\?(.*)/;
      my $resp = $auth->authenticate( {'request' => $req, 'cgi' => CGI->new($uri)} );
      ok( $token eq 'allow' ? !$resp : defined $resp && $resp->isa('HTTP::Response'), "$token $type authentication") || diag($resp);
    }
  }
  
  kill 3, $child_pid;
  ok(!$server_err, "run test authentication server");
  
} else {
  # Child process runs a server
  # (similar to http://poe.perl.org/?POE_Cookbook/Web_Server)
  use POE qw(Component::Server::TCP Filter::HTTPD);
  use HTTP::Response;
  
  POE::Component::Server::TCP->new(
    Error        => sub { diag($_[ARG2]); kill 2, getppid(); },
    Port         => 9123,
    ClientFilter => 'POE::Filter::HTTPD',
    ClientInput  => sub {
      my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
      
      # Errors appear as HTTP::Response objects (via filter)
      if ($request->isa("HTTP::Response")) {
        $heap->{client}->put($request);
      }
      
      else {
        my ($client_token) = $request->uri() =~ m/token=(.*)$/mx;
        if ($client_token eq 'allow') {
          $heap->{client}->put(HTTP::Response->new(200)); # OK
        } else {
          $heap->{client}->put(HTTP::Response->new(403)); # Forbidden
        }
      }
      
      $kernel->yield("shutdown");
    }
  );
  $poe_kernel->run();
}