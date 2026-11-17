#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(UTF-8)';
#use CGI;
use CGI qw(-utf8);
use DBI;

use lib qw( ./lib ./ ../mt/lib ../mt/extlib );
use HTML::Template;
use Encode qw(decode_utf8);
use HTML::Entities qw(encode_entities);

use MyApp::Entity::Entry;
use MyApp::Model::Entry;
use MyApp::Service::EntrySearch;
use MyApp::ToolMy;
use MyApp::Throttle;

package main;

# /cgi-bin/mt-user/my-search.cgi?blog_id=1&search=%
# /cgi-bin/mt-user/my-search.cgi?search=%25&IncludeBlogs=1&limit=20&offset=20
# /cgi-bin/mt-user/my-search.cgi?search=%25&IncludeBlogs=1&limit=20&offset=0&category=ROS2

my $q='';
my $keyword = '';
#my $category = 'ROS2';
my $category = '';
my $blog_id = 1;
my $limit = 20;
my $offset = 0;

our $script_url="/cgi-bin/mt-user/my-search.cgi";
our $common_query="";
our $tmpl_path = 'templates/search-result.tmpl';

our $session_cookie='';

if(1){
    $q = CGI->new;
    $session_cookie = MyApp::Throttle::check($q); # ★ ここで制限チェック＆クッキー取得

    #$keyword = decode_utf8($q->param('search') // '');
    $keyword = $q->param('search');
    #$category = decode_utf8($q->param('category') // '');
    $category = $q->param('category');
    $blog_id = int($q->param('IncludeBlogs') // 1);
    #$limit = int($q->param('limit') // 20);
    $offset = int($q->param('offset') // 0);
}
else{

}

#MyApp::ToolMy::exitError("search_fragment.cgi #1 \$keyword:".$keyword);

my %data = (
    keyword => $keyword,
    category => $category,
    blog_id => $blog_id,
    limit   => $limit,
    offset   => $offset
);

# 【おんちゃん流・関所】危険記号を独自規格コードへ一括変換 add by nishi 2026.11.9
foreach my $key ( qw( keyword category ) ) {
    my $val = $data{$key};
    if($val){
        $val = MyApp::ToolMy::encode_htcode($val);
        #$val =~ s/\-\-/&minusx;&minusx;/g; # コメントアウト
        #$val =~ s/\-\-/&#45;&#45;/g;
        #$val =~ s/</&lt;/g;                 # 小なり
        #$val =~ s/>/&gt;/g;                 # 大なり
        #$val =~ s/"/&quot;/g;               # ダブルクォート
        #$val =~ s/'/&#39;/g;               # シングルクォート（独自）
        #$val =~ s/=/&#61;/g;               # イコール（独自）
        $data{$key}=$val;
    }
}

foreach my $key ( qw( blog_id limit offset ) ) {
    my $val = $data{$key};
    next unless defined $val && ($val ne '');
    $val =~ s/[^0-9]//g;
    if ($val =~ /([0-9]+)/) {
        my $num = $1;  # "1500" が取得できる
        $val=$num;
    }
    $data{$key}=$val;
}

$keyword = $data{"keyword"};
$category = $data{"category"};

$blog_id = ($data{"blog_id"} ne '') ? $data{"blog_id"}: 1 ;
$limit   = ($data{"limit"} ne '') ? $data{"limit"}: 20;
$offset   = ($data{"offset"} ne '') ? $data{"offset"}: 0;

# /cgi-bin/mt-user/my-search.cgi?search=%25&IncludeBlogs=1&limit=20&offset=0&category=ROS2
$common_query="?search=".$keyword."&IncludeBlogs=".$blog_id."&category=".$category."&limit=".$limit;

#print("\$keyword:".$keyword."\n");
#print("\$category:".$category."\n");
#print("\$blog_id:".$blog_id."\n");
#print("\$offset:".$offset."\n");
#print("\$limit:".$limit."\n");

# MT 4.2x の SQLite3 データベースファイルへのパスを指定してください
my $db_path = '../mt/db/mt.db';

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=$db_path", "", "",
    {
        RaiseError     => 1,
        sqlite_unicode => 1,
        ReadOnly       => 1, # 検索専用なので読み取り専用でロック競合を防ぐ
    }
);

#MyApp::ToolMy::exitError("search_fragment.cgi #3");

# bless による各層の組み立て
my $entry_model    = MyApp::Model::Entry->new(dbh => $dbh);
my $search_service = MyApp::Service::EntrySearch->new(entry_model => $entry_model);

#exitError("search_fragment.cgi #4");
my $count=0;
my $items=[];

if($category){
    ($count,$items)=$search_service->category_search($blog_id, $keyword,$category,$limit, $offset);
}
else{
    # 検索実行
    ($count,$items) = $search_service->keyword_search($blog_id, $keyword, $limit, $offset);
}

# HTML 表示
if(0){
    display($q,$count,$items);
}
else{
    display_view($q,$count,$items,$keyword,$category,$offset);
}

$dbh->disconnect;
exit(0);

#---------
# 表示処理
# 入力パラメータ
#	$q : 
#	$count : 
#	$items : 
#---------
sub display{
	my ($q,$count,$items)=@_;
    # レスポンス出力（HTML断片）
    if($q ne ''){
        print $q->header(-type => 'text/html', -charset => 'UTF-8');
    }
    if (@$items) {
        for my $item (@$items) {
            my $title   = $item->{title};
            my $excerpt = $item->{excerpt};
            my $date    = $item->{date};
            my $url     = $item->{url};
            my $text_more_lng     = $item->{text_more_lng};
            print <<"HTML";
    <article class="entry-item">
        <h2><a href="$url">$title</a></h2>
        <p>$excerpt</p>
        <time>$date</time>
        <p>$text_more_lng</p>
    </article>
HTML
        }
    } 
    else {
        #my $safe_kw = encode_entities($keyword, '<>&"');
        my $safe_kw = MyApp::ToolMy::encode_htcode($keyword);
        print qq{<p class="no-result">「$safe_kw」に一致する記事は見つかりませんでした。</p>\n};
    }
}

sub make_pager{
 	my ($count,$limit,$offset)=@_;
    # --- 4. 【新設】「1 2 3...」の数字ページャーHTMLを自前でガチっと組み立てる ---
    my $my_pager_html = '';
    if ($count > 0 && $limit > 0) {
        # 総ページ数を計算（例：32件 / 20件 = 1.6 → 切り上げて 2 ページ）
        # Perlで簡単な切り上げ： int((総数 + 1件ずつマイナス1) / 件数)
        my $total_pages = int(($count + $limit - 1) / $limit);
        
        # 現在のページ番号（1から始まる）
        my $current_page = int($offset / $limit) + 1;

        for (my $i = 1; $i <= $total_pages; $i++) {
            my $this_offset = ($i - 1) * $limit;
            
            if ($i == $current_page) {
                # 現在見ているページは、リンクにせず太字にする
                $my_pager_html .= "<strong>$i</strong>&nbsp;";
            }
            else {
                # 他のページは、該当する offset を計算してリンクにする
                my $page_url = "${script_url}${common_query}&amp;offset=${this_offset}";
                $my_pager_html .= qq(<a href="$page_url">$i</a>&nbsp;);
            }
        }
    }
    return $my_pager_html;
}
#-----------
# テンプレートからの、serach 結果表示
#  templates/search-result.tmpl
#-----------
sub display_view{
	my ($q,$count,$items,$keyword,$category,$offset)=@_;

    # 画面に表示するラベルを決定（カテゴリ検索ならカテゴリ名、通常検索ならキーワード）
    my $display_label = ($category ne '') ? $category : $keyword;

    my $pager = make_pager($count,$limit,$offset);

    # テンプレートファイルを UTF-8 として読み込み、文字列リファレンスとして渡す
    #open my $fh, '<:encoding(UTF-8)', 'templates/search-result.tmpl' or die $!;
    open my $fh, '<:encoding(UTF-8)', $tmpl_path or die $!;
    my $tmpl_text = do { local $/; <$fh> };
    close $fh;

    # 2. 抽出済みのカテゴリナビゲーションHTMLの読み込み（UTF-8）
    my $cat_navi_path = 'templates/category_navi.txt';
    my $cat_navi_html = '';
    if (-e $cat_navi_path) {
        open my $cat_fh, '<:encoding(UTF-8)', $cat_navi_path or die "Cannot open $cat_navi_path: $!";
        $cat_navi_html = do { local $/; <$cat_fh> };
        close $cat_fh;
    }

    # テンプレートの読み込み
    my $tmpl = HTML::Template->new(
        scalarref         => \$tmpl_text, # ★ filename の代わりに scalarref を使う
        #filename          => 'templates/serach-result.tmpl',
        #utf8              => 1,      # UTF-8 ファイルを文字化けせずに読み込む
        #open_mode         => '<:encoding(UTF-8)', # ★ utf8 => 1 の代わりにこれを指定！
        #default_escape    => 'html', # すべての TMPL_VAR を自動でHTMLエスケープ（XSS対策）
        die_on_bad_params => 0,      # テンプレートに未使用の変数を渡してもエラーにしない
    );

    # テンプレート変数へ値をセット
    $tmpl->param(
        page_title   => ($display_label ne '' ? "「$display_label」の検索結果" : "検索結果"),
        search_label => $display_label,
        total_count  => $count, # count関数で取得した総件数
        entries      => $items,       # Service層が返したハッシュリファレンスの配列をそのまま渡す！
        pager        => $pager,
        category_navi => $cat_navi_html, # ★ カテゴリHTMLを流し込む
    );

    # 出力時にUTF-8へ変換する
    binmode STDOUT, ':encoding(UTF-8)';

    # レスポンス出力（HTML断片）
    if($q ne ''){
        print $q->header(
            -type => 'text/html',
            -charset => 'UTF-8',
            -cookie  => $session_cookie, # 発行されたクッキーをブラウザへ送信
        );
    }
    # 出力時にUTF-8へ変換する
    #binmode STDOUT, ':encoding(UTF-8)';
    print $tmpl->output;
}


