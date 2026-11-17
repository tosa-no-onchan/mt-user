package MT::Plugin::SearchPager;
use strict;

use vars qw( $MYNAME $VERSION );
$MYNAME = 'SearchPager';
$VERSION = '1.0';

use base qw( MT::Plugin );

my $plugin = __PACKAGE__->new({
    id  => $MYNAME,
    key => $MYNAME,
    name => $MYNAME,
    version => $VERSION,
    description => 'トップページに全件検索CGIへのページめくりリンクを吐き出すプラグイン',
    # 💡【ここがMT4の正しい登録方法！】
    # registry の中に、追加したいタグの種類と関数名を定義します。
    registry => {
        tags => {
            function => {
                'SearchPagerLinks' => \&_hdlr_search_pager_links,
            },
        },
    },
});
MT->add_plugin($plugin);
# リンクを自動計算して出力する実処理
sub _hdlr_search_pager_links {
    my ($ctx, $args) = @_;
    my $blog = $ctx->stash('blog') or return '';
    my $blog_id = $blog->id;

    # 💡1ページあたりの表示件数（デフォルトは20件）
    # 2. もしテンプレート側で limit="xx" と指定があれば、そちらを優先する
    # 3. どちらも無ければ最終手段として「20」にする
    my $limit = $args->{limit} || $blog->entries_on_index || 20;

    # 💡 テンプレート側から category="xx" が指定されたら取得する
    my $cat_id = $args->{category} || '';
    my $total_entries = 0;

    my $current_cat = $ctx->stash('archive_category');

    my $cat_label='';

    # 1. 💡【静的再構築時】まず「いまカテゴリの場所にいるか」をチェック
    if ( $current_cat ) {
        $cat_id        = $current_cat->id;
        $total_entries = $current_cat->entry_count();
        #my $path = $current_cat->category_label_path();
        $cat_label= $current_cat->label;
    }
    # 2. 💡【動的CGI（2ページ目以降）表示時】器が空っぽなら、URLの引数から直接引っこ抜く！
    else{

    }

    # 💡 3. カテゴリページじゃない（通常の全体検索）なら、今まで通りブログ全体の公開記事数をカウント
    if (!$total_entries) {
        $total_entries = MT->model('entry')->count({ blog_id => $blog_id, status => 2 });
    }

    return '' if $total_entries <= $limit;

    # 💡 4. URL用のカテゴリパラメータを作る
    #my $cat_param = $cat_id ? "&category_id=$cat_id&archive_type=Category" : "";
    #my $cat_param = $cat_id ? "&category_id=$cat_id&archive_type=category" : "";
    #my $cat_param = $cat_id ? "&category=$cat_id" : "";
    my $cat_param = $cat_id ? "&category=$cat_label" : "";

    my $html = '<div class="content-nav">';
    # 1ページ目（自分自身）はただの数字
    $html .= '<strong>1</strong>&nbsp;';

    # 2ページ目以降の数をループで計算してリンクを作る
    my $page = 2;
    my $offs=0;
    my $search_s ="";
    for (my $offset = $limit; $offset < $total_entries; $offset += $limit) {
        $offs= $limit * ($page-1);
        $search_s = "/cgi-bin/mt-user/my-search.cgi?search=%25&IncludeBlogs=".$blog_id."&limit=".$limit."&offset=".$offs . $cat_param;
        $html .= qq|<a href="$search_s">$page</a>&nbsp;|;
        $page++;
    }

    # 「次 ＞」のリンク（常に2ページ目のoffsetを指定）
    $offs= $limit * 1;
    $search_s = "/cgi-bin/mt-user/my-search.cgi?search=%25&IncludeBlogs=".$blog_id."&limit=".$limit."&offset=".$offs . $cat_param;
    $html .= qq|<a href="$search_s" rel="next">次 &gt;</a>|;
    $html .= '</div>';

    return $html;
}

1;
