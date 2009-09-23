use strict;
use warnings;
use Plack::Middleware::Restarter;
use Plack::Builder;
use Test::More;
use File::Temp ();

my $dir = File::Temp::tempdir( CLEANUP => 1 );
my $conffile = "$dir/conf.txt";

write_file("hello");

my $cache;
local $SIG{HUP} = sub { undef $cache;  };
my $handler = builder {
    enable Plack::Middleware::Restarter
        directories => [$dir],
        filter => qr{\.txt$};
    sub {
        $cache ||= do {
            open my $fh, '<', $conffile or die $!;
            local $/;
            <$fh>
        };
        [200, [], [$cache]]
    };
};
sleep 1; # waiting watcher thread
do {
    my $res = $handler->(+{});
    is_deeply $res, [200, [], ['hello']];
};
do {
    my $res = $handler->(+{});
    is_deeply $res, [200, [], ['hello']];
};
do {
    write_file('reloaded');
    sleep 1 while $cache; # waiting ChangeNotify

    my $res = $handler->(+{});
    is_deeply $res, [200, [], ['reloaded']];
};

done_testing;
exit 0;

sub write_file {
    my $body = shift;
    open my $fh, '>', $conffile or die $!;
    print $fh $body;
    close $fh;
}

