#!/usr/bin/env perl

use strict;

open (F, 'git ls-tree -r HEAD|');

my %list;
my %all_file;

# 辞書作る
while (<F>) {
    my @info = split /\s+/;

    my $filename = $info[-1];
    my $hash     = $info[-2];

    $list{$filename} = $hash;
    $all_file{$filename} = 1;
}

close(F);

$? and die;

open (COMMITS, 'git rev-list HEAD |');

# timestamp 取りつつ tree を get
my $prevtimestamp;
my $timestamp;
while (<COMMITS>) {
    my $commit = $_;

    (keys %list) or last;

    open (TMP, 'git cat-file -p ' . $commit . '|');
    my $tree;
    while (<TMP>) {
        if (/tree/) {
            my @tmp = split /\s+/;
            $tree = $tmp[1];
            next
        }
        if (/committer/) {
            my @tmp = split /\s+/;
            $timestamp = $tmp[-2];
            last;
        }
    }
    close(TMP);

    open (BLOBS, "git ls-tree -r $tree |");

    my %remained = %all_file;
    while (<BLOBS>) {
        my @tmp = split(/\s+/);
        my $filename = $tmp[-1];
        my $blobhash = $tmp[-2];

        if ($remained{$filename}) {
            delete $remained{$filename};
        }

        if (!$list{$filename}) {
            next;
        }


        if ($list{$filename} !~ /$blobhash/) {
            do_print($filename, $prevtimestamp);
        }
    }

    foreach my $filename (keys(%remained)) {
        do_print($filename, $prevtimestamp);
    }

    $prevtimestamp = $timestamp;

    close (BLOBS);
}

# For files that never changed from the root commit.
foreach my $filename (keys(%all_file)) {
    do_print($filename, $prevtimestamp);
}


sub do_print() {
    my ($filename, $timestamp) = @_;
    print $filename . "\t" . $timestamp . " \n";
    delete ($list{$filename});
    delete ($all_file{$filename});
}

close (COMMITS);
