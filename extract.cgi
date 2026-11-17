#!/usr/bin/env perl
#-----
# url:
# /cgi-bin/mt-user/extract.cgi
#-----
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $server="x-server";    # "x-server" or ""

my $in_file  = '../../html/blog/index.html';
if($server eq "x-server"){
  $in_file  = '../../blog/index.html';
}

my $out_file = 'templates/category_navi.txt';

print "Content-Type: text/plain; charset=UTF-8\n\n";
print("start extract_category\n");

# 第3引数でオプション指定（1: 1行ミニファイ, 0または省略: 改行あり）
exec_extract($in_file,$out_file,1);
#exec_extract($in_file,$out_file);

print("end\n");

exit(0);

sub exec_extract {
    my ($in_file, $out_file, $minify) = @_;
    $minify //= 0; # 省略時は 0（改行あり）にする

    open(my $in_fh,  '<:encoding(UTF-8)', $in_file)  or die "Cannot open $in_file: $!";
    open(my $out_fh, '>:encoding(UTF-8)', $out_file) or die "Cannot open $out_file: $!";

    my $in_target = 0;
    my $div_depth = 0;

    while (my $line = <$in_fh>) {
        # 1. 抽出開始の判定
        if (!$in_target && $line =~ /<div\s+class="widget-archive widget-archive-category widget"/) {
            $in_target = 1;
        }

        # 2. 抽出中の処理
        if ($in_target) {
            # 行内の <div> と </div> の数を数えて階層を追跡（トリム前に実施）
            my $open_count  = () = $line =~ /<div\b[^>]*>/gi;
            my $close_count = () = $line =~ /<\/div>/gi;
            $div_depth += ($open_count - $close_count);

            # 改行と行頭・行末の空白（スペース・タブ）を削除
            $line =~ s/^\s+|\s+$//g;

            # 空行でなければ出力（$minify が真なら改行なし、偽ならLF付与）
            if ($line ne '') {
                print $out_fh $line . ($minify ? '' : "\n");
            }

            # 最初の <div class="widget-archive..."> に対応する </div> に到達したら終了
            if ($div_depth <= 0) {
                last;
            }
        }
    }

    close($in_fh);
    close($out_fh);
}


