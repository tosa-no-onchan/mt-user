package MyApp::Throttle;
use strict;
use warnings;

use Fcntl qw(:flock);
use Digest::SHA qw(sha256_hex);
use File::Path qw(make_path);

#-----------
# スロットル制御
#-----------
sub check {
    my ($q) = @_;
    my $window_sec   = 10; # 判定する時間枠（秒）
    my $max_requests = 5;  # 時間枠内の最大アクセス回数
    my $dir = (-d '/dev/shm' && -w '/dev/shm') ? '/dev/shm/mt_throttle' : '/tmp/mt_throttle';
    #my $dir = './tmp/mt_throttle';
    unless (-d $dir) {
        my $created = make_path($dir, {
            mode => 0766, # パーミッション（任意）
        });
    }

    # クッキー取得（なければ新規IDを生成）
    my $sid = $q->cookie('search_sid') || '';
    my $new_cookie;
    if ($sid !~ /^[a-f0-9]{32}$/) {
        $sid = sha256_hex(time() . $$ . rand() . ($ENV{REMOTE_ADDR} || ''));
        $sid = substr($sid, 0, 32);
        $new_cookie = $q->cookie(-name => 'search_sid', -value => $sid, -expires => '+1d', -httponly => 1);
    }

    # クッキー未保持（ボット等）はIPアドレスもキーに含めて連打を防ぐ
    my $key_raw = $q->cookie('search_sid') ? "sid:".$sid : "ip:" . ($ENV{REMOTE_ADDR} || 'unknown');
    my $file    = $dir."/" . sha256_hex($key_raw) . ".dat";
    my $now     = time();

    open(my $fh, '+>>', $file) or return $new_cookie;
    flock($fh, LOCK_EX);
    seek($fh, 0, 0);

    # 有効期限内のタイムスタンプだけ残す
    my @logs = grep { $_ > ($now - $window_sec) } map { chomp; $_ } <$fh>;
    push @logs, $now;

    # ファイルを書き戻す
    seek($fh, 0, 0);
    truncate($fh, 0);
    print $fh join("\n", @logs) . "\n";

    close($fh);

    # 上限オーバーなら 429 エラーを返して即終了
    if (scalar(@logs) > $max_requests) {
        print $q->header(-status => '429 Too Many Requests', -type => 'text/plain; charset=UTF-8');
        print "アクセスが集中しています。10秒ほど待ってから再度お試しください。\n";
        exit 0;
    }

    # 約5%の確率で10分以上古いゴミファイルを自動削除
    if (rand() < 0.05) {
        for my $old (glob("$dir/*.dat")) {
            unlink $old if (-M $old) * 86400 > 600;
        }
    }
    return $new_cookie; # 初回発行したクッキーを呼び出し元へ返す
}


1;