BEGIN { $| = 1; print "1..7\n"; }

use Guard;

print "ok 1\n";

$Guard::DIED = sub {
   print $@ =~ /^x1 at / ? "" : "not ", "ok 3 # $@\n";
};

eval {
   scope_guard { die "x1" };
   print "ok 2\n";
};

print $@ ? "not " : "", "ok 4 # $@\n";

$Guard::DIED = sub {
   print $@ =~ /^x2 at / ? "" : "not ", "ok 6 # $@\n";
};

eval {
   scope_guard { die "x2" };
   print "ok 5\n";
   die "x3";
};

print $@ =~ /^x3 at /s ? "" : "not ", "ok 7 # $@\n";

